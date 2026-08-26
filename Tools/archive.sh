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
