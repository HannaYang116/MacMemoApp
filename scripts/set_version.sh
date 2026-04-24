#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/versioning.sh"

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/set_version.sh <version>" >&2
  exit 1
fi

CONFIG_PATH="$(versioning_config_path "$ROOT_DIR")"
BUILD_VERSION="$(numeric_build_version "$VERSION")"
TEMP_PATH="$(mktemp)"

awk -v marketing_version="$VERSION" -v build_version="$BUILD_VERSION" '
  /^MARKETING_VERSION[[:space:]]*=/ {
    print "MARKETING_VERSION = " marketing_version
    next
  }
  /^CURRENT_PROJECT_VERSION[[:space:]]*=/ {
    print "CURRENT_PROJECT_VERSION = " build_version
    next
  }
  { print }
' "$CONFIG_PATH" > "$TEMP_PATH"

mv "$TEMP_PATH" "$CONFIG_PATH"

echo "Updated version settings:"
echo "MARKETING_VERSION=$VERSION"
echo "CURRENT_PROJECT_VERSION=$BUILD_VERSION"
