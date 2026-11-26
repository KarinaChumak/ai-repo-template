#!/usr/bin/env bash
# Runs init for every stack and mode, as a new project and into an existing repo, and checks the result.
# Runs init with the same bash as this script, so `/bin/bash tests/test-init.sh` tests macOS's bash 3.2.
set -euo pipefail

# --full also installs, checks, builds and e2e-tests every starter stack, and checks that its
# quick-check catches a type error and a React Compiler violation.
here=$(cd "$(dirname "$0")/.." && pwd)
bash_bin=${BASH:-bash}
full=0
[ "${1:-}" != "--full" ] || full=1

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "  FAIL: $*"
  failures=$((failures + 1))
}

# External notes go under this fake home, never the real ~/claude-notes.
notes_home=$work/home
mkdir -p "$notes_home"
run_init() {
  HOME=$notes_home "$bash_bin" "$@" >/dev/null
}

# A path from ai-setup.json on disk: ~/ is the fake home, anything else is inside the repo.
resolve() {
  case "$2" in "~/"*) echo "$notes_home/${2#"~/"}" ;; *) echo "$1/$2" ;; esac
}

# Exit code of a hook given a JSON input.
hook_exit() {
  local dir=$1 hook=$2 json=$3
  printf '%s' "$json" | CLAUDE_PROJECT_DIR=$dir TMPDIR=$work "$bash_bin" "$dir/.claude/hooks/$hook" >/dev/null 2>&1 && echo 0 || echo $?
}

