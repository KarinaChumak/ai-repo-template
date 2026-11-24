# ai-repo-template v0 plan

Goal: a tested template that adds a Claude Code setup to any repo, new or existing. Everything AI-related lives in `.claude/`, so it never mixes with the code. It's built for big, ambiguous projects worked on in parallel tickets.

## The workflow it supports

1. **Init.** `init --stack react-vite|none` for a new project, or `--into <dir>` for an existing repo. Existing files are kept; anything that conflicts goes to `.claude/ai-setup-pending/` for merging.
2. **Kickoff (`/kickoff`).** Claude reads what exists, lists the big ambiguities as decisions with options and a recommendation, and interviews you. It writes `product.md`, `decisions.md` and `plan.md`. `plan.md` lists every phase, but only Phase 1 (a walking skeleton) is broken into tickets.
3. **Tickets.** "work on ticket T-04" creates a branch and worktree with its own port, moves the session into it, and reads the ticket's section and `decisions.md` from `main`. Claude proposes an approach, you approve, and Claude builds. Sessions run in parallel only for tickets that touch different areas.
4. **Automatic checks.**
   - Every edit: protected paths are blocked and the file is formatted.
   - Every turn: typecheck, ESLint and React Compiler rules on the changed files must pass before Claude can stop.
   - After context compaction: the ticket's section is added back.
5. **Before the PR (`/pre-pr`).**
   1. Size check: under 500 changed lines, or a split by behavior is proposed.
   2. `check`.
   3. A draft PR is opened, and `/code-review --comment` plus the `reviewer` agent post inline comments, each starting with `🤖 Claude review:`.
   4. You sort the comments on GitHub (resolve, or leave open), then run `/address-review` to fix the open ones.
6. **The PR.** Marking it ready triggers `claude-review.yml` (code and security review) and CI (checks, e2e, size limit). You review. A comment ending in `#` becomes a permanent rule, placed in the most automatic spot that fits.
7. **Decisions.** Only global decisions are recorded. `/wrap-up` adds them to `.claude/decisions.md` in the PR, and you accept them by approving the PR. Small decisions aren't logged.
8. **The next phase.** `/plan-phase` breaks down only the next phase, using what you've learned so far.

### Rules for tickets and PRs
- **A ticket is one behavior the user can see, end to end:** UI, types, API, i18n keys and tests in the same PR. Never split by layer.
- **A PR is under 500 changed lines.** A ticket may span several PRs, but each PR is still a complete slice of behavior. Lockfiles, generated files, snapshots and data files don't count toward the limit. Going over requires the `size-exception` label, which only you add.
- **One session per ticket.** Claude Code compacts context on its own; don't manage it by hand.

## What a generated repo looks like

```
.claude/
  CLAUDE.md  REVIEW.md  DESIGN.md       # DESIGN.md only for UI stacks
  product.md  plan.md  decisions.md     # decisions.md: merge=union, entries keyed by ticket ID
  scripts/  setup check test fix quick-check pr-size ticket
  settings.json  hooks/  skills/  agents/  rules/
  protected-paths  pr-size-ignore
.github/  .gitignore  .gitattributes  .worktreeinclude   # these tools require the root
```

## Steps

| # | Step | Done when |
|---|---|---|
| 1 | **Build the core from scratch, in the final layout.** `ai-repo-template-setup.md` is a reference, not something to restore. Write `init`, `core/`, `team/` and `tests/test-init.sh` with everything generated into `.claude/` from the start: `CLAUDE.md`, `REVIEW.md`, `scripts/`, hooks, settings, and `decisions.md` with `merge=union` in `.gitattributes`. Add the `--decisions-file` option. Check that the built-in reviewers find `.claude/REVIEW.md`; if not, add a one-line root pointer. The template's own dev `CLAUDE.md` stays at its root. | `tests/test-init.sh` passes, and confirms the only files at the root of a generated repo are the ones above. |
| 2 | **Add the `react-vite` stack on the new layout.** Use current Node (26, the one installed) and pnpm (12), generate a fresh lockfile, and include `DESIGN.md` and the UI skills. | `tests/test-init.sh --full` installs, builds and tests the generated app. |
| 3 | **Harden `--into`.** Add a test case for an existing repo with a real README, data files and a `package.json`. Conflicting files go to `.claude/ai-setup-pending/`; the README gets a suggested "how to run" section there too. | Existing files are byte-for-byte unchanged, `check` runs, and running `init` again changes nothing. |
| 4 | **Upgrade the `react-vite` stack.** Upgrade `eslint-plugin-react-hooks` to v6+ for the React Compiler rules, and enable `babel-plugin-react-compiler` in Vite. `quick-check` becomes incremental `tsc` plus ESLint on the changed files. Add the ESLint, `tsconfig` and Vite configs to `protected-paths`. | A sample type error and a sample compiler violation each block the Stop hook. A clean change passes in a few seconds. |
| 5 | **`--stack none`:** core only. The stub `check` fails with "fill me in"; `quick-check` passes. | Covered by the test loop. |
| 6 | **Planning skills.** `/kickoff` writes `product.md`, `decisions.md`, and `plan.md` with only Phase 1 broken down. `/plan-phase` breaks down the next phase, slicing by behavior, putting a walking skeleton first, estimating sizes with PR splits, and marking which tickets can run in parallel. | Each skill is tried on a scratch repo and its output checked against these rules. |
| 7 | **Running tickets.** The `ticket` skill (triggered by "work on ticket X" or `/ticket X`) and the `.claude/scripts/ticket` script (worktree, branch, port). A SessionStart hook re-adds the ticket's section after compaction. `/wrap-up` updates the ticket's status, adds global decisions to `decisions.md`, and drafts the PR description. | Script test: two tickets give two worktrees with different ports, and the main checkout's branch never changes. |
| 8 | **Reviews.** The `pr-size` script and its ignore list. `/pre-pr`: size, check, draft PR, then `/code-review --comment` and the `reviewer` agent with 🤖-prefixed comments, `/simplify`, design-check and verify-ui, check again. The `/address-review` skill: fetch unresolved comments, fix, reply, resolve. `claude-review.yml` using `anthropics/claude-code-action`, pinned to a SHA, triggered when a PR is marked ready and on `@claude` mentions, with code and security review in one workflow; opt-in with `--ci-review`. A CI size job. `REVIEW.md` rules: no splitting by layer, no unused types or keys, no UI without its keys and tests. | `pr-size` is tested against sample diffs. The workflow passes `actionlint`. |
| 9 | **User-level installer.** Adds the `PROFILE.md` template and the `~/.claude/CLAUDE.md` snippet. | Running it twice gives the same result as running it once. |
| 10 | **Docs, then a dry run.** Update the README. Write a `docs/ai-workflow.md` template with a pre-handoff checklist. Run `init --into` on a copy of a real existing repo. | The app runs, `check` passes, and existing files are unchanged. |

**Order:**
- Steps 1 and 2 first, one after the other.
- Every step lands on its own branch and merges into `main` through a PR. `main` is protected: merging needs a PR, with no approvals required.
- Then two lanes in parallel worktrees:
  - **Lane A** (`init` and its test): steps 3 → 5 → 7 → 8.
  - **Lane B** (the stack and the skill markdown): steps 4 → 6 → 9.
- Step 10 last.

## Left for later (v1)
- **Backend stack:** a Node/TypeScript API or Java/Spring, plus an overlay version.
- **Plugin packaging:** the workflow skills, so they work without running `init`.
- **Combining stacks** for full-stack monorepos.
- **Team mode improvements.**
