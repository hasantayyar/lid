#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/package-app.sh" release

APP="$ROOT/artifacts/Lid.app"
DMG="$ROOT/artifacts/Lid.dmg"
STAGE="$ROOT/artifacts/dmg-stage"

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Lid.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname Lid -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "Built $DMG"
echo "Open the disk image and drag Lid into Applications."
