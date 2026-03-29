import Foundation

enum FocusLockerNotifications {
    static let lockStateDidChange = Notification.Name("com.focuslocker.lock-state-did-change")
    static let helperStatusDidChange = Notification.Name("com.focuslocker.helper-status-did-change")
    static let openManager = Notification.Name("com.focuslocker.open-manager")
}

enum FocusLockerBroadcaster {
    private static let center = DistributedNotificationCenter.default()

    static func postLockStateDidChange() {
        post(FocusLockerNotifications.lockStateDidChange)
    }

    static func postHelperStatusDidChange() {
        post(FocusLockerNotifications.helperStatusDidChange)
    }

    static func postOpenManager() {
        post(FocusLockerNotifications.openManager)
    }

    private static func post(_ name: Notification.Name) {
        center.postNotificationName(
            name,
            object: SupportPaths.mainAppBundleIdentifier,
            userInfo: nil,
            options: [.deliverImmediately]
        )
    }
}