check_result() {
  local dir=$1 label=$2 mode=$3 decisions f notes notes_dir
  notes=$(jq -r .notes "$dir/.claude/ai-setup.json")
  notes_dir=$(jq -r .notes_dir "$dir/.claude/ai-setup.json")
  decisions=${4:-$notes_dir/decisions.md}
  [ -f "$(resolve "$dir" "$decisions")" ] || fail "$label: no decision log at $decisions"
  if [ "$notes" = external ]; then
    [ "$notes_dir" = "~/claude-notes/$(basename "$dir" | tr -cd 'A-Za-z0-9._-')" ] || fail "$label: external notes at $notes_dir"
    [ ! -e "$dir/claude-notes" ] || fail "$label: claude-notes/ in the repo with external notes"
    jq -e --arg d "$notes_dir" '(.permissions.allow | index("Edit(\($d)/**)")) and (.permissions.additionalDirectories | index($d))' \
      "$dir/.claude/settings.json" >/dev/null || fail "$label: settings don't let Claude edit $notes_dir"
  else
    [ "$notes_dir" = claude-notes ] || fail "$label: in-repo notes at $notes_dir"
  fi
  for f in .claude/CLAUDE.md .claude/REVIEW.md .claude/settings.json .claude/protected-paths .claude/ai-setup.json \
    .claude/hooks/protect-paths.sh .claude/hooks/format.sh .claude/hooks/stop-check.sh .claude/hooks/ticket-context.sh \
    .claude/skills/kickoff/SKILL.md .claude/skills/plan-phase/SKILL.md .claude/skills/ticket/SKILL.md .claude/skills/finish/SKILL.md \
    .claude/skills/address-review/SKILL.md .claude/agents/reviewer.md .claude/pr-size-ignore \
    .github/workflows/pr-size.yml .claude/WORKFLOW.md \
    .github/pull_request_template.md .gitignore .worktreeinclude; do
    [ -e "$dir/$f" ] || fail "$label: missing $f"
  done
  if grep -rlE '__(PROJECT_NAME|PROJECT_TITLE|DECISIONS_FILE|NOTES_DIR)__' "$dir/.claude" >/dev/null 2>&1; then
    fail "$label: placeholder left in .claude/"
  fi
  [ ! -e "$dir/.github/workflows/claude-review.yml" ] || fail "$label: claude-review.yml without --ci-review"
  grep -qF "\`$decisions\`" "$dir/.claude/agents/reviewer.md" || fail "$label: the reviewer agent doesn't name $decisions"
  grep -qF "\`$decisions\`" "$dir/.claude/skills/kickoff/SKILL.md" || fail "$label: kickoff doesn't name $decisions"
  for f in setup check test fix quick-check ticket pr-size; do
    [ -x "$dir/.claude/scripts/$f" ] || fail "$label: .claude/scripts/$f missing or not executable"
  done
  for f in CLAUDE.md REVIEW.md DESIGN.md scripts; do
    [ ! -e "$dir/$f" ] || fail "$label: $f is at the repo root; it belongs in .claude/"
  done
  ! grep -q '@@STACK_\|__DECISIONS_FILE__' "$dir/.claude/CLAUDE.md" "$dir/.claude/REVIEW.md" ||
    fail "$label: unrendered placeholder"
  grep -qF "\`$decisions\`" "$dir/.claude/CLAUDE.md" || fail "$label: CLAUDE.md doesn't name $decisions"
  case "$decisions" in
    "~/"*) [ ! -e "$dir/.gitattributes" ] || fail "$label: .gitattributes for a decision log outside the repo" ;;
    *) grep -qxF "$decisions merge=union" "$dir/.gitattributes" || fail "$label: .gitattributes has no union merge for $decisions" ;;
  esac
  jq -e '.hooks.Stop and .hooks.PreToolUse and .hooks.PostToolUse and (.permissions.deny | index("Bash(gh pr merge *)"))' \
    "$dir/.claude/settings.json" >/dev/null || fail "$label: settings.json incomplete"
  jq -e '(.permissions.allow | index("Bash(git push -u origin *)") and index("Bash(gh pr create *)"))
    and (.permissions.deny | index("Bash(git push * main)") and index("Bash(git push *--force*)"))
    and ((.permissions.ask // []) | index("Bash(git push *)") | not)' \
    "$dir/.claude/settings.json" >/dev/null || fail "$label: Claude can't push its branch and open the PR on its own, or can push to main"
  jq -e '.permissions.deny | index("Bash(python3 - *)") and index("Bash(perl -pi *)") and index("Bash(node -e *)") and index("Bash(sed -i *)")' \
    "$dir/.claude/settings.json" >/dev/null || fail "$label: Claude can run inline scripts instead of the Edit tool"
  jq -e '(.permissions.ask // []) | index("Bash(pnpm add *)") | not' "$dir/.claude/settings.json" >/dev/null ||
    fail "$label: pnpm add asks every time"
  jq -e --arg d "$decisions" '.decisions_file == $d' "$dir/.claude/ai-setup.json" >/dev/null ||
    fail "$label: ai-setup.json doesn't record the decisions file"
  if [ "$mode" = team ]; then
    [ -f "$dir/.github/CODEOWNERS" ] || fail "$label: missing CODEOWNERS"
  else
    [ ! -f "$dir/.github/CODEOWNERS" ] || fail "$label: CODEOWNERS in solo mode"
  fi

  local code
  code=$(hook_exit "$dir" protect-paths.sh "{\"tool_input\":{\"file_path\":\"$dir/.github/workflows/x.yml\"}}")
  [ "$code" = 2 ] || fail "$label: protect-paths didn't block .github/workflows (exit $code)"
  code=$(hook_exit "$dir" protect-paths.sh "{\"tool_input\":{\"file_path\":\"$dir/src/app.ts\"}}")
  [ "$code" = 0 ] || fail "$label: protect-paths blocked src/app.ts (exit $code)"
}

# The Stop hook blocks while quick-check fails, gives up after 3 blocks, and resets once it passes.
check_stop_hook() {
  local dir=$1 label=$2 qc="$1/.claude/scripts/quick-check" saved codes="" i
  saved=$(cat "$qc")
  printf '#!/usr/bin/env bash\necho "type error" >&2\nexit 1\n' >"$qc"
  for i in 1 2 3 4; do
    codes="$codes$(hook_exit "$dir" stop-check.sh '{"session_id":"s1"}')"
  done
  [ "$codes" = 2220 ] || fail "$label: stop hook with failing quick-check gave exits $codes, want 2220"
  printf '%s\n' "$saved" >"$qc"
  [ "$(hook_exit "$dir" stop-check.sh '{"session_id":"s1"}')" = 0 ] || fail "$label: stop hook blocked a passing quick-check"
}

# Two branches that each add a decision merge without a conflict and keep both entries.
check_union_merge() {
  local dir=$1 label=$2 decisions=$3
  (
    cd "$dir"
    git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main; }
    git -c user.name=t -c user.email=t@t add -A
    git -c user.name=t -c user.email=t@t commit -qm init
    git checkout -qb a
    printf '\n## T-01 Number format\nShort numbers.\n' >>"$decisions"
    git -c user.name=t -c user.email=t@t commit -qam a
    git checkout -q main && git checkout -qb b
    printf '\n## T-02 Date range\nLast 30 days.\n' >>"$decisions"
    git -c user.name=t -c user.email=t@t commit -qam b
    git -c user.name=t -c user.email=t@t merge -q --no-edit a >/dev/null 2>&1
  ) || fail "$label: merging two branches that both added a decision failed"
  grep -q 'T-01' "$dir/$decisions" && grep -q 'T-02' "$dir/$decisions" || fail "$label: union merge lost an entry"
}

