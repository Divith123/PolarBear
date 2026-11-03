#!/bin/bash
# Builds the PolarBear installer that macOS opens without any warning, and optionally publishes it.
#
#   Scripts/release.sh                          build, sign, notarise and staple dist/PolarBear.dmg
#   Scripts/release.sh --publish                ... and then create the GitHub release (needs `gh login`)
#   Scripts/release.sh --no-notarize [--publish]   development-signed build, for when there is no Developer ID:
#                                               users then install with Scripts/get-polarbear.sh (see README)
#
# macOS only opens an app downloaded from the internet without "unidentified developer" prompts, and
# without sending the user to Privacy & Security, when it is
#   1. signed with a "Developer ID Application" certificate (hardened runtime + secure timestamp), and
#   2. notarised by Apple, with the ticket stapled to the disk image.
# Both need a paid Apple Developer Program membership. One-time setup:
#
#   • Xcode ▸ Settings ▸ Accounts ▸ (your team) ▸ Manage Certificates ▸ + ▸ Developer ID Application
#   • An app-specific password for your Apple ID (account.apple.com ▸ Sign-In and Security), then
#       xcrun notarytool store-credentials PolarBear-notary --apple-id <id> --team-id <TEAM> --password <app-password>
#
# Environment:  SIGN_IDENTITY (certificate name or hash; default: the first Developer ID Application found)
#               NOTARY_PROFILE (default PolarBear-notary)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${NOTARY_PROFILE:-PolarBear-notary}"
DMG="$ROOT/dist/PolarBear.dmg"
PUBLISH=0
NOTARIZE=1
for argument in "$@"; do
  case "$argument" in
    --publish) PUBLISH=1 ;;
    --no-notarize) NOTARIZE=0 ;;
    *) echo "unknown option $argument" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

if [ "$NOTARIZE" = 1 ]; then
  # 1. A Developer ID certificate.
  IDENTITY="${SIGN_IDENTITY:-}"
  if [ -z "$IDENTITY" ]; then
    # Only the maintainer's own team (ZVTM472P7V, hustleronduty) may sign releases.
    IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) \([0-9A-F]\{40\}\) "Developer ID Application:.*(ZVTM472P7V)".*/\1/p' | head -1)"
  fi
  [ -n "$IDENTITY" ] || die "no \"Developer ID Application\" certificate for team ZVTM472P7V in the keychain.
  (Other certificates in the keychain are never used.)
  Without one, macOS shows \"unidentified developer\" for a downloaded app and Gatekeeper rejects it.
  See the setup steps at the top of this script, or publish with --no-notarize."

  # 2. Notarisation credentials.
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || die "no notarytool credentials named \"$PROFILE\". See the setup steps at the top of this script."
  export SIGN_IDENTITY="$IDENTITY"
fi
mkdir -p "$ROOT/dist"

# 3. Build the app (engine inside, Developer ID signature), then the disk image around it.
echo "Building and signing the app…"
APP="$("$ROOT/Scripts/build_release.sh" /tmp/polarbear-release-build | tail -1)"
codesign --verify --deep --strict --verbose=2 "$APP"
if [ "$NOTARIZE" = 1 ]; then
  codesign -dvv "$APP" 2>&1 | grep -q "Developer ID Application" || die "the app is not signed with a Developer ID certificate"
fi

echo "Building the disk image…"
python3 "$ROOT/Scripts/make_dmg.py" --app "$APP" >/dev/null

if [ "$NOTARIZE" = 1 ]; then
  # 4. Notarise the disk image and staple the ticket to it.
  echo "Submitting to Apple's notary service (this takes a few minutes)…"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"

  # 5. The same checks Gatekeeper makes on the user's Mac.
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
  MOUNT="$(mktemp -d)"
  hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -readonly -quiet
  spctl --assess --type execute --verbose=2 "$MOUNT/PolarBear.app"
  hdiutil detach "$MOUNT" -quiet
fi
( cd "$ROOT/dist" && shasum -a 256 PolarBear.dmg > PolarBear.dmg.sha256 )
echo "Ready: $DMG"
cat "$ROOT/dist/PolarBear.dmg.sha256"

# 6. Publish.
if [ "$PUBLISH" = 1 ]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 1.0)"
  NOTES="$ROOT/dist/release-notes.md"
  if [ "$NOTARIZE" = 1 ]; then
    printf 'Download **PolarBear.dmg**, open it and drag PolarBear to Applications.\n' > "$NOTES"
  else
    {
      printf 'This build is signed but **not notarised**, so a browser download would be stopped by macOS.\n'
      printf 'Install it from Terminal instead; nothing needs to be allowed in Privacy & Security:\n\n'
      printf '```sh\ncurl -fsSL https://raw.githubusercontent.com/%s/main/Scripts/get-polarbear.sh | bash\n```\n' "${POLARBEAR_REPO:-Divith123/PolarBear}"
    } > "$NOTES"
  fi
  gh release create "v$VERSION" "$DMG" "$ROOT/dist/PolarBear.dmg.sha256" \
    --title "PolarBear $VERSION" --notes-file "$NOTES" --generate-notes
fi

rm -rf /tmp/polarbear-release-build
