#!/usr/bin/env bash
# Downloads this project's Godot editor into .tools/godot/<version>/ and, on
# the first run, creates the Godot project in src/ with GUT installed.
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
Usage: scripts/setup-project.sh ["<Game Name>"] [--godot <version>]

  <Game Name>        Required the first time, while src/project.godot does not exist.
  --godot <version>  Godot version to use, for example 4.5.1. Defaults to the
                     version in .godot-version, else the latest stable release.
EOF
	exit 2
}

die() {
	echo "error: $*" >&2
	exit 1
}

name=""
version=""
while [ $# -gt 0 ]; do
	case "$1" in
	--godot)
		[ $# -ge 2 ] || usage
		version="$2"
		shift 2
		;;
	-h | --help) usage ;;
	-*) usage ;;
	*)
		[ -z "$name" ] || usage
		name="$1"
		shift
		;;
	esac
done

cd "$(dirname "$0")/.."
command -v python3 >/dev/null || die "python3 is required"
command -v curl >/dev/null || die "curl is required"
command -v unzip >/dev/null || die "unzip is required"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ ! -f src/project.godot ] && [ -z "$name" ]; then
	echo "error: src/project.godot does not exist yet, so a game name is required." >&2
	usage
fi

case "$(uname -s)-$(uname -m)" in
Linux-x86_64) platform="linux.x86_64" ;;
Linux-aarch64 | Linux-arm64) platform="linux.arm64" ;;
Darwin-*) platform="macos.universal" ;;
*)
	die "no Godot download for $(uname -s) $(uname -m). Download Godot by hand from https://godotengine.org/download and rerun with --godot <version>."
	;;
esac

if [ -z "$version" ] && [ -f .godot-version ]; then
	version="$(tr -d '[:space:]' <.godot-version)"
fi
if [ -z "$version" ]; then
	latest_json="$(gh api repos/godotengine/godot/releases/latest 2>/dev/null ||
		curl -fsSL https://api.github.com/repos/godotengine/godot/releases/latest)" ||
		die "could not reach the GitHub API to find the latest Godot release"
	version="$(printf '%s' "$latest_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"].removesuffix("-stable"))')"
fi
case "$version" in
4.[0-9]*) ;;
*) die "unsupported Godot version '$version'; this template needs Godot 4.x" ;;
esac
major_minor="$(printf '%s' "$version" | cut -d. -f1-2)"

tag="$version-stable"
asset="Godot_v${tag}_${platform}.zip"
godot_dir=".tools/godot/$version"
if [ "$platform" = "macos.universal" ]; then
	binary="Godot.app/Contents/MacOS/Godot"
else
	binary="Godot_v${tag}_${platform}"
fi

if [ -x "$godot_dir/$binary" ]; then
	echo "Godot $version is already downloaded in $godot_dir; skipping the download."
else
	base="https://github.com/godotengine/godot/releases/download/$tag"
	echo "Downloading $asset ..."
	curl -fL --progress-bar -o "$work/$asset" "$base/$asset" ||
		die "download failed: $base/$asset"
	curl -fsSL -o "$work/SHA512-SUMS.txt" "$base/SHA512-SUMS.txt" ||
		die "could not download $base/SHA512-SUMS.txt"
	python3 - "$work/$asset" "$work/SHA512-SUMS.txt" <<'EOF' || die "checksum mismatch for $asset; not installing it"
import hashlib, pathlib, sys
archive, sums = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
expected = {line.split()[1]: line.split()[0] for line in sums.read_text().splitlines() if line.strip()}
sys.exit(0 if expected.get(archive.name) == hashlib.sha512(archive.read_bytes()).hexdigest() else 1)
EOF
	echo "Checksum OK."
	mkdir -p "$work/unpacked" .tools/godot
	unzip -q "$work/$asset" -d "$work/unpacked"
	rm -rf "$godot_dir"
	mv "$work/unpacked" "$godot_dir"
