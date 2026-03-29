#!/bin/zsh

set -euo pipefail

APP_PATH="${1:-}"

if [ -z "$APP_PATH" ]; then
  echo "Usage: ./scripts/validate-release.sh /path/to/FocusLocker.app" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
/usr/sbin/spctl -a -t exec -vv "$APP_PATH"
