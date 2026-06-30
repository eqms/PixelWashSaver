#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

NAME=PixelWash
SRC="build/$NAME.saver"
DEST="$HOME/Library/Screen Savers"

if [ ! -d "$SRC" ]; then
  echo "Nicht gebaut. Erst ausfuehren:  ./build.sh"
  exit 1
fi

mkdir -p "$DEST"
rm -rf "$DEST/$NAME.saver"
cp -R "$SRC" "$DEST/"

# legacyScreenSaver haelt das Bundle per mmap - zum Neuladen Prozess beenden.
killall legacyScreenSaver 2>/dev/null || true
killall ScreenSaverEngine 2>/dev/null || true

echo "Installiert nach: $DEST/$NAME.saver"
echo "Auswaehlen unter: Systemeinstellungen > Bildschirmschoner > '$NAME'"
