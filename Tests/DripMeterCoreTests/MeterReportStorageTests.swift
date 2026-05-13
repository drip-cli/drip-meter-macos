@testable import DripMeterCore
import Foundation
import Testing

@Suite("MeterReport.Storage decoding")
struct MeterReportStorageTests {
    @Test("Decodes the storage block from a real meter --json payload")
    func decodesStorage() throws {
        let json = """
        {
          "scope": "lifetime",
          "session_id": "lifetime",
          "started_at": 0,
          "elapsed_secs": 0,
          "files_tracked": 0,
          "total_reads": 0,
          "files_edited": 0,
          "total_edits": 0,
          "tokens_full": 0,
          "tokens_sent": 0,
          "tokens_saved": 0,
          "reduction_pct": 0,
          "dollars_saved": 0,
          "price_per_mtok": 3.0,
          "co2_g_saved": 0,
          "co2_g_per_ktok": 0.4,
          "top": [],
          "storage": {
            "inline_max_bytes": 32768,
            "inline_rows": 12,
            "inline_bytes": 80000,
            "file_rows": 4,
            "linked_file_rows": 4,
            "unique_hashes": 16,
            "cache_files": 4,
            "cache_size_bytes": 2048000,
            "db_size_bytes": 163840,
            "orphan_files": 1,
            "orphan_bytes": 4096,
            "dedup_savings": 50000,
            "compactable_rows": 3,
            "compactable_bytes": 65000
          }
        }
        """
        let report = try JSONDecoder().decode(MeterReport.self, from: Data(json.utf8))
        let storage = try #require(report.storage)
        #expect(storage.dbSizeBytes == 163_840)
        #expect(storage.cacheSizeBytes == 2_048_000)
        #expect(storage.totalBytes == 2_211_840)
        #expect(storage.compactableBytes == 65000)
        #expect(storage.dedupSavings == 50000)
        #expect(storage.uniqueHashes == 16)
        #expect(storage.orphanFiles == 1)
    }

    @Test("Tolerates a missing storage field")
    func toleratesMissingStorage() throws {
        let json = """
        {
          "scope": "session",
          "session_id": "abc",
          "started_at": 0,
          "elapsed_secs": 0,
          "files_tracked": 0,
          "total_reads": 0,
          "files_edited": 0,
          "total_edits": 0,
          "tokens_full": 0,
          "tokens_sent": 0,
          "tokens_saved": 0,
          "reduction_pct": 0,
          "dollars_saved": 0,
          "price_per_mtok": 3.0,
          "co2_g_saved": 0,
          "co2_g_per_ktok": 0.4,
          "top": []
        }
        """
        let report = try JSONDecoder().decode(MeterReport.self, from: Data(json.utf8))
        #expect(report.storage == nil)
    }
}

@Suite("DripQuickAction wiring")
struct DripQuickActionTests {
    @Test("Reset variants pass --force so the CLI never blocks on stdin")
    func resetVariantsAreNonInteractive() {
        #expect(DripQuickAction.reset.arguments == ["reset"])
        #expect(DripQuickAction.resetStats.arguments == ["reset", "--stats", "--force"])
        #expect(DripQuickAction.resetAll.arguments == ["reset", "--all", "--force"])
    }

    @Test("Only resetAll is marked destructive")
    func destructiveActions() {
        for action in DripQuickAction.allCases {
            if action == .resetAll {
                #expect(action.isDestructive)
            } else {
                #expect(!action.isDestructive)
            }
        }
    }
}

@Suite("CostModel projection math")
struct CostModelTests {
    @Test("Project hours of saving into a monthly dollar figure")
    func projectsMonthlyFromObservedHour() {
        let report = CostModel.sonnet46
        // 100K saved over 1 hour → 2.4M / day → 72M / month → $216 at $3/Mtok
        let projected = report.project(savedTokens: 100_000, elapsedSecs: 3600, horizon: .month)
        #expect(abs(projected - 216.0) < 0.01)
    }

    @Test("Zero elapsed time returns zero (no division-by-zero)")
    func zeroElapsedReturnsZero() {
        #expect(CostModel.sonnet46.project(savedTokens: 1_000_000, elapsedSecs: 0, horizon: .month) == 0)
    }
}

