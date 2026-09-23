import Foundation

/// A named, reusable set of scroll settings.
struct Profile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var settings: ScrollSettings
    /// The built-in profile: cannot be renamed or deleted.
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, settings: ScrollSettings, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.settings = settings
        self.isDefault = isDefault
    }
}

extension Profile {
    // Fixed so stored preferences keep pointing at the same profile across launches.
    static let defaultProfileID = UUID(uuidString: "8A6E3F5E-58AF-4B8E-9C86-8A6C0F0F0001")!
    static let preciseProfileID = UUID(uuidString: "8A6E3F5E-58AF-4B8E-9C86-8A6C0F0F0002")!
    static let fastProfileID = UUID(uuidString: "8A6E3F5E-58AF-4B8E-9C86-8A6C0F0F0003")!
    static let readingProfileID = UUID(uuidString: "8A6E3F5E-58AF-4B8E-9C86-8A6C0F0F0004")!

    /// The starting set of profiles for a fresh install.
    static var presets: [Profile] {
        [
            Profile(id: defaultProfileID, name: "Default", settings: defaultSettings, isDefault: true),
            Profile(id: preciseProfileID, name: "Precise", settings: preciseSettings),
            Profile(id: fastProfileID, name: "Fast", settings: fastSettings),
            Profile(id: readingProfileID, name: "Reading", settings: readingSettings),
        ]
    }

    private static var defaultSettings: ScrollSettings {
        var settings = ScrollSettings()
        settings.threshold = 7
        settings.reverseVertical = true
        settings.reverseHorizontal = true
        return settings
    }

    private static var preciseSettings: ScrollSettings {
        var settings = ScrollSettings()
        settings.speed = 1.2
        settings.inertia = false
        return settings
    }

    private static var fastSettings: ScrollSettings {
        var settings = ScrollSettings()
        settings.speed = 4.0
        settings.throwDuration = 180
        return settings
    }

    private static var readingSettings: ScrollSettings {
        var settings = ScrollSettings()
        settings.speed = 1.5
        settings.axisLock = true
        settings.throwDuration = 140
        return settings
    }
}
