---
name: pre-pr
description: Get a ticket's branch ready for human review. Checks the size, runs the checks, opens a draft PR and posts a Claude review on it as inline comments, then simplifies and checks again. Use after /wrap-up, when the user asks to open a PR, or runs /pre-pr.
---

# Before the PR

Run the steps in order. Stop and tell the user if a step fails and you can't fix it.

## 1. Size

Run `.claude/scripts/pr-size`. If it's over the limit, propose how to split the branch into PRs that are each a complete smaller behavior, and stop. Only a human can add the `size-exception` label.

## 2. Check

Run `.claude/scripts/check` and fix what fails. Commit the fixes.

## 3. Open a draft PR

- If the branch already has a PR (`gh pr view --json number,url,isDraft`), use it.
- Otherwise push the branch and run `gh pr create --draft --base main`, with the title and description from `/wrap-up`. Run `/wrap-up` first if there's no description yet.

## 4. Review

Run both, in parallel when you can:

- The `/code-review` skill on this branch, without `--comment`, so its findings come back to you.
- The `reviewer` subagent.

Merge their findings and drop duplicates. Check each one against the code yourself, and drop the ones that don't hold up. Then post what's left as one review with inline comments, every comment starting with `🤖 Claude review:` and its severity:

```bash
gh api --method POST "repos/{owner}/{repo}/pulls/<number>/reviews" --input review.json
```

```json
{
  "event": "COMMENT",
  "body": "🤖 Claude review: 2 Important, 1 Nit.",
  "comments": [
    {
      "path": "src/dashboard/filters/range.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "🤖 Claude review: **Important.** The end date is exclusive here but inclusive in the API, so the last day is dropped. Use `endOfDay(to)`."
    }
  ]
}
```

A finding on a line the PR didn't change goes in the review's `body` instead, with its `file:line`. If nothing is left, post the review with the body "🤖 Claude review: Nothing to fix." and no comments. Write `review.json` in a temporary folder, not in the repo.

## 5. Simplify and check the UI

1. Run the `/simplify` skill, and commit what it changes.
2. If the PR changes UI and the repo has the `design-check` or `verify-ui` skills, run them, and add the screenshots' paths to the PR description.
3. Run `.claude/scripts/check` again, commit, and push.

## 6. Hand over

Tell the user:

- The PR link and how many comments were posted.
- To read the 🤖 comments on GitHub: resolve the ones that shouldn't be fixed, leave open the ones that should, and add their own. Then run `/address-review`.
- To mark the PR ready for review when they're happy with it. That starts the CI review, if the repo has one.

Never merge the PR, and don't turn on auto-merge.
