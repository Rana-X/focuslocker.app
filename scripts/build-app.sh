#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FocusLocker"
AGENT_NAME="FocusLockerAgent"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
AGENT_APP_DIR="$APP_DIR/Contents/Library/LoginItems/$AGENT_NAME.app"
ICON_WORK_DIR="$ROOT_DIR/.build/app-icon"
ICONSET_DIR="$ICON_WORK_DIR/AppIcon.iconset"
BASE_ICON_PNG="$ICON_WORK_DIR/AppIcon-1024.png"
ICNS_FILE="$ICON_WORK_DIR/AppIcon.icns"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_DIR"
rm -rf "$ICON_WORK_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Library/LoginItems"
mkdir -p "$AGENT_APP_DIR/Contents/MacOS" "$AGENT_APP_DIR/Contents/Resources"
mkdir -p "$ICONSET_DIR"

swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$BASE_ICON_PNG"

sips -z 16 16 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$BASE_ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BUILD_DIR/$AGENT_NAME" "$AGENT_APP_DIR/Contents/MacOS/$AGENT_NAME"
cp "$ROOT_DIR/AppResources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/AppResources/$AGENT_NAME-Info.plist" "$AGENT_APP_DIR/Contents/Info.plist"
cp "$ICNS_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ICNS_FILE" "$AGENT_APP_DIR/Contents/Resources/AppIcon.icns"

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$AGENT_APP_DIR/Contents/MacOS/$AGENT_NAME"
codesign --force --sign - "$AGENT_APP_DIR" >/dev/null
codesign --force --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
