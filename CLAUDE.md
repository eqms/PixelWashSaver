# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PixelWash is a macOS screensaver (`.saver` bundle) that fights OLED/LCD image
retention. The four wash modes (`noise`, `cycle`, `bars`, `checker`) are drawn
natively in Core Graphics inside `Sources/PixelWashView.swift`, a single
`ScreenSaverView` subclass. They run in an auto-mix. There is no WebView — an
earlier WKWebView-based version was scrapped because WKWebView renders blank in
the sandboxed `legacyScreenSaver` host (see git/history note below).

`Resources/pixelwash.html` still exists as a standalone, browser-openable
fullscreen tool for acute multi-hour cures, but it is **no longer bundled** into
the `.saver`.

The System Settings grid tile comes from `Resources/thumbnail.png` +
`thumbnail@2x.png` (a 2×2 montage of the four modes), which `build.sh` copies into
the bundle's `Contents/Resources/`. Without them macOS shows a generic placeholder.
Regenerate via `python3 gen_thumb.py` (needs PIL; run from repo root, writes into
`Resources/`) if the modes' look changes. macOS caches the tile — reopen System
Settings (or toggle savers) to see an update.

No Xcode project, no SwiftPM manifest — just `swiftc` driven by `build.sh`.
Only the Command Line Tools (`swiftc`, `lipo`, `codesign`) are required.

## Build / install / iterate

```bash
./build.sh        # compiles arm64 + x86_64, lipo into Universal binary,
                  # assembles build/PixelWash.saver, ad-hoc codesigns it (-O release)
./install.sh      # copies bundle to ~/Library/Screen Savers, kills the host
./build.sh && ./install.sh   # full re-deploy after any change
```

There are no tests and no lint config — verification is manual: select
"PixelWash" under *System Settings > Screen Saver*; the preview pane renders the
live animation. **`ScreenSaverEngine` invoked directly no longer works on macOS
26 (Tahoe)** — it exits immediately — so use the preview or a real idle trigger
(lock screen) to test fullscreen.

**Config is compiled in — every change needs a rebuild.** Edit the `Config` enum
at the top of `PixelWashView.swift` (`modes` / `switchEverySec` / `tempo`), then
`./build.sh && ./install.sh`.

If a re-build still shows the old version: `legacyScreenSaver` holds the bundle
via mmap. `install.sh` already kills it; if it persists, toggle to another
screensaver and back.

Diagnostics: the view logs to subsystem `de.equitania.pixelwash`. The shell
shadows the system `log` with a function, so use the absolute path:
`/usr/bin/log show --last 2m --info --predicate 'subsystem == "de.equitania.pixelwash"' --style compact`.

## Architecture

`PixelWashView` is a single `ScreenSaverView` subclass using the canonical
ScreenSaver render loop:

- `animateOneFrame()` advances state (`tick` counter, mode switching, cycle index)
  and calls `setNeedsDisplay(bounds)`.
- `draw(_:)` paints the current mode via `NSGraphicsContext.current?.cgContext`.
- `animationTimeInterval` is derived from `tempo` (tempo 10 ≈ 60fps, 1 ≈ 10fps)
  and **recomputed on mode switch**; `noise` is floored to 30fps because it issues
  tens of thousands of fills per frame.

Mode implementations (all Core Graphics): `noise` fills a small block-resolution
RGBA buffer with random colors → `CGImage` drawn scaled with
`interpolationQuality = .none` (cheap even at 4K); `cycle` fills the bounds with a
palette color; `bars` fills offset diagonal parallelograms; `checker` fills an
inverting grid. The `tick` counter must NOT be named `frame` — that collides with
`NSView.frame`.

Going native deliberately removed the whole WKWebView trap class (zero-bounds
fallback, backing-pixel frame clamping, the `requestAnimationFrame` visibility
override, WebView teardown leaks) — do not reintroduce a WebView.

Per-monitor: each display gets its own `PixelWashView` instance. Native drawing
is light; `noise` is the only heavy mode and is fps-capped.

**Settings** live in `ScreenSaverDefaults` (keyed by the bundle id), exposed via a
programmatically-built configure sheet (`hasConfigureSheet`/`configureSheet`, no
XIB). Keys: `mode_<noise|cycle|bars|checker>` (Bool), `tempo` (Int 1–10),
`switchEverySec` (Double, 0 = never). Factory defaults (registered in the `store`
lazy var) = auto-mix: all modes on, 45s, tempo 6. `loadSettings()` reads them in
`init` and again in `startAnimation` (so sheet changes apply on next run). The
sheet's OK handler writes defaults then calls `loadSettings()`.

## Conventions

- `Info.plist`: `NSPrincipalClass` = `PixelWashView`, bundle id
  `de.equitania.pixelwash`. Keep `@objc(PixelWashView)` and the plist in sync.
- Deployment target macOS 14.0 (set in both `build.sh` and `Info.plist`).
- Comments and the README are in German; keep that style. Code identifiers stay
  English. Use proper UTF-8 (umlauts), no ASCII substitutes.
- Ad-hoc signature is intentional (own Mac only). Distribution to other Macs
  would need Developer ID + notarization.

## Physical caveat to remember

A screensaver only washes while the display backlight is on. Correct usage
requires *System Settings > Lock Screen*: start the screensaver after a short
idle, but set "turn display off when inactive" to Never (or long). This is a
usage fact worth restating in any user-facing docs, not a code concern.
