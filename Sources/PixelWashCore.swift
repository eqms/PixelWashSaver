import AppKit

// PixelWashCore - gemeinsame Render-Engine fuer den Screensaver (.saver) und die
// eigenstaendige App (.app). Bewusst ohne ScreenSaver-Import: nur AppKit/CoreGraphics,
// damit beide Targets exakt dieselbe Datei kompilieren (build.sh-Glob bzw.
// Xcode-File-Reference) und die Modi nie auseinanderlaufen.

public enum PixelWashMode: String, CaseIterable {
    case noise, cycle, bars, checker

    public var label: String {
        switch self {
        case .noise:   return "Rauschen"
        case .cycle:   return "Vollfarben"
        case .bars:    return "Laufstreifen"
        case .checker: return "Schachbrett"
        }
    }

    public var defaultsKey: String { "mode_" + rawValue }
}

public final class PixelWashEngine {

    // MARK: - Konfiguration

    public private(set) var activeModes: [PixelWashMode] = PixelWashMode.allCases
    public private(set) var switchSecs: TimeInterval = 45
    public private(set) var speed = 6

    // MARK: - Zustand

    public private(set) var mode: PixelWashMode = .noise
    private var modeIdx = 0
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

    public init() {}

    // Neue Einstellungen uebernehmen und den Auto-Mix von vorn starten.
    public func configure(activeModes: [PixelWashMode], switchSecs: TimeInterval, speed: Int) {
        self.activeModes = activeModes.isEmpty ? [.noise] : activeModes
        self.switchSecs = switchSecs
        self.speed = max(1, min(10, speed))
        modeIdx = 0
        mode = self.activeModes[0]
        lastSwitch = Date()
    }

    // Tempo-Mapping: tempo 10 ~ 60fps, tempo 1 ~ 10fps.
    // noise wird auf <=30fps gedeckelt (zehntausende Fuellungen pro Frame).
    public func interval(for mode: PixelWashMode) -> TimeInterval {
        let base = (16.0 + Double(10 - speed) * 9.0) / 1000.0
        let floor = (mode == .noise) ? 1.0 / 30.0 : 0.0
        return max(base, floor)
    }

    public var currentInterval: TimeInterval { interval(for: mode) }

    // MARK: - Frame-Fortschritt

    // Einen Frame Zustand weiterschalten. Rueckgabe true bei Moduswechsel,
    // damit der Aufrufer sein Timer-Intervall neu setzen kann.
    @discardableResult
    public func advance() -> Bool {
        tick &+= 1
        let switched = maybeSwitchMode()
        if mode == .cycle, tick % cycleEvery == 0 {
            cycleIdx = (cycleIdx + 1) % palette.count
        }
        return switched
    }

    private func maybeSwitchMode() -> Bool {
        guard switchSecs > 0, activeModes.count > 1 else { return false }
        guard Date().timeIntervalSince(lastSwitch) >= switchSecs else { return false }
        modeIdx = (modeIdx + 1) % activeModes.count
        mode = activeModes[modeIdx]
        lastSwitch = Date()
        return true
    }

    // MARK: - Rendering

    public func draw(in ctx: CGContext, bounds: CGRect) {
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)
        switch mode {
        case .noise:   drawNoise(ctx, bounds: bounds)
        case .cycle:   drawCycle(ctx, bounds: bounds)
        case .bars:    drawBars(ctx, bounds: bounds)
        case .checker: drawChecker(ctx, bounds: bounds)
        }
    }

    // --- Modus 1: RGB-Rauschen (kleiner Zufallspuffer, blockig hochskaliert) ---
    private func drawNoise(_ ctx: CGContext, bounds: CGRect) {
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

    // --- Modus 2: Vollfarben-Zyklus (Index wird in advance() getaktet) ---
    private var cycleEvery: Int { max(2, 22 - speed * 2) }
    private func drawCycle(_ ctx: CGContext, bounds: CGRect) {
        ctx.setFillColor(palette[cycleIdx].cgColor)
        ctx.fill(bounds)
    }

    // --- Modus 3: diagonale Laufstreifen ---
    private func drawBars(_ ctx: CGContext, bounds: CGRect) {
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
    private func drawChecker(_ ctx: CGContext, bounds: CGRect) {
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
}
