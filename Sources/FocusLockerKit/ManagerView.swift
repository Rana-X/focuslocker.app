import AppKit
import SwiftUI

struct ManagerView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Focus Locker")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Lock the apps you want kept closed while this utility is running.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("Search applications", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.refreshCatalog()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if model.displayedApps.isEmpty {
                EmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.displayedApps) { app in
                    AppRowView(
                        app: app,
                        isLocked: model.isLocked(bundleID: app.bundleID),
                        isLockable: model.isLockable(app),
                        toggleLock: {
                            model.toggleLock(for: app)
                        }
                    )
                    .listRowSeparator(.visible)
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .padding(22)
        .frame(minWidth: 460, minHeight: 520)
    }
}

private struct AppRowView: View {
    let app: AppCatalogEntry
    let isLocked: Bool
    let isLockable: Bool
    let toggleLock: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(app.displayName)
                        .font(.headline)
                    if isLocked {
                        Text("Locked")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.red.opacity(0.14))
                            )
                            .foregroundStyle(.red)
                    }
                }

                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(app.appURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if isLockable {
                Button(isLocked ? "Unlock" : "Lock", action: toggleLock)
                    .buttonStyle(.borderedProminent)
                    .tint(isLocked ? .green : .red)
            } else {
                Text("Unavailable")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("No Applications Found")
                .font(.headline)

            Text("Try refreshing or clearing the search field.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
