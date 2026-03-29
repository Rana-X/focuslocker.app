#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/export/FocusLocker.app}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ZIP_PATH="$ROOT_DIR/build/notarization/FocusLocker.zip"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required for notarization." >&2
  exit 1
fi

if [ -z "$NOTARY_PROFILE" ]; then
  echo "Set NOTARY_PROFILE to your notarytool keychain profile name." >&2
  exit 1
fi

mkdir -p "$(dirname "$ZIP_PATH")"
rm -f "$ZIP_PATH"

/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
/usr/bin/xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
/usr/bin/xcrun stapler staple "$APP_PATH"

echo "$APP_PATH"
