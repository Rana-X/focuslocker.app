import AppKit
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var managerWindowController: ManagerWindowController!
    private var lockEnforcer: LockEnforcer!
    private var helperRegistrationController: HelperRegistrationController!
    private var agentXPCClient: AgentXPCClient!
    private var updaterController: UpdaterController!
    private var helperSyncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var distributedObservers: [NSObjectProtocol] = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        LegacyGuardianCleanup.clearIfPresent()

        let lockStore = LockStore()
        lockStore.migrateLegacyDefaultsIfNeeded()

        let model = AppModel(lockStore: lockStore)
        model.retryBackgroundHelper = { [weak self] in
            self?.retryBackgroundHelper()
        }

        let managerWindowController = ManagerWindowController(model: model)
        let lockEnforcer = LockEnforcer(model: model)
        let helperRegistrationController = HelperRegistrationController()
        let agentXPCClient = AgentXPCClient()
        let updaterController = UpdaterController()

        self.model = model
        self.managerWindowController = managerWindowController
        self.lockEnforcer = lockEnforcer
        self.helperRegistrationController = helperRegistrationController
        self.agentXPCClient = agentXPCClient
        self.updaterController = updaterController

        model.refreshCatalog()
        model.startMonitoringLockState()
        observeDistributedNotifications()
        bindLockState()
        lockEnforcer.start()
        syncBackgroundLocking(pushState: model.hasActiveLocks)
        showManager()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showManager()
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        helperSyncTask?.cancel()
        let center = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            center.removeObserver(observer)
        }
        distributedObservers.removeAll()
        model?.stopMonitoringLockState()
        lockEnforcer?.stop()
    }

    @objc
    private func openLockerFromMenu() {
        showManager()
    }

    @objc
    private func terminateFromMenu() {
        NSApp.terminate(nil)
    }

    @objc
    private func checkForUpdatesFromMenu() {
        updaterController.checkForUpdates()
    }

    @objc
    private func retryBackgroundHelperFromMenu() {
        retryBackgroundHelper()
    }

    @objc
    private func resetFocusLockerFromMenu() {
        model.disableAllLocks()
        _ = helperRegistrationController.syncRegistration(
            hasActiveLocks: false,
            mainAppBundleURL: Bundle.main.bundleURL
        )
        try? FileManager.default.removeItem(at: SupportPaths.agentEndpointURL)
        refreshBackgroundStatus()
    }

    private func showManager() {
        managerWindowController.showWindowAndActivate()
    }

    private func bindLockState() {
        model.$lockedBundleIDs
            .dropFirst()
            .sink { [weak self] lockedBundleIDs in
                guard let self else { return }
                DispatchQueue.main.async { [lockedBundleIDs] in
                    self.syncBackgroundLocking(pushState: !lockedBundleIDs.isEmpty)
                }
            }
            .store(in: &cancellables)
    }

    private func syncBackgroundLocking(pushState: Bool) {
        helperSyncTask?.cancel()

        let status = helperRegistrationController.syncRegistration(
            hasActiveLocks: model.hasActiveLocks,
            mainAppBundleURL: Bundle.main.bundleURL
        )
        model.updateBackgroundAgentStatus(status)

        guard pushState, model.hasActiveLocks else {
            refreshBackgroundStatus()
            return
        }

        guard agentXPCClient.hasPublishedEndpoint else {
            refreshBackgroundStatus()
            lockEnforcer.checkRunningApplications()
            return
        }

        let lockedBundleIDs = model.lockedBundleIDs
        helperSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.agentXPCClient.setLockedApps(lockedBundleIDs) { _ in
                Task { @MainActor [weak self] in
                    self?.refreshBackgroundStatus()
                    self?.lockEnforcer.checkRunningApplications()
                }
            }
        }
    }

    private func retryBackgroundHelper() {
        let status = helperRegistrationController.syncRegistration(
            hasActiveLocks: model.hasActiveLocks,
            mainAppBundleURL: Bundle.main.bundleURL,
            forceLaunch: true
        )
        model.updateBackgroundAgentStatus(status)
        if model.hasActiveLocks {
            syncBackgroundLocking(pushState: true)
        }
    }

    private func refreshBackgroundStatus() {
        let registrationStatus = helperRegistrationController.currentStatus(hasActiveLocks: model.hasActiveLocks)
        model.updateBackgroundAgentStatus(registrationStatus)

        guard model.hasActiveLocks, agentXPCClient.hasPublishedEndpoint else { return }

        agentXPCClient.getStatus { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case let .success(state):
                    self.model.updateBackgroundAgentStatus(
                        state.isLockingEnabled && !state.lockedBundleIDs.isEmpty ? .running : registrationStatus
                    )
                case .failure:
                    self.model.updateBackgroundAgentStatus(registrationStatus)
                }
            }
        }
    }

    private func observeDistributedNotifications() {
        let center = DistributedNotificationCenter.default()

        distributedObservers = [
            center.addObserver(forName: FocusLockerNotifications.helperStatusDidChange, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshBackgroundStatus()
                }
            },
            center.addObserver(forName: FocusLockerNotifications.openManager, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.showManager()
                }
            }
        ]
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        appMenu.addItem(checkForUpdatesItem)

        appMenu.addItem(.separator())

        let openLockerItem = NSMenuItem(
            title: "Open Locker",
            action: #selector(openLockerFromMenu),
            keyEquivalent: "o"
        )
        openLockerItem.target = self
        appMenu.addItem(openLockerItem)

        appMenu.addItem(.separator())

        let disableLocksItem = NSMenuItem(
            title: "Disable All Locks",
            action: #selector(disableAllLocksFromMenu),
            keyEquivalent: ""
        )
        disableLocksItem.target = self
        appMenu.addItem(disableLocksItem)

        let retryHelperItem = NSMenuItem(
            title: "Retry Background Helper",
            action: #selector(retryBackgroundHelperFromMenu),
            keyEquivalent: ""
        )
        retryHelperItem.target = self
        appMenu.addItem(retryHelperItem)

        let resetItem = NSMenuItem(
            title: "Reset Focus Locker",
            action: #selector(resetFocusLockerFromMenu),
            keyEquivalent: ""
        )
        resetItem.target = self
        appMenu.addItem(resetItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Focus Locker",
            action: #selector(terminateFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    @objc
    private func disableAllLocksFromMenu() {
        model.disableAllLocks()
        refreshBackgroundStatus()
    }
}
