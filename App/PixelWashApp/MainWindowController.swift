import Cocoa

// Gemeinsame UserDefaults-Schluessel - identisch zu denen des Screensavers
// (ScreenSaverDefaults in PixelWashView.swift), damit das Einstellungsschema
// ueberall gleich aussieht. Die App liest/schreibt UserDefaults.standard in
// ihrer eigenen (sandboxed) Domain.
enum WashDefaultsKey {
    static let tempo = "tempo"
    static let switchEverySec = "switchEverySec"
}

// Werksvorgaben registrieren: Auto-Mix aller Modi, Wechsel alle 45 s, Tempo 6
// (identisch zur Werkseinstellung des Screensavers).
func registerFactoryDefaults() {
    var reg: [String: Any] = [
        WashDefaultsKey.tempo: 6,
        WashDefaultsKey.switchEverySec: 45.0,
    ]
    for m in PixelWashMode.allCases { reg[m.defaultsKey] = true }
    UserDefaults.standard.register(defaults: reg)
}

func currentActiveModes() -> [PixelWashMode] {
    PixelWashMode.allCases.filter { UserDefaults.standard.bool(forKey: $0.defaultsKey) }
}

func currentSwitchSecs() -> TimeInterval {
    UserDefaults.standard.double(forKey: WashDefaultsKey.switchEverySec)
}

func currentSpeed() -> Int {
    let v = UserDefaults.standard.integer(forKey: WashDefaultsKey.tempo)
    return v == 0 ? 6 : v
}

// Lokalisierter Anzeigename je Modus. Bewusst NICHT PixelWashMode.label
// verwenden - das liefert nur deutsche Namen. Die App bildet den Modus
// stattdessen explizit auf einen Lokalisierungsschluessel ab.
func localizedName(for mode: PixelWashMode) -> String {
    switch mode {
    case .noise:   return NSLocalizedString("mode.noise", comment: "Mode name: noise")
    case .cycle:   return NSLocalizedString("mode.cycle", comment: "Mode name: solid colors")
    case .bars:    return NSLocalizedString("mode.bars", comment: "Mode name: moving bars")
    case .checker: return NSLocalizedString("mode.checker", comment: "Mode name: checkerboard")
    }
}

// MainWindowController - Hauptfenster mit Bedien-Sidebar links (~280pt) und
// Live-Vorschau rechts. Alle Steuerelemente schreiben live in UserDefaults
// und werden sofort an die Vorschau-Engine durchgereicht.
final class MainWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {

    private let previewView = WashPreviewView(frame: .zero)
    private var modeChecks: [PixelWashMode: NSButton] = [:]
    private var tempoSlider: NSSlider!
    private var tempoValueLabel: NSTextField!
    private var switchField: NSTextField!
    private var fullscreenController: FullscreenWashController?

