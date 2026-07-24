import Cocoa

// Randloses Fenster, das (anders als normale randlose Fenster) Key-Fenster
// werden kann - noetig, damit Tastaturereignisse waehrend des Vollbild-Wash
// ueberhaupt ankommen und den Abbruch ausloesen koennen.
private final class BorderlessKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// FullscreenWashController - erzeugt pro Bildschirm ein randloses Fenster auf
// Screensaver-Ebene mit eigener WashPreviewView/PixelWashEngine, blendet
// Cursor und Menueleiste aus und beendet den Wash bei jeder Taste/Maustaste.
final class FullscreenWashController: NSObject {

    private var windows: [NSWindow] = []
    private var eventMonitor: Any?
    private var onEnd: (() -> Void)?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    // Verhindert Display-Schlaf waehrend des Wash (sandbox-kompatibel, keine
    // zusaetzliche Entitlement noetig). Muss auf jedem Ausstiegspfad wieder
    // freigegeben werden.
    private var activityToken: NSObjectProtocol?

    func start(onEnd: @escaping () -> Void) {
        self.onEnd = onEnd

        activityToken = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated],
                                                                reason: "PixelWash fullscreen wash")

        let activeModes = currentActiveModes()
        let switchSecs = currentSwitchSecs()
        let speed = currentSpeed()

        windows = NSScreen.screens.map { screen in
            let window = BorderlessKeyWindow(contentRect: screen.frame, styleMask: [.borderless],
                                              backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false

            let preview = WashPreviewView(frame: NSRect(origin: .zero, size: screen.frame.size))
            preview.autoresizingMask = [.width, .height]
            preview.configure(activeModes: activeModes, switchSecs: switchSecs, speed: speed)
            window.contentView = preview

            window.makeKeyAndOrderFront(nil)
            return window
        }

        NSCursor.hide()
        previousPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]

        windows.first?.makeKey()

        // Jede Taste (inkl. ESC) oder Maustaste beendet den Wash zuverlaessig.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.stop()
            return nil   // Ereignis konsumieren, nicht weiterreichen
        }
    }

    private func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        NSCursor.unhide()
        NSApp.presentationOptions = previousPresentationOptions

        windows.forEach { $0.close() }
        windows.removeAll()

        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }

        let callback = onEnd
        onEnd = nil
        callback?()
    }

    deinit {
        // Sicherheitsnetz: falls stop() nie durchlief, Token trotzdem freigeben.
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }
}