# A repo someone else made: a brief, data files, and optionally its own package.json. The README
# contains a placeholder on purpose: init must not fill in placeholders in the repo's own files.
make_real_repo() {
  local dir=$1 with_pkg=$2
  mkdir -p "$dir/jobs"
  git -C "$dir" init -q
  printf '# The brief\n\nBuild the flow. Keep `__PROJECT_NAME__` as is.\n' >"$dir/README.md"
  printf '{ "id": "short", "questions": [{ "id": "q1", "type": "boolean" }] }\n' >"$dir/jobs/short.json"
  printf '{ "name": "Ada" }\n' >"$dir/profile.json"
  if [ "$with_pkg" = 1 ]; then printf '{\n  "name": "their-task",\n  "private": true\n}\n' >"$dir/package.json"; fi
}

# Checksum of the repo's own files; package.json counts only if the repo had one.
fixture_sums() {
  local f files="README.md jobs/short.json profile.json"
  [ "$2" = 0 ] || files="$files package.json"
  for f in $files; do cat "$1/$f"; done | cksum
}

# A checksum of every file's path and content, outside .git and node_modules.
tree_sum() {
  (cd "$1" && find . \( -name .git -o -name node_modules \) -prune -o -type f -print | sort |
    while IFS= read -r f; do printf '%s\n' "$f"; cat "$f"; done | cksum)
}

new_project() {
  local dest=$1
  mkdir -p "$dest"
  (cd "$here" && tar --exclude=.git --exclude=.claude/worktrees --exclude=node_modules --exclude=docs -cf - .) | (cd "$dest" && tar -xf -)
}

