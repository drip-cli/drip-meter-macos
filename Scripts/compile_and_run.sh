#!/bin/bash
# Dev loop: build in debug, kill any running DripMeter, relaunch.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "→ swift build (debug)"
swift build

if [[ "${1:-}" == "--test" ]]; then
    echo "→ swift test"
    swift test
fi

echo "→ killing any running DripMeter"
pkill -x DripMeter 2>/dev/null || true

BIN="$(swift build --show-bin-path)/DripMeter"
echo "→ launching $BIN"
"$BIN" &
echo "  pid: $!"
