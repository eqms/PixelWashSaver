import Cocoa

// PixelWash (App) - eigenstaendige "Wash jetzt"-Utility, das kostenpflichtige
// Mac-App-Store-Gegenstueck zum kostenlosen Screensaver. Teilt sich die
// Render-Engine (PixelWashCore.swift) mit dem .saver-Bundle, bindet aber
// KEIN .saver-Bundle ein (App-Review-Richtlinie 2.4.5(ii)) - nur ein Link
// auf die kostenlose Screensaver-Downloadseite.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerFactoryDefaults()
        buildMainMenu()

        let controller = MainWindowController()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        mainWindowController = controller

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Hauptmenue (rein programmatisch, keine XIB)

    private func buildMainMenu() {
        let appName = NSLocalizedString("app.name", comment: "App name shown in the app menu")
        let mainMenu = NSMenu()

        // App-Menue
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let aboutTitle = "\(NSLocalizedString("menu.about", comment: "About menu item")) \(appName)"
        appMenu.addItem(withTitle: aboutTitle,
                         action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                         keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let quitTitle = "\(NSLocalizedString("menu.quit", comment: "Quit menu item")) \(appName)"
        appMenu.addItem(withTitle: quitTitle,
                         action: #selector(NSApplication.terminate(_:)),
                         keyEquivalent: "q")

        // Fenster-Menue
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: NSLocalizedString("menu.window", comment: "Window menu title"))
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: NSLocalizedString("menu.minimize", comment: "Minimize menu item"),
                            action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: NSLocalizedString("menu.zoom", comment: "Zoom menu item"),
                            action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}
