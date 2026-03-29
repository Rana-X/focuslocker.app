import Foundation

enum LegacyGuardianCleanup {
    private static let label = "com.focuslocker.guardian"

    static func clearIfPresent(fileManager: FileManager = .default) {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let sentinelURL = homeDirectory
            .appendingPathComponent("Library/Application Support/FocusLocker", isDirectory: true)
            .appendingPathComponent("locks-active.sentinel", isDirectory: false)
        let launchAgentURL = homeDirectory
            .appendingPathComponent("Library/LaunchAgents/\(label).plist", isDirectory: false)

        let runningUnderGuardian = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] == label
        if !runningUnderGuardian {
            _ = runLaunchctl(arguments: ["bootout", "gui/\(getuid())/\(label)"])
            _ = runLaunchctl(arguments: ["bootout", "gui/\(getuid())", launchAgentURL.path])
        }

        try? fileManager.removeItem(at: sentinelURL)
        try? fileManager.removeItem(at: launchAgentURL)
    }

    @discardableResult
    private static func runLaunchctl(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
