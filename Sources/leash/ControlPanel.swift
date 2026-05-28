import AppKit

/// Backup UI for users whose menu-bar icon is hidden by the notch / overflow.
/// Shown when the user re-opens leash.app while it's already running.
final class ControlPanel: NSObject {
    private let window: NSWindow
    private let updates: UpdateController
    private var launchToggle: NSButton!
    private var soundToggle: NSButton!
    private var returnToggle: NSButton!
    private var notifyToggle: NSButton!
    private var mediaToggle: NSButton!

    init(updates: UpdateController) {
        self.updates = updates

        let size = NSSize(width: 460, height: 560)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
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

    @objc func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        refresh()
    }

    private func refresh() {
        launchToggle.state = LoginItem.isEnabled ? .on : .off
        soundToggle.state  = Settings.soundEnabled ? .on : .off
        returnToggle.state = Settings.autoReturnOnSubmit ? .on : .off
        notifyToggle.state = Settings.seizeOnNotification ? .on : .off
        mediaToggle.state  = Settings.pauseMedia ? .on : .off
    }

    private func buildContent(_ size: NSSize) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true

        let title = NSTextField(labelWithString: "leash")
        title.font = .systemFont(ofSize: 32, weight: .bold)

        let sub = NSTextField(labelWithString: "Yanks you back when Claude finishes.")
        sub.font = .systemFont(ofSize: 13)
        sub.textColor = .secondaryLabelColor

        let install   = button("Connect my AI tools",         #selector(installHooks))
        let uninstall = button("Disconnect (remove hooks)",   #selector(uninstallHooks))
        launchToggle  = checkbox("Launch at login",           #selector(toggleLaunch))

        let behaviorHeader = sectionHeader("Behavior")
        soundToggle  = checkbox("Ring a sound while waiting",            #selector(toggleSound))
        returnToggle = checkbox("Send me back to my app after I submit", #selector(toggleReturn))
        notifyToggle = checkbox("Also alert on permission prompts",      #selector(toggleNotify))
        mediaToggle  = checkbox("Pause media (YouTube, Spotify…)",       #selector(toggleMedia))

        let check     = button("Check for updates…",          #selector(checkForUpdates))
        let github    = button("Open project on GitHub",      #selector(openGitHub))
        let quit      = button("Quit leash",                  #selector(quitApp))
        quit.bezelColor = .systemRed

        let hint = NSTextField(wrappingLabelWithString: "Tip: leash also lives in your menu bar (🔔 icon, top right). If your menu bar is too full, reopen leash.app to get back here.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 0

        let stack = NSStackView(views: [
            title, sub,
            install, uninstall, launchToggle,
            behaviorHeader, soundToggle, returnToggle, notifyToggle, mediaToggle,
            check, github, quit, hint,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.setCustomSpacing(18, after: sub)
        stack.setCustomSpacing(16, after: launchToggle)
        stack.setCustomSpacing(16, after: mediaToggle)
        stack.setCustomSpacing(18, after: quit)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 36),
        ])

        return root
    }

    private func sectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
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

    @objc private func installHooks() {
        let summary = Installer.install()
        let alert = NSAlert()
        alert.messageText = "Connected"
        alert.informativeText = summary
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }
    @objc private func uninstallHooks() {
        Installer.uninstall()
        let alert = NSAlert()
        alert.messageText = "Disconnected"
        alert.informativeText = "Removed leash hooks from Claude Code and Codex."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    @objc private func toggleLaunch()    { LoginItem.toggle(); refresh() }
    @objc private func toggleSound()     { Settings.soundEnabled = (soundToggle.state == .on) }
    @objc private func toggleReturn()    { Settings.autoReturnOnSubmit = (returnToggle.state == .on) }
    @objc private func toggleNotify()    { Settings.seizeOnNotification = (notifyToggle.state == .on) }
    @objc private func toggleMedia()     { Settings.pauseMedia = (mediaToggle.state == .on) }
    @objc private func checkForUpdates() { updates.checkForUpdates(self) }
    @objc private func openGitHub()      { NSWorkspace.shared.open(URL(string: "https://github.com/everyai-com/leash")!) }
    @objc private func quitApp()         { NSApp.terminate(self) }
}
