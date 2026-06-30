#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

NAME=PixelWash
BUNDLE=$NAME.saver
BUILD=build/$BUNDLE
SDK=$(xcrun --sdk macosx --show-sdk-path)
DEPLOY=14.0

rm -rf "$BUILD"
mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"
cp Info.plist "$BUILD/Contents/Info.plist"
# Kachelbild fuer die Systemeinstellungen-Auswahl (sonst zeigt macOS den Platzhalter).
cp Resources/thumbnail.png Resources/thumbnail@2x.png "$BUILD/Contents/Resources/"

COMMON=(
  -sdk "$SDK"
  -framework ScreenSaver -framework AppKit
  -emit-library -Xlinker -bundle
  -module-name "$NAME" -O
)

swiftc -target arm64-apple-macos$DEPLOY  "${COMMON[@]}" \
       -o "$BUILD/Contents/MacOS/arm64.bin"  Sources/*.swift
swiftc -target x86_64-apple-macos$DEPLOY "${COMMON[@]}" \
       -o "$BUILD/Contents/MacOS/x86_64.bin" Sources/*.swift

lipo -create "$BUILD/Contents/MacOS/arm64.bin" "$BUILD/Contents/MacOS/x86_64.bin" \
     -output "$BUILD/Contents/MacOS/$NAME"
rm "$BUILD/Contents/MacOS/arm64.bin" "$BUILD/Contents/MacOS/x86_64.bin"

# Ad-hoc-Signatur reicht fuer den eigenen Mac (keine Weitergabe an andere Macs).
codesign --force --sign - --timestamp=none "$BUILD"

echo "Gebaut: $BUILD"
echo "Naechster Schritt:  ./install.sh"
