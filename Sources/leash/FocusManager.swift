import AppKit

final class FocusManager {
    private var previousApp: NSRunningApplication?

    func snapshotFrontmost() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
    }

    func restorePrevious() {
        if let app = previousApp { activate(app) }
        previousApp = nil
    }

    func clearPrevious() {
        previousApp = nil
    }

    /// Walk up the process tree from `pid` and pick the best app to activate.
    /// Priority: Claude desktop app > Cursor/VS Code > terminal emulator >
    /// any regular ancestor > a running Claude.app even if not in the chain.
    func activateTerminal(forPID pid: Int32?) {
        var ancestors: [NSRunningApplication] = []
        if var current = pid {
            for step in 0..<14 {
                if let app = NSRunningApplication(processIdentifier: current),
                   app.activationPolicy == .regular {
                    NSLog("leash: ppid-walk step=\(step) pid=\(current) bundle=\(app.bundleIdentifier ?? "?")")
                    ancestors.append(app)
                }
                guard let parent = parentPID(of: current), parent > 1 else { break }
                current = parent
            }
        }

        let preferred: [String] = [
            "com.anthropic.claudefordesktop",  // Claude desktop app (Cowork etc.)
            "com.todesktop.230313mzl4w4u92",   // Cursor
            "com.microsoft.VSCode",            // VS Code
            "com.googlecode.iterm2",           // iTerm2
            "com.apple.Terminal",              // Terminal.app
            "com.mitchellh.ghostty",           // Ghostty
            "dev.warp.Warp-Stable",            // Warp
            "io.alacritty",                    // Alacritty
        ]
        for bid in preferred {
            if let match = ancestors.first(where: { $0.bundleIdentifier == bid }) {
                NSLog("leash: preferred match in ancestors → \(bid)")
                activate(match); return
            }
        }
        if let first = ancestors.first {
            NSLog("leash: falling back to first regular ancestor → \(first.bundleIdentifier ?? "?")")
            activate(first); return
        }
        // Last resort: Claude.app isn't in the chain but is running anyway.
        if let claude = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.anthropic.claudefordesktop"
        }) {
            NSLog("leash: last-resort activating running Claude.app")
            activate(claude); return
        }
        NSLog("leash: nothing to activate")
    }

    /// True if the frontmost app is the terminal hosting `pid` (i.e. user is
    /// already looking at Claude — no need to seize the screen).
    func isAlreadyEngaged(withHookPID pid: Int32?) -> Bool {
        guard var current = pid,
              let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return false
        }
        for _ in 0..<8 {
            if current == frontPID { return true }
            guard let parent = parentPID(of: current), parent > 1 else { return false }
            current = parent
        }
        return false
    }

    private func activate(_ app: NSRunningApplication) {
        // AppKit path — works on older macOS, often blocked on 14+.
        app.activate(options: [.activateAllWindows])

        // In-process AppleScript so the Automation permission grant is for
        // leash itself, not for /usr/bin/osascript. macOS prompts once; after
        // the user grants, activations land reliably on every subsequent fire.
        guard let bid = app.bundleIdentifier else { return }
        let source = "tell application id \"\(bid)\" to activate"
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        _ = script?.executeAndReturnError(&error)
        if let error = error {
            NSLog("leash: AppleScript activate failed for \(bid): \(error)")
            // -1743 = errAEEventNotPermitted — user hasn't granted Automation
            // for this target. Surface a one-time hint so they know what to do.
            if let n = error[NSAppleScript.errorNumber] as? Int, n == -1743 {
                Self.warnMissingAutomationPermission(for: bid)
            }
        }
    }

    private static var warnedBundles = Set<String>()
    private static func warnMissingAutomationPermission(for bid: String) {
        guard !warnedBundles.contains(bid) else { return }
        warnedBundles.insert(bid)
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "leash needs permission to control \(bid)"
            alert.informativeText = """
            macOS blocked leash from bringing \(bid) forward. Open
            System Settings → Privacy & Security → Automation and turn on
            \(bid) under leash.
            """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func parentPID(of pid: Int32) -> Int32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = mib.withUnsafeMutableBufferPointer { ptr -> Int32 in
            sysctl(ptr.baseAddress, u_int(ptr.count), &info, &size, nil, 0)
        }
        guard result == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }
}
