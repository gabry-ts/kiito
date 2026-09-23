import SwiftUI

struct ProfileEditorView: View {
    @Environment(SettingsStore.self) private var store
    let profileID: UUID

    private var profile: Profile {
        store.profiles.first(where: { $0.id == profileID }) ?? store.profiles[0]
    }

    private var isPreset: Bool {
        Profile.presets.contains { $0.id == profile.id }
    }

    private var settings: Binding<ScrollSettings> {
        Binding(
            get: { profile.settings },
            set: { store.updateSettings(profileID, $0) }
        )
    }

    var body: some View {
        Form {
            Section("Activation") {
                Picker("Trigger Button", selection: settings.trigger) {
                    Text("Right Button").tag(TriggerButton.right)
                    Text("Middle Button").tag(TriggerButton.middle)
                    Text("Button 4").tag(TriggerButton.button4)
                    Text("Button 5").tag(TriggerButton.button5)
                }
                LabeledContent("Click Threshold") {
                    HStack {
                        Slider(value: settings.threshold, in: 1...15, step: 1)
                        Text("\(Int(profile.settings.threshold)) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Toggle("Stay On", isOn: settings.stayOn)
                Text("Replaces the right click with a toggle: click once to start scrolling, click again to stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Scrolling") {
                LabeledContent("Speed") {
                    HStack {
                        Slider(value: settings.speed, in: 0.5...8, step: 0.1)
                        Text(String(format: "%.1f", profile.settings.speed))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                Toggle("Acceleration", isOn: settings.acceleration)
                Toggle("Axis Lock", isOn: settings.axisLock)
                Text("Keep scrolling straight when movement is mostly vertical or horizontal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Inertia") {
                Toggle("Inertia", isOn: settings.inertia)
                LabeledContent("Throw Duration") {
                    HStack {
                        Slider(value: settings.throwDuration, in: ScrollSettings.throwDurationRange, step: 5)
                        Text("\(Int(profile.settings.throwDuration))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                .disabled(!profile.settings.inertia)
            }

            Section("Direction") {
                Toggle("Reverse Vertical", isOn: settings.reverseVertical)
                Toggle("Reverse Horizontal", isOn: settings.reverseHorizontal)
            }

            Section("Cursor") {
                CursorStylePicker(selection: settings.cursorStyle)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile.name)
        .navigationSubtitle(profile.id == store.activeProfileID ? "Active Profile" : "")
        .toolbar {
            if profile.id != store.activeProfileID {
                ToolbarItem(placement: .primaryAction) {
                    Button("Use This Profile") { store.select(profile.id) }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Reset to Defaults") { store.resetToPresetDefaults(profile.id) }
                    .disabled(!isPreset)
            }
        }
    }
}

private struct CursorStylePicker: View {
    @Binding var selection: CursorStyle

    private let options: [(style: CursorStyle, label: String)] = [
        (.smoozeCircle, "Circle"),
        (.closedHand, "Hand"),
        (.systemMove, "Move"),
        (.none, "None"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.style) { option in
                tile(style: option.style, label: option.label)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func tile(style: CursorStyle, label: String) -> some View {
        let isSelected = selection == style
        Button {
            selection = style
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 56, height: 56)
                    if let image = CursorOverlay.previewImage(for: style) {
                        Image(nsImage: image)
                    } else {
                        Image(systemName: "cursorarrow.slash")
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                )
                Text(label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
