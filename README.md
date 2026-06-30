# PixelWash – Image-Retention-Kur als macOS-Screensaver

> **Sprache / Language**: [DE](#deutsche-dokumentation) | [EN](#english-documentation)

Screensaver, der vier Wash-Modi nativ in Core Graphics zeichnet und automatisch
nach Inaktivität startet. Auto-Mix aus Rauschen, Vollfarben, Laufstreifen und
Schachbrett – komplett in Swift, ohne WebView. Version 2.1, Universal Binary
(arm64 + x86_64), ab macOS 14.

---

## Deutsche Dokumentation

### Wichtig zuerst: der physikalische Haken

Ein Screensaver wäscht **nur, solange das Display eingeschaltet ist**. Sobald
macOS den Bildschirm in den Standby schickt, geht das Backlight aus – kein
Licht, kein Washing. Damit die Kur tatsächlich läuft:

- *Systemeinstellungen > Sperrbildschirm*
  - „Bildschirmschoner starten, wenn inaktiv“ auf einen kurzen Wert (z. B. 2–5 Min.)
  - „Bildschirm ausschalten, wenn inaktiv (Netzbetrieb)“ auf **Nie** (oder länger,
    als du wegbleibst)

Erst dann gilt: Du verlässt den Platz → nach kurzer Zeit übernimmt PixelWash
und wäscht so lange, bis du zurückkommst.

### Voraussetzungen

- macOS 14+ (Baumuster getestet auf macOS 26, Apple Silicon)
- Command Line Tools: `xcode-select --install` (liefert `swiftc`, `lipo`, `codesign`)
- Xcode selbst wird **nicht** gebraucht

### Bauen und installieren

```bash
chmod +x build.sh install.sh
./build.sh        # erzeugt build/PixelWash.saver (Universal, ad-hoc signiert)
./install.sh      # kopiert nach ~/Library/Screen Savers und lädt den Host neu
```

Danach in *Systemeinstellungen > Bildschirmschoner* „PixelWash“ auswählen.
Bei mehreren Monitoren lässt sich der Screensaver pro Display einzeln wählen –
praktisch, wenn nur ein Monitor behandelt werden soll.

### Einstellen

Direkt in den Systemeinstellungen: PixelWash auswählen → **„Optionen…“**. Das
Sheet bietet:

- **Aktive Modi** (Checkboxen): Rauschen, Vollfarben, Laufstreifen, Schachbrett.
  Mind. einer; ohne Auswahl fällt PixelWash auf Rauschen zurück.
- **Tempo** (1–10): Geschwindigkeit der Wechsel/Bewegung.
- **Moduswechsel alle … Sek.**: `0` = nie wechseln (nur der erste aktive Modus).

Die Werte werden über `ScreenSaverDefaults` gespeichert und beim nächsten Start
übernommen – **kein Rebuild nötig**. Werkseinstellung ist der Auto-Mix aller vier
Modi (Wechsel alle 45 s, Tempo 6).

### Wenn nach einem Re-Build die alte Version erscheint

`legacyScreenSaver` hält das Bundle per mmap fest. `install.sh` killt den Prozess
bereits; falls doch mal die alte Version hängt, in den Systemeinstellungen kurz
auf einen anderen Screensaver und zurück wechseln.

### Vorschau in den Systemeinstellungen

Die kleine Vorschau zeigt die Animation. Der direkte Aufruf von
`ScreenSaverEngine` funktioniert auf macOS 26 (Tahoe) **nicht** mehr – zum Testen
also die Vorschau nutzen oder den echten Leerlauf abwarten (Bildschirm sperren).

### Hinweise

- Ad-hoc-Signatur reicht für den eigenen Mac; Weitergabe an andere Macs
  bräuchte Developer-ID + Notarisierung.
- Bei mehreren Monitoren läuft je Display eine eigene View-Instanz. Native
  Zeichnung ist sparsam; `noise` ist auf 30 fps gedeckelt.
- Diagnose: Die View loggt ins Subsystem `de.equitania.pixelwash`. Die Shell
  überschattet das System-`log`, daher den absoluten Pfad nutzen:
  `/usr/bin/log show --last 2m --info --predicate 'subsystem == "de.equitania.pixelwash"' --style compact`.

### Screensaver vs. aktive Kur

Für die **Erhaltung** (gelegentliches Durchwalken im Leerlauf) ist der
Screensaver ideal. Für eine **akute, mehrstündige Kur** an einem hartnäckigen
Geisterbild bleibt die eigenständige `Resources/pixelwash.html` im Browser
(Vollbild) gleich gut und besser kontrollierbar – sie nutzt dieselben vier
Verfahren, ist aber nicht mehr Teil des Screensaver-Bundles.

### Lizenz & Kontakt

Lizenziert unter der **MIT-Lizenz** – siehe [`LICENSE`](LICENSE). Die ad-hoc-Signatur
des Bundles bedeutet weiterhin „nur eigener Mac“; eine Verteilung an andere Macs
bräuchte Developer-ID + Notarisierung.

- Equitania Software GmbH
- E-Mail: <info@ownerp.com>
- Web: <https://www.ownerp.com>

---

## English Documentation

### Read this first: the physical catch

A screensaver only washes **while the display is switched on**. The moment macOS
puts the screen into standby, the backlight turns off – no light, no washing. For
the cure to actually run:

- *System Settings > Lock Screen*
  - “Start Screen Saver when inactive” → a short value (e.g. 2–5 min)
  - “Turn display off when inactive (on power adapter)” → **Never** (or longer than
    you stay away)

Only then does it hold: you leave your seat → after a short while PixelWash takes
over and washes until you return.

### Requirements

- macOS 14+ (reference build tested on macOS 26, Apple Silicon)
- Command Line Tools: `xcode-select --install` (provides `swiftc`, `lipo`, `codesign`)
- Xcode itself is **not** required

### Build and install

```bash
chmod +x build.sh install.sh
./build.sh        # produces build/PixelWash.saver (Universal, ad-hoc signed)
./install.sh      # copies to ~/Library/Screen Savers and reloads the host
```

Then pick “PixelWash” under *System Settings > Screen Saver*. With multiple
monitors the screensaver can be chosen per display – handy when only one monitor
needs treatment.

### Configuration

Right inside System Settings: select PixelWash → **“Options…”**. The sheet offers:

- **Active modes** (checkboxes): `noise`, `cycle`, `bars`, `checker`. At least one;
  with none selected PixelWash falls back to `noise`.
- **Tempo** (1–10): speed of switching/motion.
- **Switch mode every … sec.**: `0` = never switch (only the first active mode).

Values are stored via `ScreenSaverDefaults` and applied on the next start –
**no rebuild needed**. The factory setting is the auto-mix of all four modes
(switch every 45 s, tempo 6).

### If an old version shows after a re-build

`legacyScreenSaver` holds the bundle via mmap. `install.sh` already kills the
process; should the old version still hang around, briefly switch to another
screensaver and back in System Settings.

### Preview in System Settings

The small preview pane shows the animation. Invoking `ScreenSaverEngine` directly
no longer works on macOS 26 (Tahoe) – so use the preview to test, or wait for a
real idle trigger (lock the screen).

### Notes

- An ad-hoc signature is enough for your own Mac; distribution to other Macs would
  need a Developer ID + notarization.
- With multiple monitors each display runs its own view instance. Native drawing is
  light; `noise` is capped at 30 fps.
- Diagnostics: the view logs to subsystem `de.equitania.pixelwash`. The shell
  shadows the system `log`, so use the absolute path:
  `/usr/bin/log show --last 2m --info --predicate 'subsystem == "de.equitania.pixelwash"' --style compact`.

### Screensaver vs. active cure

For **maintenance** (occasional washing during idle) the screensaver is ideal. For
an **acute, multi-hour cure** of a stubborn ghost image, the standalone
`Resources/pixelwash.html` in a browser (fullscreen) remains just as good and more
controllable – it uses the same four techniques but is no longer part of the
screensaver bundle.

### License & Contact

Licensed under the **MIT License** – see [`LICENSE`](LICENSE). The bundle's ad-hoc
signature still means “your own Mac only”; distribution to other Macs would need a
Developer ID + notarization.

- Equitania Software GmbH
- Email: <info@ownerp.com>
- Web: <https://www.ownerp.com>
