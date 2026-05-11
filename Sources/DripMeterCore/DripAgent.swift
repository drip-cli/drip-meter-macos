import Foundation

/// The three coding agents that DRIP supports.
///
/// Mirrors the `sessions.agent` column in the DRIP SQLite database, which is one of
/// `claude` / `codex` / `gemini` (or `null` for legacy rows). DripMeter never invents
/// agents the CLI doesn't recognise.
public enum DripAgent: String, CaseIterable, Codable, Sendable, Hashable {
    case claude
    case codex
    case gemini

    public init?(rawTag: String?) {
        guard let raw = rawTag?.lowercased() else { return nil }
        switch raw {
        case "claude": self = .claude
        case "codex": self = .codex
        case "gemini": self = .gemini
        default: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .gemini: "Gemini"
        }
    }

    public var symbolName: String {
        switch self {
        case .claude: "sparkles"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .gemini: "diamond.fill"
        }
    }

    public var accentHex: String {
        switch self {
        case .claude: "#D97757"
        case .codex: "#10A37F"
        case .gemini: "#1A73E8"
        }
    }
}
