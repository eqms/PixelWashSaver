# PixelWash → Mac App Store: Submission-Fahrplan

Strategie (beschlossen 24.07.2026): **Zwei-Kanal-Modell.**

1. **PixelWash.app** (dieses Repo, `App/`) — eigenständiges Wash-Tool, Mac App Store,
   **2,99 €**, sandboxed, Bundle-ID `ai.it-guy.pixelwash`.
2. **PixelWash.saver** — kostenloser Direktdownload von it-guy.ai, Developer-ID-signiert
   + notarisiert (`./build_release.sh`), Bundle-ID `ai.it-guy.pixelwash.saver`.

**Warum kein Bundling:** App-Review-Guideline 2.4.5(ii) verbietet MAS-Apps, Code/Ressourcen
in geteilte Orte zu installieren; Screensaver-Installer-Apps wurden nachweislich abgelehnt,
Apple DTS: „You cannot distribute screensavers via the Mac App Store." Der `.saver` darf
also **niemals** in die App gebündelt werden — nur der https-Link ist zulässig.

---

## A. Einmalige Voraussetzungen (nur du kannst das)

- [ ] **Apple Developer Program** beitreten (Individual, Martin Schmid, 99 €/Jahr):
      <https://developer.apple.com/programs/enroll/>
- [ ] In Xcode anmelden (Settings → Accounts) und im Projekt `App/PixelWash.xcodeproj`
      das Team setzen (Signing & Capabilities; ersetzt „Sign to Run Locally").
- [ ] Zertifikate für den Direktvertrieb erzeugen (Xcode macht das automatisch, oder
      developer.apple.com → Certificates): **Developer ID Application** und
      **Developer ID Installer**.
- [ ] `xcrun notarytool store-credentials pixelwash --apple-id <id> --team-id <TEAMID>`
      (App-spezifisches Passwort von appleid.apple.com).

## B. Website-Seiten auf it-guy.ai (vor Submission live!)

| URL | Inhalt | Status |
|-----|--------|--------|
| `https://it-guy.ai/pixelwash` | Produktseite; Download-Link auf das notarisierte `.pkg` (Link-Ziel der App und `marketing_url`) | `TODO` |
| `https://it-guy.ai/pixelwash/support` | Support-/Kontaktseite (`support_url`) | `TODO` |
| `https://it-guy.ai/pixelwash/privacy` | Privacy Policy, EN+DE auf **einer** Seite (Entwurf: `docs/privacy-policy.md`) — URL nach Eintrag in App Store Connect nie mehr ändern | `TODO` |

## C. Icon

| Asset | Spec | Quelle | Status |
|-------|------|--------|--------|
| Icon-Master | 1024/2048 quadratisch, PNG, abgerundete Kachel, transparente Ecken, kein Text | Prompts: `~/Downloads/pixelwash_appicon-prompts.md` → Bild-Tool | `TODO` |
| Master ablegen | `docs/icon.png` | von ~/Downloads verschieben | `TODO` |
| `.appiconset` erzeugen | alle Größen 16→1024 + Contents.json | `/Users/picard/.claude/skills/macos-appstore-listing/scripts/generate_appiconset.sh docs/icon.png App/PixelWashApp/Assets.xcassets/AppIcon.appiconset` | `TODO` |

macOS braucht **kein** separates 1024-Store-Icon — der Store zieht das Icon aus dem Build.

## D. Metadaten

Fertig und Limit-geprüft (24.07.2026): `fastlane/metadata/{en-US,de-DE}/` (Name, Subtitle,
Promotional Text, Description, Keywords, What's New, URLs) plus `copyright.txt`
(„© 2026 Martin Schmid"), `primary_category.txt` (Utilities), `secondary_category.txt`
(Entertainment). Copy-paste-fertig für App Store Connect; später per
`fastlane deliver --metadata_path ./fastlane/metadata --platform osx` automatisierbar.

## E. Screenshots (TODO: du nimmst sie auf)

Eine Größe für das ganze Set wählen: **2880×1800** (16:10, Retina). PNG/JPEG, RGB ohne
Alpha. Pro Sprache aufnehmen (App-UI in EN bzw. DE — Sprache via System Settings oder
`defaults write ai.it-guy.pixelwash AppleLanguages '("de")'`). Ablage:
`fastlane/screenshots/en-US/` bzw. `de-DE/`.

| # | Screen/Zustand | Warum | Caption EN | Caption DE | Status |
|---|----------------|-------|------------|------------|--------|
| 1 | Hauptfenster, Vorschau läuft im Noise-Modus, Sidebar sichtbar | Hero: Wert auf einen Blick | Wash away image retention | Geisterbilder wegwaschen | `TODO` |
| 2 | Vollbild-Kur, Laufstreifen-Modus | Das Alleinstellungsmerkmal | Fullscreen wash on every display | Vollbild-Kur auf allen Displays | `TODO` |
| 3 | Hauptfenster, Vollfarben-Modus, Mode-Checkboxen im Fokus | Vielfalt der Verfahren | Four targeted wash modes | Vier gezielte Wasch-Modi | `TODO` |
| 4 | Sidebar: Tempo-Slider + Intervallfeld | Tiefe für den Abwäger | Your tempo, your mix | Dein Tempo, dein Mix | `TODO` |
| 5 | Screensaver-Box mit Download-Hinweis | Ehrlichkeit + Mehrwert | Free companion screen saver | Kostenloser Bildschirmschoner dazu | `TODO` |

## F. App Privacy (App Store Connect → App Privacy)

```
App Privacy declaration for PixelWash:
- Data collection: Data Not Collected
- Basis: Sandbox-Entitlements enthalten KEIN com.apple.security.network.client;
  kein URLSession/Analytics/Crash-SDK im Code; alle Verarbeitung lokal
  (UserDefaults auf dem Gerät). Der einzige Außenkontakt ist NSWorkspace.open
  einer https-URL im Browser des Nutzers — das ist keine Datenerhebung.
- Privacy Policy URL: https://it-guy.ai/pixelwash/privacy (TODO: live schalten)
```

Wichtig: Fragebogen ausfüllen **und publizieren** (Publish-Button, Admin-Rolle —
bei Individual-Account bist du automatisch Admin).

## G. Submission-Gates (blockieren „Add for Review")

| # | Gate | Antwort für PixelWash |
|---|------|----------------------|
| 1 | Privacy Policy URL | `https://it-guy.ai/pixelwash/privacy` — muss live sein (`TODO` B) |
| 2 | Privacy practices publiziert | „Data Not Collected" (Block F) → **Publish** klicken |
| 3 | Content Rights | **No** — die App zeigt ausschließlich selbst gezeichnete Muster, keine Fremdinhalte |
| 4 | Price tier | **2,99 €** (Tier in Pricing and Availability aktiv wählen); vorher **Paid Applications Agreement** + Bank-/Steuerdaten unter Business abschließen |
| 5 | Build | Archiv aus Xcode hochladen (H), 30–60 min Processing abwarten, dann an die Version hängen; Export-Compliance: „keine nicht-exempte Verschlüsselung" |

## H. Build, Upload, Review

1. Xcode: `App/PixelWash.xcodeproj` öffnen, Team gesetzt, **Product → Archive**.
2. Organizer → **Validate App** → Fehler beheben → **Distribute App → App Store Connect**.
3. App-Record in App Store Connect anlegen (Name PixelWash, Bundle-ID `ai.it-guy.pixelwash`,
   SKU z. B. `pixelwash-mac`), Metadaten aus D einfügen, Screenshots aus E hochladen.
4. **Review Notes** (Feld „App Review Information", einfügen):

   > PixelWash is a self-contained display-maintenance utility. All wash patterns are
   > drawn locally with Core Graphics; the app makes no network requests and collects
   > no data. The "Get the free screensaver" button simply opens our product website
   > (https://it-guy.ai/pixelwash) in the default browser, where a separately
   > distributed, Developer-ID-notarized macOS screen saver can be downloaded. The app
   > does not bundle, download, or install any code or resources outside its own
   > sandbox (Guideline 2.4.5(ii)).

5. Altersfreigabe-Fragebogen: überall „No" → 4+.
6. Submit for Review.

## I. Direktvertrieb des Screensavers (Kanal 2)

Nach A (Zertifikate + notarytool-Profil):

```bash
DEV_ID_APP="Developer ID Application: Martin Schmid (TEAMID)" \
DEV_ID_INSTALLER="Developer ID Installer: Martin Schmid (TEAMID)" \
NOTARY_PROFILE=pixelwash ./build_release.sh
```

Ergebnis `dist/PixelWash-<version>.pkg` (notarisiert, gestapelt, installiert ohne
Adminrechte nach `~/Library/Screen Savers`) auf it-guy.ai hochladen und von der
Produktseite verlinken. Gegencheck auf einem fremden/frischen Mac: Doppelklick darf
keine Gatekeeper-Warnung zeigen.
