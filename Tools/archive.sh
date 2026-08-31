#!/bin/bash
#
# Archives Symptrace for the App Store and, optionally, uploads it.
#
#   Tools/archive.sh                 # archive + export a signed .ipa
#   Tools/archive.sh --upload        # …and send it to App Store Connect
#
# Uploading needs an App Store Connect API key (App Store Connect → Users and
# Access → Integrations → App Store Connect API). Export these first:
#
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   # and put AuthKey_$ASC_KEY_ID.p8 in ~/.appstoreconnect/private_keys/
#
# Signing is automatic, so the Apple Developer account that owns team W37STSLM78
# must be signed in to Xcode. If you would rather do it by hand, open build/
# Symptrace.xcarchive in Xcode's Organizer and use Distribute App.
#
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="TrackMyIllness"
ARCHIVE="build/Symptrace.xcarchive"
EXPORT_DIR="build/export"
UPLOAD=false
[ "${1:-}" = "--upload" ] && UPLOAD=true

VERSION=$(xcodebuild -project TrackMyIllness.xcodeproj -scheme "$SCHEME" \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ MARKETING_VERSION/ {print $2; exit}')
BUILD=$(xcodebuild -project TrackMyIllness.xcodeproj -scheme "$SCHEME" \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ CURRENT_PROJECT_VERSION/ {print $2; exit}')
echo "==> Symptrace $VERSION ($BUILD)"

echo "==> Testing before archiving"
xcodebuild test -project TrackMyIllness.xcodeproj -scheme "$SCHEME" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet

echo "==> Archiving"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -project TrackMyIllness.xcodeproj \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -quiet

echo "==> Exporting a signed .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist AppStore/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -quiet

IPA=$(find "$EXPORT_DIR" -name '*.ipa' | head -1)
[ -n "$IPA" ] || { echo "!! no .ipa produced"; exit 1; }
echo "==> $IPA"

# App Review rejected 1.0 because en.lproj carried
# NSFaceIDUsageDescription = "NSFaceIDUsageDescription": a string catalog with no
# entry for its own source language compiles the key in as its own value, and a
# .lproj overrides the base Info.plist. Check the archive rather than the source,
# and check every language — an automated rejection costs a review cycle.
echo "==> Checking the purpose strings in the archive"
APP_DIR=$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -1)
bad=0
for key in $(/usr/libexec/PlistBuddy -c Print "$APP_DIR/Info.plist" \
             | awk -F' = ' '/UsageDescription = /{gsub(/^ +/,"",$1); print $1}'); do
  base=$(/usr/libexec/PlistBuddy -c "Print :$key" "$APP_DIR/Info.plist" 2>/dev/null || echo "")
  if [ "$base" = "$key" ] || [ ${#base} -lt 30 ]; then
    echo "!! base Info.plist: $key is placeholder or too short: '$base'"
    bad=1
  fi
  for lproj in "$APP_DIR"/*.lproj; do
    [ -f "$lproj/InfoPlist.strings" ] || continue
    value=$(plutil -extract "$key" raw -o - "$lproj/InfoPlist.strings" 2>/dev/null || echo "")
    [ -n "$value" ] || continue
    if [ "$value" = "$key" ] || [ ${#value} -lt 30 ]; then
      echo "!! $(basename "$lproj"): $key is placeholder or too short: '$value'"
      bad=1
    fi
  done
done
[ "$bad" -eq 0 ] || { echo "!! refusing to upload — App Review rejects these automatically"; exit 1; }
echo "    all purpose strings look real in every language"

if [ "$UPLOAD" = true ]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID (see the header of this script)}"
  : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (see the header of this script)}"
  echo "==> Validating"
  xcrun altool --validate-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "==> Uploading to App Store Connect"
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "==> Uploaded. Processing takes a few minutes; the build then appears"
  echo "    under the version in App Store Connect."
else
  echo "==> Not uploaded. Re-run with --upload, or drop the .ipa into Transporter."
fi
