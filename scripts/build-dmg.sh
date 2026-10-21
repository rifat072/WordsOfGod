#!/bin/zsh
# Builds a Release copy of the Mac app, signs it ad hoc (no Apple Developer account needed)
# and packages it as dist/WordsOfGod-<version>.dmg.
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f Config/Secrets.xcconfig ]] || { echo "Missing Config/Secrets.xcconfig (see README)."; exit 1; }

BUILD_DIR="build/dmg"
DIST_DIR="dist"
APP_NAME="WordsOfGod"

rm -rf "$BUILD_DIR"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" \
  ONLY_ACTIVE_ARCH=NO build | grep -E "error:|warning:|BUILD" || true

APP="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "Build failed."; exit 1; }
# Re-sign with the app's own entitlements minus get-task-allow, which only debug builds need.
ENTITLEMENTS="$BUILD_DIR/entitlements.plist"
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS" 2>/dev/null
/usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" "$ENTITLEMENTS" 2>/dev/null || true
codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --strict "$APP"

SIGNED_ENTITLEMENTS=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)
[[ "$SIGNED_ENTITLEMENTS" == *"com.apple.security.app-sandbox"* ]] || { echo "App is not sandboxed; not packaging."; exit 1; }
[[ "$SIGNED_ENTITLEMENTS" != *"get-task-allow"* ]] || { echo "App still allows debugging; not packaging."; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGING="$BUILD_DIR/staging"
mkdir -p "$STAGING" "$DIST_DIR"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"
rm -f "$DMG"
# `diskutil image` replaces the deprecated `hdiutil create` from macOS 27 on.
if diskutil image create from --help >/dev/null 2>&1; then
  diskutil image create from --format UDZO --volumeName "$APP_NAME $VERSION" "$STAGING" "$DMG" >/dev/null
else
  hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -format UDZO -ov "$DMG" >/dev/null
fi

echo "Created $DMG ($(du -h "$DMG" | cut -f1)), architectures: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
shasum -a 256 "$DMG"
