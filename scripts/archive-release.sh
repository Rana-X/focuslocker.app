#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/FocusLocker.xcodeproj"
SCHEME="${SCHEME:-FocusLocker}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/FocusLocker.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/release/exportOptions.plist}"
TEAM_ID="${TEAM_ID:-}"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required for the production archive flow." >&2
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  "$ROOT_DIR/scripts/generate-xcode-project.sh"
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

ARCHIVE_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration Release
  -archivePath "$ARCHIVE_PATH"
  clean archive
)

if [ -n "$TEAM_ID" ]; then
  ARCHIVE_ARGS+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

xcodebuild "${ARCHIVE_ARGS[@]}"

EXPORT_OPTIONS_COPY="$ROOT_DIR/build/exportOptions.resolved.plist"
cp "$EXPORT_OPTIONS_PLIST" "$EXPORT_OPTIONS_COPY"
if [ -n "$TEAM_ID" ]; then
  /usr/bin/plutil -replace teamID -string "$TEAM_ID" "$EXPORT_OPTIONS_COPY"
fi

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_COPY"

echo "$EXPORT_PATH"
