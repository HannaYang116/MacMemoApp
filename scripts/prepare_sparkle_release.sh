#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacMemoApp"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-$HOME/Library/Developer/Xcode/DerivedData/MacMemoApp-ewbdrxpszebiqaflvqvnmxbfjsiv/SourcePackages/artifacts/sparkle/Sparkle/bin}"
GENERATE_APPCAST="$SPARKLE_BIN_DIR/generate_appcast"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/prepare_sparkle_release.sh <version>"
  exit 1
fi

ARCHIVES_DIR="$ROOT_DIR/docs/updates"
ARCHIVE_NAME="$APP_NAME $VERSION.zip"
ARCHIVE_PATH="$ARCHIVES_DIR/$ARCHIVE_NAME"
RELEASE_NOTES_PATH="$ARCHIVES_DIR/$APP_NAME $VERSION.md"

"$ROOT_DIR/scripts/package_release.sh" "$VERSION"

mkdir -p "$ARCHIVES_DIR"
cp "$ROOT_DIR/dist/$APP_NAME.zip" "$ARCHIVE_PATH"

if [[ ! -f "$RELEASE_NOTES_PATH" ]]; then
  cat > "$RELEASE_NOTES_PATH" <<EOF
# MacMemoApp $VERSION

- Add release notes for this version.
EOF
fi

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf "%s" "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" --ed-key-file - -o "$ARCHIVES_DIR/appcast.xml" "$ARCHIVES_DIR"
else
  "$GENERATE_APPCAST" -o "$ARCHIVES_DIR/appcast.xml" "$ARCHIVES_DIR"
fi

echo "Prepared Sparkle archive at:"
echo "$ARCHIVE_PATH"
echo "Updated Sparkle feed at:"
echo "$ARCHIVES_DIR/appcast.xml"
