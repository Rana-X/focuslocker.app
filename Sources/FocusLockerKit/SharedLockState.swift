import Foundation

struct SharedLockState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var isLockingEnabled: Bool
    var lockedBundleIDs: [String]
    var updatedAt: Date

    init(
        schemaVersion: Int = SharedLockState.currentSchemaVersion,
        isLockingEnabled: Bool = true,
        lockedBundleIDs: [String],
        updatedAt: Date = Date()
    ) {
        let normalizedBundleIDs = Array(Set(lockedBundleIDs)).sorted()

        self.schemaVersion = schemaVersion
        self.isLockingEnabled = isLockingEnabled && !normalizedBundleIDs.isEmpty
        self.lockedBundleIDs = normalizedBundleIDs
        self.updatedAt = updatedAt
    }

    var activeLockedBundleIDs: Set<String> {
        guard isLockingEnabled else { return [] }
        return Set(lockedBundleIDs)
    }

    var normalized: SharedLockState {
        SharedLockState(
            schemaVersion: schemaVersion,
            isLockingEnabled: isLockingEnabled,
            lockedBundleIDs: lockedBundleIDs,
            updatedAt: updatedAt
        )
    }
}

private struct LegacySessionLockState: Codable {
    let lockedBundleIDs: [String]
    let updatedAt: Date
}

extension SharedLockState {
    static func decode(from data: Data) throws -> SharedLockState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let state = try? decoder.decode(SharedLockState.self, from: data) {
            return state.normalized
        }

        let legacyState = try decoder.decode(LegacySessionLockState.self, from: data)
        return SharedLockState(
            lockedBundleIDs: legacyState.lockedBundleIDs,
            updatedAt: legacyState.updatedAt
        )
    }
}
