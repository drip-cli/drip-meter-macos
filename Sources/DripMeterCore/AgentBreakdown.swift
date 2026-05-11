import Foundation

/// Per-agent token-savings totals computed from the DRIP SQLite database.
///
/// `drip meter --json` is global — it doesn't split totals by agent. To get the
/// "Claude vs Codex vs Gemini" view we read the `sessions` and `reads` tables
/// directly (read-only). See `DripDatabase.fetchAgentBreakdown()`.
public struct AgentBreakdown: Sendable, Equatable {
    public let agent: DripAgent
    public let sessions: Int
    public let filesTracked: Int
    public let tokensFull: Int64
    public let tokensSent: Int64
    public let lastActiveAt: Int64?

    public init(
        agent: DripAgent,
        sessions: Int,
        filesTracked: Int,
        tokensFull: Int64,
        tokensSent: Int64,
        lastActiveAt: Int64?
    ) {
        self.agent = agent
        self.sessions = sessions
        self.filesTracked = filesTracked
        self.tokensFull = tokensFull
        self.tokensSent = tokensSent
        self.lastActiveAt = lastActiveAt
    }

    public var tokensSaved: Int64 {
        max(0, tokensFull - tokensSent)
    }

    public var reductionPct: Int {
        guard tokensFull > 0 else { return 0 }
        return Int((Double(tokensSaved) / Double(tokensFull) * 100).rounded())
    }

    public var hasActivity: Bool {
        sessions > 0 || filesTracked > 0
    }
}
