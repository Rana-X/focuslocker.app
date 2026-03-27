import AppKit
import FocusLockerKit

let app = NSApplication.shared
let delegate = AppDelegate()

app.setActivationPolicy(.accessory)
app.delegate = delegate

withExtendedLifetime(delegate) {
    app.run()
}
