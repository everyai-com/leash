import Foundation

/// Wires OpenAI Codex CLI's `notify` hook into leash.
///
/// Codex calls a program (from `notify = [...]` in ~/.codex/config.toml) with a
/// single JSON argument on `agent-turn-complete`. We drop a tiny curl helper
/// script and point `notify` at it. The script ignores the JSON and just tells
/// the leash app the turn finished — leash walks up from the helper's PPID to
/// find the hosting terminal (Terminal/iTerm/Ghostty/Cursor…).
enum CodexInstaller {
    static let port: UInt16 = 7869

    enum Result { case wired, hasOwnNotify, failed }

    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private static var leashDir: URL { home.appendingPathComponent(".leash") }
    private static var scriptURL: URL { leashDir.appendingPathComponent("codex-notify.sh") }
    private static var configURL: URL { home.appendingPathComponent(".codex/config.toml") }
    private static let marker = "# leash — yanks you back when Codex finishes (added by `leash install`)"

    /// Only wire Codex if it actually looks installed, so we don't litter
    /// config for tools the user doesn't have.
    static func isPresent() -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: home.appendingPathComponent(".codex").path) { return true }
        return ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            .contains { fm.fileExists(atPath: $0) }
    }

    @discardableResult
    static func install() -> Result {
        do {
            try writeHelperScript()
            return try wireConfig()
        } catch {
            FileHandle.standardError.write("leash: codex setup failed: \(error)\n".data(using: .utf8)!)
            return .failed
        }
    }

    static func uninstall() {
        if let text = try? String(contentsOf: configURL, encoding: .utf8) {
            let kept = text.components(separatedBy: "\n").filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t == marker { return false }
                if t.hasPrefix("notify") && line.contains(scriptURL.path) { return false }
                return true
            }
            try? kept.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
        }
        try? FileManager.default.removeItem(at: scriptURL)
    }

    // MARK: -

    private static func writeHelperScript() throws {
        try FileManager.default.createDirectory(at: leashDir, withIntermediateDirectories: true)
        let curl = #"curl -s -m 1 -X POST -H "Content-Type: application/json" -d "{\"ppid\":$PPID,\"cwd\":\"$PWD\",\"message\":\"Codex finished a turn\"}" http://127.0.0.1:\#(port)/stop >/dev/null 2>&1 || true"#
        let body = "#!/bin/bash\n# leash — Codex notify hook. $1 is Codex's JSON payload (ignored).\n\(curl)\nexit 0\n"
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private static func wireConfig() throws -> Result {
        let fm = FileManager.default
        try fm.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let notifyLine = "notify = [\"\(scriptURL.path)\"]"

        guard fm.fileExists(atPath: configURL.path),
              let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            try "\(marker)\n\(notifyLine)\n".write(to: configURL, atomically: true, encoding: .utf8)
            return .wired
        }

        if text.contains(scriptURL.path) { return .wired } // idempotent

        var lines = text.components(separatedBy: "\n")
        // `notify` must be a top-level key — only consider lines before the
        // first [table] header.
        let firstTable = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
        let hasOwnNotify = lines[0..<firstTable].contains {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.hasPrefix("notify") && t.contains("=")
        }
        if hasOwnNotify { return .hasOwnNotify } // don't clobber the user's config

        lines.insert(contentsOf: ["", marker, notifyLine], at: firstTable)
        try lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
        return .wired
    }

    /// The snippet to show the user if they have their own `notify` already.
    static var manualSnippet: String { "notify = [\"\(scriptURL.path)\"]" }
}
