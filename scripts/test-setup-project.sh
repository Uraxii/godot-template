#!/usr/bin/env bash
# End-to-end check for setup-project.sh and run-tests.sh. Copies the repo to
# temp dirs, downloads real Godot and GUT releases, and runs the GUT tests.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$repo/src/project.godot" ]; then
	echo "This checks the template before setup, and this repo already has a project; nothing to do."
	exit 0
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}
pass() { echo "ok: $*"; }

fresh_copy() {
	mkdir "$tmp/$1"
	(cd "$repo" && tar --exclude=./.git --exclude=./.tools --exclude=./.agent-runs --exclude=./.godot-version -cf - .) | tar -xf - -C "$tmp/$1"
	echo "$tmp/$1"
}

latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/godotengine/godot/releases/latest)"; latest="${latest##*/}"; latest="${latest%-stable}"

copy="$(fresh_copy latest)"
cd "$copy"

if scripts/setup-project.sh >"$tmp/missing-name.log" 2>&1; then
	fail "a fresh copy without a game name should exit non-zero"
fi
grep -q "Usage:" "$tmp/missing-name.log" || fail "missing name should print usage"
[ ! -d .tools ] || fail "missing name should stop before downloading"
pass "no game name on a fresh copy is a usage error"

scripts/setup-project.sh "Test & \"Game\"" | tee "$tmp/first.log"
[ "$(cat .godot-version)" = "$latest" ] || fail ".godot-version is not the latest release $latest"
grep -qx 'config_version=5' src/project.godot || fail "config_version"
grep -qxF 'config/name="Test & \"Game\""' src/project.godot || fail "config/name"
grep -qxF "config/features=PackedStringArray(\"$(echo "$latest" | cut -d. -f1-2)\")" src/project.godot || fail "config/features"
grep -qxF 'enabled=PackedStringArray("res://addons/gut/plugin.cfg")' src/project.godot || fail "GUT plugin not enabled"
for dir in core features content actors levels assets headless_checks; do
	[ -f "src/$dir/.gitkeep" ] || fail "src/$dir/.gitkeep missing"
done
[ -f src/addons/gut/plugin.cfg ] || fail "GUT not installed"
[ -f src/tests/test_example.gd ] || fail "sample test missing"
grep -q '"res://tests"' src/.gutconfig.json || fail ".gutconfig.json does not point at res://tests"
! grep -q '<repo>' CLAUDE.md README.md || fail "<repo> left in CLAUDE.md or README.md"
grep -qF 'Test & "Game"' CLAUDE.md || fail "name not in CLAUDE.md"
grep -qF '# Test & "Game"' README.md || fail "name not in README.md title"
grep -qF 'src/core/' INDEX.md || fail "INDEX.md does not list src/core/"
grep -qF "$(cat .godot-version)/godot --path src -e" "$tmp/first.log" || fail "next step not printed"
pass "first run creates the project with Godot $latest"

before="$(cksum src/project.godot CLAUDE.md README.md INDEX.md)"
scripts/setup-project.sh "Other Name" | tee "$tmp/second.log"
grep -q "skipping the download" "$tmp/second.log" || fail "second run downloaded Godot again"
grep -q "already exists" "$tmp/second.log" || fail "second run did not note the existing project"
[ "$before" = "$(cksum src/project.godot CLAUDE.md README.md INDEX.md)" ] || fail "second run changed the project"
scripts/setup-project.sh >/dev/null || fail "no-argument run on an existing project should succeed"
pass "second run skips the download and leaves the project alone"

godot=".tools/godot/$latest/godot"
"$godot" --headless --path src --import >/dev/null 2>&1 || fail "headless import failed"
pass "Godot opens the project headless"

if command -v gdlint >/dev/null; then
	gdlint src/tests || fail "sample test fails gdlint"
	gdformat --check src/tests || fail "sample test fails gdformat"
	pass "sample test passes gdlint and gdformat"
fi

scripts/run-tests.sh >"$tmp/tests.log" 2>&1 || fail "run-tests.sh failed on the sample test; see $tmp/tests.log"
pass "sample test passes"
printf 'extends GutTest\n\n\nfunc test_fails() -> void:\n\tassert_eq(1, 2)\n' >src/tests/test_failing.gd
if scripts/run-tests.sh >/dev/null 2>&1; then fail "run-tests.sh passed with a failing test"; fi
pass "a failing test makes run-tests.sh exit non-zero"
printf 'extends GutTest\nfunc test_broken( -> void:\n' >src/tests/test_failing.gd
if scripts/run-tests.sh >/dev/null 2>&1; then fail "run-tests.sh passed with a test that does not parse"; fi
pass "a test that does not parse makes run-tests.sh exit non-zero"
rm -f src/tests/test_failing.gd src/tests/test_failing.gd.uid
scripts/run-tests.sh >/dev/null 2>&1 || fail "run-tests.sh failed after removing the failing test"
pass "tests pass again after removing the failing test"
find src -path src/.godot -prune -o -name '*.uid' -print | grep -q . || fail "setup did not import the project, so no .uid files exist"
pass "setup imports the project, so .uid files exist before the first commit"
mv src/tests "$tmp/tests-aside"
if scripts/run-tests.sh >/dev/null 2>&1; then fail "run-tests.sh passed with no tests"; fi
mv "$tmp/tests-aside" src/tests
pass "no tests makes run-tests.sh exit non-zero"

for bad in "4.5.1/../x" "4" "4.5.1.2" "4.5-rc1" "3.5" "4.5 "; do
	if scripts/setup-project.sh --godot "$bad" >"$tmp/bad-version.log" 2>&1; then fail "--godot '$bad' should be rejected"; fi
	grep -q "Godot version" "$tmp/bad-version.log" || fail "--godot '$bad' gave no version error"
done
pass "malformed --godot values are rejected"

pinned="4.5.1"
copy="$(fresh_copy pinned)"
cd "$copy"
scripts/setup-project.sh "Pinned Game" --godot "$pinned"
[ "$(cat .godot-version)" = "$pinned" ] || fail ".godot-version is not $pinned"
grep -qxF 'config/features=PackedStringArray("4.5")' src/project.godot || fail "pinned config/features"
grep -qxF 'version="9.5.0"' src/addons/gut/plugin.cfg || fail "Godot 4.5 should get GUT 9.5.0"
scripts/run-tests.sh >/dev/null 2>&1 || fail "run-tests.sh failed on Godot $pinned"
pass "--godot $pinned creates a 4.5 project with GUT 9.5.0 and its tests pass"

rm src/project.godot
scripts/setup-project.sh "Pinned Game" >/dev/null
[ ! -e src/addons/gut/gut ] || fail "rerun nested GUT inside itself"
[ -f src/project.godot ] && [ -f src/addons/gut/plugin.cfg ] || fail "rerun did not recreate the project"
pass "a rerun after partial setup replaces GUT instead of nesting it"

scripts/setup-project.sh --godot 4.5.0 >/dev/null
[ "$(cat .godot-version)" = "4.5" ] || fail "--godot 4.5.0 should be stored as 4.5"
pass "--godot 4.5.0 works and is stored as 4.5"

echo "All setup-project checks passed."
