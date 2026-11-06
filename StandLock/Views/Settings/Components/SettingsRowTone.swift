import SwiftUI
import StandLockCore

private struct SettingsRowToneKey: EnvironmentKey {
    static let defaultValue: DisciplineLevel? = nil
}

extension EnvironmentValues {
    /// The hue of a page's row chips. Set by the page's owner, so components never see a page.
    var settingsRowTone: DisciplineLevel? {
        get { self[SettingsRowToneKey.self] }
        set { self[SettingsRowToneKey.self] = newValue }
    }
}
