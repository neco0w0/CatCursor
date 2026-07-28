#!/bin/bash
# Builds CatCursor.app into build/. Ad-hoc signed, which is enough to run
# locally; distributing to other machines would need a Developer ID and
# notarisation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/CatCursor.app"

swift build -c release --package-path "$ROOT"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$ROOT/.build/release/MacCursor" "$APP/Contents/MacOS/MacCursor"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp -R "$ROOT/Resources/Cursors" "$APP/Contents/Resources/Cursors"
cp "$ROOT/Resources/cursor_table.json" "$APP/Contents/Resources/cursor_table.json"

codesign --force --sign - "$APP"

echo "built: $APP"
