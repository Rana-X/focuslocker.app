import AppKit
import FocusLockerKit

func value(for argument: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: argument) else {
        return nil
    }

    let valueIndex = CommandLine.arguments.index(after: index)
    guard valueIndex < CommandLine.arguments.endIndex else {
        return nil
    }

    return CommandLine.arguments[valueIndex]
}

let app = NSApplication.shared
let delegate = AgentAppDelegate(mainAppPath: value(for: "--main-app-path"))

app.setActivationPolicy(.accessory)
app.delegate = delegate

withExtendedLifetime(delegate) {
    app.run()
}
