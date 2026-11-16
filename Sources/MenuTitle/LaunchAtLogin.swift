import ServiceManagement

enum LaunchAtLogin {
    /// `.requiresApproval` means the login item is registered but the user has
    /// not approved it in System Settings yet.
    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Returns a message when the change fails, for example when the app is
    /// run outside an app bundle.
    static func set(_ enabled: Bool) -> String? {
        if enabled && SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return nil
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
