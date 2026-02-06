#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ClipboardManager"
PRODUCT_NAME="ClipboardManagerApp"
BUNDLE_ID="com.clipboardmanager.macos"
MIN_MACOS="13.0"
VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/.build/release"
BIN_PATH="$BUILD_DIR/$PRODUCT_NAME"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_STAGING="$DIST_DIR/dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Script này chỉ chạy trên macOS (cần hdiutil, codesign)."
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DMG_STAGING"

echo "▶ Building Swift release binary..."
swift build -c release

if [[ ! -f "$BIN_PATH" ]]; then
  echo "❌ Không tìm thấy binary tại: $BIN_PATH"
  exit 1
fi

echo "▶ Packaging .app bundle..."
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS}</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "▶ Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_DIR"

cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "▶ Creating drag-and-drop installer DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "✅ Hoàn tất"
echo "- App bundle: $APP_DIR"
echo "- DMG installer: $DMG_PATH"
