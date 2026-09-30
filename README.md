# repo-template

A GitHub template repository. It gives a new repo:

- Issue forms for epics, prototypes, mechanics, UI, art, audio, QA, and bugs.
- A pull request template.
- MegaLinter on every PR and on pushes to `main` and `develop`, plus a conventional-commit PR title check.
- A `CLAUDE.md` that describes the planning and shipping workflow the forms serve.

## Use it

1. Click **Use this template** on GitHub.
2. Replace every `<repo>` in `CLAUDE.md` with your repo name.
3. Create the labels the forms apply:

```sh
gh label create epic
gh label create prototype
gh label create mechanics
gh label create ui
gh label create art
gh label create audio
gh label create qa
gh label create bug
```

4. Create `develop` and make it the default working branch.
5. List your own directories in `INDEX.md`.
