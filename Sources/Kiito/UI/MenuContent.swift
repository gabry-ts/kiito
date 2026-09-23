import SwiftUI

struct MenuContent: View {
    @Environment(SettingsStore.self) private var store
    let openSettings: () -> Void

    var body: some View {
        @Bindable var store = store
        Toggle("Enabled", isOn: $store.isEnabled)
        Divider()
        Picker("Profile", selection: Binding(
            get: { store.activeProfileID },
            set: { store.select($0) }
        )) {
            ForEach(store.profiles) { profile in
                Text(profile.name).tag(profile.id)
            }
        }
        .pickerStyle(.inline)
        Divider()
        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Kiito") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
