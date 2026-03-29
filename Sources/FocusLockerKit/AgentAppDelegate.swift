import AppKit
import Combine

@MainActor
public final class AgentAppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusBarController: StatusBarController!
    private var lockEnforcer: LockEnforcer!
    private var helperRegistrationController: HelperRegistrationController!
    private var xpcServer: AgentXPCServer!
    private var safetySweepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isShuttingDown = false

    private let mainAppPath: String?

    public init(mainAppPath: String?) {
        self.mainAppPath = mainAppPath
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let lockStore = LockStore()
        let model = AppModel(lockStore: lockStore)
        let helperRegistrationController = HelperRegistrationController()
        let statusBarController = StatusBarController(
            model: model,
            openLocker: { [weak self] in
                self?.openLocker()
            },
            unlockApp: { [weak model] bundleID in
                model?.unlock(bundleID: bundleID)
            },
            disableAllLocksAndQuit: { [weak self] in
                self?.disableAllLocksAndQuit()
            }
        )
        let lockEnforcer = LockEnforcer(model: model)
        let xpcServer = AgentXPCServer(
            stateProvider: { [weak model] in
                var state: SharedLockState?
                let readState = {
                    state = model?.currentSharedState()
                }
                if Thread.isMainThread {
                    readState()
                } else {
                    DispatchQueue.main.sync(execute: readState)
                }
                return state
            },
            setLockedAppsHandler: { [weak model] bundleIDs in
                let update = {
                    model?.setLockedBundleIDs(Set(bundleIDs))
                }
                if Thread.isMainThread {
                    update()
                } else {
                    DispatchQueue.main.sync(execute: update)
                }
            },
            unlockHandler: { [weak model] bundleID in
                let update = {
                    model?.unlock(bundleID: bundleID)
                }
                if Thread.isMainThread {
                    update()
                } else {
                    DispatchQueue.main.sync(execute: update)
                }
            },
            disableAllLocksHandler: { [weak self] in
                let disable = {
                    self?.disableAllLocksAndQuit()
                }
                if Thread.isMainThread {
                    disable()
                } else {
                    DispatchQueue.main.sync(execute: disable)
                }
            },
            openMainAppHandler: { [weak self] in
                let open = {
                    self?.openLocker()
                }
                if Thread.isMainThread {
                    open()
                } else {
                    DispatchQueue.main.sync(execute: open)
                }
            }
        )

        self.model = model
        self.helperRegistrationController = helperRegistrationController
        self.statusBarController = statusBarController
        self.lockEnforcer = lockEnforcer
        self.xpcServer = xpcServer

        model.refreshCatalog()
        model.startMonitoringLockState()
        model.reloadLockStateFromStore()
        xpcServer.start()

        bindLockState()

        guard model.hasActiveLocks else {
            disableAllLocksAndQuit()
            return
        }

        lockEnforcer.start()
        lockEnforcer.checkRunningApplications()
        startSafetySweep()
        FocusLockerBroadcaster.postHelperStatusDidChange()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        safetySweepTimer?.invalidate()
        safetySweepTimer = nil
        xpcServer?.stop()
        model?.stopMonitoringLockState()
        lockEnforcer?.stop()
        FocusLockerBroadcaster.postHelperStatusDidChange()
    }

    private func bindLockState() {
        model.$lockedBundleIDs
            .dropFirst()
            .sink { [weak self] lockedBundleIDs in
                guard let self else { return }
                if lockedBundleIDs.isEmpty {
                    self.disableAllLocksAndQuit()
                } else {
                    self.lockEnforcer.checkRunningApplications()
                }
            }
            .store(in: &cancellables)
    }

    private func openLocker() {
        guard let mainAppURL = resolvedMainAppURL() else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, _ in }
    }

    private func disableAllLocksAndQuit() {
        guard !isShuttingDown else { return }

        isShuttingDown = true
        model.disableAllLocks()
        _ = helperRegistrationController.syncRegistration(
            hasActiveLocks: false,
            mainAppBundleURL: resolvedMainAppURL() ?? Bundle.main.bundleURL
        )
        xpcServer.stop()
        NSApp.terminate(nil)
    }

    private func resolvedMainAppURL() -> URL? {
        if let mainAppPath {
            return URL(fileURLWithPath: mainAppPath, isDirectory: true)
        }

        let agentBundleURL = Bundle.main.bundleURL
        let mainAppURL = agentBundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return mainAppURL.pathExtension == "app" ? mainAppURL : nil
    }

    private func startSafetySweep() {
        safetySweepTimer?.invalidate()
        // Keep the sweep tight because background login items do not always receive
        // workspace launch/activate notifications immediately after being started.
        safetySweepTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lockEnforcer.checkRunningApplications()
            }
        }
    }
}
