#!/usr/bin/env bash
# Runs the GUT tests in src/tests/ headless. Exits non-zero if any test fails.
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f src/project.godot ] || {
	echo "error: no Godot project yet; run scripts/setup-project.sh \"<Game Name>\" first" >&2
	exit 1
}
scripts/setup-project.sh
godot=".tools/godot/$(cat .godot-version)/godot"

"$godot" --headless --path src --import
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$godot" --headless --path src -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit 2>&1 | tee "$log"
if grep -q "Parse Error" "$log"; then
	echo "error: a script failed to parse, so GUT skipped it; see the Parse Error above" >&2
	exit 1
fi
