import Foundation

enum Installer {
    static let port: UInt16 = 7869

    static var settingsPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/settings.json")
    }

    static func install() {
        let stopCmd = curlCommand(path: "/stop")
        let notifyCmd = curlCommand(path: "/notify")
        let submitCmd = curlCommand(path: "/submit")

        var settings = loadSettings()
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]
        hooks["Stop"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": stopCmd]]
        ]]
        hooks["Notification"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": notifyCmd]]
        ]]
        hooks["UserPromptSubmit"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": submitCmd]]
        ]]
        settings["hooks"] = hooks

        do {
            try save(settings: settings)
            print("leash: hooks installed → \(settingsPath.path)")
        } catch {
            FileHandle.standardError.write("leash: failed to install: \(error)\n".data(using: .utf8)!)
        }
    }

    static func uninstall() {
        var settings = loadSettings()
        if var hooks = settings["hooks"] as? [String: Any] {
            for key in ["Stop", "Notification", "UserPromptSubmit"] {
                if let entries = hooks[key] as? [[String: Any]] {
                    let filtered = entries.compactMap { entry -> [String: Any]? in
                        guard let inner = entry["hooks"] as? [[String: Any]] else { return entry }
                        let kept = inner.filter {
                            guard let cmd = $0["command"] as? String else { return true }
                            return !cmd.contains("127.0.0.1:\(port)")
                        }
                        if kept.isEmpty { return nil }
                        var copy = entry
                        copy["hooks"] = kept
                        return copy
                    }
                    if filtered.isEmpty {
                        hooks.removeValue(forKey: key)
                    } else {
                        hooks[key] = filtered
                    }
                }
            }
            settings["hooks"] = hooks
        }
        do {
            try save(settings: settings)
            print("leash: hooks removed")
        } catch {
            FileHandle.standardError.write("leash: failed to uninstall: \(error)\n".data(using: .utf8)!)
        }
    }

    private static func curlCommand(path: String) -> String {
        // PPID is the shell that spawned Claude; we walk up from it to find the terminal app.
        return #"curl -s -m 1 -X POST -H "Content-Type: application/json" -d "{\"ppid\":$PPID,\"cwd\":\"$PWD\"}" http://127.0.0.1:\#(port)\#(path) >/dev/null 2>&1 || true"#
    }

    private static func loadSettings() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    private static func save(settings: [String: Any]) throws {
        let dir = settingsPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsPath, options: .atomic)
    }
}
