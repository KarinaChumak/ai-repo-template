---
name: wrap-up
description: Finish a ticket's PR. Proves each "done when", runs the checks, updates the ticket in the plan, records global decisions and drafts the PR description. Use when the work on a ticket or one of its PRs is done, or when the user runs /wrap-up.
---

# Wrap up a ticket

## 1. Prove it's done

For each "done when" of the ticket (or of this PR, if the ticket has several), name the test, e2e test or screenshot that proves it. Write the missing ones. If one can't be met, stop and tell the user why.

## 2. Check

Run `.claude/scripts/check` and fix what fails. Then run `git diff --stat main...HEAD`: if the PR is over 500 changed lines, not counting lockfiles, generated files, snapshots and data files, propose a split by behavior before going on.

## 3. Update the plan

In the ticket's section in `__NOTES_DIR__/plan.md`:

- `Status: in review`, or `in progress (PR 1 of 2 in review)` when more PRs follow.
- Add an `Outcome:` line: what was built, in one or two sentences, and anything that changes later tickets. `/plan-phase` reads it.
- If the work showed that a later ticket needs to change, say so to the user; don't rewrite other tickets yourself.

## 4. Record global decisions

A decision is global if another ticket has to follow it: a shared contract, a data shape, a library, a pattern for a kind of code. Choices that only affect this ticket are not recorded.

Add each one at the end of `__DECISIONS_FILE__`, keyed by the ticket ID:

```markdown
## T-04: Date ranges in the URL

Filters live in the query string (`?from=&to=`), not in local state. Why: reload and sharing keep them. Rejected: localStorage.
```

To change an earlier decision, add a new entry that says which one it supersedes. Don't edit old entries.

## 5. Commit and draft the PR

1. Commit everything with a message that says what the user can now do.
2. Draft the PR description in the format of `.github/pull_request_template.md`: the ticket ID and title under Why, how each "done when" was proved under Testing, the new decision entries under Decisions.
3. Show the draft to the user, then run the `/pre-pr` skill, which opens it as a draft PR and reviews it. Never merge it, and don't turn on auto-merge.

After the PR is merged, the user (or you, when asked) runs `.claude/scripts/ticket remove <ID>` from the main checkout to delete the worktree.
