#!/bin/bash
# Builds CatCursor.app into build/. Ad-hoc signed, which is enough to run
# locally; distributing to other machines would need a Developer ID and
# notarisation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/CatCursor.app"

swift build -c release --package-path "$ROOT"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"

cp "$ROOT/.build/release/MacCursor" "$APP/Contents/MacOS/MacCursor"
# Launched only during calibration, to produce a genuine text I-beam.
cp "$ROOT/.build/release/CursorFixture" "$APP/Contents/Helpers/CursorFixture"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Resources/Cursors" "$APP/Contents/Resources/Cursors"
cp "$ROOT/Resources/cursor_table.json" "$APP/Contents/Resources/cursor_table.json"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT"/Resources/MenuBarIcon*.png "$APP/Contents/Resources/"

# Strip extended attributes before signing: they survive into the distributed
# zip as ._ AppleDouble files and are pure noise on another machine.
xattr -cr "$APP"

# Nested code has to be signed before the bundle that contains it.
codesign --force --sign - "$APP/Contents/Helpers/CursorFixture"
codesign --force --sign - "$APP"

echo "built: $APP"
