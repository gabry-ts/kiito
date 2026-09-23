import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var selection: SidebarItem?
    @State private var renamingProfileID: UUID?
    @State private var renameText = ""

    enum SidebarItem: Hashable {
        case profile(UUID)
        case excludedApps
        case general
    }

    init(initialSelection: SidebarItem? = nil) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Profiles") {
                    ForEach(store.profiles) { profile in
                        profileRow(profile)
                            .tag(SidebarItem.profile(profile.id))
                    }
                    Button {
                        store.addProfile()
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Section {
                    Label("Excluded Apps", systemImage: "xmark.app")
                        .tag(SidebarItem.excludedApps)
                    Label("General", systemImage: "gearshape")
                        .tag(SidebarItem.general)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            detailView
        }
        .frame(minWidth: 720, minHeight: 520)
        .alert("Rename Profile", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renamingProfileID {
                    store.rename(renamingProfileID, to: renameText)
                }
            }
        }
        .onAppear {
            if selection == nil {
                selection = .profile(store.activeProfileID)
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renamingProfileID != nil },
            set: { if !$0 { renamingProfileID = nil } }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .profile(let id):
            if store.profiles.contains(where: { $0.id == id }) {
                ProfileEditorView(profileID: id)
                    .id(id)
            } else {
                ContentUnavailableView("No Profile Selected", systemImage: "slider.horizontal.3")
            }
        case .excludedApps:
            ExcludedAppsView()
        case .general:
            GeneralView()
        case nil:
            ContentUnavailableView("Select a Profile", systemImage: "sidebar.left")
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: Profile) -> some View {
        HStack {
            Text(profile.name)
            Spacer()
            if profile.id == store.activeProfileID {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .contextMenu {
            Button("Use This Profile") { store.select(profile.id) }
            Button("Duplicate") { store.duplicate(profile.id) }
            if !profile.isDefault {
                Button("Rename…") {
                    renameText = profile.name
                    renamingProfileID = profile.id
                }
                Divider()
                Button("Delete", role: .destructive) { store.delete(profile.id) }
            }
        }
    }
}

private struct GeneralView: View {
    @Environment(SettingsStore.self) private var store
    @State private var isAccessibilityTrusted = Permissions.isTrusted
    @State private var loginItemStatus = LoginItem.status

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Kiito") {
                Toggle("Enabled", isOn: $store.isEnabled)
                Toggle("Show Icon in Menu Bar", isOn: $store.showMenuBarIcon)
                Text("Relaunch Kiito from Spotlight or Finder to reopen settings when hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                if loginItemStatus == .requiresApproval {
                    HStack {
                        Text("Approval needed in Login Items settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { LoginItem.openSystemSettings() }
                    }
                }
            }
            Section("Accessibility") {
                LabeledContent("Status") {
                    HStack {
                        Image(systemName: isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(isAccessibilityTrusted ? .green : .orange)
                        Text(isAccessibilityTrusted ? "Granted" : "Not Granted")
                    }
                }
                if !isAccessibilityTrusted {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            Section("About") {
                LabeledContent("Version", value: versionString)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Quit Kiito", systemImage: "power") { NSApp.terminate(nil) }
                    .help("Quit Kiito")
            }
        }
        .onAppear {
            isAccessibilityTrusted = Permissions.isTrusted
            loginItemStatus = LoginItem.status
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginItemStatus == .enabled || loginItemStatus == .requiresApproval },
            set: { newValue in
                if newValue {
                    LoginItem.register()
                } else {
                    LoginItem.unregister()
                }
                loginItemStatus = LoginItem.status
            }
        )
    }

    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
