import Foundation
import SQLite3

/// A single row from DRIP's `sessions` table joined with read aggregates.
/// Used by the Agents tab to show the user *what* their agents have been
/// up to, not just the total token count.
public struct SessionRow: Identifiable, Sendable, Equatable {
    public let id: String
    public let agent: DripAgent?
    public let strategy: String?
    public let context: String?
    public let cwd: String?
    public let startedAt: Int64
    public let lastActiveAt: Int64
    public let filesTracked: Int
    public let tokensFull: Int64
    public let tokensSent: Int64
    /// Schema v9: how many times this session has been context-compacted
    /// by Claude/Codex/Gemini. `0` for pre-v9 sessions and for fresh ones.
    public let compactionCount: Int
    /// Unix seconds of the most recent compaction, or `nil` if none.
    public let lastCompactionAt: Int64?

    public var tokensSaved: Int64 { max(0, tokensFull - tokensSent) }

    public var reductionPct: Int {
        guard tokensFull > 0 else { return 0 }
        return Int((Double(tokensSaved) / Double(tokensFull) * 100).rounded())
    }

    public var label: String {
        // Prefer human context (branch / cwd basename) over the raw id.
        if let context, !context.isEmpty, context != "-" {
            return context
        }
        if let cwd, let basename = cwd.split(separator: "/").last {
            return String(basename)
        }
        return String(id.prefix(10))
    }
}

/// Total tokens saved on a given calendar day (UTC) — used for the daily
/// target / streak feature.
public struct DailyTotal: Sendable, Equatable {
    public let day: String
    public let tokensSaved: Int64
    public let reads: Int64
}

extension DripDatabase {
    public func fetchSessions(limit: Int = 30) throws -> [SessionRow] {
        guard exists else { return [] }
        let db = try DripDatabase.openReadOnly(at: url)
        defer { sqlite3_close_v2(db) }

        // The COALESCE around the v9 columns lets us run the same SELECT
        // against pre-v9 databases — older rows just default to 0 / NULL.
        // We don't gate on schema_version because DRIP itself refuses to
        // open a too-new DB, so by the time we read the user's DB the
        // columns are guaranteed to exist if the binary supports them.
        let sql = """
        SELECT s.session_id,
               s.agent,
               s.strategy,
               s.context,
               s.cwd,
               s.started_at,
               s.last_active,
               COALESCE((SELECT COUNT(*) FROM reads r WHERE r.session_id = s.session_id), 0) AS files,
               COALESCE((SELECT SUM(tokens_full) FROM reads r WHERE r.session_id = s.session_id), 0) AS full,
               COALESCE((SELECT SUM(tokens_sent) FROM reads r WHERE r.session_id = s.session_id), 0) AS sent,
               COALESCE(s.compaction_count, 0) AS compactions,
               s.last_compaction_at
        FROM sessions s
        ORDER BY s.last_active DESC
        LIMIT ?
        """
        var stmt: OpaquePointer?
        let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prep == SQLITE_OK, let stmt else {
            if let stmt { sqlite3_finalize(stmt) }
            throw DripDatabaseError.prepare(code: prep, message: "fetchSessions prepare")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var rows: [SessionRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = (sqlite3_column_text(stmt, 0)).map { String(cString: $0) } ?? ""
            let agentTag = (sqlite3_column_text(stmt, 1)).map { String(cString: $0) }
            let strategy = (sqlite3_column_text(stmt, 2)).map { String(cString: $0) }
            let context = (sqlite3_column_text(stmt, 3)).map { String(cString: $0) }
            let cwd = (sqlite3_column_text(stmt, 4)).map { String(cString: $0) }
            let started = sqlite3_column_int64(stmt, 5)
            let lastActive = sqlite3_column_int64(stmt, 6)
            let files = Int(sqlite3_column_int64(stmt, 7))
            let full = sqlite3_column_int64(stmt, 8)
            let sent = sqlite3_column_int64(stmt, 9)
            let compactions = Int(sqlite3_column_int64(stmt, 10))
            let lastCompaction: Int64? = sqlite3_column_type(stmt, 11) == SQLITE_NULL
                ? nil
                : sqlite3_column_int64(stmt, 11)
            rows.append(SessionRow(
                id: id,
                agent: DripAgent(rawTag: agentTag),
                strategy: strategy,
                context: context,
                cwd: cwd,
                startedAt: started,
                lastActiveAt: lastActive,
                filesTracked: files,
                tokensFull: full,
                tokensSent: sent,
                compactionCount: compactions,
                lastCompactionAt: lastCompaction
            ))
        }
        return rows
    }

    /// Total tokens saved today (UTC). Used by the daily target feature.
    public func fetchTodayTotal() throws -> DailyTotal {
        guard exists else {
            return DailyTotal(day: Self.todayUTC(), tokensSaved: 0, reads: 0)
        }
        let db = try DripDatabase.openReadOnly(at: url)
        defer { sqlite3_close_v2(db) }

        let day = Self.todayUTC()
        let sql = """
        SELECT day, reads, tokens_full, tokens_sent
        FROM lifetime_daily
        WHERE day = ?
        """
        var stmt: OpaquePointer?
        let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prep == SQLITE_OK, let stmt else {
            if let stmt { sqlite3_finalize(stmt) }
            throw DripDatabaseError.prepare(code: prep, message: "fetchTodayTotal prepare")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, day, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        if sqlite3_step(stmt) == SQLITE_ROW {
            let reads = sqlite3_column_int64(stmt, 1)
            let full = sqlite3_column_int64(stmt, 2)
            let sent = sqlite3_column_int64(stmt, 3)
            return DailyTotal(day: day, tokensSaved: max(0, full - sent), reads: reads)
        }
        return DailyTotal(day: day, tokensSaved: 0, reads: 0)
    }

    /// Number of consecutive days (ending today) with at least one read.
    /// Used for the streak indicator.
    public func fetchStreakDays() throws -> Int {
        guard exists else { return 0 }
        let db = try DripDatabase.openReadOnly(at: url)
        defer { sqlite3_close_v2(db) }

        let sql = """
        SELECT day FROM lifetime_daily
        WHERE reads > 0
        ORDER BY day DESC
        """
        var stmt: OpaquePointer?
        let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prep == SQLITE_OK, let stmt else {
            if let stmt { sqlite3_finalize(stmt) }
            throw DripDatabaseError.prepare(code: prep, message: "fetchStreakDays prepare")
        }
        defer { sqlite3_finalize(stmt) }

        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        var streak = 0
        var expected = Date()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let raw = (sqlite3_column_text(stmt, 0)).map { String(cString: $0) } ?? ""
            guard let date = formatter.date(from: raw) else { continue }
            // Walk back day-by-day; break as soon as the chain skips one.
            if calendar.isDate(date, inSameDayAs: expected) {
                streak += 1
                expected = calendar.date(byAdding: .day, value: -1, to: expected) ?? expected
            } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: expected) ?? expected) {
                streak += 1
                expected = calendar.date(byAdding: .day, value: -2, to: expected) ?? expected
            } else if streak == 0 {
                // First (most recent) entry isn't today — no current streak.
                break
            } else {
                break
            }
        }
        return streak
    }

    private static func todayUTC() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
