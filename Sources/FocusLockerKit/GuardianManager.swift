import Foundation

@MainActor
final class GuardianManager {
    static let managedLaunchArgument = "--managed-launch"

    private enum DefaultsKey {
        static let pendingForegroundPresentation = "FocusLocker.pendingForegroundPresentation"
    }

    private let label = "com.focuslocker.guardian"
    private let fileManager: FileManager
    private let defaults: UserDefaults

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    var isManagedLaunch: Bool {
        CommandLine.arguments.contains(Self.managedLaunchArgument)
    }

    func shouldShowManagerOnLaunch() -> Bool {
        let shouldShow = defaults.bool(forKey: DefaultsKey.pendingForegroundPresentation)
        if shouldShow {
            defaults.removeObject(forKey: DefaultsKey.pendingForegroundPresentation)
        }
        return shouldShow
    }

    func activatePersistence(showManagerOnManagedLaunch: Bool) -> Bool {
        guard let executablePath = resolvedExecutablePath() else {
            return false
        }

        defaults.set(showManagerOnManagedLaunch, forKey: DefaultsKey.pendingForegroundPresentation)

        do {
            try createSupportDirectoryIfNeeded()
            try Data().write(to: sentinelURL, options: .atomic)
            try writeLaunchAgent(executablePath: executablePath)
        } catch {
            defaults.removeObject(forKey: DefaultsKey.pendingForegroundPresentation)
            return false
        }

        _ = runLaunchctl(arguments: ["bootstrap", domainTarget, launchAgentURL.path], allowFailure: true)
        return runLaunchctl(arguments: ["kickstart", "-k", "\(domainTarget)/\(label)"], allowFailure: false)
    }

    func syncPersistence(hasActiveLocks: Bool) {
        if hasActiveLocks {
            do {
                try createSupportDirectoryIfNeeded()
                try Data().write(to: sentinelURL, options: .atomic)
                if let executablePath = resolvedExecutablePath() {
                    try writeLaunchAgent(executablePath: executablePath)
                    _ = runLaunchctl(arguments: ["bootstrap", domainTarget, launchAgentURL.path], allowFailure: true)
                }
            } catch {
                return
            }
        } else {
            try? fileManager.removeItem(at: sentinelURL)
        }
    }

    func disablePersistence() {
        try? fileManager.removeItem(at: sentinelURL)
        _ = runLaunchctl(arguments: ["bootout", domainTarget, "\(domainTarget)/\(label)"], allowFailure: true)
        try? fileManager.removeItem(at: launchAgentURL)
    }

    private var domainTarget: String {
        "gui/\(getuid())"
    }

    private var supportDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FocusLocker", isDirectory: true)
    }

    private var sentinelURL: URL {
        supportDirectoryURL.appendingPathComponent("locks-active.sentinel", isDirectory: false)
    }

    private var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist", isDirectory: false)
    }

    private func createSupportDirectoryIfNeeded() throws {
        try fileManager.createDirectory(at: supportDirectoryURL, withIntermediateDirectories: true)
    }

    private func writeLaunchAgent(executablePath: String) throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath, Self.managedLaunchArgument],
            "KeepAlive": [
                "PathState": [
                    sentinelURL.path: true
                ]
            ],
            "RunAtLoad": false,
            "ProcessType": "Interactive"
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func resolvedExecutablePath() -> String? {
        let directPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
        if fileManager.isExecutableFile(atPath: directPath) {
            return directPath
        }

        if let bundleExecutablePath = Bundle.main.executableURL?.standardizedFileURL.path,
           fileManager.isExecutableFile(atPath: bundleExecutablePath) {
            return bundleExecutablePath
        }

        return nil
    }

    private func runLaunchctl(arguments: [String], allowFailure: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return true
            }
            return allowFailure
        } catch {
            return false
        }
    }
}
