import AppKit
import AudioToolbox

final class OverlayController {
    private var windows: [NSWindow] = []
    private var soundTimer: Timer?
    private let focus: FocusManager
    private var pendingPID: Int32?

    init(focus: FocusManager) {
        self.focus = focus
    }

    func seize(event: HookEvent) {
        release()
        pendingPID = event.ppid

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.85)
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = OverlayView(message: event.message ?? "Claude is waiting") { [weak self] in
                self?.engage()
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        playSound()
        soundTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            self?.playSound()
        }

        // Try to pause whatever is playing (YouTube, Spotify, etc.) by sending
        // the media-play/pause key.
        sendMediaKey()
    }

    func release() {
        soundTimer?.invalidate()
        soundTimer = nil
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
    }

    private func engage() {
        let pid = pendingPID
        pendingPID = nil
        release()
        // Give up active status so the target app can come forward cleanly.
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [focus] in
            focus.activateTerminal(forPID: pid)
        }
    }

    private func playSound() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_UserPreferredAlert))
    }

    private func sendMediaKey() {
        // NX_KEYTYPE_PLAY = 16
        func post(_ down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? [.init(rawValue: 0xa00)] : [.init(rawValue: 0xb00)]
            let data1 = (16 << 16) | ((down ? 0xA : 0xB) << 8)
            if let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                event.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        post(true); post(false)
    }
}

private final class OverlayView: NSView {
    private let onEngage: () -> Void

    init(message: String, onEngage: @escaping () -> Void) {
        self.onEngage = onEngage
        super.init(frame: .zero)
        wantsLayer = true

        let title = NSTextField(labelWithString: "Claude is waiting")
        title.font = .systemFont(ofSize: 64, weight: .bold)
        title.textColor = .white
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: message)
        subtitle.font = .systemFont(ofSize: 22, weight: .regular)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.8)
        subtitle.alignment = .center

        let hint = NSTextField(labelWithString: "Press ⏎ to engage")
        hint.font = .systemFont(ofSize: 18, weight: .medium)
        hint.textColor = NSColor.systemRed
        hint.alignment = .center

        let stack = NSStackView(views: [title, subtitle, hint])
        stack.orientation = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // return / numpad return
            onEngage()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onEngage()
    }
}
