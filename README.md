# leash

**Yanks you back the moment Claude finishes — or asks a question.**

Long-running AI agents broke the human attention loop. You can't focus on anything else while waiting, because you don't know when they'll need you — so you babysit a terminal instead of getting your time back.

`leash` is a tiny macOS menu-bar app that:

1. Hooks Claude Code's `Stop` and `Notification` events.
2. Slams a full-screen overlay across every display, plays an alert, pauses media.
3. Press `⏎` to engage → overlay vanishes, the originating terminal/app jumps to the front, your cursor is in the prompt. (Or `Esc` to dismiss and stay where you are.)
4. Type your next instruction. The moment you submit, leash re-focuses whatever you were doing before.

It tracks a small state machine (`idle → waiting → engaged`) so it only pulls you back when it actually seized you — submitting a prompt while working normally never yanks you anywhere. Repeated finish events while the overlay is already up are de-duplicated, and everything is tunable from the control window (sound, auto-return, alert-on-permission-prompts, media pause).

Go full brain-rot mode. The leash pulls you back.

## Works with

- **Claude Code** — first-class. One click installs `Stop` / `Notification` / `UserPromptSubmit` hooks.
- **Codex, aider, gemini-cli, any CLI** — via the universal wrapper:
  ```bash
  leash watch -- codex
  leash watch -- aider --model gpt-4o
  leash watch -- python long_train.py
  ```
  When the wrapped command exits, leash fires the same overlay.
- **Cursor / native IDE agents** — not yet (no public hook API). Use `leash watch` around any terminal commands they spawn.

## Install

### One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/everyai-com/leash/main/install.sh | bash
```

That's it. The script downloads the latest release, installs to `/Applications`, and launches. Then click the 🐕 in your menu bar → **Install Claude Code hooks** → **Launch at login**.

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
- Three hook entries in `~/.claude/settings.json` (`Stop`, `Notification`, `UserPromptSubmit`) that `curl` it.
- Each request carries `$PPID` so leash walks up the process tree to find which terminal hosted Claude — and focuses exactly that one.
- Skips the seize when you're already looking at Claude (no double-yanks mid-conversation).

## Trust

- **No accounts. No telemetry. No network egress.** The only network code in the whole app binds a listener to `127.0.0.1:7869` and POSTs to `127.0.0.1`. Grep the source.
- **No third-party dependencies.** Pure Swift + AppKit. The entire SBOM is "macOS".
- **Open source under MIT.** See [`SECURITY.md`](SECURITY.md) for the threat model and how to report issues.
- Releases are signed with **SAPHAARE LABS PRIVATE LIMITED**'s Developer ID and (soon) notarized by Apple.

## Design principles

- **Forced context switch, not notification.** Notifications fail the trust-to-disengage test.
- **One opinionated escalation.** Settings come after we know the default works.
- **Mac + Claude Code first.** Other tools/platforms are v2 plugins once the core proves itself.

## Roadmap

- Codex / Cursor / Aider hooks
- Snooze key, per-source intensity
- Phone push as a plugin
- Linux/Windows ports
- Custom icon + Homebrew cask

## Contributing

Issues and PRs welcome. The whole app is <500 lines of Swift — easy to read in one sitting. Start at [`Sources/leash/AppDelegate.swift`](Sources/leash/AppDelegate.swift).

## License

MIT. See [`LICENSE`](LICENSE).
