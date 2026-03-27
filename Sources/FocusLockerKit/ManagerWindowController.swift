import AppKit
import SwiftUI

@MainActor
final class ManagerWindowController: NSWindowController, NSWindowDelegate {
    init(model: AppModel) {
        let rootView = ManagerView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Focus Locker"
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 520)
        window.center()
        window.contentViewController = hostingController

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }
}