for stack_dir in "$here"/stacks/*/; do
  stack=$(basename "$stack_dir")
  for mode in solo team; do
    label="$stack/$mode new"
    echo "== $label"
    copy="$work/new-$stack-$mode/My App"
    new_project "$copy"
    notes=external
    [ "$mode" = solo ] || notes=in-repo
    run_init "$copy/init" --stack "$stack" --mode "$mode" --notes "$notes"
    for f in core stacks team tests init README.md CLAUDE.md; do
      # A starter stack ships its own README.md.
      [ "$f" = README.md ] && [ -f "$stack_dir/README.md.tpl" ] && continue
      [ ! -e "$copy/$f" ] || fail "$label: template file $f left behind"
    done
    check_result "$copy" "$label" "$mode"
    if [ -d "$stack_dir/tree" ]; then
      while IFS= read -r f; do
        [ -e "$copy/${f#"$stack_dir/tree/"}" ] || fail "$label: missing ${f#"$stack_dir/tree/"} from the stack"
      done < <(find "$stack_dir/tree" -type f ! -name .DS_Store)
    fi
    if grep -rqE '__PROJECT_(NAME|TITLE)__' "$copy" --exclude-dir=node_modules; then fail "$label: placeholder left"; fi
    if [ -f "$copy/index.html" ]; then
      grep -qF '<title>My App</title>' "$copy/index.html" || fail "$label: page title isn't the project name 'My App'"
      grep -qF '"name": "my-app"' "$copy/package.json" || fail "$label: package name isn't the slug 'my-app'"
    fi
    check_stop_hook "$copy" "$label"

    label="$stack/$mode existing"
    echo "== $label"
    repo="$work/existing-$stack-$mode"
    mkdir -p "$repo/.claude"
    git -C "$repo" init -q
    echo "# Existing" >"$repo/CLAUDE.md"
    echo "dist/" >"$repo/.gitignore"
    echo '{"permissions":{"allow":["Bash(make build)"]},"model":"opus"}' >"$repo/.claude/settings.json"
    run_init "$here/init" --stack "$stack" --mode "$mode" --into "$repo"
    [ "$(cat "$repo/CLAUDE.md")" = "# Existing" ] || fail "$label: existing CLAUDE.md changed"
    [ ! -e "$repo/.claude/CLAUDE.md" ] || fail "$label: wrote .claude/CLAUDE.md next to an existing CLAUDE.md"
    [ -f "$repo/.claude/ai-setup-pending/CLAUDE.md" ] || fail "$label: no pending CLAUDE.md"
    [ -f "$repo/.claude/REVIEW.md" ] || fail "$label: missing .claude/REVIEW.md"
    jq -e '.model == "opus" and (.permissions.allow | index("Bash(make build)")) and (.permissions.allow | index("Bash(.claude/scripts/check)"))' \
      "$repo/.claude/settings.json" >/dev/null || fail "$label: settings.json not merged"
    [ "$(grep -cxF 'dist/' "$repo/.gitignore")" = 1 ] || fail "$label: .gitignore duplicated lines"
    before=$(cd "$repo" && find . -path ./.git -prune -o -type f -print | sort | xargs cat | cksum)
    run_init "$here/init" --stack "$stack" --mode "$mode" --into "$repo"
    after=$(cd "$repo" && find . -path ./.git -prune -o -type f -print | sort | xargs cat | cksum)
    [ "$before" = "$after" ] || fail "$label: running init again changed files"
  done

  label="$stack decisions at root"
  echo "== $label"
  repo="$work/decisions-$stack"
  mkdir -p "$repo"
  run_init "$here/init" --stack "$stack" --into "$repo" --decisions-file DECISIONS.md
  check_result "$repo" "$label" solo DECISIONS.md
  [ ! -e "$notes_home/claude-notes/decisions-$stack/decisions.md" ] || fail "$label: also wrote decisions.md in the notes"
  check_union_merge "$repo" "$label" DECISIONS.md

  for with_pkg in 0 1; do
    label="$stack into a real repo (package.json: $with_pkg)"
    echo "== $label"
    repo="$work/real-$stack-$with_pkg"
    make_real_repo "$repo" "$with_pkg"
    before=$(fixture_sums "$repo" "$with_pkg")
    run_init "$here/init" --stack "$stack" --into "$repo"
    [ "$(fixture_sums "$repo" "$with_pkg")" = "$before" ] || fail "$label: the repo's own files changed"
    check_result "$repo" "$label" solo
    pending="$repo/.claude/ai-setup-pending"
    if [ -f "$stack_dir/README.md.tpl" ]; then
      [ -f "$pending/README.md" ] || fail "$label: generated README.md not set aside"
      grep -qF '| `.claude/ai-setup-pending/README.md` | `README.md` |' "$pending/MERGE.md" 2>/dev/null ||
        fail "$label: MERGE.md doesn't list README.md"
    fi
    if [ "$with_pkg" = 1 ] && [ -f "$stack_dir/tree/package.json" ]; then
      [ -f "$pending/package.json" ] || fail "$label: generated package.json not set aside"
      grep -qF '| `.claude/ai-setup-pending/package.json` | `package.json` |' "$pending/MERGE.md" 2>/dev/null ||
        fail "$label: MERGE.md doesn't list package.json"
    fi
    [ -f "$stack_dir/README.md.tpl" ] || [ ! -e "$pending" ] || fail "$label: set files aside for no reason"
    grep -qxF '.claude/ai-setup-pending/' "$repo/.gitignore" || fail "$label: pending folder isn't gitignored"
    grep -qxF '.claude/launch.json' "$repo/.gitignore" || fail "$label: .claude/launch.json isn't gitignored"
    before=$(tree_sum "$repo")
    run_init "$here/init" --stack "$stack" --into "$repo"
    [ "$(tree_sum "$repo")" = "$before" ] || fail "$label: running init again changed files"
  done
done

echo "== none: root holds only files other tools require"
root=$(cd "$work/new-none-solo/My App" && ls -A | sort | tr '\n' ' ')
[ "$root" = ".claude .github .gitignore .worktreeinclude " ] || fail "none, external notes: unexpected files at root: $root"
root=$(cd "$work/new-none-team/My App" && ls -A | sort | tr '\n' ' ')
[ "$root" = ".claude .gitattributes .github .gitignore .worktreeinclude claude-notes " ] || fail "none, in-repo notes: unexpected files at root: $root"

echo "== ticket: parallel tickets get their own worktree, branch and port"
origin="$work/ticket-origin.git"
repo="$work/ticket-repo"
mkdir -p "$repo"
repo=$(cd "$repo" && pwd -P)
run_init "$here/init" --stack none --into "$repo" --notes in-repo
(
  cd "$repo"
  git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main; }
  mkdir -p claude-notes
  printf '# Plan\n\n## Phase 1: Skeleton\n\n### T-01 Sign in\n\n- Status: todo\n\n### T-010 Other\n\n- Status: todo\n\n### T-02 Dashboard\n\n- Status: todo\n\n## Notes\n\nnot a ticket\n' >claude-notes/plan.md
  git -c user.name=t -c user.email=t@t add -A
  git -c user.name=t -c user.email=t@t commit -qm init
  git clone -q --bare . "$origin" && git remote add origin "$origin" && git fetch -q origin
  echo 'SECRET=1' >.env
) || fail "ticket: setting up the repo failed"
t1=$(cd "$repo" && "$bash_bin" .claude/scripts/ticket start T-01 "Sign In!") || fail "ticket: start T-01 failed"
# A commit on main that isn't pushed yet: the next ticket starts from it, not from origin/main.
(cd "$repo" && echo local >local.txt && git add local.txt && git -c user.name=t -c user.email=t@t commit -qm local)
t2=$(cd "$repo" && "$bash_bin" .claude/scripts/ticket start T-02 dashboard) || fail "ticket: start T-02 failed"
field() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }
[ "$(field "$t1" path)" = "$repo/.claude/worktrees/T-01" ] || fail "ticket: T-01 path is $(field "$t1" path)"
[ "$(field "$t1" branch)" = T-01-sign-in ] || fail "ticket: T-01 branch is $(field "$t1" branch)"
[ "$(field "$t2" branch)" = T-02-dashboard ] || fail "ticket: T-02 branch is $(field "$t2" branch)"
[ -f "$repo/.claude/worktrees/T-02/local.txt" ] || fail "ticket: T-02 didn't start from the local main that is ahead of origin"
[ "$(field "$t1" port)" != "$(field "$t2" port)" ] || fail "ticket: both tickets got port $(field "$t1" port)"
[ "$(field "$t1" new)" = yes ] || fail "ticket: first start of T-01 isn't new"
[ "$(git -C "$repo" branch --show-current)" = main ] || fail "ticket: the main checkout left main"
[ -z "$(git -C "$repo" status --porcelain)" ] || fail "ticket: the main checkout has changes: $(git -C "$repo" status --porcelain)"
[ "$(cat "$repo/.claude/worktrees/T-01/.env" 2>/dev/null)" = SECRET=1 ] || fail "ticket: .env wasn't copied into the worktree"
again=$(cd "$repo/.claude/worktrees/T-02" && "$bash_bin" .claude/scripts/ticket start T-01) || fail "ticket: starting T-01 again failed"
[ "$(field "$again" new)" = no ] && [ "$(field "$again" port)" = "$(field "$t1" port)" ] ||
  fail "ticket: starting T-01 again from another worktree gave: $again"
if (cd "$repo" && "$bash_bin" .claude/scripts/ticket start '../x' >/dev/null 2>&1); then fail "ticket: accepted the ID ../x"; fi
ctx=$(CLAUDE_PROJECT_DIR="$repo/.claude/worktrees/T-01" "$bash_bin" "$repo/.claude/hooks/ticket-context.sh")
printf '%s\n' "$ctx" | grep -qF '### T-01 Sign in' || fail "ticket: SessionStart hook didn't print T-01's section"
if printf '%s\n' "$ctx" | grep -qE 'T-010|T-02|Phase|Notes'; then fail "ticket: hook printed more than T-01's section: $ctx"; fi
[ -z "$(CLAUDE_PROJECT_DIR=$repo "$bash_bin" "$repo/.claude/hooks/ticket-context.sh")" ] || fail "ticket: hook printed something on main"
git -C "$repo/.claude/worktrees/T-02" checkout -q -b T-010-other
ctx=$(CLAUDE_PROJECT_DIR="$repo/.claude/worktrees/T-02" "$bash_bin" "$repo/.claude/hooks/ticket-context.sh")
printf '%s\n' "$ctx" | grep -qF '### T-010 Other' || fail "ticket: hook on branch T-010-other didn't pick T-010: $ctx"
(cd "$repo" && "$bash_bin" .claude/scripts/ticket remove T-01 >/dev/null) || fail "ticket: remove T-01 failed"
[ ! -e "$repo/.claude/worktrees/T-01" ] || fail "ticket: remove left the worktree"
if git -C "$repo" rev-parse -q --verify T-01-sign-in >/dev/null; then fail "ticket: remove kept the merged branch"; fi
# A commit pushed from elsewhere: once origin/main is ahead, the next ticket starts from it.
(
  git clone -q "$origin" "$work/ticket-other" && cd "$work/ticket-other" && git pull -q "$repo" main &&
    echo remote >remote.txt && git add remote.txt && git -c user.name=t -c user.email=t@t commit -qm remote && git push -q origin HEAD:main
) || fail "ticket: pushing from another clone failed"
t3=$(cd "$repo" && "$bash_bin" .claude/scripts/ticket start T-03) || fail "ticket: start T-03 failed"
[ -f "$repo/.claude/worktrees/T-03/remote.txt" ] || fail "ticket: T-03 didn't start from origin/main when it was ahead"
[ "$(field "$t3" port)" = "$(field "$t1" port)" ] || fail "ticket: T-03 didn't reuse the freed port"

echo "== external notes: the hook reads them, and running init again keeps them"
repo="$work/ext-repo"
mkdir -p "$repo"
run_init "$here/init" --stack none --into "$repo"
notes="$notes_home/claude-notes/ext-repo"
printf '\n## T-01: Kept\nA decision.\n' >>"$notes/decisions.md"
printf '# Plan\n\n### T-07 Export a report\n\n- Status: todo\n' >"$notes/plan.md"
run_init "$here/init" --stack none --into "$repo"
grep -qF '## T-01: Kept' "$notes/decisions.md" || fail "external notes: running init again replaced the decision log"
(cd "$repo" && git init -q && git checkout -q -b T-07-report)
ctx=$(HOME=$notes_home CLAUDE_PROJECT_DIR=$repo "$bash_bin" "$repo/.claude/hooks/ticket-context.sh")
printf '%s\n' "$ctx" | grep -qF '### T-07 Export a report' || fail "external notes: the hook didn't print T-07 from ~/claude-notes: $ctx"
if "$bash_bin" "$here/init" --stack none --into "$repo" --notes elsewhere >/dev/null 2>&1; then fail "accepted --notes elsewhere"; fi

echo "== pr-size: counts the branch's lines, skips ignored files, fails over the limit"
repo="$work/size-repo"
mkdir -p "$repo"
run_init "$here/init" --stack none --into "$repo"
lines() { i=0; while [ "$i" -lt "$1" ]; do echo "line $i"; i=$((i + 1)); done; }
size() { (cd "$repo" && PR_SIZE_LIMIT=${limit:-500} "$bash_bin" .claude/scripts/pr-size main 2>&1); }
(
  cd "$repo"
  git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main; }
  echo 'src/generated/*' >>.claude/pr-size-ignore
  git -c user.name=t -c user.email=t@t add -A
  git -c user.name=t -c user.email=t@t commit -qm init
  git checkout -qb T-01-size
  mkdir -p src/generated/deep claude-notes
  lines 300 >src/a.ts
  lines 2000 >pnpm-lock.yaml
  lines 900 >src/generated/deep/api.ts
  lines 100 >claude-notes/plan.md
  git -c user.name=t -c user.email=t@t add -A
  git -c user.name=t -c user.email=t@t commit -qm a
) || fail "pr-size: setting up the repo failed"
out=$(size) || fail "pr-size: failed at 300 lines: $out"
printf '%s\n' "$out" | grep -qF 'pr-size: 300 changed lines against main (limit 500); 3000 more in ignored files' ||
  fail "pr-size: wrong count: $out"
lines 250 >"$repo/src/b.ts"
if out=$(size); then fail "pr-size: passed at 550 lines, counting the untracked file: $out"; fi
printf '%s\n' "$out" | grep -qF 'size-exception' || fail "pr-size: no advice when over the limit: $out"
out=$(limit=600 size) || fail "pr-size: PR_SIZE_LIMIT=600 didn't raise the limit: $out"
rm "$repo/src/b.ts"
sed -i.bak '1,200d' "$repo/src/a.ts" && rm "$repo/src/a.ts.bak"
(cd "$repo" && git -c user.name=t -c user.email=t@t commit -qam shrink)
out=$(size)
printf '%s\n' "$out" | grep -qF 'pr-size: 100 changed lines' || fail "pr-size: deleted lines on the branch aren't counted: $out"
(cd "$repo" && git mv .claude/WORKFLOW.md WORKFLOW-moved.md && echo moved >>WORKFLOW-moved.md &&
  git -c user.name=t -c user.email=t@t commit -qam rename)
out=$(size)
printf '%s\n' "$out" | grep -qF 'pr-size: 101 changed lines' || fail "pr-size: a renamed file with one new line isn't counted as 1 line: $out"

echo "== --ci-review adds the Claude review workflow"
repo="$work/ci-review"
mkdir -p "$repo"
run_init "$here/init" --stack none --into "$repo" --ci-review
grep -qF 'anthropics/claude-code-action@' "$repo/.github/workflows/claude-review.yml" || fail "ci-review: no claude-review.yml"
grep -qE 'claude-code-action@[0-9a-f]{40}' "$repo/.github/workflows/claude-review.yml" || fail "ci-review: action isn't pinned to a SHA"
jq -e '.ci_review == true' "$repo/.claude/ai-setup.json" >/dev/null || fail "ci-review: ai-setup.json doesn't record it"

echo "== workflows pass actionlint"
if command -v actionlint >/dev/null; then
  actionlint "$here"/core/tree/.github/workflows/*.yml "$here"/core/ci-review/*.yml "$here"/stacks/*/tree/.github/workflows/*.yml ||
    fail "actionlint found problems"
else
  echo "  skipped: actionlint isn't installed"
fi

echo "== every agent has a name matching its file, a description and tools"
for agent in "$here"/core/tree/.claude/agents/*.md; do
  grep -qxF "name: $(basename "$agent" .md)" "$agent" || fail "$agent: name doesn't match the file"
  grep -qE '^description: .{40,}' "$agent" || fail "$agent: description missing or too short"
  grep -qE '^tools: ' "$agent" || fail "$agent: no tools list"
done

echo "== every skill has a name matching its folder and a description"
while IFS= read -r skill; do
  folder=$(basename "$(dirname "$skill")")
  [ "$(sed -n '1p' "$skill")" = --- ] || fail "$skill: no frontmatter"
  grep -qxF "name: $folder" "$skill" || fail "$skill: name isn't '$folder'"
  grep -qE '^description: .{40,}' "$skill" || fail "$skill: description missing or too short to trigger on"
  for link in $(grep -oE '\]\([a-z./-]+\.md\)' "$skill" | tr -d '])('); do
    [ -f "$(dirname "$skill")/$link" ] || fail "$skill: links to missing $link"
  done
done < <(find "$here/core" "$here/stacks" -path '*/.claude/skills/*/SKILL.md')

echo "== bad --decisions-file values are refused"
for bad in /abs.md ../up.md 'a b.md' dir/; do
  if "$bash_bin" "$here/init" --stack none --into "$work" --decisions-file "$bad" >/dev/null 2>&1; then
    fail "accepted --decisions-file '$bad'"
  fi
done

# quick-check must fail with the given file added, and pass again once it's removed.
expect_quick_check_fails() {
  local app=$1 label=$2 file=$3 body=$4
  printf '%s\n' "$body" >"$app/$file"
  if (cd "$app" && .claude/scripts/quick-check >/dev/null 2>&1); then fail "$label: quick-check passed with $file"; fi
  rm "$app/$file"
}

if [ "$full" -eq 1 ]; then
  for stack_dir in "$here"/stacks/*/; do
    stack=$(basename "$stack_dir")
    [ -d "$stack_dir/tree" ] || continue
    label="$stack full"
    echo "== $label"
    app="$work/new-$stack-solo/My App"
    (
      cd "$app"
      git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main; }
      git -c user.name=t -c user.email=t@t add -A
      git -c user.name=t -c user.email=t@t commit -qm init
      .claude/scripts/setup --frozen-lockfile >/dev/null
      .claude/scripts/check >/dev/null
      .claude/scripts/quick-check >/dev/null
    ) || fail "$label: setup, check or quick-check failed on a fresh project"
    (cd "$work/real-$stack-0" && .claude/scripts/setup --frozen-lockfile >/dev/null && .claude/scripts/check >/dev/null) ||
      fail "$label: setup or check failed after init into a repo with its own README and data files"
    if [ "$stack" = react-vite ]; then
      expect_quick_check_fails "$app" "$label" src/bad-type.ts 'export const n: number = "x";'
      expect_quick_check_fails "$app" "$label" src/BadRef.tsx "import { useRef } from 'react';
