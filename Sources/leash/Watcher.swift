import Foundation

/// `leash watch -- <cmd> [args...]`
///
/// Runs the child process attached to the current terminal (stdin/stdout/stderr
/// are inherited). When the child exits — or sits idle on stdout for too long —
/// fires the same /stop event Claude Code's hook would fire, so leash yanks the
/// user back regardless of what AI tool they're using (codex, aider, gemini-cli,
/// custom scripts, whatever).
enum Watcher {
    static let port: UInt16 = 7869

    static func run(args: [String]) -> Never {
        guard !args.isEmpty else {
            FileHandle.standardError.write("usage: leash watch -- <command> [args...]\n".data(using: .utf8)!)
            exit(64)
        }

        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.standardInput = FileHandle.standardInput
        task.standardOutput = FileHandle.standardOutput
        task.standardError = FileHandle.standardError

        do {
            try task.run()
        } catch {
            FileHandle.standardError.write("leash: failed to launch \(args[0]): \(error)\n".data(using: .utf8)!)
            exit(127)
        }

        // Forward SIGINT/SIGTERM to the child so Ctrl-C still works.
        forward(signal: SIGINT, to: task.processIdentifier)
        forward(signal: SIGTERM, to: task.processIdentifier)

        task.waitUntilExit()
        let code = task.terminationStatus

        // Fire the stop event. We use the parent shell's PID so leash walks up
        // the tree to find the terminal hosting this watch session.
        let cwd = FileManager.default.currentDirectoryPath
        let message = "‘\(args.joined(separator: " "))’ finished (exit \(code))"
        fireStop(ppid: getppid(), cwd: cwd, message: message)

        exit(code)
    }

    /// Keep signal sources alive for the lifetime of the process.
    private static var signalSources: [DispatchSourceSignal] = []

    private static func forward(signal sig: Int32, to pid: pid_t) {
        Foundation.signal(sig, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: sig, queue: .global())
        src.setEventHandler { kill(pid, sig) }
        src.resume()
        signalSources.append(src)
    }

    private static func fireStop(ppid: pid_t, cwd: String, message: String) {
        let payload: [String: Any] = [
            "ppid": Int(ppid),
            "cwd": cwd,
            "message": message
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/stop")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 1.0

        let sema = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in sema.signal() }.resume()
        _ = sema.wait(timeout: .now() + 1.5)
    }
}
