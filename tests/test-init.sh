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

run_init() {
  "$bash_bin" "$@" >/dev/null
}

# Exit code of a hook given a JSON input.
hook_exit() {
  local dir=$1 hook=$2 json=$3
  printf '%s' "$json" | CLAUDE_PROJECT_DIR=$dir TMPDIR=$work "$bash_bin" "$dir/.claude/hooks/$hook" >/dev/null 2>&1 && echo 0 || echo $?
}

check_result() {
  local dir=$1 label=$2 mode=$3 decisions=${4:-.claude/decisions.md} f
  for f in .claude/CLAUDE.md .claude/REVIEW.md .claude/settings.json .claude/protected-paths .claude/ai-setup.json \
    .claude/hooks/protect-paths.sh .claude/hooks/format.sh .claude/hooks/stop-check.sh \
    .github/pull_request_template.md .gitignore .gitattributes .worktreeinclude "$decisions"; do
    [ -e "$dir/$f" ] || fail "$label: missing $f"
  done
  for f in setup check test fix quick-check; do
    [ -x "$dir/.claude/scripts/$f" ] || fail "$label: .claude/scripts/$f missing or not executable"
  done
  for f in CLAUDE.md REVIEW.md DESIGN.md scripts; do
    [ ! -e "$dir/$f" ] || fail "$label: $f is at the repo root; it belongs in .claude/"
  done
  ! grep -q '@@STACK_\|__DECISIONS_FILE__' "$dir/.claude/CLAUDE.md" "$dir/.claude/REVIEW.md" ||
    fail "$label: unrendered placeholder"
  grep -qF "\`$decisions\`" "$dir/.claude/CLAUDE.md" || fail "$label: CLAUDE.md doesn't name $decisions"
  grep -qxF "$decisions merge=union" "$dir/.gitattributes" || fail "$label: .gitattributes has no union merge for $decisions"
  jq -e '.hooks.Stop and .hooks.PreToolUse and .hooks.PostToolUse and (.permissions.deny | index("Bash(gh pr merge *)"))' \
    "$dir/.claude/settings.json" >/dev/null || fail "$label: settings.json incomplete"
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

new_project() {
  local dest=$1
  mkdir -p "$dest"
  (cd "$here" && tar --exclude=.git --exclude=node_modules --exclude=docs -cf - .) | (cd "$dest" && tar -xf -)
}

for stack_dir in "$here"/stacks/*/; do
  stack=$(basename "$stack_dir")
  for mode in solo team; do
    label="$stack/$mode new"
    echo "== $label"
    copy="$work/new-$stack-$mode/My App"
    new_project "$copy"
    run_init "$copy/init" --stack "$stack" --mode "$mode"
    for f in core stacks team tests init README.md CLAUDE.md; do
      # A starter stack ships its own README.md.
      [ "$f" = README.md ] && [ -f "$stack_dir/README.md.tpl" ] && continue
      [ ! -e "$copy/$f" ] || fail "$label: template file $f left behind"
    done
    check_result "$copy" "$label" "$mode"
    if grep -rqF __PROJECT_NAME__ "$copy" --exclude-dir=node_modules; then fail "$label: placeholder left"; fi
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
  [ ! -e "$repo/.claude/decisions.md" ] || fail "$label: also wrote .claude/decisions.md"
  check_union_merge "$repo" "$label" DECISIONS.md
done

echo "== none: root holds only files other tools require"
root=$(cd "$work/new-none-solo/My App" && ls -A | sort | tr '\n' ' ')
[ "$root" = ".claude .gitattributes .github .gitignore .worktreeinclude " ] || fail "none: unexpected files at root: $root"

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
    if [ "$stack" = react-vite ]; then
      expect_quick_check_fails "$app" "$label" src/bad-type.ts 'export const n: number = "x";'
      expect_quick_check_fails "$app" "$label" src/BadRef.tsx "import { useRef } from 'react';
export function BadRef() {
  const ref = useRef(0);
  ref.current += 1;
  return <p>{ref.current}</p>;
}"
      (cd "$app" && pnpm exec playwright install chromium >/dev/null && .claude/scripts/e2e >/dev/null) ||
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
