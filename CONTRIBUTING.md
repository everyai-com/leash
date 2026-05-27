# Contributing to leash

Thanks for being here. leash is intentionally tiny — the whole app is well under 1k lines of Swift — so it's easy to land a PR.

## Quick start

```bash
git clone https://github.com/everyai-com/leash
cd leash
swift build           # compiles the binary
swift run leash       # launches the menu-bar app from sources
./scripts/build-app.sh  # produces .build/app/leash.app
```

## Code map

| File | What it does |
|---|---|
| `Sources/leash/main.swift` | CLI entry + subcommand routing |
| `Sources/leash/AppDelegate.swift` | Wires server → overlay → focus |
| `Sources/leash/HookServer.swift` | Local HTTP listener (`/stop`, `/submit`) |
| `Sources/leash/OverlayController.swift` | The full-screen takeover UI |
| `Sources/leash/FocusManager.swift` | App-switching + PPID walk |
| `Sources/leash/Installer.swift` | Edits `~/.claude/settings.json` |
| `Sources/leash/Watcher.swift` | `leash watch -- <cmd>` wrapper |
| `Sources/leash/MenuBarController.swift` | 🐕 menu in the status bar |
| `Sources/leash/LoginItem.swift` | Launch-at-login toggle |
| `scripts/build-app.sh` | Bundles + signs the .app |
| `scripts/make-icon.swift` | Generates AppIcon.icns |

## Pull request checklist

- [ ] `swift build -c release` passes locally.
- [ ] No new dependencies (we have zero — let's keep it that way unless there's a strong reason).
- [ ] No telemetry, no network egress to anywhere except `127.0.0.1`.
- [ ] If you changed UX, add a short before/after note in the PR description.
- [ ] If you changed the hook protocol, update `README.md` and `SECURITY.md`.

## Adding support for a new AI tool

You have two paths:

1. **The tool has hooks** (like Claude Code): add to `Installer.swift` so users get one-click setup.
2. **The tool doesn't have hooks**: nothing to add — `leash watch -- <tool>` already works. Just add an example to the README.

## Releases

Maintainers tag `vX.Y.Z` → GitHub Actions builds the universal `.app` and attaches it. See `.github/workflows/release.yml`.

## Conduct

Be kind. Be patient. No drama.
