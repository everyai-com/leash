# Security Policy

## Reporting a vulnerability

Please **do not** open public issues for security problems. Email **everyai.com@gmail.com** with:

- A description of the issue
- Reproduction steps
- The affected version (output of `leash --help` or the release tag)

You'll get an acknowledgement within 72 hours. We'll work with you on a fix and credit you in the release notes unless you'd rather stay anonymous.

## Threat model

leash is intentionally small. The full attack surface:

- **Local HTTP listener** on `127.0.0.1:7869`. Bound to loopback only — never exposed to the network. Any local process running as your user can POST to it and trigger an overlay. The overlay has no destructive capability; the worst a malicious local process can do is be annoying.
- **Apple Events permission** to focus other apps. Used only to bring the originating terminal forward; no scripting of third-party apps.
- **Accessibility permission** (optional, not requested by default).
- **No network egress.** leash never makes outbound connections.
- **No telemetry, no accounts, no analytics.** Verifiable in the source — search for `URLSession` and `Network`; the only uses are the local listener and `URLRequest` for `127.0.0.1`.
- **No file writes** outside `~/.claude/settings.json` (only when you click "Install hooks") and `~/Library/Application Support/com.everyai.leash` (login-item state, managed by macOS).

If you want to harden further, run `leash uninstall` to remove the hooks and quit the app — leaves zero trace.

## Roadmap

- Optional shared-secret token in the hook URL to prevent other local processes from triggering the overlay.
- Signed + notarized release builds (in progress).
