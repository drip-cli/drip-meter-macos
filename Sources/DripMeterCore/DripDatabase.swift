import Foundation
import SQLite3

/// Read-only SQLite reader for `~/Library/Application Support/drip/sessions.db`.
///
/// We open the DB with `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX` so we never
/// take a write lock or block the running CLI/agents. Schema reference lives
/// in `src/core/session.rs` of the DRIP repo (`SCHEMA_VERSION = 6` at time of
/// writing). New columns are accommodated by selecting only the ones we need.
public struct DripDatabase: Sendable {
    public let url: URL

    public init(url: URL = DripPaths.sessionsDatabaseURL()) {
        self.url = url
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Aggregate per-agent counts across the lifetime of the install.
    ///
    /// We join `sessions` (which carries the `agent` column) with `reads`
    /// (per-session file rows). This intentionally only counts files seen
    /// in *currently retained* per-session rows — DRIP purges those after
    /// 2 h of idle to keep the DB small. For lifetime-since-install totals
    /// the source of truth is `drip meter --json` (no agent split available
    /// there).
    public func fetchAgentBreakdown() throws -> [AgentBreakdown] {
        guard exists else { return [] }
        let db = try Self.openReadOnly(at: url)
        defer { sqlite3_close_v2(db) }

        let sql = """
        SELECT
            s.agent,
            COUNT(DISTINCT s.session_id) AS sessions,
            COALESCE(SUM(r.files), 0)         AS files_tracked,
            COALESCE(SUM(r.tokens_full), 0)   AS tokens_full,
            COALESCE(SUM(r.tokens_sent), 0)   AS tokens_sent,
            MAX(s.last_active)                AS last_active
        FROM sessions s
        LEFT JOIN (
            SELECT session_id,
                   COUNT(*) AS files,
                   SUM(tokens_full) AS tokens_full,
                   SUM(tokens_sent) AS tokens_sent
            FROM reads
            GROUP BY session_id
        ) r ON r.session_id = s.session_id
        WHERE s.agent IS NOT NULL
        GROUP BY s.agent
        """

        var stmt: OpaquePointer?
        let prepResult = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prepResult == SQLITE_OK, let stmt else {
            if let stmt { sqlite3_finalize(stmt) }
            throw DripDatabaseError.prepare(code: prepResult, message: lastErrorMessage(db))
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [AgentBreakdown] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let agentTag = readText(stmt, 0)
            guard let agent = DripAgent(rawTag: agentTag) else { continue }
            let sessions = Int(sqlite3_column_int64(stmt, 1))
            let filesTracked = Int(sqlite3_column_int64(stmt, 2))
            let tokensFull = sqlite3_column_int64(stmt, 3)
            let tokensSent = sqlite3_column_int64(stmt, 4)
            let lastActive: Int64? = sqlite3_column_type(stmt, 5) == SQLITE_NULL
                ? nil
                : sqlite3_column_int64(stmt, 5)
            rows.append(AgentBreakdown(
                agent: agent,
                sessions: sessions,
                filesTracked: filesTracked,
                tokensFull: tokensFull,
                tokensSent: tokensSent,
                lastActiveAt: lastActive
            ))
        }
        // Pad with empty rows so the UI always renders the full Claude / Codex /
        // Gemini grid even if one of them hasn't been used yet.
        let seen = Set(rows.map(\.agent))
        for agent in DripAgent.allCases where !seen.contains(agent) {
            rows.append(AgentBreakdown(
                agent: agent,
                sessions: 0,
                filesTracked: 0,
                tokensFull: 0,
                tokensSent: 0,
                lastActiveAt: nil
            ))
        }
        rows.sort { $0.agent.rawValue < $1.agent.rawValue }
        return rows
    }

    /// Open the SQLite file for read-only use, but go through the
    /// READ_WRITE flag and a `PRAGMA query_only = 1` lock instead of
    /// `SQLITE_OPEN_READONLY` directly.
    ///
    /// Why: DRIP's DB runs in WAL mode and our heavier queries
    /// (`GROUP BY s.agent` with a correlated subquery) need temp
    /// storage to materialise intermediate results. Pure READONLY mode
    /// disables that temp store and `prepare_v2` fails with
    /// SQLITE_CANTOPEN (code 14, "unable to open database file"). The
    /// `query_only` pragma + `temp_store = MEMORY` combo lets SQLite
    /// use a heap-only temp store while still refusing any write SQL
    /// we accidentally send.
    static func openReadOnly(at url: URL) throws -> OpaquePointer {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
        let openResult = sqlite3_open_v2(url.path, &db, flags, nil)
        guard openResult == SQLITE_OK, let db else {
            if let db { sqlite3_close_v2(db) }
            throw DripDatabaseError.open(code: openResult)
        }
        // Application-level read-only lock + heap temp store. Both are
        // best-effort — if the pragma SQL itself errors we still let
        // the caller continue; the worst case is a noisy log entry.
        sqlite3_exec(
            db,
            "PRAGMA query_only = 1; PRAGMA temp_store = MEMORY; PRAGMA busy_timeout = 1000;",
            nil,
            nil,
            nil
        )
        return db
    }

    private func readText(_ stmt: OpaquePointer, _ column: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: cString)
    }

    private func lastErrorMessage(_ db: OpaquePointer) -> String {
        guard let raw = sqlite3_errmsg(db) else { return "unknown sqlite error" }
        return String(cString: raw)
    }
}

public enum DripDatabaseError: Error, LocalizedError {
    case open(code: Int32)
    case prepare(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .open(code):
            "Failed to open DRIP SQLite database (code \(code))"
        case let .prepare(code, message):
            "Failed to prepare SQL (code \(code)): \(message)"
        }
    }
}
