#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacMemoApp"
DIST_DIR="$ROOT_DIR/dist"
DERIVED_DATA_DIR="$ROOT_DIR/.xcodebuild"
APP_DIR="$DIST_DIR/$APP_NAME.app"
BUILT_APP_DIR="$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-100}"

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
