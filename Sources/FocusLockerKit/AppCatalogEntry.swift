import AppKit
import Foundation

struct AppCatalogEntry: Identifiable {
    let bundleID: String
    let displayName: String
    let appURL: URL
    let icon: NSImage?

    var id: String { bundleID }
}

extension AppCatalogEntry: Hashable {
    static func == (lhs: AppCatalogEntry, rhs: AppCatalogEntry) -> Bool {
        lhs.bundleID == rhs.bundleID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}
