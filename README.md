# ai-repo-template

A Claude Code setup for new and existing repos, built for big, ambiguous projects worked on in parallel. It follows Anthropic's guidance: [best practices](https://code.claude.com/docs/en/best-practices) and [verification loops with skills](https://claude.com/resources/articles/building-verification-loops-in-claude-code-with-skills).

It's a point-in-time template, not a library. `init` writes the setup into a repo, and from then on that repo owns it and changes it freely. Nothing syncs back.

The setup lives in two folders, so it never mixes with your code:

- **`.claude/`**: config and rules, edited rarely: `CLAUDE.md`, `REVIEW.md`, settings, hooks, skills, scripts. Claude Code asks before every edit here, which is what you want for rule files.
- **`ai/`**: the files Claude updates all the time: `plan.md`, `product.md` and `decisions.md`. Edits here don't need a prompt, so planning and decisions work in unattended runs too.

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

- **Existing files are kept, byte for byte.** When a file the setup would write is already there and differs, the generated version goes to `.claude/ai-setup-pending/` (gitignored), listed in `.claude/ai-setup-pending/MERGE.md` with the file to merge it into. Ask Claude to "merge the files listed in .claude/ai-setup-pending/MERGE.md". `--force` overwrites instead.
- **`CLAUDE.md` and `REVIEW.md`** count as existing at the root or in `.claude/`, so a repo never ends up with two.
- **`.claude/settings.json` is merged:** your permissions and hooks stay, and the template's are added.
- **`.gitignore`, `.gitattributes`, `.worktreeinclude` and `.claude/protected-paths`** get the missing lines appended.
- **Apart from those appended lines and the merged settings, the repo's own files are never edited.** Placeholders like the project name are filled in before anything is written.
- **Starter stacks:** `check` runs Prettier on the whole repo, including files that were there before. Format them, or list the ones that must stay as they are in `.prettierignore`.
- **Running it again is safe:** nothing gets duplicated.

## Options

| Option | Default | |
| --- | --- | --- |
| `--stack <name>` | asked | See the table below |
| `--mode solo\|team` | `solo` | `team` adds `.github/CODEOWNERS` so `.claude/` and `.github/` always need a code owner's review |
| `--into <dir>` | this clone | Add the setup to an existing repo |
| `--decisions-file <path>` | `ai/decisions.md` | Where the decision log goes, for a project that needs it somewhere else, such as `DECISIONS.md` |
| `--force` | off | Overwrite existing files |

## Stacks

| Stack | Kind | Notes |
| --- | --- | --- |
| `none` | overlay | The AI setup only. `.claude/scripts/` are stubs: `check` and `test` fail until you fill them in |
| `react-vite` | starter | React 19, TypeScript 6, Vite 8 with React Compiler, Vitest, Testing Library, Playwright (desktop and mobile), ESLint with the React Compiler and a11y rules, Prettier, GitHub Actions CI. Node 26, pnpm 12 |

### react-vite

- **`quick-check`** (run before Claude stops): an incremental typecheck of the whole project, plus ESLint on the files the branch changed. ESLint includes the React Compiler rules from `eslint-plugin-react-hooks`, so code the compiler can't handle, like reading a ref during render, blocks Claude until it's fixed.
- **`check`** (and CI): format check, lint, typecheck, unit tests, build. CI also runs the Playwright e2e tests.
- **UI skills:** `/design-check` checks the branch's UI changes against `.claude/DESIGN.md` (tokens, layout, states, accessibility, copy), with `.claude/scripts/raw-styles` flagging raw colors and pixel sizes. `/verify-ui` runs the app, screenshots the changed screens at mobile and desktop widths, and runs e2e. `/scaffold-component` creates a component with its test, following `src/components/Button/`.
- **Path rules:** `.claude/rules/components.md` and `.claude/rules/tests.md` load only when Claude works on those files.
- **Protected:** `pnpm-lock.yaml` and the ESLint, TypeScript, Vite and Playwright configs, so a check can't be switched off to make it pass.
- **Versions:** TypeScript stays on 6.0 until `typescript-eslint` supports 7. Accessibility lint uses `eslint-plugin-jsx-a11y-x`, a fork of `eslint-plugin-jsx-a11y` that supports ESLint 10. pnpm 12 only installs versions older than its minimum release age, so a brand-new package version can't be added the day it's published.

A stack is either a **starter** (ships app code in `tree/`, for new projects) or an **overlay** (no `tree/`: only the AI setup and scripts, for any repo).

## What every repo gets

| | |
| --- | --- |
| `.claude/CLAUDE.md` | Commands, what "done" means, conventions, gotchas, and the `#` feedback rule |
| `.claude/REVIEW.md` | What reviewers flag and skip, evidence rules, Important/Nit/Pre-existing tags |
| `.claude/skills/kickoff`, `plan-phase` | `/kickoff` turns an idea into decisions, `ai/product.md` and a phased `ai/plan.md` with only Phase 1 broken into tickets. `/plan-phase` breaks down the next phase: behavior slices, PRs under 500 lines, parallel lanes |
| `ai/decisions.md` | Decisions that affect more than one ticket. Entries are only ever added, and git merges the file with the `union` driver so parallel branches never conflict |
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

## User-level setup

Some rules belong to you, not to one repo: never merging pull requests, how you like to work. `install-user` puts them in `~/.claude/`, which Claude Code reads in every repo:

```bash
~/Code/ai-repo-template/install-user --dry-run
~/Code/ai-repo-template/install-user
```

- **`~/.claude/PROFILE.md`**: a personal profile to fill in (conventions, review preferences, tone), copied from `user/PROFILE.md` only if you don't have one yet.
- **`~/.claude/CLAUDE.md`**: gets the rules from `user/CLAUDE.md.snippet` between `<!-- ai-repo-template:start -->` and `<!-- ai-repo-template:end -->`. Running it again replaces only that block, so snippet updates apply cleanly. Everything outside the markers stays byte for byte.
- `--dry-run` prints what would change. `--home <dir>` installs into `<dir>/.claude` instead of `~/.claude`.

## Working on the template

- **Layout:** `core/` goes into every repo, `stacks/<name>/` holds what's specific to one stack, and `team/` holds the team-mode extras.
- **Tests:** `/bin/bash tests/test-init.sh` runs `init` for every stack and mode, as a new project and into an existing repo, on macOS's bash 3.2.
  `--full` also installs, checks, builds and e2e-tests each starter stack.
- **Adding a stack:** copy `stacks/none`, then edit `stack.conf`, `scripts/` and `claude/*.md`. Add `settings.json`, `protected-paths`, `gitignore` or `tree/` if the stack needs them. Run the tests.
- **Picking up template improvements:** an existing repo doesn't get them automatically. Compare `.claude/ai-setup.json`'s `template_commit` with the template's history and copy over what you want.
