# ai-repo-template

A Claude Code setup for new and existing repos, built for big, ambiguous projects worked on in parallel. It follows Anthropic's guidance: [best practices](https://code.claude.com/docs/en/best-practices) and [verification loops with skills](https://claude.com/resources/articles/building-verification-loops-in-claude-code-with-skills).

It's a point-in-time template, not a library. `init` writes the setup into a repo, and from then on that repo owns it and changes it freely. Nothing syncs back.

The setup lives in two places, so it never mixes with your code:

- **`.claude/`**: config and rules, edited rarely: `CLAUDE.md`, `REVIEW.md`, settings, hooks, skills, scripts. Claude Code asks before every edit here, which is what you want for rule files.
- **The notes**: the files Claude updates all the time: `plan.md`, `product.md` and `decisions.md`. By default they live outside the repo in `~/claude-notes/<repo>/`, never committed, and shared by every worktree of the repo. With `--notes in-repo` they're in `claude-notes/` and committed, for projects where others should see the plan and decisions, like a take-home task. Either way Claude edits them without a prompt, so planning works in unattended runs too.

## Start a new project

```bash
gh repo create my-app --private --template <you>/ai-repo-template --clone
cd my-app
./init --stack none
```

`init` without flags asks for the stack and mode. In this mode it removes the template's own files (`init`, `install-user`, `core/`, `stacks/`, `team/`, `tests/`, `user/`, this README), so the result is a plain project.

Then `init` commits the result on the `ai-repo-setup` branch, pushes it and opens a PR called "AI repo setup", so the setup lands like any other change. For a new project it also protects `main` on GitHub: changes land through PRs, admins included, with no approvals required, and turns on deleting a PR's branch once it's merged. A private repo needs GitHub Pro or Team for that; `init` says so when GitHub refuses.

## Add the setup to an existing repo

```bash
git clone https://github.com/<you>/ai-repo-template ~/Code/ai-repo-template
~/Code/ai-repo-template/init --stack none --into ~/Code/my-existing-repo
```

- **Existing files are kept, byte for byte.** When a file the setup would write is already there and differs, the generated version goes to `.claude/ai-setup-pending/` (gitignored), listed in `.claude/ai-setup-pending/MERGE.md` with the file to merge it into. Ask Claude to "merge the files listed in .claude/ai-setup-pending/MERGE.md". `--force` overwrites instead.
- **`CLAUDE.md` and `REVIEW.md`** count as existing at the root or in `.claude/`, so a repo never ends up with two.
- **`.claude/settings.json` is merged:** your permissions and hooks stay, and the template's are added.
- **`.gitignore`, `.gitattributes`, `.worktreeinclude` and `.claude/protected-paths`** get the missing lines appended.
- **`gh` is pinned to `origin`**, so PRs never open in an `upstream` remote such as the company repo of a take-home task. A default you already chose with `gh repo set-default` is kept. `ticket start` does the same for repos set up before this.
- **Apart from those appended lines and the merged settings, the repo's own files are never edited.** Placeholders like the project name are filled in before anything is written.
- **Starter stacks:** `check` runs Prettier on the whole repo, including files that were there before. Format them, or list the ones that must stay as they are in `.prettierignore`.
- **The setup arrives as a PR** called "AI repo setup", on the `ai-repo-setup` branch, when the repo is on GitHub, `gh` is installed and there were no uncommitted changes. Otherwise `init` says why and leaves the files for you to commit, so your own changes never end up in its commit. Branch protection stays as it is unless you pass `--protect-main`.
- **Running it again is safe:** nothing gets duplicated.

## Options

| Option | Default | |
| --- | --- | --- |
| `--stack <name>` | asked | See the table below |
| `--mode solo\|team` | `solo` | `team` adds `.github/CODEOWNERS` so `.claude/` and `.github/` always need a code owner's review |
| `--into <dir>` | this clone | Add the setup to an existing repo |
| `--notes external\|in-repo` | `external` | Where the notes live: `~/claude-notes/<repo>/` (never committed) or `claude-notes/` in the repo (committed) |
| `--decisions-file <path>` | `decisions.md` in the notes | Where the decision log goes, for a project that needs it somewhere else, such as `DECISIONS.md` |
| `--ci-review` | off | Add `.github/workflows/claude-review.yml`: Claude reviews a PR (code and security, one pass) when it's marked ready, and answers `@claude` in PR comments. Needs the Claude GitHub app (`/install-github-app`) and an `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` secret |
| `--no-pr` | off | Leave the files uncommitted instead of opening the "AI repo setup" PR |
| `--protect-main` | on for a new project | Require PRs for the default branch on GitHub, admins included, and delete branches once their PR is merged |
| `--force` | off | Overwrite existing files |

## Stacks

| Stack | Kind | Notes |
| --- | --- | --- |
| `none` | overlay | The AI setup only. `.claude/scripts/` are stubs: `check` and `test` fail until you fill them in |
| `react-vite` | starter | React 19, TypeScript 6, Vite 8 with React Compiler, Vitest, Testing Library, Playwright (desktop and mobile), ESLint with the React Compiler and a11y rules, Prettier, GitHub Actions CI. Node 26, pnpm 12 |

