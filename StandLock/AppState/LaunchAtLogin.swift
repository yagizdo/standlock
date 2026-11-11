import ServiceManagement

/// The app's login item, read and written through `SMAppService` only: no stored preference, so
/// a change made in System Settings shows up as is.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Also true when the user switched the item off in System Settings: it is still listed
    /// there until the app unregisters it.
    static var isRegistered: Bool {
        [.enabled, .requiresApproval].contains(SMAppService.mainApp.status)
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
