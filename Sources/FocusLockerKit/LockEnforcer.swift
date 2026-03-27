import AppKit
import Foundation

@MainActor
final class LockEnforcer: NSObject {
    private let model: AppModel

    private var isObserving = false
    private var recentEnforcements: [String: Date] = [:]

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func start() {
        guard !isObserving else { return }

        let notificationCenter = NSWorkspace.shared.notificationCenter
        let notifications: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        for notificationName in notifications {
            notificationCenter.addObserver(
                self,
                selector: #selector(handleWorkspaceNotification(_:)),
                name: notificationName,
                object: nil
            )
        }

        isObserving = true
        checkRunningApplications()
    }

    func stop() {
        guard isObserving else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isObserving = false
    }

    func checkRunningApplications() {
        for runningApplication in NSWorkspace.shared.runningApplications {
            enforceIfNeeded(for: runningApplication)
        }
    }

    @objc
    private func handleWorkspaceNotification(_ notification: Notification) {
        guard let runningApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        enforceIfNeeded(for: runningApplication)
    }

    private func enforceIfNeeded(for runningApplication: NSRunningApplication) {
        guard let bundleID = runningApplication.bundleIdentifier else { return }
        guard runningApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        guard model.isLocked(bundleID: bundleID) else { return }
        guard shouldEnforce(bundleID: bundleID) else { return }

        let didTerminate = runningApplication.terminate()
        if !didTerminate {
            _ = runningApplication.forceTerminate()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !runningApplication.isTerminated {
                    _ = runningApplication.forceTerminate()
                }
            }
        }

    }

    private func shouldEnforce(bundleID: String) -> Bool {
        let now = Date()
        if let previousDate = recentEnforcements[bundleID],
           now.timeIntervalSince(previousDate) < 1.0 {
            return false
        }

        recentEnforcements[bundleID] = now
        return true
    }

}
