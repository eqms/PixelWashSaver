import ScreenSaver
import AppKit
import os

// PixelWash - Image-Retention-Kur als macOS-Screensaver.
// Duenner ScreenSaverView-Wrapper um die geteilte Render-Engine (PixelWashCore.swift);
// hier leben nur noch Persistenz (ScreenSaverDefaults) und das Konfigurations-Sheet.
// Universal-Binary, getestet auf macOS 26 (Tahoe), Apple Silicon.

@objc(PixelWashView)
public final class PixelWashView: ScreenSaverView {

    private typealias Mode = PixelWashMode

    // MARK: - Defaults / Persistenz

    private enum Key {
        static let switchEverySec = "switchEverySec"
        static let tempo = "tempo"
    }
    // Werkseinstellung: Auto-Mix aller Modi, Wechsel alle 45 s, Tempo 6.
    private static let defaultSwitchEverySec: Double = 45
    private static let defaultTempo = 6

    private lazy var store: ScreenSaverDefaults = {
        let id = Bundle(for: PixelWashView.self).bundleIdentifier ?? "ai.it-guy.pixelwash.saver"
        let d = ScreenSaverDefaults(forModuleWithName: id) ?? ScreenSaverDefaults()
        var reg: [String: Any] = [
            Key.switchEverySec: Self.defaultSwitchEverySec,
            Key.tempo: Self.defaultTempo,
        ]
        for m in Mode.allCases { reg[m.defaultsKey] = true }   // alle Modi an
        d.register(defaults: reg)
        return d
    }()

    // MARK: - Zustand

    private let log = Logger(subsystem: "ai.it-guy.pixelwash.saver", category: "main")
    private let engine = PixelWashEngine()

    // MARK: - Init

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        loadSettings()
        animationTimeInterval = engine.currentInterval
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSettings()
        animationTimeInterval = engine.currentInterval
    }

    // MARK: - Einstellungen laden

    private func loadSettings() {
        let active = Mode.allCases.filter { store.bool(forKey: $0.defaultsKey) }
        engine.configure(activeModes: active,
                         switchSecs: store.double(forKey: Key.switchEverySec),
                         speed: store.integer(forKey: Key.tempo))
    }

    // MARK: - Lebenszyklus

    public override func startAnimation() {
        super.startAnimation()
        loadSettings()                       // frische Werte aus dem Sheet uebernehmen
        animationTimeInterval = engine.currentInterval
        log.info("startAnimation preview=\(self.isPreview, privacy: .public) modes=\(self.engine.activeModes.map { $0.rawValue }.joined(separator: ","), privacy: .public)")
    }

    public override func stopAnimation() {
        super.stopAnimation()
    }

    public override func animateOneFrame() {
        if engine.advance() {
            animationTimeInterval = engine.currentInterval   // Timer mit neuem Takt
        }
        setNeedsDisplay(bounds)
    }

    // MARK: - Rendering

    public override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        engine.draw(in: ctx, bounds: bounds)
    }

    // MARK: - Konfigurations-Sheet

    private var sheet: NSWindow?
    private var modeChecks: [Mode: NSButton] = [:]
    private var tempoSlider: NSSlider?
    private var tempoValue: NSTextField?
    private var switchField: NSTextField?

    public override var hasConfigureSheet: Bool { true }

    public override var configureSheet: NSWindow? {
        let w: CGFloat = 380, h: CGFloat = 320
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                           styleMask: [.titled], backing: .buffered, defer: true)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        func label(_ s: String, _ x: CGFloat, _ y: CGFloat, _ lw: CGFloat = 320) -> NSTextField {
            let t = NSTextField(labelWithString: s)
            t.frame = NSRect(x: x, y: y, width: lw, height: 18)
            content.addSubview(t)
            return t
        }

        let title = label("PixelWash – Einstellungen", 20, h - 40)
        title.font = .boldSystemFont(ofSize: 14)

        _ = label("Aktive Modi:", 20, h - 72)
        modeChecks.removeAll()
        var y = h - 96
        for m in Mode.allCases {
            let cb = NSButton(checkboxWithTitle: m.label, target: nil, action: nil)
            cb.frame = NSRect(x: 36, y: y, width: 300, height: 20)
            cb.state = store.bool(forKey: m.defaultsKey) ? .on : .off
            content.addSubview(cb)
            modeChecks[m] = cb
            y -= 24
        }

        y -= 8
        _ = label("Tempo:", 20, y)
        let slider = NSSlider(value: Double(max(1, min(10, store.integer(forKey: Key.tempo)))),
                              minValue: 1, maxValue: 10,
                              target: self, action: #selector(tempoChanged(_:)))
        slider.frame = NSRect(x: 90, y: y - 2, width: 220, height: 22)
        slider.numberOfTickMarks = 10
        slider.allowsTickMarkValuesOnly = true
        content.addSubview(slider)
        tempoSlider = slider
        let tv = label("\(Int(slider.doubleValue))", 320, y, 40)
        tempoValue = tv

        y -= 36
        _ = label("Moduswechsel alle (Sek., 0 = nie):", 20, y, 230)
        let field = NSTextField(frame: NSRect(x: 256, y: y - 2, width: 60, height: 22))
        field.integerValue = Int(store.double(forKey: Key.switchEverySec))
        field.alignment = .right
        content.addSubview(field)
        switchField = field

        let ok = NSButton(title: "OK", target: self, action: #selector(okClicked(_:)))
        ok.frame = NSRect(x: w - 100, y: 16, width: 84, height: 30)
        ok.bezelStyle = .rounded
        ok.keyEquivalent = "\r"
        content.addSubview(ok)

        let cancel = NSButton(title: "Abbrechen", target: self, action: #selector(cancelClicked(_:)))
        cancel.frame = NSRect(x: w - 196, y: 16, width: 92, height: 30)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"   // Esc
        content.addSubview(cancel)

        win.contentView = content
        sheet = win
        return win
    }

    @objc private func tempoChanged(_ sender: NSSlider) {
        tempoValue?.stringValue = "\(Int(sender.doubleValue.rounded()))"
    }

    @objc private func okClicked(_ sender: Any) {
        for (m, cb) in modeChecks {
            store.set(cb.state == .on, forKey: m.defaultsKey)
        }
        if let s = tempoSlider {
            store.set(Int(s.doubleValue.rounded()), forKey: Key.tempo)
        }
        if let f = switchField {
            store.set(Double(max(0, f.integerValue)), forKey: Key.switchEverySec)
        }
        store.synchronize()
        loadSettings()
        animationTimeInterval = engine.currentInterval
        endSheet()
    }

    @objc private func cancelClicked(_ sender: Any) {
        endSheet()
    }

    private func endSheet() {
        guard let win = sheet else { return }
        if let parent = win.sheetParent {
            parent.endSheet(win)
        } else {
            win.orderOut(nil)
        }
        sheet = nil
    }
}
