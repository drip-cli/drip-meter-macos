import Foundation

public enum DripQuickAction: String, CaseIterable, Sendable {
    case reset
    case resetStats
    case resetAll
    case cacheCompact
    case cacheGc
    case watch
    case initClaude
    case initCodex
    case initGemini

    public var displayName: String {
        switch self {
        case .reset: "Reset current session"
        case .resetStats: "Reset lifetime stats"
        case .resetAll: "Wipe all DRIP data"
        case .cacheCompact: "Compact cache"
        case .cacheGc: "Garbage-collect cache"
        case .watch: "Pre-warm watcher (drip watch)"
        case .initClaude: "Wire Claude Code (drip init -g)"
        case .initCodex: "Wire Codex CLI (drip init --agent codex)"
        case .initGemini: "Wire Gemini CLI (drip init -g --agent gemini)"
        }
    }

    public var symbolName: String {
        switch self {
        case .reset: "arrow.uturn.backward"
        case .resetStats: "chart.line.downtrend.xyaxis"
        case .resetAll: "trash"
        case .cacheCompact: "rectangle.compress.vertical"
        case .cacheGc: "arrow.clockwise.icloud"
        case .watch: "eye"
        case .initClaude, .initCodex, .initGemini: "link.badge.plus"
        }
    }

    public var arguments: [String] {
        switch self {
        case .reset: ["reset"]
        // The CLI requires --force in non-interactive contexts; DripMeter
        // already gates these behind a SwiftUI confirmation alert so the
        // user has acknowledged before we get here.
        case .resetStats: ["reset", "--stats", "--force"]
        case .resetAll: ["reset", "--all", "--force"]
        case .cacheCompact: ["cache", "compact"]
        case .cacheGc: ["cache", "gc"]
        case .watch: ["watch"]
        case .initClaude: ["init", "-g"]
        case .initCodex: ["init", "--agent", "codex"]
        case .initGemini: ["init", "-g", "--agent", "gemini"]
        }
    }

    /// Quick actions that take longer than a few seconds. UI shows a
    /// progress spinner instead of fire-and-forget.
    public var isLongRunning: Bool {
        switch self {
        case .watch, .cacheCompact: true
        default: false
        }
    }

    /// Whether the action is destructive enough to warrant a confirmation
    /// dialog. Maps to SwiftUI `ButtonRole.destructive`.
    public var isDestructive: Bool {
        switch self {
        case .resetAll: true
        default: false
        }
    }
}

extension DripCLI {
    /// Invoke an arbitrary `drip <args>` subcommand and capture stdout.
    public func runQuickAction(_ action: DripQuickAction) async throws -> String {
        try await runRaw(action.arguments)
    }

    private func runRaw(_ args: [String]) async throws -> String {
        // Reuse the existing private runner via a public passthrough we add
        // here. Splitting the helper into the same actor keeps the timeout
        // and env-scrubbing semantics identical.
        try await runPublic(args)
    }
}
