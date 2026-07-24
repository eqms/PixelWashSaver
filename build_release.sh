#!/usr/bin/env bash
# Release-Build fuer den Direktvertrieb AUSSERHALB des Mac App Store:
# Developer-ID-Signatur + Hardened Runtime, Notarisierung, Stapling und ein
# per-User-Installer-.pkg (installiert nach ~/Library/Screen Savers, kein Admin).
#
# Voraussetzungen (einmalig, siehe docs/APPSTORE_SUBMISSION.md):
#   - Apple Developer Program aktiv
#   - Zertifikate im Schluesselbund: "Developer ID Application: ..." und
#     "Developer ID Installer: ..."
#   - notarytool-Keychain-Profil:  xcrun notarytool store-credentials pixelwash \
#         --apple-id <apple-id> --team-id <TEAMID>
#
# Aufruf:
#   DEV_ID_APP="Developer ID Application: Martin Schmid (TEAMID)" \
#   DEV_ID_INSTALLER="Developer ID Installer: Martin Schmid (TEAMID)" \
#   NOTARY_PROFILE=pixelwash ./build_release.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

NAME=PixelWash
BUNDLE=build/$NAME.saver
DIST=dist

: "${DEV_ID_APP:?DEV_ID_APP fehlt (z. B. 'Developer ID Application: Martin Schmid (TEAMID)')}"
: "${DEV_ID_INSTALLER:?DEV_ID_INSTALLER fehlt (z. B. 'Developer ID Installer: Martin Schmid (TEAMID)')}"
: "${NOTARY_PROFILE:?NOTARY_PROFILE fehlt (notarytool store-credentials <profil>)}"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
PKG="$DIST/$NAME-$VERSION.pkg"

# 1) Normaler Build (ad-hoc), danach mit Developer ID + Hardened Runtime neu signieren.
./build.sh
codesign --force --options runtime --timestamp --sign "$DEV_ID_APP" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

# 2) Per-User-Installer-.pkg: Distribution mit enable_currentUserHome installiert
#    ohne Adminrechte nach ~/Library/Screen Savers.
rm -rf "$DIST" build/pkgroot
mkdir -p "$DIST" "build/pkgroot/Library/Screen Savers"
cp -R "$BUNDLE" "build/pkgroot/Library/Screen Savers/"

# BundleIsRelocatable abschalten, sonst darf der Installer das Bundle "wiederfinden"
# und an einem anderen Ort aktualisieren statt fest nach Library/Screen Savers zu gehen.
pkgbuild --analyze --root build/pkgroot build/component.plist
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' build/component.plist || true

pkgbuild --root build/pkgroot \
         --component-plist build/component.plist \
         --identifier ai.it-guy.pixelwash.saver.pkg \
         --version "$VERSION" \
         --install-location "/" \
         build/$NAME-component.pkg

cat > build/distribution.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>PixelWash Screensaver</title>
    <domains enable_currentUserHome="true"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <choices-outline>
        <line choice="default"/>
    </choices-outline>
    <choice id="default" title="PixelWash">
        <pkg-ref id="ai.it-guy.pixelwash.saver.pkg"/>
    </choice>
    <pkg-ref id="ai.it-guy.pixelwash.saver.pkg" version="$VERSION">$NAME-component.pkg</pkg-ref>
</installer-gui-script>
XML

productbuild --distribution build/distribution.xml \
             --package-path build \
             --sign "$DEV_ID_INSTALLER" \
             "$PKG"

# 3) Notarisieren + Ticket antackern.
xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$PKG"

# 4) Gatekeeper-Kontrolle.
spctl --assess --type install --verbose=2 "$PKG"

echo "Fertig: $PKG"
echo "Upload-Ziel: https://it-guy.ai/pixelwash (Link-Ziel der App)"
