#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="PeekMeow"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD")"
COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
DIST="$ROOT/dist"
APP="$DIST/${APP_NAME}.app"
ZIP="$DIST/PeekMeow-macOS-${VERSION}.zip"
PLIST="$APP/Contents/Info.plist"

echo "→ Building $APP_NAME (release)"
swift build -c release --product "$APP_NAME"

BIN_DIR="$(swift build -c release --product "$APP_NAME" --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
  echo "error: expected executable at $BIN" >&2
  exit 1
fi

echo "→ Assembling $APP"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Sources/PeekMeow/Resources/Info.plist" "$PLIST"
ICON="$ROOT/Brand/AppIcon.icns"
MARK="$ROOT/Brand/PeekMeow-Mark.png"
ATMOSPHERE="$ROOT/Brand/PeekMeow-Atmosphere.png"
if [[ ! -f "$ICON" ]]; then
  echo "error: missing $ICON — run scripts/make-icons.py" >&2
  exit 1
fi
if [[ ! -f "$MARK" ]]; then
  echo "error: missing $MARK" >&2
  exit 1
fi
if [[ ! -f "$ATMOSPHERE" ]]; then
  echo "error: missing $ATMOSPHERE" >&2
  exit 1
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
cp "$MARK" "$APP/Contents/Resources/PeekMeowMark.png"
cp "$ATMOSPHERE" "$APP/Contents/Resources/PeekMeowAtmosphere.png"
set_plist() {
  local key="$1"
  local value="$2"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$PLIST"
  fi
}
set_plist CFBundleShortVersionString "$VERSION"
set_plist CFBundleVersion "$BUILD"
set_plist PeekMeowCommit "$COMMIT"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

if find "$APP" \( -name '*.sqlite' -o -name '*.sqlite-shm' -o -name '*.sqlite-wal' -o -name 'settings.json' \) | grep -q .; then
  echo "error: the app bundle contains user data" >&2
  exit 1
fi

if command -v codesign >/dev/null; then
  echo "→ Ad-hoc codesign (not Developer ID, not notarized)"
  codesign --force --deep --sign - "$APP"
fi

echo "→ Zipping $ZIP"
(
  cd "$DIST"
  ditto -c -k --keepParent "${APP_NAME}.app" "$(basename "$ZIP")"
)

echo "Built:"
echo "  $APP"
echo "  $ZIP"
