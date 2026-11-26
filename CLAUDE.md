# This repo

The source of `ai-repo-template`. `init` renders `core/`, `stacks/<name>/` and `team/` into a target repo, with the whole AI setup under `.claude/`. This file is for working on the template; generated repos get `core/CLAUDE.md` rendered into `.claude/CLAUDE.md` instead.

# Commands

- Test every stack and mode on macOS's bash: /bin/bash tests/test-init.sh
- Also install, check, build and e2e-test the starter stacks: /bin/bash tests/test-init.sh --full
- Try one: ./init --stack <name> --into "$(mktemp -d)"
- Test the user-level installer: /bin/bash tests/test-install-user.sh

# Conventions

- `init`, `tests/test-init.sh`, hooks and stack scripts must run on macOS's bash 3.2: no associative arrays, no `mapfile`, and guard empty-array expansions.
- Generated repos keep AI config in `.claude/`, always committed. The files Claude updates constantly (`plan.md`, `product.md`, `decisions.md`) are the notes, kept out of `.claude/` because Claude Code asks before every edit there. `--notes external` (the default) puts them in `~/claude-notes/<repo>/`, never committed; `--notes in-repo` puts them in `claude-notes/`. The only other files `init` may put at the root are ones another tool requires there: `.gitignore`, `.gitattributes` (only for a decision log in the repo), `.worktreeinclude`, `.github/`, and a decisions file if `--decisions-file` asks for it.
- `core/CLAUDE.md` and `core/REVIEW.md` hold `@@STACK_<NAME>@@` lines, each replaced by `stacks/<stack>/claude/<name>.md` or removed if that file doesn't exist, `__DECISIONS_FILE__`, replaced by the decision log's path, and `__NOTES_DIR__`, replaced by the notes folder. Every core file can use the last two.
- Hooks, skills and CI call only `.claude/scripts/*`, never a stack's tools directly, so `core/` stays stack-agnostic.
- Generated guidance follows Anthropic's best practices: short CLAUDE.md, no emphasis words, deterministic rules in hooks, everything else in skills and rules.
- Every change to `init` gets a check in `tests/test-init.sh`.
- Open pull requests, never merge them.

# Gotchas

- `init` without `--into` deletes the template's own files, including this one. Test with `--into` or on a copy, as `tests/test-init.sh` does.
- `docs/` is the maintainer's local working folder and isn't committed.
