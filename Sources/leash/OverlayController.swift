import AppKit
import AudioToolbox
import QuartzCore

final class OverlayController {
    /// Called when the user accepts (⏎ / click). Carries the hook PID so the
    /// coordinator can activate the right terminal/app.
    var onEngage: ((Int32?) -> Void)?
    /// Called when the user snoozes (Esc).
    var onSnooze: (() -> Void)?

    private var windows: [NSWindow] = []
    private var soundTimer: Timer?
    private var pendingPID: Int32?
    private var eventMonitor: Any?
    private var resolved = false
    private var rings = 0
    /// Stop ringing after ~90s so a forgotten overlay doesn't ring forever.
    private let maxRings = 12

    func seize(event: HookEvent) {
        release()
        pendingPID = event.ppid
        resolved = false
        rings = 0

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
            window.backgroundColor = .clear
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            // Force dark appearance so the frosted card + white text stay
            // high-contrast even when the user is in Light Mode.
            window.appearance = NSAppearance(named: .darkAqua)

            let view = OverlayView(
                message: event.message,
                cwd: event.cwd,
                onEngage: { [weak self] in self?.fireEngage() },
                onSnooze: { [weak self] in self?.fireSnooze() }
            )
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            view.animateIn()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        if Settings.soundEnabled {
            playSound()
            soundTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
                self?.playSound()
            }
        }
        if Settings.pauseMedia { sendMediaKey() }

