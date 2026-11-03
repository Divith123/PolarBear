#!/bin/bash
# Builds PolarBear with its engine and installs it in /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$("$ROOT/Scripts/build_release.sh" /tmp/polarbear-install-build)"

osascript -e 'tell application "PolarBear" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf /Applications/PolarBear.app
cp -R "$APP" /Applications/PolarBear.app
rm -rf /tmp/polarbear-install-build
echo "Installed /Applications/PolarBear.app"
open /Applications/PolarBear.app
