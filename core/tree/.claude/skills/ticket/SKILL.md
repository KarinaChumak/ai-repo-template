---
name: ticket
description: Start or resume work on a ticket from ai/plan.md in its own branch and worktree. Use when the user says "work on ticket T-04", "next ticket", "continue T-04", or runs /ticket.
---

# Work on a ticket

One ticket, one session, one worktree. The main checkout stays on `main`, so other sessions can run their own tickets in parallel.

## 1. Find the ticket

- Read the ticket's `### <ID> <title>` section in `ai/plan.md`.
- For "next ticket": pick the first ticket with `Status: todo` whose `After` tickets are all done, and confirm it with the user.
- If its `After` tickets aren't merged yet, or another ticket in progress has the same `Touches`, say so and ask before starting.

## 2. Move into its worktree

1. Run `.claude/scripts/ticket start <ID> <short-slug>`, with a slug of 2–4 words from the title. It prints `path`, `branch`, `port` and `new`.
2. Call the EnterWorktree tool with that `path`, so the rest of the session works there.
3. If `new=no`, this is a resumed ticket: read `git log --oneline main..HEAD` and `git status` to see where it stands, and carry on from there.
4. The dev server and e2e tests in this worktree use `port`. Pass it on if you start anything else that listens.

## 3. Read before proposing

- `.claude/CLAUDE.md`, the ticket's section, and `ai/product.md`.
- `__DECISIONS_FILE__` as it is on `main` (`git show origin/main:__DECISIONS_FILE__`, or `main:` without a remote), since other tickets may have added decisions after this branch started.
- The code in the ticket's `Touches`.

## 4. Mark it started

In the ticket's section, set `Status: in progress` and `Branch: <branch>`. Commit that with the first code change, not alone.

## 5. Propose, then build

- Propose the approach in a few lines: what changes in which files, how each "done when" will be proved, and the PR split if the ticket has more than one. Wait for the user's approval.
- Questions that only affect this ticket: decide, and mention the choice in the proposal. Questions that affect other tickets: ask, since they become entries in `__DECISIONS_FILE__`.
- Build in small commits. Keep each PR a complete slice of behavior, with its types, copy, keys and tests, under 500 changed lines.

## 6. Finish

When every "done when" holds, run the `/wrap-up` skill. Don't merge; a human does.