@Suite("MeterReport.Compaction decoding")
struct MeterReportCompactionTests {
    @Test("Decodes the compaction block from the v9 ledger")
    func decodesCompaction() throws {
        let json = """
        {
          "scope": "lifetime",
          "session_id": "lifetime",
          "started_at": 0,
          "elapsed_secs": 0,
          "files_tracked": 0,
          "total_reads": 0,
          "files_edited": 0,
          "total_edits": 0,
          "tokens_full": 0,
          "tokens_sent": 0,
          "tokens_saved": 0,
          "reduction_pct": 0,
          "dollars_saved": 0,
          "price_per_mtok": 3.0,
          "co2_g_saved": 0,
          "co2_g_per_ktok": 0.4,
          "top": [],
          "compaction": {
            "total_compactions": 4,
            "last_compaction_at": 1778334000,
            "last_compaction_age": "5 min ago",
            "tokens_resent_after_compaction": 1234
          }
        }
        """
        let report = try JSONDecoder().decode(MeterReport.self, from: Data(json.utf8))
        let compaction = try #require(report.compaction)
        #expect(compaction.totalCompactions == 4)
        #expect(compaction.lastCompactionAt == 1_778_334_000)
        #expect(compaction.lastCompactionAge == "5 min ago")
        #expect(compaction.tokensResentAfterCompaction == 1234)
    }

    @Test("Compaction block is optional (skip_if_none on the Rust side)")
    func toleratesMissingCompaction() throws {
        let json = """
        {
          "scope": "lifetime",
          "session_id": "lifetime",
          "started_at": 0,
          "elapsed_secs": 0,
          "files_tracked": 0,
          "total_reads": 0,
          "files_edited": 0,
          "total_edits": 0,
          "tokens_full": 0,
          "tokens_sent": 0,
          "tokens_saved": 0,
          "reduction_pct": 0,
          "dollars_saved": 0,
          "price_per_mtok": 3.0,
          "co2_g_saved": 0,
          "co2_g_per_ktok": 0.4,
          "top": []
        }
        """
        let report = try JSONDecoder().decode(MeterReport.self, from: Data(json.utf8))
        #expect(report.compaction == nil)
    }
}

@Suite("CompactionWatcher thresholds")
struct CompactionWatcherTests {
    private func freshDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "io.drip-cli.dripmeter.test.\(UUID().uuidString)")!
        suite.removePersistentDomain(forName: suite.dictionaryRepresentation().keys.first ?? "x")
        return suite
    }

    @Test("Crosses 3 / 5 / 10 thresholds in order, never repeats")
    @MainActor
    func crossesAndRemembers() {
        let watcher = CompactionWatcher(defaults: freshDefaults())

        // Below the smallest threshold — nothing fires.
        #expect(watcher.newlyCrossed(totalCompactions: 2).isEmpty)

        // Crossing 3 fires the .three threshold.
        let firstBatch = watcher.newlyCrossed(totalCompactions: 3)
        #expect(firstBatch.count == 1)
        #expect(firstBatch.first?.count == 3)
        firstBatch.forEach { watcher.markFired($0) }

        // Same level — already fired, nothing new.
        #expect(watcher.newlyCrossed(totalCompactions: 4).isEmpty)

        // Skipping past 5 directly to 10 fires both at once.
        let bigBatch = watcher.newlyCrossed(totalCompactions: 10)
        #expect(bigBatch.map(\.count).sorted() == [5, 10])
    }

    @Test("Reset re-arms every threshold")
    @MainActor
    func resetReFires() {
        let watcher = CompactionWatcher(defaults: freshDefaults())
        let crossed = watcher.newlyCrossed(totalCompactions: 5)
        crossed.forEach { watcher.markFired($0) }
        #expect(watcher.newlyCrossed(totalCompactions: 5).isEmpty)
        watcher.reset()
        #expect(watcher.newlyCrossed(totalCompactions: 5).count == 2)
    }
}

@Suite("Milestone progression")
struct MilestoneCrossingTests {
    @Test("Token milestones fire at the documented thresholds")
    func tokenMilestones() {
        #expect(Milestone.tokens100K.isCrossed(tokensSaved: 99999, dollarsSaved: 0) == false)
        #expect(Milestone.tokens100K.isCrossed(tokensSaved: 100_000, dollarsSaved: 0))
        #expect(Milestone.tokens1M.isCrossed(tokensSaved: 1_000_001, dollarsSaved: 0))
        #expect(Milestone.tokens10M.isCrossed(tokensSaved: 9_999_999, dollarsSaved: 0) == false)
    }

    @Test("Dollar milestones don't fire on tokens alone")
    func dollarVsToken() {
        // Big tokens, zero dollars (e.g. user using a free local model) —
        // dollar milestones must not fire.
        #expect(Milestone.dollars10.isCrossed(tokensSaved: 100_000_000, dollarsSaved: 0) == false)
        #expect(Milestone.dollars10.isCrossed(tokensSaved: 0, dollarsSaved: 10.01))
    }
}
