import PartitiUI
import SwiftUI

struct ProfileEditorView: View {
    @Environment(SettingsStore.self) private var store
    let profileID: UUID
    @State private var isRenaming = false
    @State private var renameText = ""

    private var profile: Profile {
        store.profiles.first(where: { $0.id == profileID }) ?? store.profiles[0]
    }

    private var isPreset: Bool {
        Profile.presets.contains { $0.id == profile.id }
    }

    private var isActive: Bool {
        profile.id == store.activeProfileID
    }

    private var settings: Binding<ScrollSettings> {
        Binding(
            get: { profile.settings },
            set: { store.updateSettings(profileID, $0) }
        )
    }

    var body: some View {
        let current = profile.settings
        KiitoPane {
            PaneHeader(Text(verbatim: profile.name),
                       subtitle: isActive
                           ? Text("Active profile. Hold the trigger button and move the mouse to scroll.")
                           : Text("Not in use."),
                       symbol: "computermouse.fill", color: KiitoStyle.accent.color) {
                headerActions
            }
        } content: {
            SettingsGroup("Activation") {
                SettingsRow("Trigger button") {
                    PopUpMenu(current.trigger.title) {
                        Picker("Trigger button", selection: settings.trigger) {
                            ForEach(TriggerButton.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                SettingsRow("Click threshold") {
                    sliderControl(settings.threshold, range: ScrollSettings.thresholdRange, step: 1,
                                  value: "\(Int(current.threshold)) px")
                }
                SettingsRow("Stay on", subtitle: "Click once to start scrolling, click again to stop.") {
                    toggle("Stay on", settings.stayOn)
                }
            }

            SettingsGroup("Scrolling") {
                SettingsRow("Speed") {
                    sliderControl(settings.speed, range: ScrollSettings.speedRange, step: 0.1, value: current.speedText)
                }
                SettingsRow("Acceleration") {
                    toggle("Acceleration", settings.acceleration)
                }
                SettingsRow(Text("Axis"), subtitle: Text(verbatim: current.axisMode.caption)) {
                    PopUpMenu(current.axisMode.title) {
                        Picker("Axis", selection: settings.axisMode) {
                            ForEach(AxisMode.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                if current.axisMode == .snap {
                    SettingsRow("Snap sensitivity") {
                        sliderControl(settings.snapSensitivity, range: 0...1, step: 0.05,
                                      value: "\(Int((current.snapSensitivity * 100).rounded()))%")
                    }
                }
            }

            SettingsGroup("Inertia") {
                SettingsRow("Inertia") {
                    toggle("Inertia", settings.inertia)
                }
                SettingsRow("Throw duration") {
                    sliderControl(settings.throwDuration, range: ScrollSettings.throwDurationRange, step: 5,
                                  value: "\(Int(current.throwDuration))")
                }
                .disabled(!current.inertia)
            }

            SettingsGroup("Direction") {
                SettingsRow("Reverse vertical") {
                    toggle("Reverse vertical", settings.reverseVertical)
                }
                SettingsRow("Reverse horizontal") {
                    toggle("Reverse horizontal", settings.reverseHorizontal)
                }
            }

            SettingsGroup("Cursor") {
                CursorStylePicker(selection: settings.cursorStyle)
                    .padding(PUI.Space.l)
            }
        }
        .alert("Rename Profile", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { store.rename(profileID, to: renameText) }
        }
    }

    // MARK: Header

    private var headerActions: some View {
        HStack(spacing: PUI.Space.s) {
            if !isActive {
                Button("Use This Profile") { store.select(profileID) }
                    .buttonStyle(PrimaryButtonStyle(height: PUI.Control.small, fullWidth: false))
            }
            Button("Reset to Defaults") { store.resetToPresetDefaults(profileID) }
                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                .disabled(!isPreset)
            ProfileActionsMenu {
                Button("Duplicate") { store.duplicate(profileID) }
                if !profile.isDefault {
                    Button("Rename…") {
                        renameText = profile.name
                        isRenaming = true
                    }
                    Divider()
                    Button("Delete", role: .destructive) { store.delete(profileID) }
                }
            }
        }
        .fixedSize()
    }

    // MARK: Controls

    private func toggle(_ title: LocalizedStringKey, _ isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(PUISwitchStyle(showsLabel: false))
    }

    private func sliderControl(_ binding: Binding<Double>, range: ClosedRange<Double>, step: Double, value: String) -> some View {
        HStack(spacing: PUI.Space.m) {
            SteppedSlider(value: binding, range: range, step: step)
                .frame(width: 180)
            ValueText(value, width: 44)
        }
    }
}

/// The profile's less frequent actions, behind an ellipsis button next to the header's.
private struct ProfileActionsMenu<Items: View>: View {
    @ViewBuilder let items: () -> Items
    @Environment(\.puiGlassRendering) private var rendering

    var body: some View {
        let label = Image(systemName: "ellipsis")
        switch rendering {
        case .live:
            Menu {
                items()
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More")
        case .painted:
            Button {} label: { label }
                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
        }
    }
}

private struct CursorStylePicker: View {
    @Binding var selection: CursorStyle

    private let options: [(style: CursorStyle, label: LocalizedStringKey)] = [
        (.smoozeCircle, "Circle"),
        (.closedHand, "Hand"),
        (.systemMove, "Move"),
        (.dot, "Dot"),
        (.vertical, "Vertical"),
        (.compass, "Compass"),
        (.glass, "Glass"),
        (.none, "None"),
    ]

    /// One row of eight, as the pane's width allows.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: PUI.Space.m), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: PUI.Space.m) {
            ForEach(options, id: \.style) { option in
                CursorTile(style: option.style, label: option.label, selected: selection == option.style) {
                    selection = option.style
                }
            }
        }
    }
}

/// A cursor style tile: the cursor itself and its name, selection in the accent.
private struct CursorTile: View {
    let style: CursorStyle
    let label: LocalizedStringKey
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.puiAccent) private var accent

    var body: some View {
        let ink = Ink(scheme)
        let shape = RoundedRectangle(cornerRadius: PUI.Radius.row, style: .continuous)
        Button(action: action) {
            VStack(spacing: PUI.Space.xs) {
                ZStack {
                    shape.fill(ink.fill)
                    preview(ink)
                }
                .frame(height: 44)
                .overlay(shape.strokeBorder(selected ? accent.color : .clear, lineWidth: 2))
                Text(label)
                    .font(PUI.Font.caption)
                    .foregroundStyle(selected ? accent.legible(scheme) : ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func preview(_ ink: Ink) -> some View {
        if let image = CursorOverlay.previewImage(for: style) {
            let side: CGFloat = 28
            let scale = min(1, side / max(image.size.width, image.size.height, 1))
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            Image(systemName: "nosign")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ink.secondary)
        }
    }
}