        // Catch ⏎/Esc/click anywhere across all overlay windows (no matter
        // which display has the key window).
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 36 || event.keyCode == 76 {      // return / numpad enter
                    self.fireEngage(); return nil
                } else if event.keyCode == 53 {                       // escape
                    self.fireSnooze(); return nil
                }
            } else if event.type == .leftMouseDown {
                self.fireEngage(); return nil
            }
            return event
        }
    }

    func release() {
        soundTimer?.invalidate()
        soundTimer = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
    }

    private func fireEngage() {
        guard !resolved else { return }
        resolved = true
        let pid = pendingPID
        pendingPID = nil
        release()
        onEngage?(pid)
    }

    private func fireSnooze() {
        guard !resolved else { return }
        resolved = true
        pendingPID = nil
        release()
        onSnooze?()
    }

    private func playSound() {
        guard rings < maxRings else {
            soundTimer?.invalidate()
            soundTimer = nil
            return
        }
        rings += 1
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_UserPreferredAlert))
    }

    private func sendMediaKey() {
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

// MARK: - View

private final class OverlayView: NSView {
    private let onEngage: () -> Void
    private let onSnooze: () -> Void
    private let card = NSView()
    private let accent = NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.24, alpha: 1.0)

    init(message: String?, cwd: String?, onEngage: @escaping () -> Void, onSnooze: @escaping () -> Void) {
        self.onEngage = onEngage
        self.onSnooze = onSnooze
        super.init(frame: .zero)
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor

        // Subtle radial vignette for focus
        let vignette = CAGradientLayer()
        vignette.type = .radial
        vignette.colors = [
            NSColor.black.withAlphaComponent(0.35).cgColor,
            NSColor.black.withAlphaComponent(0.82).cgColor
        ]
        vignette.startPoint = CGPoint(x: 0.5, y: 0.5)
        vignette.endPoint = CGPoint(x: 1, y: 1)
        vignette.frame = bounds
        vignette.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(vignette)

        buildCard(message: message, cwd: cwd)
    }

    required init?(coder: NSCoder) { nil }

    private func buildCard(message: String?, cwd: String?) {
        // Vibrant frosted-glass background
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.state = .active
        blur.blendingMode = .behindWindow
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 28
        blur.layer?.cornerCurve = .continuous
        blur.layer?.masksToBounds = true
        blur.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        blur.layer?.borderWidth = 1
        blur.translatesAutoresizingMaskIntoConstraints = false

        card.wantsLayer = true
        card.layer?.cornerRadius = 28
        card.layer?.cornerCurve = .continuous
        card.layer?.shadowColor = accent.cgColor
        card.layer?.shadowOpacity = 0.35
        card.layer?.shadowRadius = 60
        card.layer?.shadowOffset = .zero
        card.translatesAutoresizingMaskIntoConstraints = false

        addSubview(card)
        card.addSubview(blur)

        // Dark tint over the blur so white text is always high-contrast,
        // independent of what's behind the overlay or the system appearance.
        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(white: 0.04, alpha: 0.55).cgColor
        tint.layer?.cornerRadius = 28
        tint.layer?.cornerCurve = .continuous
        tint.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(tint)

        // Accent badge (red dot, breathing)
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = accent.cgColor
        badge.layer?.cornerRadius = 8
        badge.layer?.shadowColor = accent.cgColor
        badge.layer?.shadowOpacity = 0.9
        badge.layer?.shadowRadius = 18
        badge.layer?.shadowOffset = .zero
        badge.translatesAutoresizingMaskIntoConstraints = false
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.35
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        badge.layer?.add(pulse, forKey: "pulse")

        let kicker = NSTextField(labelWithString: "CLAUDE IS WAITING")
        kicker.font = .systemFont(ofSize: 13, weight: .bold)
        kicker.textColor = NSColor.white.withAlphaComponent(0.92)
        kicker.alignment = .left
        kicker.setContentHuggingPriority(.required, for: .vertical)

        let kickerRow = NSStackView(views: [badge, kicker])
        kickerRow.orientation = .horizontal
        kickerRow.spacing = 10
        kickerRow.alignment = .centerY

        // Headline
        let title = NSTextField(labelWithString: "Your turn.")
        title.font = NSFont.systemFont(ofSize: 72, weight: .bold)
        title.textColor = .white
        title.alignment = .left

        // Subtitle (the cwd / repo it's waiting in)
        let where_ = projectName(from: cwd) ?? "an open session"
        let subtitle = NSTextField(labelWithString: "in \(where_)")
        subtitle.font = .systemFont(ofSize: 20, weight: .medium)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.85)
        subtitle.alignment = .left

        // Optional message from the hook (e.g. permission prompt text)
        var extras: [NSView] = []
        if let m = message?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            let msg = NSTextField(labelWithString: "“\(m)”")
            msg.font = .systemFont(ofSize: 17, weight: .regular)
            msg.textColor = NSColor.white.withAlphaComponent(0.95)
            msg.alignment = .left
            msg.maximumNumberOfLines = 3
            msg.lineBreakMode = .byTruncatingTail
            extras.append(msg)
        }

        // Call-to-action chip
        let chip = ChipView(title: "Press ⏎ to engage   ·   Esc to dismiss")
        chip.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [kickerRow, title, subtitle] + extras)
        textStack.orientation = .vertical
        textStack.spacing = 8
        textStack.alignment = .leading
        textStack.setCustomSpacing(18, after: kickerRow)
        textStack.setCustomSpacing(2, after: title)

        let stack = NSStackView(views: [textStack, chip])
        stack.orientation = .vertical
        stack.spacing = 38
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 16),
            badge.heightAnchor.constraint(equalToConstant: 16),

            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 820),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 560),

            blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            blur.topAnchor.constraint(equalTo: card.topAnchor),
            blur.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            tint.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tint.topAnchor.constraint(equalTo: card.topAnchor),
            tint.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 56),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -56),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 56),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -56),
        ])
    }

    func animateIn() {
        guard let layer = card.layer else { return }
        layer.opacity = 0
        layer.transform = CATransform3DMakeScale(0.94, 0.94, 1)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.28)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer.opacity = 1
        layer.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    private func projectName(from cwd: String?) -> String? {
        guard let cwd, !cwd.isEmpty else { return nil }
        let trimmed = cwd.hasSuffix("/") ? String(cwd.dropLast()) : cwd
        let name = (trimmed as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // return / numpad
            onEngage()
        } else if event.keyCode == 53 { // escape
            onSnooze()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onEngage()
    }
}

// MARK: - Chip

private final class ChipView: NSView {
    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        layer?.borderWidth = 1

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { nil }
}
