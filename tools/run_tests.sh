#!/usr/bin/env bash
# Runs the headless test suite. Usage: tools/run_tests.sh [filter]
# GODOT env var overrides the binary (default: godot on PATH).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Refresh imports and the global class cache (fast when nothing changed).
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --fixed-fps 60 --audio-driver Dummy res://tests/test_runner.tscn -- "${1:-}"
