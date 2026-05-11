import Foundation
import SQLite3

/// Single intercepted-read event, as recorded in the `read_events` table by
/// the DRIP hook layer. Used by the Live tab to show what's happening right
/// now (last N reads, with outcome + savings).
public struct ReplayEvent: Identifiable, Sendable, Equatable {
    public enum Outcome: String, Sendable {
        case first
        // DRIP emits `first-compressed` for the very first read where the
        // semantic compressor elided some function bodies. Same UX
        // semantically as `first`, just slightly cheaper for the agent.
        case firstCompressed = "first-compressed"
        case unchanged
        // Window-scoped equivalent emitted on a partial Read whose target
        // window is byte-identical to the cached baseline.
        case partialUnchanged = "partial-unchanged"
        case delta
        case fallback
        case deleted
        case passthrough

        public var displayName: String {
            switch self {
            case .first: "First read"
            case .firstCompressed: "First (compressed)"
            case .unchanged: "Unchanged"
            case .partialUnchanged: "Window unchanged"
            case .delta: "Delta"
            case .fallback: "Fallback"
            case .deleted: "Deleted"
            case .passthrough: "Passthrough"
            }
        }

        public var symbolName: String {
            switch self {
            case .first: "doc.badge.plus"
            case .firstCompressed: "doc.badge.gearshape"
            case .unchanged: "equal.circle"
            case .partialUnchanged: "equal.square"
            case .delta: "arrow.triangle.merge"
            case .fallback: "arrow.uturn.backward"
            case .deleted: "trash"
            case .passthrough: "arrow.right"
            }
        }
    }

    public let id: Int64
    public let occurredAt: Int64
    public let filePath: String
    public let outcome: Outcome
    public let tokensFull: Int64
    public let tokensSent: Int64
    /// `true` when DRIP's rendered output for this read carried the v9
    /// `↺ context was compacted` decoration. Detected by sniffing the
    /// stored `rendered` text — cheaper than a JOIN against sessions for
    /// the in-popover Live view.
    public let isPostCompaction: Bool

    public var tokensSaved: Int64 { max(0, tokensFull - tokensSent) }
}

extension DripDatabase {
    /// Last N read events, most recent first. Window is bounded by `since`
    /// (Unix seconds, e.g. `now - 300` for last 5 min).
    public func fetchRecentEvents(since: Int64, limit: Int = 50) throws -> [ReplayEvent] {
        guard exists else { return [] }
        let db = try DripDatabase.openReadOnly(at: url)
        defer { sqlite3_close_v2(db) }

        // We pull a 256-byte prefix of `rendered` so we can detect the v9
        // `↺ context was compacted` decoration without dragging the full
        // (sometimes 32 KB) blob across the SQLite boundary.
        let sql = """
        SELECT id, occurred_at, file_path, outcome_kind, tokens_full, tokens_sent,
               substr(rendered, 1, 256) AS rendered_prefix
        FROM read_events
        WHERE occurred_at >= ?
        ORDER BY occurred_at DESC
        LIMIT ?
        """
        var stmt: OpaquePointer?
        let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prep == SQLITE_OK, let stmt else {
            if let stmt { sqlite3_finalize(stmt) }
            throw DripDatabaseError.prepare(code: prep, message: "fetchRecentEvents prepare")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, since)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var rows: [ReplayEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let occurredAt = sqlite3_column_int64(stmt, 1)
            let pathPtr = sqlite3_column_text(stmt, 2)
            let outcomePtr = sqlite3_column_text(stmt, 3)
            let tokensFull = sqlite3_column_int64(stmt, 4)
            let tokensSent = sqlite3_column_int64(stmt, 5)
            let path = pathPtr.map { String(cString: $0) } ?? ""
            let outcomeRaw = outcomePtr.map { String(cString: $0) } ?? ""
            let outcome = ReplayEvent.Outcome(rawValue: outcomeRaw) ?? .passthrough
            let renderedPtr = sqlite3_column_text(stmt, 6)
            let renderedPrefix = renderedPtr.map { String(cString: $0) } ?? ""
            // Marker emitted by DRIP's `render_with_session`. Catches both
            // the `↺` glyph itself and the human phrase so a future DRIP
            // template tweak doesn't silently break the badge.
            let isPostCompaction = renderedPrefix.contains("↺")
                || renderedPrefix.lowercased().contains("context was compacted")
            rows.append(ReplayEvent(
                id: id,
                occurredAt: occurredAt,
                filePath: path,
                outcome: outcome,
                tokensFull: tokensFull,
                tokensSent: tokensSent,
                isPostCompaction: isPostCompaction
            ))
        }
        return rows
    }

    /// Top-N files across the lifetime registry. Lets the Files tab show many
    /// more rows than `drip meter --json`'s default top-10.
    public func fetchTopFiles(limit: Int = 50) throws -> [MeterReport.PerFile] {
        guard exists else { return [] }
        let db = try DripDatabase.openReadOnly(at: url)
        defer { sqlite3_close_v2(db) }

        let sql = """
        SELECT file_path, reads, tokens_full, tokens_sent
        FROM lifetime_per_file
        ORDER BY (tokens_full - tokens_sent) DESC
        LIMIT ?
        """
        var stmt: OpaquePointer?
        let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prep == SQLITE_OK, let stmt else {
            if let stmt { sqlite3_finalize(stmt) }
            throw DripDatabaseError.prepare(code: prep, message: "fetchTopFiles prepare")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var rows: [MeterReport.PerFile] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let pathPtr = sqlite3_column_text(stmt, 0)
            let reads = sqlite3_column_int64(stmt, 1)
            let full = sqlite3_column_int64(stmt, 2)
            let sent = sqlite3_column_int64(stmt, 3)
            let path = pathPtr.map { String(cString: $0) } ?? ""
            let saved = max(0, full - sent)
            let pct = full > 0 ? Int((Double(saved) / Double(full) * 100).rounded()) : 0
            rows.append(MeterReport.PerFile(
                file: path,
                reads: reads,
                tokensFull: full,
                tokensSent: sent,
                tokensSaved: saved,
                reductionPct: pct
            ))
        }
        return rows
    }
}
