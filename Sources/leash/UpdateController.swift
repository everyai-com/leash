import AppKit
import Sparkle

/// Thin wrapper around Sparkle so the menu bar / AppDelegate don't need to
/// import Sparkle directly.
final class UpdateController: NSObject {
    let updater: SPUStandardUpdaterController

    override init() {
        updater = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updater.checkForUpdates(sender)
    }
}
