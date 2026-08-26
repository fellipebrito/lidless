#!/usr/bin/env bash
# Build, sign, notarize, staple, and package Lidless as a DMG.
#
# Everything here is automatic EXCEPT the certificate, which Apple will only let
# the Account Holder create. See README, "Getting the certificate".
#
#   ./scripts/release.sh            signed + notarized (needs the cert)
#   ./scripts/release.sh --unsigned ad-hoc, for local testing only
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APPDIR="$HERE/../app"
DIST="$HERE/../dist"
TEAM="R29263A4RW"
KEY_ID="CV35ZGBL62"
# The .p8 and the issuer are NOT in this repo. The key lives at
# ~/.appstoreconnect/private_keys/ and the issuer is passed in the environment.
: "${ASC_ISSUER:?set ASC_ISSUER to the App Store Connect issuer id}"

UNSIGNED=0
[ "${1:-}" = "--unsigned" ] && UNSIGNED=1

rm -rf "$DIST"; mkdir -p "$DIST"
cd "$APPDIR"
xcodegen generate >/dev/null

if [ "$UNSIGNED" = 1 ]; then
  xcodebuild -project Lidless.xcodeproj -scheme Lidless -configuration Release \
    -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build >/dev/null
else
  xcodebuild -project Lidless.xcodeproj -scheme Lidless -configuration Release \
    -derivedDataPath build/dd \
    CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM" build >/dev/null
fi

APP="$(find build/dd/Build/Products/Release -maxdepth 1 -name 'Lidless.app' | head -1)"
[ -n "$APP" ] || { echo "no app built" >&2; exit 1; }
cp -R "$APP" "$DIST/Lidless.app"

if [ "$UNSIGNED" = 0 ]; then
  # Hardened runtime is required for notarization and is set in project.yml.
  codesign --force --options runtime --timestamp \
    --sign "Developer ID Application" "$DIST/Lidless.app"
  codesign --verify --strict --verbose=2 "$DIST/Lidless.app"
fi

# A DMG rather than a zip: teammates get the drag-to-Applications gesture, and
# the notarization ticket can be stapled to the DMG itself.
ln -s /Applications "$DIST/Applications"
hdiutil create -volname "Lidless" -srcfolder "$DIST" -ov -format UDZO "$DIST/../Lidless.dmg" >/dev/null
mv "$DIST/../Lidless.dmg" "$DIST/Lidless.dmg"
rm -f "$DIST/Applications"

if [ "$UNSIGNED" = 0 ]; then
  codesign --force --sign "Developer ID Application" "$DIST/Lidless.dmg"
  xcrun notarytool submit "$DIST/Lidless.dmg" \
    --key "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8" \
    --key-id "$KEY_ID" --issuer "$ASC_ISSUER" --wait
  # Stapling is what lets it open on a Mac with no network.
  xcrun stapler staple "$DIST/Lidless.dmg"
  xcrun stapler validate "$DIST/Lidless.dmg"
  echo
  echo "  Signed and notarized: $DIST/Lidless.dmg"
  echo "  Verify the way a teammate's Mac will:"
  echo "    spctl -a -vvv -t install $DIST/Lidless.dmg"
else
  echo "  UNSIGNED build: $DIST/Lidless.dmg"
  echo "  Teammates will be blocked by Gatekeeper. Local testing only."
fi
