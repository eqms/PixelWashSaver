# Release Notes

## App 1.0 (in Vorbereitung, 24.07.2026)

- [FIX] App: main window never appeared — `@main` on an XIB-less
  NSApplicationDelegate never instantiates the delegate; added an explicit
  `static func main()` entry point that creates and attaches it.
- [FIX] App: German download button label was truncated in the screen saver
  box ("Kostenlos herunterladen" instead of the overlong phrasing).

## 2.2 (24.07.2026)

- [CHG] Rebranding: publisher is now Martin Schmid (it-guy.ai); bundle id changed
  from `de.equitania.pixelwash` to `ai.it-guy.pixelwash.saver`, log subsystem
  renamed accordingly. **Note:** local screensaver settings reset once because
  `ScreenSaverDefaults` is keyed by the bundle id (three simple settings, set
  them again in the configure sheet).
- [CHG] Refactor: rendering engine extracted to `Sources/PixelWashCore.swift`
  (`PixelWashEngine`, `PixelWashMode`) with no ScreenSaver dependency, shared
  between the `.saver` and the upcoming Mac App Store app. No behavior change.
- [ADD] Preparation for two-channel distribution: Mac App Store app
  (standalone wash player) + free Developer-ID-signed `.saver` download.

## 2.1 (22.07.2026)

- Initial public state: four native Core Graphics wash modes (noise, cycle,
  bars, checker), auto-mix, configure sheet (modes, tempo 1–10, switch
  interval), universal binary (arm64 + x86_64), ad-hoc signed.
