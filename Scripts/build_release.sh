#!/bin/bash
# Builds the Release app with the PolarBear Engine inside it (Contents/Helpers/polarbear-engine).
#
#   Scripts/build_release.sh [build-folder]     prints the path of the finished .app
#
# The engine is a separate Rust program (engine/polarbear). Xcode does not build it, so this
# script builds it with cargo, builds the app, copies the engine in and signs both again with the
# identity the app was signed with. The app finds it at launch (PolarBearEngine.locate).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/polarbear-release}"

# The engine is optional for the app (it compiles with Tectonic or a TeX distribution until the
# engine can typeset), so a failing engine build must not stop the app from being built.
echo "Building the engine…" >&2
EMBED_ENGINE=1
if ! (cd "$ROOT/engine/polarbear" && cargo build --release --quiet) >&2; then
  echo "warning: the PolarBear Engine did not build; the app is built without it." >&2
  EMBED_ENGINE=0
fi

echo "Building the app…" >&2
xcodebuild -project "$ROOT/PolarBear.xcodeproj" -scheme PolarBear -configuration Release \
  -derivedDataPath "$OUT" build -quiet >&2

APP="$OUT/Build/Products/Release/PolarBear.app"
TEAM="${EXPECTED_TEAM:-ZVTM472P7V}"
ENGINE="$ROOT/engine/polarbear/target/release/polarbear-engine"
[ -d "$APP" ] || { echo "No app at $APP" >&2; exit 1; }
# Only the maintainer's own team signs PolarBear. Stop if Xcode picked another certificate.
SIGNED_TEAM="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
[ "$SIGNED_TEAM" = "$TEAM" ] || { echo "error: the app is signed by team '$SIGNED_TEAM', expected '$TEAM'" >&2; exit 1; }

if [ "$EMBED_ENGINE" = 1 ]; then
  [ -x "$ENGINE" ] || { echo "No engine at $ENGINE" >&2; exit 1; }
  mkdir -p "$APP/Contents/Helpers"
  cp "$ENGINE" "$APP/Contents/Helpers/polarbear-engine"
fi

# SIGN_IDENTITY (the hash or name of a "Developer ID Application" certificate) is what Scripts/release.sh
# passes in. Without it the app is re-signed with the certificate Xcode already used, named by its hash
# (names can be ambiguous when the keychain holds the same certificate twice).
# A secure timestamp keeps the signature valid after the certificate expires (and notarisation needs it).
TIMESTAMP=(--timestamp)
if [ -n "${SIGN_IDENTITY:-}" ]; then
  IDENTITY="$SIGN_IDENTITY"
else
  CERTS="$(mktemp -d)"
  (cd "$CERTS" && codesign -d --extract-certificates "$APP" >/dev/null 2>&1) || true
  if [ -f "$CERTS/codesign0" ]; then
    IDENTITY="$(shasum -a 1 "$CERTS/codesign0" | cut -d' ' -f1 | tr 'a-f' 'A-F')"
  else
    IDENTITY="-"
  fi
  rm -rf "$CERTS"
fi
echo "Signing with: $IDENTITY" >&2
if [ "$EMBED_ENGINE" = 1 ]; then
  codesign --force --options runtime ${TIMESTAMP[@]+"${TIMESTAMP[@]}"} --sign "$IDENTITY" "$APP/Contents/Helpers/polarbear-engine" >&2
fi
codesign --force --options runtime ${TIMESTAMP[@]+"${TIMESTAMP[@]}"} --preserve-metadata=identifier,entitlements,flags --sign "$IDENTITY" "$APP" >&2
codesign --verify --deep --strict "$APP" >&2

echo "$APP"
