# `<repo>`

A GitHub template for Godot 4 games written in GDScript. It gives a new repo:

- A setup script that downloads Godot, creates the project in `src/`, and installs [GUT](https://github.com/bitwes/Gut) for unit tests.
- Issue forms for epics, prototypes, mechanics, UI, art, audio, QA, and bugs.
- A pull request template.
- CI on every PR and on pushes to `main` and `develop`: MegaLinter, gdlint and gdformat, GUT tests, and a conventional-commit PR title check.
- A `CLAUDE.md` that describes the planning and shipping workflow the forms serve.

## Use it

1. Click **Use this template** on GitHub, then clone your new repo.
2. From inside the clone, create the Godot project. This downloads the latest stable Godot editor into `.tools/godot/`, pins that version in `.godot-version`, and puts your game's name in this README and in `CLAUDE.md`:

   ```sh
   scripts/setup-project.sh "My Game"
   ```

   Add `--godot 4.5.1` to use a specific Godot version instead. Teammates and CI run `scripts/setup-project.sh` with no arguments to get the pinned editor. Commit what the script creates.

3. Create the labels the forms apply:

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

## Lint and format GDScript

CI runs [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) on every `.gd` file outside `src/addons/`. To run it locally:

```sh
pip install "gdtoolkit==4.*"
find src -name '*.gd' -not -path 'src/addons/*' -not -path 'src/.godot/*' -exec gdlint {} +
find src -name '*.gd' -not -path 'src/addons/*' -not -path 'src/.godot/*' -exec gdformat {} +
```

The second command rewrites files in place; `gdformat --check` only reports. The commands skip `src/addons/`, which holds vendored plugins.

## Tests

Tests are [GUT](https://gut.readthedocs.io/) scripts in `src/tests/`. Each file is named `test_*.gd`, extends `GutTest`, and holds `test_*` functions. `src/tests/test_example.gd` is the sample.

Run every test headless:

```sh
scripts/run-tests.sh
```

It downloads the pinned Godot if needed and exits non-zero when a test fails or a test script does not parse. You can also run tests from the GUT panel in the editor.
