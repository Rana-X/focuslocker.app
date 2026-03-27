import AppKit
import Foundation

@MainActor
final class AppScanner {
    private let fileManager: FileManager
    private let workspace: NSWorkspace

    init(
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.fileManager = fileManager
        self.workspace = workspace
    }

    func scanApplications() -> [AppCatalogEntry] {
        let rootDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var seenBundleIDs = Set<String>()
        var entries: [AppCatalogEntry] = []

        for rootDirectory in rootDirectories where fileManager.fileExists(atPath: rootDirectory.path) {
            guard let enumerator = fileManager.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let appURL as URL in enumerator where appURL.pathExtension.lowercased() == "app" {
                guard let bundle = Bundle(url: appURL),
                      let bundleID = bundle.bundleIdentifier,
                      !bundleID.isEmpty,
                      !seenBundleIDs.contains(bundleID)
                else {
                    continue
                }

                let displayName = Self.displayName(for: bundle, appURL: appURL)
                let icon = workspace.icon(forFile: appURL.path)
                icon.size = NSSize(width: 32, height: 32)

                entries.append(
                    AppCatalogEntry(
                        bundleID: bundleID,
                        displayName: displayName,
                        appURL: appURL,
                        icon: icon
                    )
                )
                seenBundleIDs.insert(bundleID)
            }
        }

        return entries.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private static func displayName(for bundle: Bundle, appURL: URL) -> String {
        if let localizedDisplayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !localizedDisplayName.isEmpty {
            return localizedDisplayName
        }

        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }

        return appURL.deletingPathExtension().lastPathComponent
    }
}
