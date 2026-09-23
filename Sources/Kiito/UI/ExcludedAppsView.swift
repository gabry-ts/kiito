import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        Form {
            Section {
                if store.excludedBundleIDs.isEmpty {
                    Text("No excluded apps")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.excludedBundleIDs, id: \.self) { bundleID in
                        row(for: bundleID)
                    }
                }
            } header: {
                Text("Excluded Apps")
            } footer: {
                Text("Apps added here keep their normal right click; Kiito won't respond to the trigger button.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Excluded Apps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add App…") { addApp() }
            }
        }
    }

    private func row(for bundleID: String) -> some View {
        HStack {
            if let icon = icon(for: bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            Text(name(for: bundleID))
            Spacer()
            Button {
                store.removeExcludedApp(bundleID)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button("Remove", role: .destructive) {
                store.removeExcludedApp(bundleID)
            }
        }
    }

    private func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            store.addExcludedApp(at: url)
        }
    }
}