export function BadRef() {
  const ref = useRef(0);
  ref.current += 1;
  return <p>{ref.current}</p>;
}"
      printf '.x {\n  color: #ff0000;\n  padding: 13px;\n  border: 1px solid;\n}\n' >"$app/src/x.css"
      raw=$(cd "$app" && .claude/scripts/raw-styles || true)
      [ "$(printf '%s\n' "$raw" | grep -c .)" = 2 ] || fail "$label: raw-styles should flag the hex color and 13px, got: $raw"
      rm "$app/src/x.css"
      (cd "$app" && .claude/scripts/raw-styles >/dev/null) || fail "$label: raw-styles flagged the clean starter app"
      # Pages and features have no styles or HTML elements; tests mock neither fetch nor console.
      mkdir -p "$app/src/pages/BadPage" "$app/src/features/bad"
      : >"$app/src/pages/BadPage/BadPage.css"
      printf "import './BadPage.css';\n\nexport function BadPage() {\n  return <div className=\"x\">x</div>;\n}\n" >"$app/src/pages/BadPage/BadPage.tsx"
      printf "it('x', () => {\n  vi.stubGlobal('fetch', vi.fn());\n  vi.spyOn(console, 'warn');\n});\n" >"$app/src/features/bad/bad.test.ts"
      lint=$(cd "$app" && pnpm -s exec eslint src/pages/BadPage src/features/bad 2>&1 || true)
      for want in 'have no styles. Put them' 'render only components' 'Give the component' 'Mock the network with MSW' "Don't mock console"; do
        printf '%s\n' "$lint" | grep -qF "$want" || fail "$label: ESLint didn't flag: $want"
      done
      rm -rf "$app/src/pages/BadPage" "$app/src/features"
      # The desktop app's launch.json is gitignored, so the formatter skips it.
      printf '{"version":"0.0.1",\n"configurations":[]}\n' >"$app/.claude/launch.json"
      (cd "$app" && pnpm -s format:check >/dev/null) || fail "$label: format:check flagged .claude/launch.json"
      rm "$app/.claude/launch.json"
      # check installs like CI does, so a lockfile out of step with package.json fails it.
      cp "$app/package.json" "$work/package.json.bak"
      jq '.dependencies["left-pad"] = "1.3.0"' "$work/package.json.bak" >"$app/package.json"
      out=$(cd "$app" && .claude/scripts/check 2>&1) && fail "$label: check passed with a lockfile out of date"
      printf '%s\n' "$out" | grep -q OUTDATED_LOCKFILE || fail "$label: check didn't fail on the install: $out"
      cp "$work/package.json.bak" "$app/package.json"
      # A port of its own: Playwright reuses a server already on the port, even another project's.
      (cd "$app" && pnpm exec playwright install chromium >/dev/null && PORT=5299 .claude/scripts/e2e >/dev/null) ||
        fail "$label: e2e failed"
    fi
  done
fi

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "All checks passed"
