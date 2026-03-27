import Foundation

final class LockStore {
    static let lockedBundleIDsKey = "FocusLocker.lockedBundleIDs"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadLockedBundleIDs() -> Set<String> {
        let storedIDs = userDefaults.stringArray(forKey: Self.lockedBundleIDsKey) ?? []
        return Set(storedIDs)
    }

    func saveLockedBundleIDs(_ bundleIDs: Set<String>) {
        userDefaults.set(Array(bundleIDs).sorted(), forKey: Self.lockedBundleIDsKey)
    }
}
