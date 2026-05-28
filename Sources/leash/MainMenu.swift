import AppKit

/// Builds the macOS top-of-screen menu bar (App / Edit / Window / Help)
/// that appears when leash is the frontmost app.
enum MainMenu {
    static func build(updates: UpdateController, panel: ControlPanel) -> NSMenu {
        let main = NSMenu()

        main.addItem(appMenu(updates: updates, panel: panel))
        main.addItem(editMenu())
        main.addItem(windowMenu())
        main.addItem(helpMenu())

        return main
    }

    // MARK: - App menu

    private static func appMenu(updates: UpdateController, panel: ControlPanel) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "leash")

        menu.addItem(withTitle: "About leash",
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Open Control Window",
                                  action: #selector(ControlPanel.show),
                                  keyEquivalent: ",")
        settings.target = panel
        menu.addItem(settings)
        menu.addItem(.separator())

        let install = NSMenuItem(title: "Connect my AI tools",
                                 action: #selector(InstallerProxy.install),
                                 keyEquivalent: "")
        install.target = InstallerProxy.shared
        menu.addItem(install)

        let uninstall = NSMenuItem(title: "Disconnect (remove hooks)",
                                   action: #selector(InstallerProxy.uninstall),
                                   keyEquivalent: "")
        uninstall.target = InstallerProxy.shared
        menu.addItem(uninstall)
        menu.addItem(.separator())

        let check = NSMenuItem(title: "Check for Updates…",
                               action: #selector(UpdateController.checkForUpdates(_:)),
                               keyEquivalent: "")
        check.target = updates
        menu.addItem(check)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Hide leash",
                     action: #selector(NSApplication.hide(_:)),
                     keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "Hide Others",
                                      action: #selector(NSApplication.hideOtherApplications(_:)),
                                      keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All",
                     action: #selector(NSApplication.unhideAllApplications(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())

        menu.addItem(withTitle: "Quit leash",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        item.submenu = menu
        return item
    }

    // MARK: - Edit menu (standard)

    private static func editMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")

        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut",   action: #selector(NSText.cut(_:)),   keyEquivalent: "x")
        menu.addItem(withTitle: "Copy",  action: #selector(NSText.copy(_:)),  keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        item.submenu = menu
        return item
    }

    // MARK: - Window menu

    private static func windowMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")

        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom",     action: #selector(NSWindow.performZoom(_:)),       keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring All to Front",
                     action: #selector(NSApplication.arrangeInFront(_:)),
                     keyEquivalent: "")

        item.submenu = menu
        // Tell AppKit this is the Window menu so it auto-populates window list.
        NSApp.windowsMenu = menu
        return item
    }

    // MARK: - Help menu

    private static func helpMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Help")

        let github = NSMenuItem(title: "leash on GitHub",
                                action: #selector(HelpProxy.openGitHub),
                                keyEquivalent: "")
        github.target = HelpProxy.shared
        menu.addItem(github)

        let issues = NSMenuItem(title: "Report an Issue…",
                                action: #selector(HelpProxy.openIssues),
                                keyEquivalent: "")
        issues.target = HelpProxy.shared
        menu.addItem(issues)

        item.submenu = menu
        return item
    }
}

// MARK: - Small target proxies (so menu actions land on objects with @objc selectors)

final class InstallerProxy: NSObject {
    static let shared = InstallerProxy()
    @objc func install() {
        let summary = Installer.install()
        let alert = NSAlert()
        alert.messageText = "Connected"
        alert.informativeText = summary
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }
    @objc func uninstall() { Installer.uninstall() }
}

final class HelpProxy: NSObject {
    static let shared = HelpProxy()
    @objc func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/everyai-com/leash")!)
    }
    @objc func openIssues() {
        NSWorkspace.shared.open(URL(string: "https://github.com/everyai-com/leash/issues/new")!)
    }
}
