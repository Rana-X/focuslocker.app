import OSLog

enum FocusLockerLog {
    private static let subsystem = SupportPaths.mainAppBundleIdentifier

    static let app = Logger(subsystem: subsystem, category: "app")
    static let helper = Logger(subsystem: subsystem, category: "helper")
    static let registration = Logger(subsystem: subsystem, category: "registration")
    static let enforcement = Logger(subsystem: subsystem, category: "enforcement")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let updater = Logger(subsystem: subsystem, category: "updater")
    static let xpc = Logger(subsystem: subsystem, category: "xpc")
}
