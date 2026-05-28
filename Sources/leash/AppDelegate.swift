import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var server: HookServer!
    private var focus: FocusManager!
    private var overlay: OverlayController!
    private var updates: UpdateController!
    private var panel: ControlPanel!
    private var coordinator: Coordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()

        focus = FocusManager()
        overlay = OverlayController()
        updates = UpdateController()
        panel = ControlPanel(updates: updates)
        NSApp.mainMenu = MainMenu.build(updates: updates, panel: panel)
        menuBar = MenuBarController(updates: updates)
        coordinator = Coordinator(focus: focus, overlay: overlay, menuBar: menuBar)

        server = HookServer { [weak self] kind, event in
            self?.coordinator.handle(kind, event)
        }
        do {
            try server.start(port: 7869)
        } catch {
            NSLog("leash: server failed to start: \(error)")
        }

        // On first launch, open the control panel so the user has a guaranteed
        // way to reach the controls — even if the menu-bar icon is hidden by
        // a packed/notched menu bar.
        let key = "hasShownWelcome"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.panel.show()
            }
        }
    }

    /// Called when the user re-opens leash.app while it's already running
    /// (double-clicking the .app, opening from Spotlight, etc.). Show the
    /// control panel as the backup UI.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.show()
        return true
    }
}
