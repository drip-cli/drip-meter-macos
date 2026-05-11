import Foundation
import OSLog

/// Centralised loggers, one per subsystem. We use `os.Logger` so DripMeter's
/// logs show up in `Console.app` filtered by `subsystem:io.drip-cli.dripmeter`,
/// and obey the standard `OSLOG_LEVEL` env-var.
public enum DripLogger {
    public static let subsystem = "io.drip-cli.dripmeter"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let store = Logger(subsystem: subsystem, category: "store")
    public static let cli = Logger(subsystem: subsystem, category: "cli")
    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let statusItem = Logger(subsystem: subsystem, category: "statusItem")
}
