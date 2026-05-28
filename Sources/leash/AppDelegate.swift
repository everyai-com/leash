import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var server: HookServer!
    private var focus: FocusManager!
    private var overlay: OverlayController!
    private var updates: UpdateController!
    private var panel: ControlPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        focus = FocusManager()
        overlay = OverlayController(focus: focus)
        updates = UpdateController()
        panel = ControlPanel(updates: updates)
        menuBar = MenuBarController(updates: updates)

        server = HookServer(
            onStop: { [weak self] event in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if self.focus.isAlreadyEngaged(withHookPID: event.ppid) {
                        // User is already looking at Claude — don't yank them.
                        return
                    }
                    self.focus.snapshotFrontmost()
                    self.overlay.seize(event: event)
                    self.menuBar.setWaiting(true)
                }
            },
            onSubmit: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.overlay.release()
                    self?.focus.restorePrevious()
                    self?.menuBar.setWaiting(false)
                }
            }
        )
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
