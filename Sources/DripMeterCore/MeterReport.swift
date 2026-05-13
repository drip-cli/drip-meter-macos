import Foundation

/// Mirror of `drip meter --json` output. Tracks DRIP's renamed-from-`gain`
/// command introduced in commit `25690ec`. Field names match the Rust
/// `MeterReport` struct (see `src/commands/meter.rs` in the DRIP repo).
public struct MeterReport: Codable, Sendable, Equatable {
    public enum Scope: String, Codable, Sendable {
        case lifetime
        case session
    }

    public let scope: Scope
    public let sessionId: String
    public let startedAt: Int64
    public let elapsedSecs: Int64
    public let filesTracked: Int64
    public let totalReads: Int64
    public let filesEdited: Int64
    public let totalEdits: Int64
    public let tokensFull: Int64
    public let tokensSent: Int64
    public let tokensSaved: Int64
    public let reductionPct: Int
    public let dollarsSaved: Double
    public let pricePerMtok: Double
    public let co2GSaved: Double
    public let co2GPerKtok: Double
    public let top: [PerFile]
    public let history: [DayBucket]?
    public let storage: Storage?
    public let compaction: Compaction?

    public init(
        scope: Scope,
        sessionId: String,
        startedAt: Int64,
        elapsedSecs: Int64,
        filesTracked: Int64,
        totalReads: Int64,
        filesEdited: Int64,
        totalEdits: Int64,
        tokensFull: Int64,
        tokensSent: Int64,
        tokensSaved: Int64,
        reductionPct: Int,
        dollarsSaved: Double,
        pricePerMtok: Double,
        co2GSaved: Double,
        co2GPerKtok: Double,
        top: [PerFile],
        history: [DayBucket]? = nil,
        storage: Storage? = nil,
        compaction: Compaction? = nil
    ) {
        self.scope = scope
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.elapsedSecs = elapsedSecs
        self.filesTracked = filesTracked
        self.totalReads = totalReads
        self.filesEdited = filesEdited
        self.totalEdits = totalEdits
        self.tokensFull = tokensFull
        self.tokensSent = tokensSent
        self.tokensSaved = tokensSaved
        self.reductionPct = reductionPct
        self.dollarsSaved = dollarsSaved
        self.pricePerMtok = pricePerMtok
        self.co2GSaved = co2GSaved
        self.co2GPerKtok = co2GPerKtok
        self.top = top
        self.history = history
        self.storage = storage
        self.compaction = compaction
    }

    public struct PerFile: Codable, Sendable, Equatable, Identifiable {
        public let file: String
        public let reads: Int64
        public let tokensFull: Int64
        public let tokensSent: Int64
        public let tokensSaved: Int64
        public let reductionPct: Int

        public init(
            file: String,
            reads: Int64,
            tokensFull: Int64,
            tokensSent: Int64,
            tokensSaved: Int64,
            reductionPct: Int
        ) {
            self.file = file
            self.reads = reads
            self.tokensFull = tokensFull
            self.tokensSent = tokensSent
            self.tokensSaved = tokensSaved
            self.reductionPct = reductionPct
        }

        public var id: String {
            file
        }

        enum CodingKeys: String, CodingKey {
            case file
            case reads
            case tokensFull = "tokens_full"
            case tokensSent = "tokens_sent"
            case tokensSaved = "tokens_saved"
            case reductionPct = "reduction_pct"
        }
    }

    public struct DayBucket: Codable, Sendable, Equatable, Identifiable {
        public let day: String
        public let reads: Int64
        public let tokensFull: Int64
        public let tokensSent: Int64
        public let tokensSaved: Int64
        public let reductionPct: Int

        public init(
            day: String,
            reads: Int64,
            tokensFull: Int64,
            tokensSent: Int64,
            tokensSaved: Int64,
            reductionPct: Int
        ) {
            self.day = day
            self.reads = reads
            self.tokensFull = tokensFull
            self.tokensSent = tokensSent
            self.tokensSaved = tokensSaved
            self.reductionPct = reductionPct
        }

        public var id: String {
            day
        }

        enum CodingKeys: String, CodingKey {
            case day
            case reads
            case tokensFull = "tokens_full"
            case tokensSent = "tokens_sent"
            case tokensSaved = "tokens_saved"
            case reductionPct = "reduction_pct"
        }
    }

