# leash

**Yanks you back the moment your AI agent finishes — or needs you.**

Long-running AI agents broke the human attention loop. You can't focus on anything else while waiting, because you don't know when they'll need you — so you babysit a terminal instead of getting your time back.

`leash` is a tiny macOS menu-bar app that:

1. Hooks your agent's finish/needs-input events (Claude Code, Codex, or any command).
2. Slams a full-screen overlay across every display, plays an alert, pauses media.
3. Press `⏎` to engage → overlay vanishes, the originating terminal/app jumps to the front, your cursor is in the prompt. (Or `Esc` to dismiss and stay where you are.)
4. Type your next instruction. The moment you submit, leash re-focuses whatever you were doing before.

It tracks a small state machine (`idle → waiting → engaged`) so it only pulls you back when it actually seized you — submitting a prompt while working normally never yanks you anywhere. Repeated finish events while the overlay is already up are de-duplicated, and everything is tunable from the control window (sound, auto-return, alert-on-permission-prompts, media pause).

Go full brain-rot mode. The leash pulls you back.

## Works with

`leash` connects to every AI tool it detects in one step — click **Connect my AI tools** (or run `leash install`):

| Tool | How | Status |
|---|---|---|
| **Claude Code** | `Stop` / `Notification` / `UserPromptSubmit` hooks in `~/.claude/settings.json` | ✅ auto |
| **OpenAI Codex** | `notify` hook in `~/.codex/config.toml` (fires on `agent-turn-complete`) | ✅ auto (if installed) |
| **Cursor / VS Code** | Run `claude` or `codex` in the built-in terminal — leash walks the process tree to the IDE window and focuses it | ✅ auto |
| **aider, gemini-cli, any command** | Wrap it: `leash watch -- <cmd>` | ✅ universal |

```bash
leash watch -- aider --model gpt-4o
leash watch -- gemini
leash watch -- python long_train.py
```

> Cursor/VS Code's *own* built-in agent has no public "finished" hook, so leash can't follow it directly — but anything you run in their terminal works, and `leash watch` covers the rest.

## Install

### One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/everyai-com/leash/main/install.sh | bash
```

That's it. The script downloads the latest release, installs to `/Applications`, and launches. Then in the window that opens (or the 🔔 menu-bar icon): **Connect my AI tools** → **Launch at login**.

Future updates install themselves silently — you never run this script again.

### Manual download

If you'd rather not pipe a script:

1. Grab the latest `leash-*-macos.zip` from [Releases](https://github.com/everyai-com/leash/releases).
2. Unzip → drag `leash.app` to `/Applications`.
3. One-time unblock:
   ```bash
   xattr -d com.apple.quarantine /Applications/leash.app
   ```
4. Double-click `leash.app` to launch.

### Build from source

```bash
git clone https://github.com/everyai-com/leash
cd leash
./scripts/build-app.sh
open .build/app/leash.app
```

## Permissions you'll be asked for

- **Apple Events / Automation** — to focus the terminal that ran Claude.
- **Accessibility** (optional) — for stronger focus-stealing on Sonoma+.

If the overlay shows but doesn't pull you to the terminal, you skipped one of these — grant it in **System Settings → Privacy & Security**.

## How it works

- A local HTTP listener on `127.0.0.1:7869`.
- Hook entries that `curl` it: Claude Code's `Stop`/`Notification`/`UserPromptSubmit` in `~/.claude/settings.json`, and Codex's `notify` (via a tiny helper script in `~/.leash/`).
- Each request carries `$PPID`, so leash walks up the process tree to find which app hosted the agent — terminal, Claude desktop app, Cursor, VS Code — and focuses exactly that one.
- A small state machine (`idle → waiting → engaged`) means it only returns you when it actually pulled you in, and de-duplicates repeated finish events so subagents and parallel sessions don't spam the overlay.
- Skips the seize entirely when you're already looking at the agent.

## Trust

- **No accounts. No telemetry. No network egress.** The only network code in the whole app binds a listener to `127.0.0.1:7869` and POSTs to `127.0.0.1`. Grep the source.
- **No third-party dependencies.** Pure Swift + AppKit. The entire SBOM is "macOS".
- **Open source under MIT.** See [`SECURITY.md`](SECURITY.md) for the threat model and how to report issues.
- Releases are signed with **SAPHAARE LABS PRIVATE LIMITED**'s Developer ID and (soon) notarized by Apple.

## Design principles

- **Forced context switch, not notification.** Notifications fail the trust-to-disengage test — you still glance at the terminal "just in case." A full-screen takeover means you can truly look away.
- **Local-only, zero-config, zero-account.** It should work the second you install it, and never phone home.
- **Opinionated defaults, escape hatches in the window.** It does the right thing out of the box; tune it only if you want to.

## Roadmap

- Snooze / "remind me in 5 min" key
- Per-tool intensity (louder for Claude Code, quieter for a quick script)
- Phone push as an optional plugin
- Homebrew cask + Apple notarization
- Linux / Windows ports

## Contributing

Issues and PRs welcome. The whole app is a few hundred lines of dependency-free Swift — readable in one sitting. Start at [`Sources/leash/Coordinator.swift`](Sources/leash/Coordinator.swift) (the state machine) and [`Sources/leash/AppDelegate.swift`](Sources/leash/AppDelegate.swift). See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT. See [`LICENSE`](LICENSE).
