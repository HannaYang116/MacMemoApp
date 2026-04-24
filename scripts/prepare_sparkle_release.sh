#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacMemoApp"
VERSION="${1:-}"

find_generate_appcast() {
  local candidates=()

  if [[ -n "${SPARKLE_BIN_DIR:-}" ]]; then
    candidates+=("$SPARKLE_BIN_DIR/generate_appcast")
  fi

  candidates+=(
    "$ROOT_DIR/.xcodebuild/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
    "$ROOT_DIR/.xcodebuild/SourcePackages/checkouts/Sparkle/generate_appcast"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  echo "Could not find Sparkle generate_appcast tool." >&2
  echo "Set SPARKLE_BIN_DIR to the folder containing generate_appcast if needed." >&2
  return 1
}

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/prepare_sparkle_release.sh <version>"
  exit 1
fi

ARCHIVES_DIR="$ROOT_DIR/docs/updates"
ARCHIVE_NAME="$APP_NAME $VERSION.dmg"
ARCHIVE_PATH="$ARCHIVES_DIR/$ARCHIVE_NAME"
RELEASE_NOTES_PATH="$ARCHIVES_DIR/$APP_NAME $VERSION.md"

"$ROOT_DIR/scripts/package_release.sh" "$VERSION"

GENERATE_APPCAST="$(find_generate_appcast)"

mkdir -p "$ARCHIVES_DIR"
cp "$ROOT_DIR/dist/$APP_NAME.dmg" "$ARCHIVE_PATH"

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
