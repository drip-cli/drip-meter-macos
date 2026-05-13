import Foundation

/// Where DRIP keeps its state on disk, and how to find its CLI binary.
///
/// The CLI is the source of truth — env-vars (`DRIP_DATA_DIR`) override the default
/// `~/Library/Application Support/drip/` location, so we mirror that lookup here.
public enum DripPaths {
    public static let defaultBinaryName = "drip"

    /// Common install prefixes, in priority order. We prepend `$PATH` first so a
    /// user's deliberate override wins.
    public static let candidateBinaryDirectories: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "\(NSHomeDirectory())/.cargo/bin",
        "\(NSHomeDirectory())/.local/bin",
        "/usr/bin"
    ]

    /// Resolve the DRIP binary, trying `$PATH` first then the well-known prefixes.
    /// Returns `nil` only when nothing answers `--version` cleanly.
    public static func resolveBinary(overridePath: String? = nil) -> URL? {
        if let override = overridePath, !override.isEmpty {
            let url = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }
        for directory in pathDirectories() + candidateBinaryDirectories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(defaultBinaryName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Where DRIP stores its SQLite. Honours `DRIP_DATA_DIR` exactly like the CLI.
    public static func dataDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["DRIP_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("drip", isDirectory: true)
    }

    public static func sessionsDatabaseURL() -> URL {
        dataDirectory().appendingPathComponent("sessions.db", isDirectory: false)
    }

    public static func sessionsDatabaseExists() -> Bool {
        FileManager.default.fileExists(atPath: sessionsDatabaseURL().path)
    }

    private static func pathDirectories() -> [String] {
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return pathVar.split(separator: ":").map(String.init).filter { !$0.isEmpty }
    }
}
