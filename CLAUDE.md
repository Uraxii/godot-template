## How work ships
- Work is tracked as GitHub issues on the <repo> GitHub project board.
- Related items share a `feature/<category>` branch cut from `develop`; each item is its own `<category>/<item>` branch and PR into that category branch, and the category reaches `develop` as one PR.
- Every change has a user story with testable acceptance criteria, and a gameplay change has an in-engine playtest scene for it.
- The PR body explains the feature and proves it works with screenshots, videos, tables, graphs. A playtest reviewer must be able to complete the story before approving.
- Answer each review comment on its thread: fixed, and where, or dismissed, and why.
- Use conventional commits.

## Planning and finishing features
- A feature is an epic issue made from the Feature epic form, and every piece of work on it is a sub-issue of that epic.
- Before any real work, answer the epic's riskiest question with a Prototype issue: one question, a time box, and a written build, change, or drop decision.
- Prototype code is thrown away, never merged into the feature.
- Record the prototype decision in the epic's Prototype result field before opening task issues.
- Split the epic into one sub-issue per discipline (mechanics, UI, art, audio), each made from its form and marked blocked by the prototype.
- UI tasks link to mockups from a UI mockup prototype that ended in build it.
- Every sub-issue's Done when items are things a playtester can see or run in the game.
- The epic is one `feature/<category>`; each sub-issue is one `<category>/<item>` PR that closes it and links the playtest scene proving its Done when items.
- When every task is merged, a QA test pass sub-issue checks the epic's Done when items on each platform, and every failure is filed as a linked bug.
- The epic closes when its QA pass is done, and its category branch then reaches `develop`.
- Move the epic on the <repo> GitHub project board as it goes: Todo, Prototype, In Progress, Done.

@./INDEX.md
