import AppKit
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var managerWindowController: ManagerWindowController!
    private var statusBarController: StatusBarController!
    private var lockEnforcer: LockEnforcer!
    private var guardianManager: GuardianManager!

    private var allowManagedQuit = false
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()

        let guardianManager = GuardianManager()
        let model = AppModel()
        let managerWindowController = ManagerWindowController(model: model)
        let statusBarController = StatusBarController(
            model: model,
            openLocker: { [weak self] in
                self?.showManager()
            },
            disableAllLocksAndQuit: { [weak self] in
                self?.disableAllLocksAndQuit()
            }
        )
        let lockEnforcer = LockEnforcer(model: model)

        self.guardianManager = guardianManager
        self.model = model
        self.managerWindowController = managerWindowController
        self.statusBarController = statusBarController
        self.lockEnforcer = lockEnforcer

        model.refreshCatalog()
        bindLockState()

        if model.hasActiveLocks && !guardianManager.isManagedLaunch {
            if guardianManager.activatePersistence(showManagerOnManagedLaunch: true) {
                allowManagedQuit = true
                NSApp.terminate(nil)
                return
            }
        }

        guardianManager.syncPersistence(hasActiveLocks: model.hasActiveLocks)
        lockEnforcer.start()

        if guardianManager.isManagedLaunch {
            if guardianManager.shouldShowManagerOnLaunch() {
                showManager()
            }
        } else {
            showManager()
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.hasActiveLocks, !allowManagedQuit else {
            return .terminateNow
        }

        hideManager()
        return .terminateCancel
    }

    public func applicationWillTerminate(_ notification: Notification) {
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

    private func showManager() {
        managerWindowController.showWindowAndActivate()
    }

    private func hideManager() {
        managerWindowController.hideWindow()
    }

    private func disableAllLocksAndQuit() {
        model.disableAllLocks()
        guardianManager.disablePersistence()
        allowManagedQuit = true
        NSApp.terminate(nil)
    }

    private func bindLockState() {
        model.$lockedBundleIDs
            .dropFirst()
            .sink { [weak self] lockedBundleIDs in
                self?.handleLockStateChange(hasActiveLocks: !lockedBundleIDs.isEmpty)
            }
            .store(in: &cancellables)
    }

    private func handleLockStateChange(hasActiveLocks: Bool) {
        guard let guardianManager else { return }

        if hasActiveLocks && !guardianManager.isManagedLaunch {
            if guardianManager.activatePersistence(showManagerOnManagedLaunch: true) {
                allowManagedQuit = true
                NSApp.terminate(nil)
                return
            }
        }

        guardianManager.syncPersistence(hasActiveLocks: hasActiveLocks)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()

        let openLockerItem = NSMenuItem(
            title: "Open Locker",
            action: #selector(openLockerFromMenu),
            keyEquivalent: "o"
        )
        openLockerItem.target = self
        appMenu.addItem(openLockerItem)

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
}
