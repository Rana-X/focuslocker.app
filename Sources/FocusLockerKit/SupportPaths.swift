import Foundation

enum SupportPaths {
    static let mainAppBundleIdentifier = "com.focuslocker.app"
    static let agentBundleIdentifier = "com.focuslocker.agent"

    static var supportDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FocusLocker", isDirectory: true)
    }

    static var lockStateURL: URL {
        supportDirectoryURL.appendingPathComponent("lock-state.json", isDirectory: false)
    }

    static var corruptedStateDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("CorruptedState", isDirectory: true)
    }

    static var agentEndpointURL: URL {
        supportDirectoryURL.appendingPathComponent("agent.endpoint", isDirectory: false)
    }

    static func ensureSupportDirectories(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: supportDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corruptedStateDirectoryURL, withIntermediateDirectories: true)
    }

    static func embeddedAgentBundleURL(in mainAppBundleURL: URL) -> URL {
        mainAppBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LoginItems", isDirectory: true)
            .appendingPathComponent("FocusLockerAgent.app", isDirectory: true)
    }
}
