import Foundation

final class LockStore {
    static let legacyLockedBundleIDsKey = "FocusLocker.lockedBundleIDs"

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let lockStateURL: URL

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        lockStateURL: URL = SupportPaths.lockStateURL
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.lockStateURL = lockStateURL
    }

    func loadState() -> SharedLockState? {
        guard fileManager.fileExists(atPath: lockStateURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: lockStateURL)
            let state = try SharedLockState.decode(from: data)
            guard state.schemaVersion <= SharedLockState.currentSchemaVersion else {
                FocusLockerLog.store.error("Unsupported lock state schema: \(state.schemaVersion, privacy: .public)")
                return nil
            }
            return state
        } catch {
            FocusLockerLog.store.error("Failed to read lock state: \(error.localizedDescription, privacy: .public)")
            quarantineCorruptedStateFile()
            return nil
        }
    }

    func loadLockedBundleIDs() -> Set<String> {
        loadState()?.activeLockedBundleIDs ?? []
    }

    @discardableResult
    func saveLockedBundleIDs(_ bundleIDs: Set<String>) -> SharedLockState? {
        let state = SharedLockState(lockedBundleIDs: Array(bundleIDs))
        save(state)
        return state
    }

    func clear() {
        try? fileManager.removeItem(at: lockStateURL)
    }

    func migrateLegacyDefaultsIfNeeded() {
        guard loadState() == nil else { return }

        let legacyBundleIDs = userDefaults.stringArray(forKey: Self.legacyLockedBundleIDsKey) ?? []
        guard !legacyBundleIDs.isEmpty else { return }

        saveLockedBundleIDs(Set(legacyBundleIDs))
        userDefaults.removeObject(forKey: Self.legacyLockedBundleIDsKey)
    }

    private func save(_ state: SharedLockState) {
        do {
            try fileManager.createDirectory(
                at: lockStateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state.normalized)
            try data.write(to: lockStateURL, options: .atomic)
            FocusLockerLog.store.debug("Saved lock state with \(state.lockedBundleIDs.count, privacy: .public) locked apps")
        } catch {
            FocusLockerLog.store.error("Failed to save lock state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func quarantineCorruptedStateFile() {
        guard fileManager.fileExists(atPath: lockStateURL.path) else { return }

        do {
            try SupportPaths.ensureSupportDirectories(fileManager: fileManager)
            let formatter = ISO8601DateFormatter()
            let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let corruptedURL = SupportPaths.corruptedStateDirectoryURL
                .appendingPathComponent("lock-state-\(timestamp).json", isDirectory: false)
            try? fileManager.removeItem(at: corruptedURL)
            try fileManager.moveItem(at: lockStateURL, to: corruptedURL)
            FocusLockerLog.store.error("Moved corrupted lock state to \(corruptedURL.path, privacy: .public)")
        } catch {
            FocusLockerLog.store.error("Failed to quarantine corrupted lock state: \(error.localizedDescription, privacy: .public)")
            try? fileManager.removeItem(at: lockStateURL)
        }
    }
}
