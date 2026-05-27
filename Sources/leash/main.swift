import AppKit

let args = CommandLine.arguments.dropFirst()

if let first = args.first {
    switch first {
    case "install":
        Installer.install()
        exit(0)
    case "uninstall":
        Installer.uninstall()
        exit(0)
    case "--help", "-h":
        print("""
        leash — yanks you back when Claude finishes.

        Usage:
          leash             Launch the menu-bar app
          leash install     Wire up Claude Code hooks in ~/.claude/settings.json
          leash uninstall   Remove the hooks
        """)
        exit(0)
    default:
        FileHandle.standardError.write("unknown command: \(first)\n".data(using: .utf8)!)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
