# repo-template

A GitHub template repository. It gives a new repo:

- Issue forms for epics, prototypes, mechanics, UI, art, audio, QA, and bugs.
- A pull request template.
- MegaLinter on every PR and on pushes to `main` and `develop`, plus a conventional-commit PR title check.
- A `CLAUDE.md` that describes the planning and shipping workflow the forms serve.

## Use it

1. Click **Use this template** on GitHub.
2. Replace every `<repo>` in `CLAUDE.md` with your repo name.
3. Clone your new repo, then create the labels the forms apply from inside the clone:

```sh
gh label create epic --force
gh label create prototype --force
gh label create mechanics --force
gh label create ui --force
gh label create art --force
gh label create audio --force
gh label create qa --force
gh label create bug --force
```

4. Create `develop` and make it GitHub's default branch:

```sh
git push origin main:develop
gh repo edit --default-branch develop
```

5. List your own directories in `INDEX.md`.
