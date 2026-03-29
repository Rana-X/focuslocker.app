import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var catalog: [AppCatalogEntry] = []
    @Published private(set) var lockedBundleIDs: Set<String>
    @Published private(set) var backgroundAgentStatus: BackgroundAgentStatus = .inactive
    @Published var searchText = ""

    private let lockStore: LockStore
    private let appScanner: AppScanner
    private let unsupportedBundleIDs: Set<String>
    private var distributedObservers: [NSObjectProtocol] = []

    var retryBackgroundHelper: (() -> Void)?

    init(
        lockStore: LockStore = LockStore(),
        appScanner: AppScanner = AppScanner(),
        unsupportedBundleIDs: Set<String> = AppModel.defaultUnsupportedBundleIDs
    ) {
        self.lockStore = lockStore
        self.appScanner = appScanner
        self.unsupportedBundleIDs = unsupportedBundleIDs
        self.lockedBundleIDs = lockStore.loadLockedBundleIDs().subtracting(unsupportedBundleIDs)
        if self.lockedBundleIDs.isEmpty {
            lockStore.clear()
        } else {
            lockStore.saveLockedBundleIDs(self.lockedBundleIDs)
        }
    }

    var displayedApps: [AppCatalogEntry] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredApps = catalog.filter { entry in
            guard !trimmedQuery.isEmpty else { return true }
            return entry.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                || entry.bundleID.localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filteredApps.sorted { lhs, rhs in
            let lhsLocked = isLocked(bundleID: lhs.bundleID)
            let rhsLocked = isLocked(bundleID: rhs.bundleID)
            if lhsLocked != rhsLocked {
                return lhsLocked && !rhsLocked
            }

            let lhsLockable = isLockable(lhs)
            let rhsLockable = isLockable(rhs)
            if lhsLockable != rhsLockable {
                return lhsLockable && !rhsLockable
            }

            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var hasActiveLocks: Bool {
        !lockedBundleIDs.isEmpty
    }

    func refreshCatalog() {
        catalog = appScanner.scanApplications()
    }

    func startMonitoringLockState() {
        guard distributedObservers.isEmpty else { return }

        let center = DistributedNotificationCenter.default()

        let names = [
            FocusLockerNotifications.lockStateDidChange,
            FocusLockerNotifications.helperStatusDidChange
        ]

        distributedObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reloadLockStateFromStore()
                }
            }
        }
    }

    func stopMonitoringLockState() {
        let center = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            center.removeObserver(observer)
        }
        distributedObservers.removeAll()
    }

    func reloadLockStateFromStore() {
        let externalLockedBundleIDs = lockStore.loadLockedBundleIDs().subtracting(unsupportedBundleIDs)
        guard externalLockedBundleIDs != lockedBundleIDs else { return }
        lockedBundleIDs = externalLockedBundleIDs
    }

    func updateBackgroundAgentStatus(_ status: BackgroundAgentStatus) {
        guard backgroundAgentStatus != status else { return }
        backgroundAgentStatus = status
    }

    func isLocked(bundleID: String) -> Bool {
        lockedBundleIDs.contains(bundleID)
    }

    func isLockable(_ app: AppCatalogEntry) -> Bool {
        !unsupportedBundleIDs.contains(app.bundleID)
    }

    func toggleLock(for app: AppCatalogEntry) {
        guard isLockable(app) else { return }

        if isLocked(bundleID: app.bundleID) {
            unlock(bundleID: app.bundleID)
        } else {
            lock(bundleID: app.bundleID)
        }
    }

    func lock(bundleID: String) {
        guard !unsupportedBundleIDs.contains(bundleID) else { return }
        guard !lockedBundleIDs.contains(bundleID) else { return }

        lockedBundleIDs.insert(bundleID)
        persistLocks()
    }

    func unlock(bundleID: String) {
        guard lockedBundleIDs.contains(bundleID) else { return }

        lockedBundleIDs.remove(bundleID)
        persistLocks()
    }

    func disableAllLocks() {
        lockedBundleIDs.removeAll()
        persistLocks()
    }

    func setLockedBundleIDs(_ bundleIDs: Set<String>) {
        let sanitizedBundleIDs = bundleIDs.subtracting(unsupportedBundleIDs)
        guard sanitizedBundleIDs != lockedBundleIDs else { return }
        lockedBundleIDs = sanitizedBundleIDs
        persistLocks()
    }

    func displayName(for bundleID: String) -> String {
        appEntry(for: bundleID)?.displayName ?? bundleID
    }

    func appEntry(for bundleID: String) -> AppCatalogEntry? {
        catalog.first { $0.bundleID == bundleID }
    }

    func currentSharedState() -> SharedLockState? {
        guard !lockedBundleIDs.isEmpty else { return nil }
        return SharedLockState(lockedBundleIDs: Array(lockedBundleIDs))
    }

    private func persistLocks() {
        if lockedBundleIDs.isEmpty {
            lockStore.clear()
        } else {
            lockStore.saveLockedBundleIDs(lockedBundleIDs)
        }
        FocusLockerBroadcaster.postLockStateDidChange()
    }

    private static let defaultUnsupportedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.notificationcenterui"
    ]
}
