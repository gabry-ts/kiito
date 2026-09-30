import Observation
import PartitiUI
import Sparkle
import SwiftUI

/// Which page the settings window shows, so the popover can open it on a given page.
@MainActor
@Observable
final class Navigation {
    /// A profile's UUID string or one of the fixed pane ids; nil shows the active profile.
    var selection: String?

    init(selection: String? = nil) {
        self.selection = selection
    }
}

/// The settings window: profiles first, then the fixed panes, in Partiti UI's floating sidebar.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Bindable var navigation: Navigation

    enum Pane {
        static let addProfile = "addProfile"
        static let excludedApps = "excludedApps"
        static let general = "general"
        static let about = "about"
    }

    var body: some View {
        SettingsWindow(sections: sections, selection: selection) {
            paneView(selection.wrappedValue)
        }
        // The sidebar leaves room for the traffic lights itself, so it runs under the
        // transparent title bar instead of below it.
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: PUI.Window.settingsMin.width, minHeight: PUI.Window.settingsMin.height)
        .puiAccent(KiitoStyle.accent)
    }

    private var sections: [SidebarSection] {
        let profiles = store.profiles.map { profile in
            SidebarItem(Text(verbatim: profile.name), id: profile.id.uuidString, symbol: "circle.circle",
                        style: .plain, checked: profile.id == store.activeProfileID)
        }
        return [
            SidebarSection("Profiles", profiles + [
                SidebarItem("Add Profile", id: Pane.addProfile, symbol: "plus", style: .plain),
            ]),
            SidebarSection(nil, [
                SidebarItem("Excluded Apps", id: Pane.excludedApps, symbol: "xmark.app.fill", style: .tile(.red)),
                SidebarItem("General", id: Pane.general, symbol: "gearshape.fill", style: .tile(.gray)),
                SidebarItem("About", id: Pane.about, symbol: "info", style: .tile(.teal)),
            ]),
        ]
    }

    /// Falls back to the active profile when nothing, or a deleted profile, is selected.
    /// Add Profile is an action: it creates the profile and selects it.
    private var selection: Binding<String> {
        Binding(
            get: {
                if let id = navigation.selection, profile(for: id) != nil || [Pane.excludedApps, Pane.general, Pane.about].contains(id) {
                    return id
                }
                return store.activeProfileID.uuidString
            },
            set: { id in
                if id == Pane.addProfile {
                    store.addProfile()
                    navigation.selection = store.activeProfileID.uuidString
                } else {
                    navigation.selection = id
                }
            })
    }

    private func profile(for id: String) -> Profile? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return store.profiles.first { $0.id == uuid }
    }

    @ViewBuilder
    private func paneView(_ id: String) -> some View {
        switch id {
        case Pane.excludedApps: ExcludedAppsView()
        case Pane.general: GeneralView()
        case Pane.about: AboutView()
        default:
            if let profile = profile(for: id) {
                ProfileEditorView(profileID: profile.id)
                    .id(profile.id)
            }
        }
    }
}

/// A scrolling settings pane opening with Partiti UI's header.
struct KiitoPane<Header: View, Content: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            SettingsPane {
                header
            } content: {
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct GeneralView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var isAccessibilityTrusted = Permissions.isTrusted
    @State private var loginItemStatus = LoginItem.status

    var body: some View {
        @Bindable var store = store
        let ink = Ink(scheme)
        KiitoPane {
            PaneHeader("General", subtitle: "Menu bar icon, startup and permissions.",
                       symbol: "gearshape.fill", color: .gray)
        } content: {
            SettingsGroup("Kiito", footer: "Relaunch Kiito from Spotlight or Finder to reopen settings when the icon is hidden.") {
                SettingsRow("Enabled") {
                    Toggle("Enabled", isOn: $store.isEnabled)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                SettingsRow("Show icon in menu bar") {
                    Toggle("Show icon in menu bar", isOn: $store.showMenuBarIcon)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                SettingsRow("Quit Kiito") {
                    Button("Quit") { NSApp.terminate(nil) }
                        .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                }
            }
            SettingsGroup("Startup") {
                SettingsRow(Text("Launch at login"),
                            subtitle: loginItemStatus == .requiresApproval ? Text("Approval needed in Login Items settings.") : nil) {
                    HStack(spacing: PUI.Space.m) {
                        if loginItemStatus == .requiresApproval {
                            Button("Open Login Items") { LoginItem.openSystemSettings() }
                                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                        }
                        Toggle("Launch at login", isOn: launchAtLoginBinding)
                            .toggleStyle(PUISwitchStyle(showsLabel: false))
                    }
                }
            }
            SettingsGroup("Accessibility", footer: "Kiito needs Accessibility access to read the trigger button and scroll for you.") {
                SettingsRow("Status") {
                    HStack(spacing: PUI.Space.xs) {
                        Image(systemName: isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(isAccessibilityTrusted ? ink.green : ink.orange)
                        Text(isAccessibilityTrusted ? "Granted" : "Not Granted")
                            .font(PUI.Font.body)
                            .foregroundStyle(ink.secondary)
                    }
                }
                if !isAccessibilityTrusted {
                    SettingsRow("Allow Kiito in Privacy & Security") {
                        Button("Open System Settings") { Permissions.openSystemSettings() }
                            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    }
                }
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
}

private struct AboutView: View {
    @Environment(\.updater) private var updater
    @State private var automaticallyChecksForUpdates = false

    var body: some View {
        ScrollView {
            AboutPane(
                brand: PartitiBrand(
                    accent: KiitoStyle.accent,
                    tagline: "Trackball scrolling for any mouse",
                    coffeeLine: "Kiito is free. If it makes scrolling a little nicer, you can buy me a coffee.",
                    icon: KiitoStyle.icon),
                version: "Version \(versionString)",
                checksAutomatically: $automaticallyChecksForUpdates,
                onCheckForUpdates: { updater?.checkForUpdates() },
                onBuyMeACoffee: { BuyMeACoffee.open() })
                .padding(.top, 44)
                .padding(.horizontal, PUI.Space.xxl)
                .padding(.bottom, PUI.Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            automaticallyChecksForUpdates = updater?.automaticallyChecksForUpdates ?? false
        }
        .onChange(of: automaticallyChecksForUpdates) { _, enabled in
            // Written only on a real change, so opening About never answers Sparkle's
            // own question about automatic checks.
            if let updater, updater.automaticallyChecksForUpdates != enabled {
                updater.automaticallyChecksForUpdates = enabled
            }
        }
    }

    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
