#!/bin/bash
# Dev loop: build a debug bundle of DripMeter.app, kill any running
# instance, relaunch.
#
# Running the loose binary at `.build/<arch>/debug/DripMeter` works
# on older macOS, but UserNotifications (used by MilestoneNotifier)
# refuses to initialise outside a real .app bundle on macOS 14+:
#   *** NSInternalInconsistencyException: bundleProxyForCurrentProcess is nil
# So we always go through package_app.sh, which assembles a proper
# bundle. The debug build keeps it fast (~3 s incremental).
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--test" ]]; then
    echo "→ swift test"
    swift test
fi

CONFIGURATION=debug ./Scripts/package_app.sh

echo "→ killing any running DripMeter"
pkill -x DripMeter 2>/dev/null || true

echo "→ launching DripMeter.app"
open DripMeter.app
