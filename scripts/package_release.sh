#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacMemoApp"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
VERSION="${1:-${MARKETING_VERSION:-1.0.0}}"

numeric_build_version() {
  local input="$1"
  local digits="${input//[^0-9]/}"
  if [[ -z "$digits" ]]; then
    digits="1"
  fi
  echo "$digits"
}

MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$(numeric_build_version "$VERSION")" "$ROOT_DIR/scripts/build_app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Created release archive at:"
echo "$ZIP_PATH"
