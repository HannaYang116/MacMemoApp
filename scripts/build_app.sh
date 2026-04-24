#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/versioning.sh"

APP_NAME="MacMemoApp"
DIST_DIR="$ROOT_DIR/dist"
DERIVED_DATA_DIR="$ROOT_DIR/.xcodebuild"
APP_DIR="$DIST_DIR/$APP_NAME.app"
BUILT_APP_DIR="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"
MARKETING_VERSION="${MARKETING_VERSION:-$(read_version_setting MARKETING_VERSION "$(versioning_config_path "$ROOT_DIR")")}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-$(read_version_setting CURRENT_PROJECT_VERSION "$(versioning_config_path "$ROOT_DIR")")}"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/MacMemoApp.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION" \
  build

rm -rf "$APP_DIR"
cp -R "$BUILT_APP_DIR" "$APP_DIR"

echo "Created app bundle at:"
echo "$APP_DIR"