    /// Mirror of the `compaction` block introduced in DRIP schema v9.
    /// Reports how often Claude/Codex/Gemini have hit their context limit
    /// and reset DRIP's baselines, plus the cost (in re-sent input tokens)
    /// of those reset events. Absent on installs without compaction
    /// activity yet — the Rust side uses `skip_if_none` serialization.
    public struct Compaction: Codable, Sendable, Equatable {
        public let totalCompactions: Int64
        public let lastCompactionAt: Int64?
        public let lastCompactionAge: String?
        public let tokensResentAfterCompaction: Int64

        public init(
            totalCompactions: Int64,
            lastCompactionAt: Int64? = nil,
            lastCompactionAge: String? = nil,
            tokensResentAfterCompaction: Int64
        ) {
            self.totalCompactions = totalCompactions
            self.lastCompactionAt = lastCompactionAt
            self.lastCompactionAge = lastCompactionAge
            self.tokensResentAfterCompaction = tokensResentAfterCompaction
        }

        enum CodingKeys: String, CodingKey {
            case totalCompactions = "total_compactions"
            case lastCompactionAt = "last_compaction_at"
            case lastCompactionAge = "last_compaction_age"
            case tokensResentAfterCompaction = "tokens_resent_after_compaction"
        }
    }

    /// Mirror of the `storage` block in `drip meter --json`. Surfaces how
    /// much DB / cache space DRIP is using and how much could be reclaimed
    /// via `drip cache compact`.
    public struct Storage: Codable, Sendable, Equatable {
        public let inlineMaxBytes: Int64
        public let inlineRows: Int64
        public let inlineBytes: Int64
        public let fileRows: Int64
        public let linkedFileRows: Int64
        public let uniqueHashes: Int64
        public let cacheFiles: Int64
        public let cacheSizeBytes: Int64
        public let dbSizeBytes: Int64
        public let orphanFiles: Int64
        public let orphanBytes: Int64
        public let dedupSavings: Int64
        public let compactableRows: Int64
        public let compactableBytes: Int64

        public var totalBytes: Int64 {
            dbSizeBytes + cacheSizeBytes
        }

        enum CodingKeys: String, CodingKey {
            case inlineMaxBytes = "inline_max_bytes"
            case inlineRows = "inline_rows"
            case inlineBytes = "inline_bytes"
            case fileRows = "file_rows"
            case linkedFileRows = "linked_file_rows"
            case uniqueHashes = "unique_hashes"
            case cacheFiles = "cache_files"
            case cacheSizeBytes = "cache_size_bytes"
            case dbSizeBytes = "db_size_bytes"
            case orphanFiles = "orphan_files"
            case orphanBytes = "orphan_bytes"
            case dedupSavings = "dedup_savings"
            case compactableRows = "compactable_rows"
            case compactableBytes = "compactable_bytes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case scope
        case sessionId = "session_id"
        case startedAt = "started_at"
        case elapsedSecs = "elapsed_secs"
        case filesTracked = "files_tracked"
        case totalReads = "total_reads"
        case filesEdited = "files_edited"
        case totalEdits = "total_edits"
        case tokensFull = "tokens_full"
        case tokensSent = "tokens_sent"
        case tokensSaved = "tokens_saved"
        case reductionPct = "reduction_pct"
        case dollarsSaved = "dollars_saved"
        case pricePerMtok = "price_per_mtok"
        case co2GSaved = "co2_g_saved"
        case co2GPerKtok = "co2_g_per_ktok"
        case top
        case history
        case storage
        case compaction
    }

    /// An empty report — used as a placeholder before the first refresh and as a
    /// safe value when the binary isn't installed yet.
    public static let empty = MeterReport(
        scope: .lifetime,
        sessionId: "",
        startedAt: 0,
        elapsedSecs: 0,
        filesTracked: 0,
        totalReads: 0,
        filesEdited: 0,
        totalEdits: 0,
        tokensFull: 0,
        tokensSent: 0,
        tokensSaved: 0,
        reductionPct: 0,
        dollarsSaved: 0,
        pricePerMtok: 3.0,
        co2GSaved: 0,
        co2GPerKtok: 0.4,
        top: [],
        history: []
    )
}
