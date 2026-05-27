import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private var launchItem: NSMenuItem!
    private let updates: UpdateController

    init(updates: UpdateController) {
        self.updates = updates
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🐕"
            button.toolTip = "leash — idle"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "leash", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        addItem(menu, title: "Install Claude Code hooks", selector: #selector(install))
        addItem(menu, title: "Uninstall hooks", selector: #selector(uninstall))
        menu.addItem(.separator())

        launchItem = addItem(menu, title: "Launch at login", selector: #selector(toggleLaunch))
        refreshLaunchItem()
        menu.addItem(.separator())

        let check = NSMenuItem(title: "Check for Updates…", action: #selector(UpdateController.checkForUpdates(_:)), keyEquivalent: "")
        check.target = updates
        menu.addItem(check)
        addItem(menu, title: "Open project on GitHub", selector: #selector(openGitHub))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit leash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func setWaiting(_ waiting: Bool) {
        DispatchQueue.main.async {
            self.statusItem.button?.title = waiting ? "🔴" : "🐕"
            self.statusItem.button?.toolTip = waiting ? "leash — waiting for you" : "leash — idle"
        }
    }

    @discardableResult
    private func addItem(_ menu: NSMenu, title: String, selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func refreshLaunchItem() {
        launchItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func install() { Installer.install() }
    @objc private func uninstall() { Installer.uninstall() }
    @objc private func toggleLaunch() {
        LoginItem.toggle()
        refreshLaunchItem()
    }
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/everyai-com/leash") {
            NSWorkspace.shared.open(url)
        }
    }
}
