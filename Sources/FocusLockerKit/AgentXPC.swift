import Foundation

@objc protocol FocusLockerAgentXPCProtocol {
    func getStatus(reply: @escaping ([String], Bool) -> Void)
    func setLockedApps(_ bundleIDs: [String], reply: @escaping ([String], Bool) -> Void)
    func unlock(bundleID: String, reply: @escaping ([String], Bool) -> Void)
    func disableAllLocks(reply: @escaping () -> Void)
    func openMainApp(reply: @escaping () -> Void)
}

enum AgentXPCClientError: LocalizedError {
    case missingEndpoint
    case invalidEndpoint
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "The background helper endpoint is not available yet."
        case .invalidEndpoint:
            return "The background helper endpoint could not be decoded."
        case let .unavailable(message):
            return message
        }
    }
}

final class AgentXPCClient {
    private let endpointURL: URL

    init(endpointURL: URL = SupportPaths.agentEndpointURL) {
        self.endpointURL = endpointURL
    }

    var hasPublishedEndpoint: Bool {
        FileManager.default.fileExists(atPath: endpointURL.path)
    }

    func getStatus(completion: @escaping (Result<SharedLockState, Error>) -> Void) {
        withConnection(completion: completion) { proxy, connection, finish in
            proxy.getStatus { bundleIDs, isLockingEnabled in
                connection.invalidate()
                finish(.success(SharedLockState(isLockingEnabled: isLockingEnabled, lockedBundleIDs: bundleIDs)))
            }
        }
    }

    func setLockedApps(_ bundleIDs: Set<String>, completion: ((Result<SharedLockState, Error>) -> Void)? = nil) {
        let sortedBundleIDs = Array(bundleIDs).sorted()
        withConnection(completion: completion) { proxy, connection, finish in
            proxy.setLockedApps(sortedBundleIDs) { lockedBundleIDs, isLockingEnabled in
                connection.invalidate()
                finish(.success(SharedLockState(isLockingEnabled: isLockingEnabled, lockedBundleIDs: lockedBundleIDs)))
            }
        }
    }

    func unlock(bundleID: String, completion: ((Result<SharedLockState, Error>) -> Void)? = nil) {
        withConnection(completion: completion) { proxy, connection, finish in
            proxy.unlock(bundleID: bundleID) { lockedBundleIDs, isLockingEnabled in
                connection.invalidate()
                finish(.success(SharedLockState(isLockingEnabled: isLockingEnabled, lockedBundleIDs: lockedBundleIDs)))
            }
        }
    }

    func disableAllLocks(completion: ((Result<Void, Error>) -> Void)? = nil) {
        withConnection(completion: completion) { proxy, connection, finish in
            proxy.disableAllLocks {
                connection.invalidate()
                finish(.success(()))
            }
        }
    }

    func openMainApp(completion: ((Result<Void, Error>) -> Void)? = nil) {
        withConnection(completion: completion) { proxy, connection, finish in
            proxy.openMainApp {
                connection.invalidate()
                finish(.success(()))
            }
        }
    }

    private func withConnection<ResultValue>(
        completion: ((Result<ResultValue, Error>) -> Void)?,
        body: (_ proxy: FocusLockerAgentXPCProtocol, _ connection: NSXPCConnection, _ finish: @escaping (Result<ResultValue, Error>) -> Void) -> Void
    ) {
        do {
            let connection = try makeConnection()
            let finish: (Result<ResultValue, Error>) -> Void = { result in
                completion?(result)
            }
            let errorHandler: (Error) -> Void = { error in
                connection.invalidate()
                completion?(.failure(error))
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler(errorHandler) as? FocusLockerAgentXPCProtocol else {
                connection.invalidate()
                completion?(.failure(AgentXPCClientError.unavailable("The background helper rejected the XPC connection.")))
                return
            }

            body(proxy, connection, finish)
        } catch {
            completion?(.failure(error))
        }
    }

    private func makeConnection() throws -> NSXPCConnection {
        guard let data = try? Data(contentsOf: endpointURL) else {
            throw AgentXPCClientError.missingEndpoint
        }

        guard let endpoint = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSXPCListenerEndpoint else {
            throw AgentXPCClientError.invalidEndpoint
        }

        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: FocusLockerAgentXPCProtocol.self)
        connection.resume()
        return connection
    }
}

final class AgentXPCServer: NSObject {
    private let stateProvider: () -> SharedLockState?
    private let setLockedAppsHandler: ([String]) -> Void
    private let unlockHandler: (String) -> Void
    private let disableAllLocksHandler: () -> Void
    private let openMainAppHandler: () -> Void
    private let fileManager: FileManager
    private let endpointURL: URL

    private var listener: NSXPCListener?

    init(
        fileManager: FileManager = .default,
        endpointURL: URL = SupportPaths.agentEndpointURL,
        stateProvider: @escaping () -> SharedLockState?,
        setLockedAppsHandler: @escaping ([String]) -> Void,
        unlockHandler: @escaping (String) -> Void,
        disableAllLocksHandler: @escaping () -> Void,
        openMainAppHandler: @escaping () -> Void
    ) {
        self.fileManager = fileManager
        self.endpointURL = endpointURL
        self.stateProvider = stateProvider
        self.setLockedAppsHandler = setLockedAppsHandler
        self.unlockHandler = unlockHandler
        self.disableAllLocksHandler = disableAllLocksHandler
        self.openMainAppHandler = openMainAppHandler
    }

    func start() {
        guard listener == nil else { return }

        let listener = NSXPCListener.anonymous()
        listener.delegate = self
        do {
            try SupportPaths.ensureSupportDirectories(fileManager: fileManager)
            let endpointData = try NSKeyedArchiver.archivedData(
                withRootObject: listener.endpoint,
                requiringSecureCoding: false
            )
            try endpointData.write(to: endpointURL, options: .atomic)
            FocusLockerLog.xpc.info("Published helper XPC endpoint")
        } catch {
            FocusLockerLog.xpc.error("Failed to publish helper XPC endpoint: \(error.localizedDescription, privacy: .public)")
        }

        self.listener = listener
        listener.resume()
    }

    func stop() {
        listener?.invalidate()
        listener = nil
        try? fileManager.removeItem(at: endpointURL)
    }
}

extension AgentXPCServer: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: FocusLockerAgentXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}

extension AgentXPCServer: FocusLockerAgentXPCProtocol {
    func getStatus(reply: @escaping ([String], Bool) -> Void) {
        let state = stateProvider()
        reply(Array(state?.activeLockedBundleIDs ?? []).sorted(), state?.isLockingEnabled ?? false)
    }

    func setLockedApps(_ bundleIDs: [String], reply: @escaping ([String], Bool) -> Void) {
        setLockedAppsHandler(bundleIDs)
        let state = stateProvider()
        reply(Array(state?.activeLockedBundleIDs ?? []).sorted(), state?.isLockingEnabled ?? false)
    }

    func unlock(bundleID: String, reply: @escaping ([String], Bool) -> Void) {
        unlockHandler(bundleID)
        let state = stateProvider()
        reply(Array(state?.activeLockedBundleIDs ?? []).sorted(), state?.isLockingEnabled ?? false)
    }

    func disableAllLocks(reply: @escaping () -> Void) {
        disableAllLocksHandler()
        reply()
    }

    func openMainApp(reply: @escaping () -> Void) {
        openMainAppHandler()
        reply()
    }
}
