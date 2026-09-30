import PartitiUI
import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = Ink(scheme)
        KiitoPane {
            PaneHeader("Excluded Apps", subtitle: "Apps where Kiito stays out of the way.",
                       symbol: "xmark.app.fill", color: .red) {
                Button("Add App…") { addApp() }
                    .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
            }
        } content: {
            SettingsGroup("Apps", footer: "Apps added here keep their normal right click; Kiito won't respond to the trigger button.") {
                if store.excludedBundleIDs.isEmpty {
                    Text("No excluded apps")
                        .font(PUI.Font.body)
                        .foregroundStyle(ink.secondary)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                        .padding(.horizontal, PUI.Space.l)
                } else {
                    ForEach(store.excludedBundleIDs, id: \.self) { bundleID in
                        row(for: bundleID, ink)
                    }
                }
            }
        }
    }

    /// A settings row with the app's icon in front, which `SettingsRow` has no slot for.
    private func row(for bundleID: String, _ ink: Ink) -> some View {
        HStack(spacing: PUI.Space.m) {
            if let icon = ExcludedApp.icon(for: bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            Text(verbatim: ExcludedApp.name(for: bundleID))
                .font(PUI.Font.body)
                .foregroundStyle(ink.primary)
            Spacer(minLength: PUI.Space.l)
            Button {
                store.removeExcludedApp(bundleID)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ink.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove")
            .accessibilityLabel("Remove")
        }
        .padding(.horizontal, PUI.Space.l)
        .padding(.vertical, PUI.Space.m)
        .frame(minHeight: 38)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove", role: .destructive) {
                store.removeExcludedApp(bundleID)
            }
        }
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
