#!/usr/bin/env bash
# Runs the project's pinned Godot (console build, so output reaches the terminal)
# with --path set to the project folder. Extra arguments are passed through.
#
#   tools/godot.sh --headless --import
#   tools/godot.sh --headless --script res://tools/run_tests.gd
#   tools/godot.sh -- --screenshot=tmp/screenshots/main.png
#   tools/godot.sh --editor
#
# Override the binary with GODOT=/path/to/Godot_console.exe.
set -euo pipefail

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
if [[ ! -f "$GODOT" ]]; then
	echo "Godot not found at: $GODOT" >&2
	echo "Install Godot 4.7.2 or set GODOT=/path/to/godot" >&2
	exit 127
fi

cd "$(dirname "$0")/.."
exec "$GODOT" --path . "$@"