fi
# shellcheck disable=SC2016 # the launcher expands $0 and $@ when it runs, not now
printf '#!/bin/sh\nexec "$(dirname "$0")/%s" "$@"\n' "$binary" >"$godot_dir/godot"
chmod +x "$godot_dir/godot"
printf '%s\n' "$version" >.godot-version

if [ -f src/project.godot ]; then
	echo "Note: src/project.godot already exists, so the project was left as is."
	echo "Open it with: $godot_dir/godot --path src -e"
	exit 0
fi

gut_tag="$(curl -fsSL https://raw.githubusercontent.com/bitwes/Gut/main/README.md | python3 -c '
import re, sys
minor = int(sys.argv[1].split(".")[1])
rows = []
for line in sys.stdin:
    m = re.match(r"\|\[(9\.\d+\.\d+)\]\(https://github\.com/bitwes/Gut/releases/tag/([^)]+)\)[^|]*\|([^|]+)\|", line)
    if m:
        minors = [int(x) for x in re.findall(r"4\.(\d+)", m.group(3))]
        rows.append((tuple(map(int, m.group(1).split("."))), m.group(2), min(minors), max(minors)))
rows.sort(reverse=True)
fits = [tag for _, tag, lo, hi in rows if lo <= minor <= hi]
if fits:
    print(fits[0])
elif rows and minor > max(hi for *_, hi in rows):
    print(f"warning: no GUT release lists Godot 4.{minor} yet; using the newest one.", file=sys.stderr)
    print(rows[0][1])
' "$major_minor")" || die "could not find a GUT release for Godot $major_minor"
[ -n "$gut_tag" ] || die "no GUT release supports Godot $major_minor"

echo "Downloading GUT $gut_tag ..."
curl -fsSL -o "$work/gut.zip" "https://github.com/bitwes/Gut/archive/refs/tags/$gut_tag.zip" ||
	die "could not download GUT $gut_tag"
unzip -q "$work/gut.zip" -d "$work"
mkdir -p src/addons
mv "$work"/*/addons/gut src/addons/gut

for dir in core features content actors levels assets headless_checks; do
	mkdir -p "src/$dir"
	touch "src/$dir/.gitkeep"
done
mkdir -p src/tests

python3 - "$name" "$major_minor" <<'EOF'
import json, pathlib, sys
name, major_minor = sys.argv[1], sys.argv[2]
godot_name = name.replace("\\", "\\\\").replace('"', '\\"')
pathlib.Path("src/project.godot").write_text(f"""; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="{godot_name}"
config/features=PackedStringArray("{major_minor}")

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
""")
pathlib.Path("src/.gutconfig.json").write_text(json.dumps(
    {"dirs": ["res://tests"], "include_subdirs": True, "should_exit": True}, indent=2) + "\n")
pathlib.Path("src/tests/test_example.gd").write_text("""extends GutTest


func test_vector_length_is_pythagorean() -> void:
	assert_eq(Vector2(3, 4).length(), 5.0)
""")
for doc in ("CLAUDE.md", "README.md"):
    path = pathlib.Path(doc)
    path.write_text(path.read_text().replace("`<repo>`", name).replace("<repo>", name))
pathlib.Path("INDEX.md").write_text("""# Index

- `src/core/`: engine glue and game-wide services.
- `src/features/`: one folder per game system.
- `src/content/`: authored data, the Resources designers edit.
- `src/actors/`: player, enemy, and NPC scenes.
- `src/levels/`: playable levels and playtest scenes.
- `src/assets/`: art, audio, and fonts.
- `src/headless_checks/`: scripted checks run with `godot --headless`.
- `src/tests/`: GUT unit tests; `scripts/run-tests.sh` runs them.
- `src/addons/`: vendored plugins, GUT included. Do not edit addons.
- `scripts/`: host tools. `setup-project.sh` fetches this project's Godot; `run-tests.sh` runs the tests.
- `.github/`: issue forms, the PR template, and CI workflows.
""")
EOF

echo
echo "Created the Godot $major_minor project \"$name\" in src/ with GUT $gut_tag."
echo "Next step, open it in the editor:"
echo "  $godot_dir/godot --path src -e"
