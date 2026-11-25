#!/usr/bin/env bash
# Tests install-user against temporary home directories, never the real ~/.claude.
# Runs install-user with the same bash as this script, so `/bin/bash tests/test-install-user.sh` tests macOS's bash 3.2.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
bash_bin=${BASH:-bash}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0
snippet=$here/user/CLAUDE.md.snippet

fail() {
  echo "  FAIL: $*"
  failures=$((failures + 1))
}

install() {
  "$bash_bin" "$here/install-user" "$@" >"$work/out" 2>&1
}

new_home() {
  local h=$work/$1
  mkdir -p "$h"
  echo "$h"
}

# Checksums of every file under a directory, to compare before and after.
snapshot() {
  (cd "$1" && find . -type f | LC_ALL=C sort | while read -r f; do cksum "$f"; done)
}

echo "Fresh home"
h=$(new_home fresh)
install --home "$h" || fail "fresh: install-user failed: $(cat "$work/out")"
cmp -s "$h/.claude/PROFILE.md" "$here/user/PROFILE.md" || fail "fresh: PROFILE.md not copied"
cmp -s "$h/.claude/CLAUDE.md" "$snippet" || fail "fresh: CLAUDE.md isn't the snippet"
grep -q "PROFILE.md" "$work/out" || fail "fresh: output doesn't say what it did"
install --home "$h" || fail "fresh: second run failed with the block on line 1: $(cat "$work/out")"
cmp -s "$h/.claude/CLAUDE.md" "$snippet" || fail "fresh: second run changed CLAUDE.md"

echo "Existing CLAUDE.md and PROFILE.md"
h=$(new_home existing)
mkdir -p "$h/.claude"
printf '# Mine\n\nKeep this line.\n' >"$h/.claude/CLAUDE.md"
printf 'my profile' >"$h/.claude/PROFILE.md"
cp "$h/.claude/CLAUDE.md" "$work/before"
install --home "$h" || fail "existing: install-user failed: $(cat "$work/out")"
[ "$(cat "$h/.claude/PROFILE.md")" = "my profile" ] || fail "existing: PROFILE.md overwritten"
{ cat "$work/before"; printf '\n'; cat "$snippet"; } >"$work/expected"
cmp -s "$h/.claude/CLAUDE.md" "$work/expected" || fail "existing: content not kept, or snippet not appended after a blank line"

echo "No trailing newline"
h=$(new_home no-newline)
mkdir -p "$h/.claude"
printf 'last line' >"$h/.claude/CLAUDE.md"
install --home "$h" || fail "no-newline: install-user failed"
{ printf 'last line\n\n'; cat "$snippet"; } >"$work/expected"
cmp -s "$h/.claude/CLAUDE.md" "$work/expected" || fail "no-newline: snippet joined onto the last line"

echo "Running twice"
h=$(new_home twice)
mkdir -p "$h/.claude"
printf 'before\n' >"$h/.claude/CLAUDE.md"
install --home "$h"
cp "$h/.claude/CLAUDE.md" "$work/once"
install --home "$h" || fail "twice: second run failed"
cmp -s "$h/.claude/CLAUDE.md" "$work/once" || fail "twice: second run changed CLAUDE.md"
grep -q "up to date" "$work/out" || fail "twice: second run doesn't say the block is up to date"
[ "$(grep -c 'ai-repo-template:start' "$h/.claude/CLAUDE.md")" = 1 ] || fail "twice: block duplicated"

echo "Changed snippet"
# A copy of the template with a different snippet, as a later version of it would have.
tpl=$work/template
mkdir -p "$tpl/user"
cp "$here/install-user" "$tpl/"
cp "$here/user/PROFILE.md" "$tpl/user/"
{
  echo '<!-- ai-repo-template:start -->'
  echo '- A new rule.'
  echo '<!-- ai-repo-template:end -->'
} >"$tpl/user/CLAUDE.md.snippet"
h=$(new_home changed)
mkdir -p "$h/.claude"
{ printf 'above\n\n'; cat "$snippet"; printf '\nbelow, no newline'; } >"$h/.claude/CLAUDE.md"
"$bash_bin" "$tpl/install-user" --home "$h" >"$work/out" 2>&1 || fail "changed: install-user failed: $(cat "$work/out")"
{ printf 'above\n\n'; cat "$tpl/user/CLAUDE.md.snippet"; printf '\nbelow, no newline'; } >"$work/expected"
cmp -s "$h/.claude/CLAUDE.md" "$work/expected" || fail "changed: block not replaced, or text around it changed"

echo "Dry run"
h=$(new_home dry)
mkdir -p "$h/.claude"
printf 'mine\n' >"$h/.claude/CLAUDE.md"
before=$(snapshot "$h")
install --home "$h" --dry-run || fail "dry: install-user failed"
[ "$(snapshot "$h")" = "$before" ] || fail "dry: files changed"
grep -q "Would append" "$work/out" || fail "dry: doesn't say what it would append"
grep -q "Would copy" "$work/out" || fail "dry: doesn't say it would copy PROFILE.md"
h=$(new_home dry-empty)
install --home "$h" --dry-run || fail "dry-empty: install-user failed"
[ ! -e "$h/.claude" ] || fail "dry-empty: created .claude/"

echo "Broken markers"
h=$(new_home broken)
mkdir -p "$h/.claude"
printf '<!-- ai-repo-template:start -->\nno end\n' >"$h/.claude/CLAUDE.md"
cp "$h/.claude/CLAUDE.md" "$work/before"
! install --home "$h" || fail "broken: accepted a start marker without an end"
cmp -s "$h/.claude/CLAUDE.md" "$work/before" || fail "broken: changed CLAUDE.md"

echo "Symlinked CLAUDE.md"
h=$(new_home symlink)
mkdir -p "$h/.claude" "$h/dotfiles"
printf 'linked\n' >"$h/dotfiles/CLAUDE.md"
ln -s "$h/dotfiles/CLAUDE.md" "$h/.claude/CLAUDE.md"
install --home "$h" || fail "symlink: install-user failed"
[ -L "$h/.claude/CLAUDE.md" ] || fail "symlink: link replaced by a file"
grep -q 'ai-repo-template:start' "$h/dotfiles/CLAUDE.md" || fail "symlink: target not updated"

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)."
  exit 1
fi
echo "All install-user tests passed."