### react-vite

- **Decided up front,** so Claude doesn't stop to ask: React Router for routing, TanStack Query for server data, MSW for API mocks in tests, plain CSS per component. `.claude/CLAUDE.md` lists them, plus what `/kickoff` still settles (the API server, translations, a widget library, forms).
- **Where code goes:** generic styled components in `src/components/`, product components and queries in `src/features/<area>/`, one component per route in `src/pages/`. ESLint keeps pages and features free of CSS, `className` and HTML elements, and keeps tests from stubbing `fetch` or `console`.
- **`quick-check`** (run before Claude stops): an incremental typecheck of the whole project, plus ESLint on the files the branch changed. ESLint includes the React Compiler rules from `eslint-plugin-react-hooks`, so code the compiler can't handle, like reading a ref during render, blocks Claude until it's fixed.
- **`check`** (and CI): format check, lint, typecheck, unit tests, build. CI also runs the Playwright e2e tests.
- **UI skills:** `/design-check` checks the branch's UI changes against `.claude/DESIGN.md` (tokens, layout, states, accessibility, copy), with `.claude/scripts/raw-styles` flagging raw colors and pixel sizes. `/verify-ui` runs the app, screenshots the changed screens at mobile and desktop widths, and runs e2e. `/scaffold-component` creates a component with its test, following `src/components/Button/`.
- **Path rules:** `.claude/rules/components.md`, `features.md` and `tests.md` load only when Claude works on those files.
- **Protected:** `pnpm-lock.yaml` and the ESLint, TypeScript, Vite and Playwright configs, so a check can't be switched off to make it pass.
- **Versions:** TypeScript stays on 6.0 until `typescript-eslint` supports 7. Accessibility lint uses `eslint-plugin-jsx-a11y-x`, a fork of `eslint-plugin-jsx-a11y` that supports ESLint 10. pnpm 12 only installs versions older than its minimum release age, so a brand-new package version can't be added the day it's published.

A stack is either a **starter** (ships app code in `tree/`, for new projects) or an **overlay** (no `tree/`: only the AI setup and scripts, for any repo).

## What every repo gets

| | |
| --- | --- |
| `.claude/CLAUDE.md` | Commands, what "done" means, conventions, gotchas, and the `#` feedback rule |
| `.claude/REVIEW.md` | What reviewers flag and skip, evidence rules, Important/Nit/Pre-existing tags |
| `.claude/WORKFLOW.md` | For people: the loop from `/kickoff` to the merge in one table, and a checklist for before you hand the project over |
| `.claude/skills/kickoff`, `plan-phase` | `/kickoff` turns an idea into decisions, `product.md`, and a phased `plan.md` in the notes with only Phase 1 broken into tickets. `/plan-phase` breaks down the next phase: behavior slices of one PR each, about 150 lines for the first tickets and at most 300 after, parallel lanes |
| `.claude/skills/ticket` | "work on ticket T-04" (or `/ticket T-04`) runs `.claude/scripts/ticket start`, which makes a branch and a worktree in `.claude/worktrees/T-04` with its own dev-server port, and moves the session there, so the main checkout stays on `main` and tickets run in parallel. Claude reads the ticket and the latest decisions, proposes an approach, waits for your OK, then builds. `ticket remove T-04` cleans up after the merge |
| `.claude/skills/finish`, `.claude/agents/reviewer.md` | Runs on its own when a ticket is done, or with `/finish`: proves each "done when", runs `check` and the size check, then has the `reviewer` agent review the branch. The agent runs in its own context and never saw how the code was written. Claude fixes the findings that hold up and notes the ones it rejects, runs `/simplify` and the UI checks, updates the plan and the decision log, then pushes and opens the PR with a "Local review" section and a short title like `T-04: Date range filter on the dashboard`. Then it waits for CI and the CI review, fixes failed checks and addresses the review's comments, so the PR it hands over is green |
| `.claude/skills/address-review` | "address the comments": fetches the PR's unresolved threads, fixes them, replies and resolves them; disagreements stay open for you |
| `decisions.md` in the notes | Decisions that affect more than one ticket. Entries are only ever added. In the repo, git merges the file with the `union` driver so parallel branches never conflict |
| `.claude/scripts/` | `setup`, `check`, `test`, `fix`, `quick-check`, `ticket`, `pr-size`: the only commands hooks, skills and CI call |
| `.claude/settings.json` | Permissions (Claude can push ticket branches and open PRs; pushing to `main`, force-pushing, merging PRs and editing files through inline Python, Perl, Node or `sed -i` scripts are denied), plus hooks: the current ticket's section from the plan at session start and after compaction, protect paths before edits, format after edits, `quick-check` before Claude stops |
| `.claude/protected-paths` | Globs Claude may not edit. Starts with `.github/workflows/*` |
| `.claude/pr-size-ignore` | Globs that don't count toward the 500-line PR limit: lockfiles, snapshots, `claude-notes/*` |
| `.github/workflows/pr-size.yml` | Fails a PR over 500 changed lines, unless a human adds the `size-exception` label |
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
