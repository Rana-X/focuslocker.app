import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let openLocker: () -> Void
    private let unlockApp: (String) -> Void
    private let disableAllLocksAndQuit: () -> Void

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(
        model: AppModel,
        openLocker: @escaping () -> Void,
        unlockApp: @escaping (String) -> Void,
        disableAllLocksAndQuit: @escaping () -> Void
    ) {
        self.model = model
        self.openLocker = openLocker
        self.unlockApp = unlockApp
        self.disableAllLocksAndQuit = disableAllLocksAndQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly

        bindModel()
        rebuildMenu()
        updateStatusIcon()
    }

    private func bindModel() {
        model.$lockedBundleIDs
            .combineLatest(model.$catalog)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.rebuildMenu()
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let openItem = NSMenuItem(
            title: "Open Locker",
            action: #selector(handleOpenLocker),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let lockedAppsItem = NSMenuItem(title: "Locked Apps", action: nil, keyEquivalent: "")
        let lockedAppIDs = model.lockedBundleIDs.sorted {
            model.displayName(for: $0).localizedStandardCompare(model.displayName(for: $1)) == .orderedAscending
        }

        if lockedAppIDs.isEmpty {
            lockedAppsItem.isEnabled = false
        } else {
            let submenu = NSMenu()
            for bundleID in lockedAppIDs {
                let appItem = NSMenuItem(
                    title: "Unlock \(model.displayName(for: bundleID))",
                    action: #selector(handleUnlockApp(_:)),
                    keyEquivalent: ""
                )
                appItem.representedObject = bundleID
                appItem.target = self
                submenu.addItem(appItem)
            }
            lockedAppsItem.submenu = submenu
        }
        menu.addItem(lockedAppsItem)

        menu.addItem(.separator())

        let disableAndQuitItem = NSMenuItem(
            title: "Disable All Locks and Quit",
            action: #selector(handleDisableAllLocksAndQuit),
            keyEquivalent: ""
        )
        disableAndQuitItem.target = self
        menu.addItem(disableAndQuitItem)
    }

    private func updateStatusIcon() {
        let symbolName = model.hasActiveLocks ? "lock.fill" : "lock.open"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Focus Locker"
        )
        statusItem.button?.toolTip = model.hasActiveLocks
            ? "Focus Locker: locks active"
            : "Focus Locker: no active locks"
    }

    @objc
    private func handleOpenLocker() {
        openLocker()
    }

    @objc
    private func handleUnlockApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        unlockApp(bundleID)
    }

    @objc
    private func handleDisableAllLocksAndQuit() {
        disableAllLocksAndQuit()
    }
}
