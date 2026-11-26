# Working in this repo with Claude Code

For people. Claude's own instructions are in `CLAUDE.md`, the skills and the hooks. The notes (the plan, the product brief and the decision log) are in `__NOTES_DIR__/`.

## The loop

| Step                          | You say                              | What happens                                                                                                                                                                          |
| ----------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Start a project or a big area | `/kickoff` and the idea              | Claude reads what exists, asks about the decisions that shape everything, and writes the product brief, the decision log and the plan, with Phase 1 broken into tickets, in the notes |
| Work on a ticket              | "work on ticket T-04"                | A branch and a worktree in `.claude/worktrees/T-04` with its own port. Claude proposes an approach and waits for your OK, then builds. Before each stop, a hook runs `quick-check`    |
| Finish it                     | `/wrap-up`                           | Each "done when" is proved, `check` passes, the ticket and the decision log are updated, and the PR description is drafted                                                            |
| Review it                     | `/pre-pr`                            | Size check, `check`, a draft PR, and Claude's review as inline 🤖 comments                                                                                                            |
| Sort the comments             | on GitHub                            | Resolve the 🤖 comments that shouldn't be fixed, leave the rest open, add your own. End a comment with `#` to make it a permanent rule                                                |
| Fix them                      | `/address-review`                    | Open threads are fixed, replied to and resolved; disagreements stay open for you                                                                                                      |
| Merge                         | on GitHub                            | Mark the PR ready (this starts the CI review, if set up), review, merge. Claude never merges                                                                                          |
| Clean up                      | `.claude/scripts/ticket remove T-04` | Deletes the worktree and the merged branch                                                                                                                                            |
| Plan ahead                    | `/plan-phase`                        | When a phase is nearly done, the next one is broken into tickets, using what the last one taught                                                                                      |

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
