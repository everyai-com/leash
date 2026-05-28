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

    /// Walk up the process tree from `pid` and activate the first ancestor that
    /// corresponds to a running NSApplication (i.e. the terminal hosting Claude).
    func activateTerminal(forPID pid: Int32?) {
        guard var current = pid else {
            NSLog("leash: activateTerminal called with nil pid")
            return
        }
        for step in 0..<12 {
            let appName = NSRunningApplication(processIdentifier: current)?.bundleIdentifier ?? "?"
            NSLog("leash: ppid-walk step=\(step) pid=\(current) bundle=\(appName)")
            if let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy == .regular {
                NSLog("leash: activating \(app.bundleIdentifier ?? "?") (pid \(current))")
                activate(app)
                return
            }
            guard let parent = parentPID(of: current), parent > 1 else {
                NSLog("leash: no parent for pid \(current); giving up")
                return
            }
            current = parent
        }
        NSLog("leash: ppid-walk exhausted without finding a regular app")
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

        // Reliable fallback: AppleScript by bundle id. Apple still honors this
        // for cross-app activation when the calling process can't directly.
        guard let bid = app.bundleIdentifier else { return }
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "tell application id \"\(bid)\" to activate"]
        try? task.run()
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
