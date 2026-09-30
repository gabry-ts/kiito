import PartitiUI
import SwiftUI

/// The menu bar popover: the on/off switch, the active profile, the settings you reach for
/// most, and the excluded apps.
struct MenuContent: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    var isAccessibilityTrusted = Permissions.isTrusted
    let openSettings: () -> Void
    let openExcludedApps: () -> Void
    let checkForUpdates: () -> Void
    let openBuyMeACoffee: () -> Void

    /// Beyond this many profiles the segmented control would crowd, so a menu takes over.
    private static let maxSegmentedProfiles = 4

    var body: some View {
        let ink = Ink(scheme)
        PopoverScaffold {
            PopoverHeader(icon: KiitoStyle.icon, name: KiitoStyle.accent.name) {
                if isAccessibilityTrusted {
                    HeaderStatus(store.activeProfile.settings.trigger.title)
                } else {
                    HeaderStatus("Needs Accessibility", symbol: "exclamationmark.triangle.fill", color: ink.orange)
                }
            }
        } content: {
            enabledCard(ink)
            profileCard(ink)
            scrollingCard(ink)
            excludedAppsCard(ink)
        } footer: {
            PopoverFooter(
                onSettings: openSettings,
                onCheckForUpdates: checkForUpdates,
                onBuyMeACoffee: openBuyMeACoffee)
        }
        .puiAccent(KiitoStyle.accent)
    }

    // MARK: Cards

    private func enabledCard(_ ink: Ink) -> some View {
        @Bindable var store = store
        let accent = KiitoStyle.accent
        let on = store.isEnabled && isAccessibilityTrusted
        return Card(tint: on ? accent.color : nil) {
            VStack(alignment: .leading, spacing: PUI.Space.m) {
                HStack(spacing: PUI.Space.l) {
                    ZStack {
                        Circle().fill(on ? accent.color.opacity(scheme == .dark ? 0.25 : 0.18) : ink.fill)
                        KiitoBall().foregroundStyle(on ? accent.legible(scheme) : ink.secondary)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Enabled").font(PUI.Font.headline).foregroundStyle(ink.primary)
                        Text(verbatim: hint).font(PUI.Font.caption).foregroundStyle(ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Toggle("Enabled", isOn: $store.isEnabled)
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                if !isAccessibilityTrusted {
                    Button("Open Accessibility Settings…") { Permissions.openSystemSettings() }
                        .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small, fullWidth: true))
                }
            }
        }
    }

    private var hint: String {
        let settings = store.activeProfile.settings
        if !isAccessibilityTrusted {
            return "Allow Kiito in Privacy & Security, Accessibility to start scrolling."
        }
        if !store.isEnabled {
            return "Off. Clicks work as usual."
        }
        if settings.stayOn {
            return "Click \(settings.trigger.phrase) to start scrolling, click again to stop"
        }
        return "Hold \(settings.trigger.phrase) and move to scroll"
    }

    @ViewBuilder
    private func profileCard(_ ink: Ink) -> some View {
        Card {
            if store.profiles.count <= Self.maxSegmentedProfiles {
                VStack(alignment: .leading, spacing: PUI.Space.m) {
                    SectionHeader("Profile")
                    SegmentedPill(store.profiles.map { (value: $0.id, title: $0.name) },
                                  selection: store.activeProfileSelection,
                                  height: PUI.Control.regular - 2, stretch: true)
                }
            } else {
                row("Profile", ink) {
                    PopUpMenu(store.activeProfile.name) {
                        Picker("Profile", selection: store.activeProfileSelection) {
                            ForEach(store.profiles) { profile in
                                Text(verbatim: profile.name).tag(profile.id)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    private func scrollingCard(_ ink: Ink) -> some View {
        let settings = store.activeSettings
        return Card {
            VStack(alignment: .leading, spacing: PUI.Space.xs) {
                SectionHeader("Scrolling")
                row("Trigger", ink) {
                    PopUpMenu(settings.wrappedValue.trigger.title) {
                        Picker("Trigger", selection: settings.trigger) {
                            ForEach(TriggerButton.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                Hairline()
                VStack(spacing: PUI.Space.xs) {
                    HStack {
                        Text("Speed").font(PUI.Font.body).foregroundStyle(ink.primary)
                        Spacer()
                        Text(verbatim: settings.wrappedValue.speedText)
                            .font(PUI.Font.body).monospacedDigit().foregroundStyle(ink.secondary)
                    }
                    SteppedSlider(value: settings.speed, range: ScrollSettings.speedRange, step: 0.1)
                }
                .padding(.vertical, PUI.Space.xs)
                Hairline()
                row("Axis", ink) {
                    PopUpMenu(settings.wrappedValue.axisMode.title) {
                        Picker("Axis", selection: settings.axisMode) {
                            ForEach(AxisMode.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                Hairline()
                row("Inertia", ink) {
                    Toggle("Inertia", isOn: settings.inertia)
                        .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
                }
            }
        }
    }

    private func excludedAppsCard(_ ink: Ink) -> some View {
        let ids = store.excludedBundleIDs
        return Button(action: openExcludedApps) {
            Card(padding: PUI.Space.m + 2) {
                HStack(spacing: PUI.Space.m) {
                    RowSymbol("xmark.app")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Excluded Apps").font(PUI.Font.body).foregroundStyle(ink.primary)
                        Text(verbatim: excludedSummary(ids)).font(PUI.Font.caption).foregroundStyle(ink.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !ids.isEmpty {
                        Text(verbatim: "\(ids.count)").font(PUI.Font.body).monospacedDigit().foregroundStyle(ink.secondary)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(ink.tertiary)
                }
                .padding(.horizontal, PUI.Space.xxs)
            }
            .contentShape(RoundedRectangle(cornerRadius: PUI.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func excludedSummary(_ ids: [String]) -> String {
        guard !ids.isEmpty else { return "Kiito works in every app" }
        return ids.map(ExcludedApp.name(for:)).joined(separator: ", ")
    }

    private func row<C: View>(_ title: LocalizedStringKey, _ ink: Ink, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(title).font(PUI.Font.body).foregroundStyle(ink.primary)
            Spacer()
            control()
        }
        .frame(height: PUI.Control.regular)
    }
}
