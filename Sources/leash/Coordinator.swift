import AppKit

/// Owns the seize → engage → submit loop as an explicit state machine so the
/// overlay, focus, and menu-bar state never drift out of sync.
///
/// States:
///   .idle     nothing happening
///   .waiting  overlay is up, awaiting the user
///   .engaged  user pressed ⏎; we sent them to Claude and are waiting for the
///             prompt-submit that means "I'm done, send me back"
final class Coordinator {
    enum State { case idle, waiting, engaged }

    private let focus: FocusManager
    private let overlay: OverlayController
    private let menuBar: MenuBarController

    private var state: State = .idle
    private var lastEngageAt: Date?
    /// After engaging, ignore re-seizes for this long so Claude's trailing
    /// output (which fires more Stop/Notification hooks) doesn't bounce the
    /// overlay right back at the user.
    private let reSeizeCooldown: TimeInterval = 2.5

    init(focus: FocusManager, overlay: OverlayController, menuBar: MenuBarController) {
        self.focus = focus
        self.overlay = overlay
        self.menuBar = menuBar

        overlay.onEngage = { [weak self] pid in self?.engage(pid) }
        overlay.onSnooze = { [weak self] in self?.snooze() }
    }

    /// Entry point for every hook event. Always hops to main.
    func handle(_ kind: HookKind, _ event: HookEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch kind {
            case .stop:
                self.seizeIfNeeded(event)
            case .notify:
                if Settings.seizeOnNotification { self.seizeIfNeeded(event) }
            case .submit:
                self.handleSubmit()
            }
        }
    }

    // MARK: - Transitions

    private func seizeIfNeeded(_ event: HookEvent) {
        switch state {
        case .waiting:
            // Already showing — dedupe. Don't rebuild windows or replay sound.
            NSLog("leash: dedupe seize (already waiting)")
            return
        case .engaged:
            if let t = lastEngageAt, Date().timeIntervalSince(t) < reSeizeCooldown {
                NSLog("leash: ignoring seize (engage cooldown)")
                return
            }
            if focus.isAlreadyEngaged(withHookPID: event.ppid) {
                NSLog("leash: ignoring seize (user already in Claude)")
                return
            }
        case .idle:
            if focus.isAlreadyEngaged(withHookPID: event.ppid) {
                NSLog("leash: not seizing — user already looking at Claude")
                return
            }
        }

        NSLog("leash: seizing (state was \(state))")
        focus.snapshotFrontmost()
        overlay.seize(event: event)
        menuBar.setWaiting(true)
        state = .waiting
    }

    private func engage(_ pid: Int32?) {
        focus.activateTerminal(forPID: pid)
        menuBar.setWaiting(false)
        state = .engaged
        lastEngageAt = Date()
    }

    private func snooze() {
        // User dismissed without going to Claude — send them back to whatever
        // they were doing, drop the state.
        focus.restorePrevious()
        menuBar.setWaiting(false)
        state = .idle
    }

    private func handleSubmit() {
        // THE fix: only act on submit when we actually have the user engaged
        // via leash. Otherwise a normal prompt-submit while working in Claude
        // would yank the user to a stale "previous app".
        guard state == .engaged else { return }
        if Settings.autoReturnOnSubmit {
            focus.restorePrevious()
        } else {
            focus.clearPrevious()
        }
        state = .idle
    }
}
