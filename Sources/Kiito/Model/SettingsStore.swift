import Foundation
import Observation

/// Holds profiles and global preferences, persists them to disk, and keeps the engine in sync.
@MainActor
@Observable
final class SettingsStore {
    private(set) var profiles: [Profile]
    var activeProfileID: UUID {
        didSet {
            pushActiveProfile()
            save()
        }
    }
    var excludedBundleIDs: [String] {
        didSet { save() }
    }
    var isEnabled: Bool {
        didSet {
            engine?.isEnabled = isEnabled
            save()
        }
    }
    var showMenuBarIcon: Bool {
        didSet { save() }
    }

    private weak var engine: ScrollEngine?
    private var saveTask: Task<Void, Never>?
    /// False for the in-memory store used when rendering offscreen snapshots, so mock
    /// data never touches the real settings.json.
    private let persistsToDisk: Bool

    private static let directory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Kiito", isDirectory: true)
    private static let fileURL = directory.appendingPathComponent("settings.json")

    private struct Persisted: Codable {
        var profiles: [Profile]
        var activeProfileID: UUID
        var excludedBundleIDs: [String]
        var isEnabled: Bool
        var showMenuBarIcon: Bool
    }

    init() {
        persistsToDisk = true
        if let persisted = Self.load() {
            profiles = persisted.profiles
            activeProfileID = persisted.activeProfileID
            excludedBundleIDs = persisted.excludedBundleIDs
            isEnabled = persisted.isEnabled
            showMenuBarIcon = persisted.showMenuBarIcon
        } else {
            profiles = Profile.presets
            activeProfileID = Profile.defaultProfileID
            excludedBundleIDs = []
            isEnabled = true
            showMenuBarIcon = true
        }
        if !profiles.contains(where: { $0.id == activeProfileID }) {
            activeProfileID = profiles.first?.id ?? Profile.defaultProfileID
        }
    }

    /// In-memory store seeded with mock data, for offscreen snapshot rendering. Never
    /// reads or writes settings.json.
    init(profiles: [Profile], activeProfileID: UUID, excludedBundleIDs: [String], isEnabled: Bool, showMenuBarIcon: Bool) {
        persistsToDisk = false
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.excludedBundleIDs = excludedBundleIDs
        self.isEnabled = isEnabled
        self.showMenuBarIcon = showMenuBarIcon
    }

    /// Connects the engine so it reflects the active profile and enabled state from now on.
    func attach(engine: ScrollEngine) {
        self.engine = engine
        engine.isEnabled = isEnabled
        pushActiveProfile()
    }

    var activeProfile: Profile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    // MARK: - Profile operations

    func addProfile() {
        let profile = Profile(name: nextProfileName(), settings: activeProfile.settings)
        profiles.append(profile)
        activeProfileID = profile.id
        save()
    }

    func duplicate(_ id: UUID) {
        guard let source = profiles.first(where: { $0.id == id }) else { return }
        let profile = Profile(name: duplicateName(of: source.name), settings: source.settings)
        profiles.append(profile)
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }), !profiles[index].isDefault else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profiles[index].name = trimmed
        save()
    }

    func delete(_ id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }), !profiles[index].isDefault else { return }
        profiles.remove(at: index)
        if activeProfileID == id {
            activeProfileID = profiles.first(where: { $0.isDefault })?.id ?? profiles[0].id
        }
        save()
    }

    func select(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
    }

    func updateSettings(_ id: UUID, _ settings: ScrollSettings) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].settings = settings
        if id == activeProfileID {
            pushActiveProfile()
        }
        save()
    }

    func resetToPresetDefaults(_ id: UUID) {
        guard let preset = Profile.presets.first(where: { $0.id == id }) else { return }
        updateSettings(id, preset.settings)
    }

    // MARK: - Excluded apps

    func addExcludedApp(at url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier, !excludedBundleIDs.contains(bundleID) else { return }
        excludedBundleIDs.append(bundleID)
    }

    func removeExcludedApp(_ bundleID: String) {
        excludedBundleIDs.removeAll { $0 == bundleID }
    }

    // MARK: - Private

    private func nextProfileName() -> String {
        let existing = Set(profiles.map(\.name))
        var n = profiles.count + 1
        var name = "Profile \(n)"
        while existing.contains(name) {
            n += 1
            name = "Profile \(n)"
        }
        return name
    }

    private func duplicateName(of name: String) -> String {
        let existing = Set(profiles.map(\.name))
        let base = "\(name) copy"
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    private func pushActiveProfile() {
        engine?.settings = activeProfile.settings
    }

    private func save() {
        guard persistsToDisk else { return }
        saveTask?.cancel()
        let snapshot = Persisted(
            profiles: profiles,
            activeProfileID: activeProfileID,
            excludedBundleIDs: excludedBundleIDs,
            isEnabled: isEnabled,
            showMenuBarIcon: showMenuBarIcon
        )
        saveTask = Task { [snapshot] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            Self.write(snapshot)
        }
    }

    private static func load() -> Persisted? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Persisted.self, from: data)
    }

    private static func write(_ persisted: Persisted) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort: settings simply won't persist this run.
        }
    }
}
