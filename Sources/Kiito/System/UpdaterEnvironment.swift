import Sparkle
import SwiftUI

/// Makes the Sparkle updater reachable from Settings without threading it through every
/// view's initializer.
private struct UpdaterKey: EnvironmentKey {
    static let defaultValue: SPUUpdater? = nil
}

extension EnvironmentValues {
    var updater: SPUUpdater? {
        get { self[UpdaterKey.self] }
        set { self[UpdaterKey.self] = newValue }
    }
}
