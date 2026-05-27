import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🐕"
            button.toolTip = "leash — idle"
        }

        let menu = NSMenu()
        menu.addItem(.init(title: "leash", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(.init(title: "Install Claude Code hooks", action: #selector(install), keyEquivalent: ""))
        menu.addItem(.init(title: "Uninstall hooks", action: #selector(uninstall), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(.init(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action == #selector(install) || item.action == #selector(uninstall) {
            item.target = self
        }
        statusItem.menu = menu
    }

    func setWaiting(_ waiting: Bool) {
        DispatchQueue.main.async {
            self.statusItem.button?.title = waiting ? "🔴" : "🐕"
            self.statusItem.button?.toolTip = waiting ? "leash — waiting for you" : "leash — idle"
        }
    }

    @objc private func install() { Installer.install() }
    @objc private func uninstall() { Installer.uninstall() }
}
