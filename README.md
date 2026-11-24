# ai-repo-template

A Claude Code setup for new and existing repos, built for big, ambiguous projects worked on in parallel. It follows Anthropic's guidance: [best practices](https://code.claude.com/docs/en/best-practices) and [verification loops with skills](https://claude.com/resources/articles/building-verification-loops-in-claude-code-with-skills).

It's a point-in-time template, not a library. `init` writes the setup into a repo, and from then on that repo owns it and changes it freely. Nothing syncs back.

The whole setup lives in `.claude/`, so it never mixes with your code.

## Start a new project

```bash
gh repo create my-app --private --template <you>/ai-repo-template --clone
cd my-app
./init --stack none
git add -A && git commit -m "Add AI setup from ai-repo-template"
```

`init` without flags asks for the stack and mode. In this mode it removes the template's own files (`init`, `core/`, `stacks/`, `team/`, `tests/`, this README), so the result is a plain project.

## Add the setup to an existing repo

```bash
git clone https://github.com/<you>/ai-repo-template ~/Code/ai-repo-template
~/Code/ai-repo-template/init --stack none --into ~/Code/my-existing-repo
```

- **Existing files are kept**, and the ones it skipped are listed. `--force` overwrites them.
- **`.claude/settings.json` is merged:** your permissions and hooks stay, and the template's are added.
- **`.gitignore`, `.gitattributes`, `.worktreeinclude` and `.claude/protected-paths`** get the missing lines appended.
- **If the repo already has a `CLAUDE.md` or `REVIEW.md`** (at the root or in `.claude/`), the generated versions go to `.claude/ai-setup-pending/`, and `init` prints a prompt to have Claude merge them.
- **Running it again is safe:** nothing gets duplicated.

## Options

| Option | Default | |
| --- | --- | --- |
| `--stack <name>` | asked | See the table below |
| `--mode solo\|team` | `solo` | `team` adds `.github/CODEOWNERS` so `.claude/` and `.github/` always need a code owner's review |
| `--into <dir>` | this clone | Add the setup to an existing repo |
| `--decisions-file <path>` | `.claude/decisions.md` | Where the decision log goes, for a project that needs it somewhere else, such as `DECISIONS.md` |
| `--force` | off | Overwrite existing files |

## Stacks

| Stack | Kind | Notes |
| --- | --- | --- |
| `none` | overlay | The AI setup only. `.claude/scripts/` are stubs: `check` and `test` fail until you fill them in |

A stack is either a **starter** (ships app code in `tree/`, for new projects) or an **overlay** (no `tree/`: only the AI setup and scripts, for any repo).

## What every repo gets

| | |
| --- | --- |
| `.claude/CLAUDE.md` | Commands, what "done" means, conventions, gotchas, and the `#` feedback rule |
| `.claude/REVIEW.md` | What reviewers flag and skip, evidence rules, Important/Nit/Pre-existing tags |
| `.claude/decisions.md` | Decisions that affect more than one ticket. Entries are only ever added, and git merges the file with the `union` driver so parallel branches never conflict |
| `.claude/scripts/` | `setup`, `check`, `test`, `fix`, `quick-check`: the only commands hooks, skills and CI call |
| `.claude/settings.json` | Permissions (merging PRs is denied: a human merges), plus hooks: protect paths before edits, format after edits, `quick-check` before Claude stops |
| `.claude/protected-paths` | Globs Claude may not edit. Starts with `.github/workflows/*` |
| `.claude/ai-setup.json` | Which template commit, stack, mode and decisions file it came from |
| `.github/pull_request_template.md` | Why, testing, decisions, risk, how to revert |

Personal preferences go in `CLAUDE.local.md` and `.claude/settings.local.json`, which are gitignored.

### The Stop hook

Before Claude finishes a turn, `.claude/hooks/stop-check.sh` runs `.claude/scripts/quick-check`. If it fails, Claude has to fix it. After three blocks in a row it lets Claude stop and tells you, so a failure Claude can't fix doesn't loop forever. Keep `quick-check` fast; slow checks belong in `check`.

### Review tools and `REVIEW.md`

The template's own reviewers read `.claude/REVIEW.md`. If you use a review tool that only looks for `REVIEW.md` at the repo root, add a root `REVIEW.md` that points to `.claude/REVIEW.md`.

## Working on the template

- **Layout:** `core/` goes into every repo, `stacks/<name>/` holds what's specific to one stack, and `team/` holds the team-mode extras.
- **Tests:** `/bin/bash tests/test-init.sh` runs `init` for every stack and mode, as a new project and into an existing repo, on macOS's bash 3.2.
- **Adding a stack:** copy `stacks/none`, then edit `stack.conf`, `scripts/` and `claude/*.md`. Add `settings.json`, `protected-paths`, `gitignore` or `tree/` if the stack needs them. Run the tests.
- **Picking up template improvements:** an existing repo doesn't get them automatically. Compare `.claude/ai-setup.json`'s `template_commit` with the template's history and copy over what you want.
