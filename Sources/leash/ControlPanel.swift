import AppKit

/// Backup UI for users whose menu-bar icon is hidden by the notch / overflow.
/// Shown when the user re-opens leash.app while it's already running.
final class ControlPanel: NSObject {
    private let window: NSWindow
    private let updates: UpdateController
    private var launchToggle: NSButton!

    init(updates: UpdateController) {
        self.updates = updates

        let size = NSSize(width: 420, height: 360)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "leash"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.isMovableByWindowBackground = true

        super.init()

        window.contentView = buildContent(size)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        refresh()
    }

    private func refresh() {
        launchToggle.state = LoginItem.isEnabled ? .on : .off
    }

    private func buildContent(_ size: NSSize) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true

        let title = NSTextField(labelWithString: "leash")
        title.font = .systemFont(ofSize: 32, weight: .bold)

        let sub = NSTextField(labelWithString: "Yanks you back when Claude finishes.")
        sub.font = .systemFont(ofSize: 13)
        sub.textColor = .secondaryLabelColor

        let install   = button("Install Claude Code hooks",   #selector(installHooks))
        let uninstall = button("Uninstall hooks",             #selector(uninstallHooks))
        launchToggle  = checkbox("Launch at login",           #selector(toggleLaunch))
        let check     = button("Check for updates…",          #selector(checkForUpdates))
        let github    = button("Open project on GitHub",      #selector(openGitHub))
        let quit      = button("Quit leash",                  #selector(quitApp))
        quit.bezelColor = .systemRed

        let hint = NSTextField(wrappingLabelWithString: "Tip: leash lives in your menu bar (🔔 icon, top right). If your menu bar is too full, this window is always here as a backup — just open leash.app again.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 0

        let stack = NSStackView(views: [title, sub, install, uninstall, launchToggle, check, github, quit, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(20, after: sub)
        stack.setCustomSpacing(20, after: quit)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 36),
        ])

        return root
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .large
        return b
    }

    private func checkbox(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: self, action: action)
        return b
    }

    @objc private func installHooks()    { Installer.install() }
    @objc private func uninstallHooks()  { Installer.uninstall() }
    @objc private func toggleLaunch()    { LoginItem.toggle(); refresh() }
    @objc private func checkForUpdates() { updates.checkForUpdates(self) }
    @objc private func openGitHub()      { NSWorkspace.shared.open(URL(string: "https://github.com/everyai-com/leash")!) }
    @objc private func quitApp()         { NSApp.terminate(self) }
}
