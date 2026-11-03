#!/bin/bash
# Static checks of PolarBear's source conventions (see CONTRIBUTING.md). It only greps the
# repository — it is not a test suite. CI runs it on every push.
#
#   bash Scripts/lint.sh
cd "$(dirname "$0")/.." || exit 2

SRC="PolarBear"
ORIGINAL_SHA="52e17944910bbe928aff0655632b44eb22f7235e5f26712d82edb5b161a79209"
failures=0

fail() { echo "FAIL  $1"; shift; printf '      %s\n' "$@"; failures=$((failures + 1)); }
pass() { echo "ok    $1"; }

# $1 label, $2 extended regex, $3 optional "keep" regex lines to ignore
forbid() {
  local hits
  hits=$(grep -rnE "$2" "$SRC" --include='*.swift' | { if [ -n "$3" ]; then grep -vE "$3"; else cat; fi; })
  [ -z "$hits" ] && pass "$1" || fail "$1" "$hits"
}

echo "== Look and feel"

# Solid, opaque UI (no glass or translucency)
forbid "no glass / material APIs" 'glassEffect|GlassEffectContainer|buttonStyle\(\.glass|NSVisualEffectView|NSGlassEffectView|containerBackground|\bMaterial\b|ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial'
forbid "themes: no hard-coded colour scheme (use .appAppearance())" 'preferredColorScheme\(\.(dark|light)\)'
forbid "chrome uses theme tokens, not .white/.black" 'foregroundStyle\(\.(white|black)\)|background\(\.(white|black)|fill\(\.(white|black)\)|Color\.(white|black)' 'DesignSystem/AppTheme.swift|TabStripFade'
forbid "window stays opaque" 'window\.isOpaque *= *false|window\.backgroundColor *= *\.clear|backgroundColor *= *NSColor\.clear'

# No title-bar strip; window buttons on the first row; draggable top rows
grep -q 'windowStyle(.hiddenTitleBar)' "$SRC/App/PolarBearApp.swift" && pass "hidden title bar" || fail ".windowStyle(.hiddenTitleBar) missing in App/PolarBearApp.swift"
grep -q 'positionTrafficLights' "$SRC/Window/WindowChromeController.swift" && pass "traffic lights positioned" || fail "traffic-light placement missing"
for f in Sidebar/SidebarWindowRow Editor/EditorTabBar Preview/PDFHeaderRow; do
  grep -q 'WindowDragArea()' "$SRC/$f.swift" && pass "drag area in $f" || fail "WindowDragArea missing in $f.swift"
done

# Continuous corners only
forbid "RoundedRectangle uses .continuous" 'RoundedRectangle\(' 'continuous'
forbid "no NSBezierPath rounded rects" 'NSBezierPath\(roundedRect'
for f in $(grep -rl '\.cornerRadius *=' "$SRC" --include='*.swift'); do
  radius=$(grep -c '\.cornerRadius *=' "$f"); curve=$(grep -c 'cornerCurve *= *\.continuous' "$f")
  [ "$curve" -ge "$radius" ] && pass "layer corners continuous in $f" || fail "cornerCurve missing in $f ($radius radii, $curve curves)"
done

# Branding and the original artwork
# The name may appear only where it names the source of a migration: the importer and its menu items.
forbid "no 'Prism' in sources" 'Prism' 'legacy|Migrate from Prism|^PolarBear/Import/'
for f in "Design/polarbear-original.png" "$SRC/Assets.xcassets/PolarBearArtwork.imageset/polarbear-original.png"; do
  sha=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
  [ "$sha" = "$ORIGINAL_SHA" ] && pass "untouched artwork: $f" || fail "artwork changed or missing: $f"
done
[ -f "$SRC/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" ] && pass "app icon present" || fail "app icon missing"

echo
echo "== Structure, API and concurrency"

# Project structure: one type per file, grouped in feature folders
many=""
for f in $(find "$SRC" -name '*.swift'); do
  n=$(grep -cE '^(@[A-Za-z]+ +)*((public|internal|private|fileprivate|final|open|indirect) +)*(struct|class|enum|actor|protocol) ' "$f")
  [ "$n" -gt 1 ] && many="$many$f ($n types)"$'\n'
done
[ -z "$many" ] && pass "one top-level type per file" || fail "several types in one file" "$many"

loose=$(find "$SRC" -maxdepth 1 -name '*.swift')
[ -z "$loose" ] && pass "no Swift files loose in the source root" || fail "Swift files outside feature folders" "$loose"

# Deprecated / discouraged API
forbid "no foregroundColor() / cornerRadius()" '\.foregroundColor\(|\.cornerRadius\([0-9]'
forbid "no onTapGesture (use Button)" 'onTapGesture'
forbid "no showsIndicators: (use scrollIndicators)" 'showsIndicators:'
forbid "no closure Binding(get:set:)" 'Binding\(get:'
forbid "no fixed font sizes in the UI (use text styles)" '\.font\(\.system\(size' 
forbid "no GeometryReader (use onGeometryChange / containerRelativeFrame)" 'GeometryReader'
forbid "no AnyView" 'AnyView'
forbid "no ObservableObject-era wrappers" 'ObservableObject|@Published|@StateObject|@ObservedObject|@EnvironmentObject'
forbid "no NavigationView" 'NavigationView'

# Swift style and concurrency
# FSEvents only delivers on a dispatch queue, so the folder watcher is the one place that has one.
forbid "no GCD (use Swift concurrency)" 'DispatchQueue|DispatchGroup|DispatchSemaphore' '^PolarBear/Project/Watching/FolderWatcher.swift:'
forbid "no Task.sleep(nanoseconds:)" 'Task\.sleep\(nanoseconds'
forbid "no force try / force cast" 'try!|as!'
forbid "no replacingOccurrences / String(format:)" 'replacingOccurrences|String\(format:'
forbid "filter text with localizedStandardContains" 'localizedCaseInsensitiveContains'
forbid "no redundant 'import AppKit' next to SwiftUI" '^import AppKit'

echo
if [ "$failures" -eq 0 ]; then echo "PASS"; else echo "FAIL ($failures)"; exit 1; fi
