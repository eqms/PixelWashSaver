import Cocoa

// WashPreviewView - NSView, die eine eigene PixelWashEngine-Instanz per Timer
// antreibt und deren Ausgabe zeichnet. Wird sowohl fuer die Live-Vorschau im
// Hauptfenster als auch (mit frischer Instanz je Bildschirm) im Vollbild-Wash
// verwendet. Der Timer wird bei Fensterwechsel/-schluss zuverlaessig beendet,
// um Leaks bzw. weiterlaufende Timer nach Fensterschluss zu vermeiden.
final class WashPreviewView: NSView {

    private let engine = PixelWashEngine()
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // Neue Einstellungen uebernehmen und den Auto-Mix von vorn starten
    // (identisch zum Verhalten von PixelWashEngine.configure).
    func configure(activeModes: [PixelWashMode], switchSecs: TimeInterval, speed: Int) {
        engine.configure(activeModes: activeModes, switchSecs: switchSecs, speed: speed)
        rescheduleTimer()
    }

    // MARK: - Lebenszyklus / Timer-Management

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(handleWindowWillClose(_:)),
                                                    name: NSWindow.willCloseNotification, object: window)
            rescheduleTimer()
        } else {
            stopTimer()
        }
    }

    @objc private func handleWindowWillClose(_ notification: Notification) {
        stopTimer()
    }

    private func rescheduleTimer() {
        stopTimer()
        guard window != nil else { return }
        let interval = engine.currentInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Auch waehrend Fenster-Resize/Menue-Tracking weiterlaufen lassen.
        if let t = timer {
            RunLoop.current.add(t, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let switched = engine.advance()
        setNeedsDisplay(bounds)
        if switched {
            rescheduleTimer()   // Timer-Intervall an neuen Modus anpassen
        }
    }

    // MARK: - Rendering

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        engine.draw(in: ctx, bounds: bounds)
    }
}
