# Project

@@STACK_PROJECT@@

# Commands

These scripts are the entry points in this repo. Use them instead of calling the underlying tools.

- Install dependencies: .claude/scripts/setup
- Everything CI checks: .claude/scripts/check
- Tests, all or one target: .claude/scripts/test [target]
- Format files: .claude/scripts/fix <files>
@@STACK_COMMANDS@@

# Verification

- A change is done when `.claude/scripts/check` passes.
@@STACK_VERIFICATION@@
- When you report done, include the command you ran and its output, or the screenshot path.
- Bug fixes start with a failing test that reproduces the bug.

# Planning

- `.claude/product.md` says what the product is for; `.claude/plan.md` holds the phases and the current phase's tickets. `/kickoff` creates both; `/plan-phase` breaks down the next phase.
- A ticket is one behavior the user can see, with its UI, types, API, copy and tests in the same PR. PRs stay under 500 changed lines; a bigger ticket is split into PRs that are each a complete smaller behavior.

# Conventions

- Decisions that affect more than one ticket are in `__DECISIONS_FILE__`. Read it before proposing an approach. To change a decision, add a new entry at the end that says which one it supersedes; don't edit old entries.
- Open pull requests, never merge them. A human merges.
@@STACK_CONVENTIONS@@

# Gotchas

- Paths listed in `.claude/protected-paths` are blocked from edits by a hook. Ask a human to change them.
- Before you stop, a hook runs `.claude/scripts/quick-check`. If it blocks you, fix the cause rather than working around it.
@@STACK_GOTCHAS@@

# Feedback ending in `#`

A message or review comment you're addressing that ends with `#` is a rule to keep, not just a one-off fix. Fix the code it's about, then write the rule as one sentence about a class of code and put it in the first place that fits:

| If the comment is…                                      | Put it in                                                                                                    |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Something a machine can check                           | A linter rule, a type, or a test                                                                             |
| A rule with zero exceptions about what Claude may touch | A hook in `.claude/hooks/`, a line in `.claude/protected-paths`, or a `deny` rule in `.claude/settings.json` |
| Something reviewers should flag                         | `.claude/REVIEW.md`                                                                                          |
| A convention for some files only                        | `.claude/rules/*.md` with `paths:`                                                                           |
| A convention for all code                               | This file                                                                                                    |
| A procedure with several steps                          | A skill in `.claude/skills/`                                                                                 |

If a rule already covers it, fix why it didn't work instead of adding a duplicate. Show the rule working: the linter failing on a sample violation, or the hook blocking a sample input. Then run `.claude/scripts/check`, and say where the rule went.
