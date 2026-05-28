import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var server: HookServer!
    private var focus: FocusManager!
    private var overlay: OverlayController!
    private var updates: UpdateController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        focus = FocusManager()
        overlay = OverlayController(focus: focus)
        updates = UpdateController()
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

        showFirstLaunchAlertIfNeeded()
    }

    private func showFirstLaunchAlertIfNeeded() {
        let key = "hasShownWelcome"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            let alert = NSAlert()
            alert.messageText = "leash is running."
            alert.informativeText = """
            Look for the 🔔 icon at the top-right of your screen — that's leash.

            Click it, then choose:
              1. Install Claude Code hooks
              2. Launch at login

            That's all the setup. From here on, leash pulls you back the moment Claude finishes.
            """
            alert.addButton(withTitle: "Show me where")
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self?.menuBar?.flashIcon()
            }
        }
    }
}
