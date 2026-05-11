import Foundation
#if canImport(ServiceManagement)
import ServiceManagement
#endif

/// Thin wrapper around `SMAppService.mainApp` (macOS 13+). Falls back to
/// a no-op on platforms where ServiceManagement isn't available so unit
/// tests can compile on Linux CI.
public enum LaunchAtLoginManager {
    public static var isEnabled: Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        #endif
        return false
    }

    public static func setEnabled(_ enabled: Bool) {
        #if canImport(ServiceManagement)
        if #available(macOS 13, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                DripLogger.app.error(
                    "LaunchAtLogin toggle failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        #endif
    }
}
