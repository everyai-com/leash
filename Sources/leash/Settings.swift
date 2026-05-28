import Foundation

/// User-tunable behavior, backed by UserDefaults. Keeps leash from feeling
/// too aggressive — every knob here has a sensible default but can be turned
/// off from the control window.
enum Settings {
    private static let d = UserDefaults.standard

    /// Register defaults once at launch so first reads return the intended
    /// value instead of `false`/`0`.
    static func registerDefaults() {
        d.register(defaults: [
            Key.sound: true,
            Key.autoReturn: true,
            Key.seizeOnNotification: true,
            Key.pauseMedia: true,
        ])
    }

    enum Key {
        static let sound = "soundEnabled"
        static let autoReturn = "autoReturnOnSubmit"
        static let seizeOnNotification = "seizeOnNotification"
        static let pauseMedia = "pauseMediaOnSeize"
    }

    /// Ring an alert sound while the overlay is up.
    static var soundEnabled: Bool {
        get { d.bool(forKey: Key.sound) }
        set { d.set(newValue, forKey: Key.sound) }
    }

    /// After you engage and submit your prompt, jump back to whatever you were
    /// doing before (the "free your mind" return).
    static var autoReturnOnSubmit: Bool {
        get { d.bool(forKey: Key.autoReturn) }
        set { d.set(newValue, forKey: Key.autoReturn) }
    }

    /// Also seize on Claude's Notification events (permission prompts, idle
    /// waits), not just when a turn fully finishes.
    static var seizeOnNotification: Bool {
        get { d.bool(forKey: Key.seizeOnNotification) }
        set { d.set(newValue, forKey: Key.seizeOnNotification) }
    }

    /// Send a play/pause media key when the overlay seizes (pauses YouTube etc.).
    static var pauseMedia: Bool {
        get { d.bool(forKey: Key.pauseMedia) }
        set { d.set(newValue, forKey: Key.pauseMedia) }
    }
}
