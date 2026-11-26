# Working in this repo with Claude Code

For people. Claude's own instructions are in `CLAUDE.md`, the skills and the hooks. The notes (the plan, the product brief and the decision log) are in `__NOTES_DIR__/`.

## The loop

| Step              | You                                                                                                                                                                  | Claude                                                                                                                                                           |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plan              | Run `/kickoff` with the idea, and answer its questions                                                                                                               | Reads what exists, asks about the decisions that shape everything, and writes the product brief, the decision log and the plan, with Phase 1 broken into tickets |
| Work on a ticket  | Say "work on ticket T-04", then approve the approach                                                                                                                 | Makes a branch and a worktree in `.claude/worktrees/T-04` with its own port, then builds. A hook runs `quick-check` before each stop                             |
| Finish it         | Run `/wrap-up`                                                                                                                                                       | Proves each "done when", runs `check`, updates the ticket and the decision log, and drafts the PR description                                                    |
| Review it         | Run `/pre-pr`                                                                                                                                                        | Checks the size, runs `check`, opens a draft PR and posts its review as inline 🤖 comments                                                                       |
| Sort the comments | On the PR page in GitHub: resolve the 🤖 comments that shouldn't be fixed, leave the rest open, and add your own. End a comment with `#` to make it a permanent rule | Nothing                                                                                                                                                          |
| Fix them          | Run `/address-review`                                                                                                                                                | Fixes the open threads, replies to each and resolves them. Disagreements stay open for you                                                                       |
| Merge             | On the PR page in GitHub: click "Ready for review" (this starts the CI review, if set up), review the changes, and merge                                             | Nothing. Claude never merges                                                                                                                                     |
| Clean up          | Run `.claude/scripts/ticket remove T-04`                                                                                                                             | Deletes the worktree and the merged branch                                                                                                                       |
| Plan ahead        | Run `/plan-phase` when a phase is nearly done                                                                                                                        | Breaks the next phase into tickets, using what the last one taught                                                                                               |

Run tickets in parallel only when their `Touches` don't overlap; `__NOTES_DIR__/plan.md` marks the lanes. One session per ticket. Context is compacted automatically, and the hook puts the ticket back afterwards.

## Before handing the project over

Run through this before a demo, a hand-in, or passing the repo to someone else.

- [ ] `.claude/scripts/check` passes on `main`, and CI is green.
- [ ] The README says how to install, run and test the project, in commands that work on a fresh clone.
- [ ] Every ticket in `__NOTES_DIR__/plan.md` has its real status, and finished ones have an `Outcome`.
- [ ] The decision log covers every choice another person would ask about, with the reason and what was rejected.
- [ ] `__NOTES_DIR__/product.md` lists what's out of scope and the open questions that are left.
- [ ] No secrets in the repo: `.env` is gitignored, and `.env.example` lists every variable.
- [ ] No leftovers: `.claude/ai-setup-pending/` is gone, no worktrees are left (`git worktree list`), no stray branches.
- [ ] `.claude/` is committed. If the notes live outside the repo (`~/claude-notes/`) and the people you hand over to should see the plan and decisions, share them or move them in with `init --notes in-repo`.
