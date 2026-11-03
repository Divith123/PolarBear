#!/bin/bash
# Installs the latest PolarBear release into /Applications without any "unidentified developer"
# prompt and without a trip to Privacy & Security.
#
#   curl -fsSL https://raw.githubusercontent.com/Divith123/PolarBear/main/Scripts/get-polarbear.sh | bash
#
# Why this works: macOS only checks apps that carry the "quarantine" flag, and a browser puts that
# flag on everything it downloads. `curl` does not, so the app installed here opens like any other.
# The disk image is still checked against the SHA-256 published with the release before anything
# is copied. (A notarised build, see Scripts/release.sh, needs none of this.)
#
# Environment:  POLARBEAR_REPO     owner/name on GitHub        (default Divith123/PolarBear)
#               INSTALL_DIR        where the app goes          (default /Applications)
#               POLARBEAR_DMG_URL  use this disk image instead of the latest release (testing)
set -euo pipefail

REPO="${POLARBEAR_REPO:-Divith123/PolarBear}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
BASE="https://github.com/$REPO/releases/latest/download"
DMG_URL="${POLARBEAR_DMG_URL:-$BASE/PolarBear.dmg}"
SUM_URL="${POLARBEAR_SHA256_URL:-${DMG_URL}.sha256}"

[ "$(uname)" = "Darwin" ] || { echo "PolarBear is a Mac app." >&2; exit 1; }

WORK="$(mktemp -d)"
MOUNT="$WORK/mount"
cleanup() {
  hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Downloading PolarBear…"
curl -fL --progress-bar -o "$WORK/PolarBear.dmg" "$DMG_URL"
curl -fsSL -o "$WORK/PolarBear.dmg.sha256" "$SUM_URL"

echo "Checking the download…"
EXPECTED="$(awk '{print $1}' "$WORK/PolarBear.dmg.sha256")"
ACTUAL="$(shasum -a 256 "$WORK/PolarBear.dmg" | awk '{print $1}')"
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo "error: the checksum does not match; nothing was installed." >&2; exit 1; }

mkdir -p "$MOUNT"
hdiutil attach "$WORK/PolarBear.dmg" -mountpoint "$MOUNT" -nobrowse -readonly -quiet
[ -d "$MOUNT/PolarBear.app" ] || { echo "error: the disk image has no PolarBear.app." >&2; exit 1; }

# Quit a running copy, then replace it.
osascript -e 'tell application "PolarBear" to quit' >/dev/null 2>&1 || true
sleep 1
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/PolarBear.app"
ditto "$MOUNT/PolarBear.app" "$INSTALL_DIR/PolarBear.app"
xattr -dr com.apple.quarantine "$INSTALL_DIR/PolarBear.app" 2>/dev/null || true

codesign --verify --deep --strict "$INSTALL_DIR/PolarBear.app"
echo "Installed $INSTALL_DIR/PolarBear.app"
[ "$INSTALL_DIR" = "/Applications" ] && open "$INSTALL_DIR/PolarBear.app"
exit 0
