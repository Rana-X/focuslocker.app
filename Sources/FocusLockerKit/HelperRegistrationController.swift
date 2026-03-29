import AppKit
import Foundation
import ServiceManagement

enum BackgroundAgentStatus: Equatable {
    case inactive
    case starting
    case running
    case requiresApproval
    case missing
    case failed(String)

    var title: String {
        switch self {
        case .inactive:
            return "Background locking is off"
        case .starting:
            return "Background locking is starting"
        case .running:
            return "Background locking is active"
        case .requiresApproval:
            return "Background helper needs approval"
        case .missing:
            return "Background helper is missing"
        case let .failed(message):
            return message
        }
    }

    var detail: String {
        switch self {
        case .inactive:
            return "Locks only stay active while Focus Locker itself is open."
        case .starting:
            return "Focus Locker is registering the background helper and launching it for this user session."
        case .running:
            return "Locked apps stay blocked after you close the main app and after you log back in."
        case .requiresApproval:
            return "Approve Focus Locker in System Settings > General > Login Items so macOS allows the background helper to stay active."
        case .missing:
            return "The bundled helper could not be found. Rebuild the app bundle before distributing it."
        case let .failed(message):
            return message
        }
    }

    var showsRecoveryAction: Bool {
        switch self {
        case .requiresApproval, .missing, .failed:
            return true
        case .inactive, .starting, .running:
            return false
        }
    }
}

@MainActor
final class HelperRegistrationController {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func syncRegistration(hasActiveLocks: Bool, mainAppBundleURL: URL, forceLaunch: Bool = false) -> BackgroundAgentStatus {
        guard #available(macOS 13.0, *) else {
            return .failed("macOS 13 or newer is required for the production helper registration path.")
        }

        let service = SMAppService.loginItem(identifier: SupportPaths.agentBundleIdentifier)

        if hasActiveLocks {
            do {
                if service.status == .notRegistered {
                    try service.register()
                    FocusLockerLog.registration.info("Registered login item helper")
                }
            } catch {
                FocusLockerLog.registration.error("Failed to register helper: \(error.localizedDescription, privacy: .public)")
                return .failed("macOS could not register the background helper. \(error.localizedDescription)")
            }

            launchHelperIfNeeded(mainAppBundleURL: mainAppBundleURL, forceLaunch: forceLaunch)
            let status = currentStatus(hasActiveLocks: hasActiveLocks)
            FocusLockerBroadcaster.postHelperStatusDidChange()
            return status
        }

        terminateRunningHelper()

        do {
            if service.status != .notRegistered {
                try service.unregister()
                FocusLockerLog.registration.info("Unregistered login item helper")
            }
        } catch {
            FocusLockerLog.registration.error("Failed to unregister helper: \(error.localizedDescription, privacy: .public)")
            let status = BackgroundAgentStatus.failed("The background helper could not be removed cleanly. \(error.localizedDescription)")
            FocusLockerBroadcaster.postHelperStatusDidChange()
            return status
        }

        try? fileManager.removeItem(at: SupportPaths.agentEndpointURL)
        FocusLockerBroadcaster.postHelperStatusDidChange()
        return .inactive
    }

    func currentStatus(hasActiveLocks: Bool) -> BackgroundAgentStatus {
        guard hasActiveLocks else { return .inactive }
        guard #available(macOS 13.0, *) else {
            return .failed("macOS 13 or newer is required for the production helper registration path.")
        }

        let service = SMAppService.loginItem(identifier: SupportPaths.agentBundleIdentifier)
        switch service.status {
        case .enabled:
            return isHelperRunning() ? .running : .starting
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .missing
        case .notRegistered:
            return .starting
        @unknown default:
            return .failed("macOS reported an unknown background helper state.")
        }
    }

    func terminateRunningHelper() {
        for application in NSRunningApplication.runningApplications(withBundleIdentifier: SupportPaths.agentBundleIdentifier) {
            if !application.terminate() {
                _ = application.forceTerminate()
            }
        }
    }

    func isHelperRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SupportPaths.agentBundleIdentifier).isEmpty
    }

    private func launchHelperIfNeeded(mainAppBundleURL: URL, forceLaunch: Bool) {
        guard forceLaunch || !isHelperRunning() else { return }

        let helperBundleURL = SupportPaths.embeddedAgentBundleURL(in: mainAppBundleURL)
        guard fileManager.fileExists(atPath: helperBundleURL.path) else {
            FocusLockerLog.registration.error("Missing helper bundle at \(helperBundleURL.path, privacy: .public)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        workspace.openApplication(at: helperBundleURL, configuration: configuration) { _, error in
            if let error {
                FocusLockerLog.registration.error("Failed to launch helper app: \(error.localizedDescription, privacy: .public)")
            } else {
                FocusLockerLog.registration.info("Launched helper app")
            }
            FocusLockerBroadcaster.postHelperStatusDidChange()
        }
    }
}