    convenience init() {
        let width: CGFloat = 920, height: CGFloat = 620
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable],
                               backing: .buffered, defer: false)
        window.title = NSLocalizedString("window.title", comment: "Main window title")
        window.minSize = NSSize(width: 760, height: 560)
        window.center()

        self.init(window: window)
        window.delegate = self
        buildUI()
        applySettingsToPreview()
    }

    // MARK: - UI-Aufbau

    private func buildUI() {
        guard let window = window else { return }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: window.frame.width, height: window.frame.height))
        window.contentView = content

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        previewView.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(sidebar)
        content.addSubview(previewView)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 280),

            previewView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: content.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            previewView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])

        buildSidebarContents(in: sidebar)
    }

    private func buildSidebarContents(in sidebar: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        sidebar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor),
        ])

        // Titel
        let title = NSTextField(labelWithString: NSLocalizedString("sidebar.title", comment: "Sidebar heading"))
        title.font = .boldSystemFont(ofSize: 16)
        stack.addArrangedSubview(title)

        // Aktive Modi
        stack.addArrangedSubview(sectionLabel(NSLocalizedString("sidebar.modes", comment: "Modes section label")))

        modeChecks.removeAll()
        let activeModes = currentActiveModes()
        for mode in PixelWashMode.allCases {
            let checkbox = NSButton(checkboxWithTitle: localizedName(for: mode),
                                     target: self, action: #selector(controlChanged(_:)))
            checkbox.state = activeModes.contains(mode) ? .on : .off
            stack.addArrangedSubview(checkbox)
            modeChecks[mode] = checkbox
        }

        // Tempo
        stack.addArrangedSubview(sectionLabel(NSLocalizedString("sidebar.tempo", comment: "Speed section label")))

        let tempoRow = NSStackView()
        tempoRow.orientation = .horizontal
        tempoRow.spacing = 8
        let slider = NSSlider(value: Double(currentSpeed()), minValue: 1, maxValue: 10,
                               target: self, action: #selector(controlChanged(_:)))
        slider.numberOfTickMarks = 10
        slider.allowsTickMarkValuesOnly = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 170).isActive = true
        tempoSlider = slider

        let valueLabel = NSTextField(labelWithString: "\(currentSpeed())")
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        tempoValueLabel = valueLabel

        tempoRow.addArrangedSubview(slider)
        tempoRow.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(tempoRow)

        // Moduswechsel-Intervall
        stack.addArrangedSubview(sectionLabel(NSLocalizedString("sidebar.switchInterval", comment: "Switch interval section label")))

        let switchRow = NSStackView()
        switchRow.orientation = .horizontal
        switchRow.spacing = 8
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        field.integerValue = Int(currentSwitchSecs())
        field.alignment = .right
        field.target = self
        field.action = #selector(controlChanged(_:))
        field.delegate = self
        switchField = field

        let unitLabel = NSTextField(labelWithString: NSLocalizedString("sidebar.seconds", comment: "Seconds unit label"))
        switchRow.addArrangedSubview(field)
        switchRow.addArrangedSubview(unitLabel)
        stack.addArrangedSubview(switchRow)

        // Start-Button
        let startButton = NSButton(title: NSLocalizedString("sidebar.startButton", comment: "Start fullscreen wash button"),
                                    target: self, action: #selector(startFullscreenWash(_:)))
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.keyEquivalent = "\r"
        stack.addArrangedSubview(startButton)
        stack.setCustomSpacing(16, after: startButton)

        // Trenner
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 240).isActive = true
        stack.addArrangedSubview(separator)

        // Screensaver-Cross-Promotion-Box
        stack.addArrangedSubview(buildScreenSaverBox())
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func buildScreenSaverBox() -> NSBox {
        let box = NSBox()
        box.titlePosition = .atTop
        box.title = NSLocalizedString("sidebar.saverBox.title", comment: "Screen saver box title")
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let innerStack = NSStackView()
        innerStack.orientation = .vertical
        innerStack.alignment = .leading
        innerStack.spacing = 8
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        let info = NSTextField(wrappingLabelWithString: NSLocalizedString("sidebar.saverBox.text", comment: "Screen saver promo text"))
        info.preferredMaxLayoutWidth = 210
        info.font = .systemFont(ofSize: 11)
        innerStack.addArrangedSubview(info)

        let getButton = NSButton(title: NSLocalizedString("sidebar.saverBox.button", comment: "Open screen saver download page"),
                                  target: self, action: #selector(openScreensaverSite(_:)))
        getButton.bezelStyle = .rounded
        innerStack.addArrangedSubview(getButton)

        if let contentView = box.contentView {
            contentView.addSubview(innerStack)
            NSLayoutConstraint.activate([
                innerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                innerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                innerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                innerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            ])
        }
        return box
    }

    // MARK: - Aktionen

    @objc private func controlChanged(_ sender: Any) {
        if let slider = sender as? NSSlider, slider === tempoSlider {
            tempoValueLabel.stringValue = "\(Int(slider.doubleValue.rounded()))"
        }
        persistSettings()
        applySettingsToPreview()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === switchField else { return }
        controlChanged(field)
    }

    private func persistSettings() {
        for (mode, checkbox) in modeChecks {
            UserDefaults.standard.set(checkbox.state == .on, forKey: mode.defaultsKey)
        }
        if let slider = tempoSlider {
            UserDefaults.standard.set(Int(slider.doubleValue.rounded()), forKey: WashDefaultsKey.tempo)
        }
        if let field = switchField {
            UserDefaults.standard.set(Double(max(0, field.integerValue)), forKey: WashDefaultsKey.switchEverySec)
        }
    }

    private func applySettingsToPreview() {
        previewView.configure(activeModes: currentActiveModes(),
                               switchSecs: currentSwitchSecs(),
                               speed: currentSpeed())
    }

    @objc private func openScreensaverSite(_ sender: Any) {
        guard let url = URL(string: "https://it-guy.ai/pixelwash") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func startFullscreenWash(_ sender: Any) {
        guard fullscreenController == nil else { return }
        let controller = FullscreenWashController()
        fullscreenController = controller
        controller.start { [weak self] in
            guard let self = self else { return }
            self.fullscreenController = nil
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
