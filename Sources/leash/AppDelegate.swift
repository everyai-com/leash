import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var server: HookServer!
    private var focus: FocusManager!
    private var overlay: OverlayController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        focus = FocusManager()
        overlay = OverlayController(focus: focus)
        menuBar = MenuBarController()

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
    }
}
