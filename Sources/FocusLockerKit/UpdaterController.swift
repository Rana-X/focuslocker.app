import AppKit

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class UpdaterController: NSObject {
    #if canImport(Sparkle)
    private let standardUpdaterController: SPUStandardUpdaterController
    #endif

    override init() {
        #if canImport(Sparkle)
        standardUpdaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
        super.init()
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        standardUpdaterController.checkForUpdates(nil)
        #else
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Updates Are Available In Release Builds"
        alert.informativeText = "Sparkle is wired up for the Xcode release configuration. The local SwiftPM build does not embed the updater framework."
        alert.runModal()
        FocusLockerLog.updater.info("Update check requested in local SwiftPM build")
        #endif
    }
}
