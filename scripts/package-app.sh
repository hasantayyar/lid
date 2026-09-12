#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
APP="$ROOT/artifacts/Lid.app"

swift build --product LidApp --configuration "$CONFIG"
PRODUCT_DIR="$(swift build --product LidApp --configuration "$CONFIG" --show-bin-path)"
BINARY="$PRODUCT_DIR/LidApp"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/Lid"
chmod +x "$APP/Contents/MacOS/Lid"
if [[ ! -f "$ROOT/Sources/LidApp/Resources/AppIcon.icns" ]]; then
    "$ROOT/scripts/render-app-icon.sh"
fi

cp "$ROOT/Sources/LidApp/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Sources/LidApp/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - --timestamp=none "$APP"

echo "Built $APP"
