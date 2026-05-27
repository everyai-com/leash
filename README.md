# leash

**Yanks you back the moment Claude finishes.**

Long-running AI agents broke the human attention loop: you can't focus on anything else while waiting, because you don't know when they'll need you — so you babysit a terminal instead of getting your time back.

`leash` is a tiny Mac menu-bar app that:

1. Listens for Claude Code's `Stop` hook (fires when Claude finishes a turn).
2. Slams a full-screen overlay across every display, plays an alert, and pauses media.
3. Press `⏎` → overlay vanishes, the originating terminal jumps to the front, your cursor is in the prompt.
4. Type your next instruction. The moment you submit, Claude's `UserPromptSubmit` hook fires → `leash` re-focuses whatever you were doing before (YouTube, whatever).

You get to go full brain-rot mode. The leash pulls you back.

## Status

Pre-alpha. Built in a weekend. MIT.

## Install (from source, for now)

```bash
git clone <repo>
cd leash
swift build -c release
cp .build/release/leash /usr/local/bin/leash
leash install      # writes hooks into ~/.claude/settings.json
leash &            # launches menu-bar app
```

Grant Accessibility permission when prompted (needed to focus other apps).

## Uninstall

```bash
leash uninstall
```

## How it works

- A local HTTP listener on `127.0.0.1:7869`.
- Two hook entries in `~/.claude/settings.json` that `curl` it.
- Each request carries `$PPID` so the app can walk up the process tree to find which terminal hosted Claude — and focus exactly that one.

No accounts. No telemetry. No network egress. All local.

## Design principles

- **Forced context switch, not notification.** Notifications fail the trust-to-disengage test.
- **One opinionated escalation.** No settings in v1 — settings come after we know the default works.
- **Mac + Claude Code only.** Other tools/platforms are v2 plugins once the core proves itself.

## Roadmap (only after v1 ships and is loved)

- Codex / Cursor / Aider hooks
- Snooze keys, per-source intensity
- Phone push as a plugin
- Linux/Windows ports

## License

MIT. See `LICENSE`.
