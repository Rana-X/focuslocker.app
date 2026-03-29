#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/export/FocusLocker.app}"
OUTPUT_PATH="${2:-$ROOT_DIR/build/dmg/FocusLocker.dmg}"
STAGING_DIR="$(mktemp -d)"

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp -R "$APP_PATH" "$STAGING_DIR/FocusLocker.app"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "Focus Locker" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_PATH" >/dev/null

rm -rf "$STAGING_DIR"
echo "$OUTPUT_PATH"
