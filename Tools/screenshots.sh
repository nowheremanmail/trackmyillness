#!/bin/bash
#
# Generates the App Store screenshots.
#
# Apple wants one set at 6.9" iPhone (1320×2868) and, because the app ships for
# iPad too, one at 13" iPad (2064×2752). Both simulators produce those sizes
# natively, so nothing is scaled.
#
# The app is launched once per screen with -seedScreenshotData, which replaces the
# store with a tidy sample, and -screenshotRoute, which opens the screen directly.
# No tapping, so a rerun produces the same images. See ScreenshotSupport.swift.
#
#   Tools/screenshots.sh              # every locale below
#   Tools/screenshots.sh es-ES        # just one
#
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="AppStore/screenshots"
SCHEME="TrackMyIllness"
BUNDLE_ID="eu.nowhereman.ios.trackmyillness"
ROUTES=(report history settings close)

# App Store Connect locale -> the language code the app is built with.
LOCALES=("en-US:en" "es-ES:es")
[ $# -gt 0 ] && LOCALES=("$1:$(echo "$1" | cut -d- -f1)")

DEVICES=("iPhone 17 Pro Max:iphone-6.9" "iPad Pro 13-inch (M5):ipad-13")

echo "==> Building $SCHEME (Debug, simulator)"
xcodebuild -project TrackMyIllness.xcodeproj -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  -derivedDataPath build/screenshots build > /dev/null
APP="build/screenshots/Build/Products/Debug-iphonesimulator/$SCHEME.app"
[ -d "$APP" ] || { echo "no app at $APP"; exit 1; }

for device_entry in "${DEVICES[@]}"; do
  device_name="${device_entry%%:*}"
  device_slug="${device_entry##*:}"
  udid=$(xcrun simctl list devices available -j \
    | python3 -c "
import json, re, sys
name = sys.argv[1]
best = None
for runtime, devices in json.load(sys.stdin)['devices'].items():
    match = re.search(r'iOS-(\\d+)-(\\d+)', runtime)
    if not match: continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in devices:
        # Newest runtime wins: the same model exists on several, and only the
        # newest satisfies the app's deployment target.
        if device['name'] == name and (best is None or version > best[0]):
            best = (version, device['udid'])
if best: print(best[1])
" "$device_name")
  [ -n "$udid" ] || { echo "!! no simulator named '$device_name' — skipping"; continue; }

  echo "==> $device_name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl install "$udid" "$APP"

  for locale_entry in "${LOCALES[@]}"; do
    store_locale="${locale_entry%%:*}"
    language="${locale_entry##*:}"
    dir="$OUT/$store_locale/$device_slug"
    mkdir -p "$dir"

    index=1
    for route in "${ROUTES[@]}"; do
      xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
      xcrun simctl launch "$udid" "$BUNDLE_ID" \
        -seedScreenshotData -screenshotRoute "$route" \
        -AppleLanguages "($language)" -AppleLocale "${store_locale/-/_}" > /dev/null
      # Let the seed land and the first frame settle before the shutter.
      sleep 4
      out="$dir/$(printf '%02d' $index)-$route.png"
      xcrun simctl io "$udid" screenshot --type=png "$out" > /dev/null 2>&1
      echo "    $out  ($(sips -g pixelWidth -g pixelHeight "$out" | awk '/pixel/ {printf "%s ", $2}'))"
      index=$((index + 1))
    done
  done

  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
done

echo "==> done — screenshots in $OUT"
