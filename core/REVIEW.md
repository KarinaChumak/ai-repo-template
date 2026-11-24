# Review guidance

Read by every reviewer of this repo: `/code-review`, the `reviewer` subagent, and the review on pull requests. When a reviewer keeps repeating a comment, move it here, into a linter rule, or into a skill.

@@STACK_REVIEW@@

## Always flag

- Code that breaks a convention in `.claude/CLAUDE.md`, or a change that makes a line there out of date.
- Code that contradicts an entry in `__DECISIONS_FILE__` without a new entry superseding it.
- A pull request split by layer instead of by behavior: components in one PR and their types, tests or copy in another.
- Types, translation keys or helpers added without the behavior that uses them, or UI added without its keys and tests.
- Tests that assert implementation details instead of behavior.
- Errors swallowed in a `catch` without being handled or reported.

## Skip

- Formatting and import order. The formatter and linter own them.
- Lockfiles and generated files.
- Naming preferences unless the name is misleading.

## Rules for findings

- Every finding cites `file:line` as evidence. Don't infer behavior from a function's name; read it.
- Tag each finding **Important**, **Nit**, or **Pre-existing**. At most 3 Nits per review.
- When a bug is a class of problem, say so and list every instance, not just the first.
- Start the summary with the count of Important findings. If there is nothing to fix, say "Nothing to fix." plainly.
