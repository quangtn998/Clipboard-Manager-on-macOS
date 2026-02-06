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
BUILD_ROOT="$ROOT_DIR/.build"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_STAGING="$DIST_DIR/dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
UNIVERSAL_BIN="$MACOS_DIR/$APP_NAME"
ARM_BIN="$BUILD_ROOT/release-arm64/$PRODUCT_NAME"
X64_BIN="$BUILD_ROOT/release-x86_64/$PRODUCT_NAME"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARIZE="${NOTARIZE:-0}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Script này chỉ chạy trên macOS (cần xcrun, hdiutil, codesign)."
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Thiếu lệnh bắt buộc: $1"; exit 1; }
}

require_cmd swift
require_cmd lipo
require_cmd codesign
require_cmd hdiutil
require_cmd xcrun

rm -rf "$DIST_DIR" "$BUILD_ROOT/release-arm64" "$BUILD_ROOT/release-x86_64"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DMG_STAGING"

echo "▶ Building arm64 release binary..."
swift build -c release --arch arm64 --build-path "$BUILD_ROOT/release-arm64"

echo "▶ Building x86_64 release binary..."
swift build -c release --arch x86_64 --build-path "$BUILD_ROOT/release-x86_64"

if [[ ! -f "$ARM_BIN" || ! -f "$X64_BIN" ]]; then
  echo "❌ Không tìm thấy binary cho cả 2 kiến trúc."
  echo "  - arm64:  $ARM_BIN"
  echo "  - x86_64: $X64_BIN"
  exit 1
fi

echo "▶ Creating universal binary (.app)..."
lipo -create -output "$UNIVERSAL_BIN" "$ARM_BIN" "$X64_BIN"
chmod +x "$UNIVERSAL_BIN"

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

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "▶ Ad-hoc signing app..."
  codesign --force --deep --sign - "$APP_DIR"
else
  echo "▶ Signing app with Developer ID identity: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "▶ Creating drag-and-drop installer DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  echo "▶ Signing DMG..."
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ "$NOTARIZE" == "1" ]]; then
  : "${APPLE_API_KEY_ID:?Cần APPLE_API_KEY_ID khi NOTARIZE=1}"
  : "${APPLE_API_ISSUER_ID:?Cần APPLE_API_ISSUER_ID khi NOTARIZE=1}"
  : "${APPLE_API_PRIVATE_KEY:?Cần APPLE_API_PRIVATE_KEY (base64 của file .p8) khi NOTARIZE=1}"

  KEY_FILE="$DIST_DIR/AuthKey_${APPLE_API_KEY_ID}.p8"
  echo "$APPLE_API_PRIVATE_KEY" | base64 --decode > "$KEY_FILE"

  echo "▶ Notarizing DMG..."
  xcrun notarytool submit "$DMG_PATH" \
    --key "$KEY_FILE" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" \
    --wait

  echo "▶ Stapling notarization ticket..."
  xcrun stapler staple "$APP_DIR"
  xcrun stapler staple "$DMG_PATH"
fi

echo "✅ Hoàn tất"
echo "- Universal app: $APP_DIR"
echo "- DMG installer: $DMG_PATH"
