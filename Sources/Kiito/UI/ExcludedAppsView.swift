import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.excludedBundleIDs.isEmpty {
                ContentUnavailableView(
                    "No Excluded Apps",
                    systemImage: "xmark.app",
                    description: Text("Apps added here keep their normal right click; Kiito won't respond to the trigger button.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.excludedBundleIDs, id: \.self, selection: $selection) { bundleID in
                    row(for: bundleID)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Button {
                    addApp()
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    if let selection {
                        store.removeExcludedApp(selection)
                        self.selection = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .navigationTitle("Excluded Apps")
    }

    private func row(for bundleID: String) -> some View {
        HStack {
            if let icon = icon(for: bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            Text(name(for: bundleID))
            Spacer()
            Text(bundleID)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .tag(bundleID)
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
