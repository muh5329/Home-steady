#!/usr/bin/env bash
# Renders capture tests to tests/output/*.png. Usage: tools/capture.sh [filter]
# Needs a display; on a headless Linux box it runs under xvfb with software Vulkan.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null; then
  VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}" \
    xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path . --resolution 1600x900 --fixed-fps 30 \
    --audio-driver Dummy res://tests/test_runner.tscn -- --capture "${1:-}"
else
  "$GODOT" --path . --resolution 1600x900 --fixed-fps 30 res://tests/test_runner.tscn -- --capture "${1:-}"
fi
