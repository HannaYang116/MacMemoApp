#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/versioning.sh"

APP_NAME="MacMemoApp"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DEFAULT_MARKETING_VERSION="$(read_version_setting MARKETING_VERSION "$(versioning_config_path "$ROOT_DIR")")"
VERSION="${1:-${MARKETING_VERSION:-$DEFAULT_MARKETING_VERSION}}"
STAGING_DIR="$(mktemp -d "$DIST_DIR/${APP_NAME}.dmg-staging.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$(numeric_build_version "$VERSION")" "$ROOT_DIR/scripts/build_app.sh"

rm -f "$DMG_PATH"
cp -R "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "Created release archive at:"
echo "$DMG_PATH"
