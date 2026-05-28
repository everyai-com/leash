import AppKit

let args = CommandLine.arguments.dropFirst()

if let first = args.first {
    switch first {
    case "install":
        print(Installer.install())
        exit(0)
    case "uninstall":
        Installer.uninstall()
        exit(0)
    case "watch":
        // Everything after `watch` (optionally preceded by `--`) is the command.
        var rest = Array(args.dropFirst())
        if rest.first == "--" { rest.removeFirst() }
        Watcher.run(args: rest)
    case "--help", "-h":
        print("""
        leash — yanks you back when your AI agent finishes.

        Usage:
          leash                       Launch the menu-bar app
          leash install               Wire up every detected AI tool
                                      (Claude Code hooks + Codex notify)
          leash uninstall             Remove all leash hooks
          leash watch -- <cmd> ...    Run any command, fire the overlay when it exits
                                      (works for aider, gemini-cli, scripts, or any
                                       agent without a native hook)
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
app.setActivationPolicy(.regular)
app.run()
