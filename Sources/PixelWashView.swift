import ScreenSaver
import AppKit
import os

// PixelWash - Image-Retention-Kur als macOS-Screensaver.
// Zeichnet vier Wasch-Modi nativ in Core Graphics direkt in der ScreenSaverView.
// Einstellungen ueber das Konfigurations-Sheet (ScreenSaverDefaults).
// Universal-Binary, getestet auf macOS 26 (Tahoe), Apple Silicon.

@objc(PixelWashView)
public final class PixelWashView: ScreenSaverView {

    enum Mode: String, CaseIterable {
        case noise, cycle, bars, checker
        var label: String {
            switch self {
            case .noise:   return "Rauschen"
            case .cycle:   return "Vollfarben"
            case .bars:    return "Laufstreifen"
            case .checker: return "Schachbrett"
            }
        }
        var defaultsKey: String { "mode_" + rawValue }
    }

    // MARK: - Defaults / Persistenz

    private enum Key {
        static let switchEverySec = "switchEverySec"
        static let tempo = "tempo"
    }
    // Werkseinstellung: Auto-Mix aller Modi, Wechsel alle 45 s, Tempo 6.
    private static let defaultSwitchEverySec: Double = 45
    private static let defaultTempo = 6

    private lazy var store: ScreenSaverDefaults = {
        let id = Bundle(for: PixelWashView.self).bundleIdentifier ?? "de.equitania.pixelwash"
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

    private let log = Logger(subsystem: "de.equitania.pixelwash", category: "main")
    private var activeModes: [Mode] = Mode.allCases
    private var switchSecs: TimeInterval = defaultSwitchEverySec
    private var speed = defaultTempo
    private var modeIdx = 0
    private var mode: Mode = .noise
    private var lastSwitch = Date()
    private var tick = 0           // globaler Frame-Zaehler fuer modusinterne Takte

    // Wiederverwendeter Rauschpuffer (Block-Aufloesung, nicht Pixel-Aufloesung).
    private var noiseBuf = [UInt8]()
    private var noiseCols = 0
    private var noiseRows = 0

    // Vollfarben-Palette fuer den cycle-Modus.
    private let palette: [NSColor] = [
        .white, .black,
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
        NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
        NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
        NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1),
        NSColor(srgbRed: 0, green: 1, blue: 1, alpha: 1),
        NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1),
        NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1),
    ]
    private var cycleIdx = 0

    // MARK: - Init

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        loadSettings()
        animationTimeInterval = interval(for: mode)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSettings()
        animationTimeInterval = interval(for: mode)
    }

    // MARK: - Einstellungen laden

    private func loadSettings() {
        activeModes = Mode.allCases.filter { store.bool(forKey: $0.defaultsKey) }
        if activeModes.isEmpty { activeModes = [.noise] }
        switchSecs = store.double(forKey: Key.switchEverySec)
        speed = max(1, min(10, store.integer(forKey: Key.tempo)))
        modeIdx = 0
        mode = activeModes[0]
    }

    // MARK: - Lebenszyklus

    public override func startAnimation() {
        super.startAnimation()
        loadSettings()                       // frische Werte aus dem Sheet uebernehmen
        animationTimeInterval = interval(for: mode)
        log.info("startAnimation preview=\(self.isPreview, privacy: .public) modes=\(self.activeModes.map { $0.rawValue }.joined(separator: ","), privacy: .public)")
        lastSwitch = Date()
    }

    public override func stopAnimation() {
        super.stopAnimation()
    }

    public override func animateOneFrame() {
        tick &+= 1
        maybeSwitchMode()
        if mode == .cycle, tick % cycleEvery == 0 {
            cycleIdx = (cycleIdx + 1) % palette.count
        }
        setNeedsDisplay(bounds)
    }

    // MARK: - Auto-Mix

    private func maybeSwitchMode() {
        guard switchSecs > 0, activeModes.count > 1 else { return }
        if Date().timeIntervalSince(lastSwitch) >= switchSecs {
            modeIdx = (modeIdx + 1) % activeModes.count
            mode = activeModes[modeIdx]
            lastSwitch = Date()
            animationTimeInterval = interval(for: mode)   // Timer mit neuem Takt
        }
    }

    // Tempo-Mapping: tempo 10 ~ 60fps, tempo 1 ~ 10fps.
    // noise wird auf <=30fps gedeckelt (zehntausende Fuellungen pro Frame).
    private func interval(for mode: Mode) -> TimeInterval {
        let base = (16.0 + Double(10 - speed) * 9.0) / 1000.0
        let floor = (mode == .noise) ? 1.0 / 30.0 : 0.0
        return max(base, floor)
    }

    // MARK: - Rendering

    public override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)
        switch mode {
        case .noise:   drawNoise(ctx)
        case .cycle:   drawCycle(ctx)
        case .bars:    drawBars(ctx)
        case .checker: drawChecker(ctx)
        }
    }

    // --- Modus 1: RGB-Rauschen (kleiner Zufallspuffer, blockig hochskaliert) ---
    private func drawNoise(_ ctx: CGContext) {
        let block: CGFloat = 7
        let cols = max(1, Int((bounds.width / block).rounded(.up)))
        let rows = max(1, Int((bounds.height / block).rounded(.up)))
        if cols != noiseCols || rows != noiseRows {
            noiseCols = cols; noiseRows = rows
            noiseBuf = [UInt8](repeating: 0, count: cols * rows * 4)
        }
        noiseBuf.withUnsafeMutableBufferPointer { buf in
            var i = 0
            while i < buf.count {
                buf[i]     = UInt8.random(in: 0...255)   // R
                buf[i + 1] = UInt8.random(in: 0...255)   // G
                buf[i + 2] = UInt8.random(in: 0...255)   // B
                buf[i + 3] = 255                          // A
                i += 4
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(noiseBuf) as CFData),
              let img = CGImage(width: cols, height: rows, bitsPerComponent: 8,
                                bitsPerPixel: 32, bytesPerRow: cols * 4,
                                space: cs,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil,
                                shouldInterpolate: false, intent: .defaultIntent)
        else { return }
        ctx.interpolationQuality = .none
        ctx.draw(img, in: bounds)
    }

    // --- Modus 2: Vollfarben-Zyklus (Index wird in animateOneFrame getaktet) ---
    private var cycleEvery: Int { max(2, 22 - speed * 2) }
    private func drawCycle(_ ctx: CGContext) {
        ctx.setFillColor(palette[cycleIdx].cgColor)
        ctx.fill(bounds)
    }

    // --- Modus 3: diagonale Laufstreifen ---
    private func drawBars(_ ctx: CGContext) {
        let bar: CGFloat = 80
        let H = bounds.height
        let W = bounds.width
        let off = CGFloat((tick * speed) % Int(bar * 2))
        ctx.setFillColor(NSColor.white.cgColor)
        var x = -bar * 2 + off
        while x < W + H {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: H))
            ctx.addLine(to: CGPoint(x: x + bar, y: H))
            ctx.addLine(to: CGPoint(x: x + bar - H, y: 0))
            ctx.addLine(to: CGPoint(x: x - H, y: 0))
            ctx.closePath()
            ctx.fillPath()
            x += bar * 2
        }
    }

    // --- Modus 4: invertierendes Schachbrett ---
    private func drawChecker(_ ctx: CGContext) {
        let c: CGFloat = 24
        let every = max(2, 18 - speed)
        let inv = (tick / every) % 2 == 1
        var ry = 0
        var y: CGFloat = 0
        while y < bounds.height {
            var rx = 0
            var x: CGFloat = 0
            while x < bounds.width {
                let on = ((rx + ry) & 1) == (inv ? 1 : 0)
                if on {
                    ctx.setFillColor(NSColor.white.cgColor)
                    ctx.fill(CGRect(x: x, y: y, width: c, height: c))
                }
                x += c; rx += 1
            }
            y += c; ry += 1
        }
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
