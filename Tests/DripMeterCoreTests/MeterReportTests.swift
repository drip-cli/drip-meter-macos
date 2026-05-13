@testable import DripMeterCore
import Foundation
import Testing

@Suite("MeterReport JSON decoding")
struct MeterReportTests {
    @Test("Decodes a real lifetime payload")
    func decodesLifetimePayload() throws {
        let json = """
        {
          "scope": "lifetime",
          "session_id": "lifetime",
          "started_at": 1731000000,
          "elapsed_secs": 86400,
          "files_tracked": 47,
          "total_reads": 312,
          "files_edited": 18,
          "total_edits": 62,
          "tokens_full": 133300,
          "tokens_sent": 30500,
          "tokens_saved": 102800,
          "reduction_pct": 77,
          "dollars_saved": 0.31,
          "price_per_mtok": 3.0,
          "co2_g_saved": 41.0,
          "co2_g_per_ktok": 0.4,
          "top": [
            {
              "file": "src/app.py",
              "reads": 34,
              "tokens_full": 8800,
              "tokens_sent": 600,
              "tokens_saved": 8200,
              "reduction_pct": 94
            }
          ],
          "history": [
            {
              "day": "2026-05-01",
              "reads": 12,
              "tokens_full": 5000,
              "tokens_sent": 1200,
              "tokens_saved": 3800,
              "reduction_pct": 76
            }
          ]
        }
        """

        let report = try JSONDecoder().decode(MeterReport.self, from: Data(json.utf8))
        #expect(report.scope == .lifetime)
        #expect(report.tokensSaved == 102_800)
        #expect(report.reductionPct == 77)
        #expect(report.top.first?.file == "src/app.py")
        #expect(report.top.first?.reductionPct == 94)
        #expect(report.history?.first?.day == "2026-05-01")
    }

    @Test("Tolerates a missing history field")
    func toleratesMissingHistory() throws {
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
        #expect(report.history == nil)
        #expect(report.scope == .session)
    }
}

@Suite("DripAgent tag normalisation")
struct DripAgentTests {
    @Test("Recognises the persisted tags")
    func recognisesPersistedTags() {
        #expect(DripAgent(rawTag: "claude") == .claude)
        #expect(DripAgent(rawTag: "Codex") == .codex)
        #expect(DripAgent(rawTag: "GEMINI") == .gemini)
        #expect(DripAgent(rawTag: nil) == nil)
        #expect(DripAgent(rawTag: "shell") == nil)
    }
}

@Suite("DripFormatter")
struct DripFormatterTests {
    @Test("Compact integer formatter")
    func compactIntegerFormatter() {
        #expect(DripFormatter.compactInteger(0) == "0")
        #expect(DripFormatter.compactInteger(999) == "999")
        #expect(DripFormatter.compactInteger(1000) == "1K")
        #expect(DripFormatter.compactInteger(102_800).hasSuffix("K"))
        #expect(DripFormatter.compactInteger(2_500_000) == "2.5M")
    }

    @Test("Path shortening keeps the tail")
    func pathShorteningKeepsTail() {
        let path = "/Users/me/code/very/deep/project/src/components/widget.swift"
        let shortened = DripFormatter.shortenPath(path, maxLength: 24)
        #expect(shortened.count <= 24)
        #expect(shortened.hasPrefix("…"))
        #expect(shortened.hasSuffix("widget.swift"))
    }
}

@Suite("AgentBreakdown derived stats")
struct AgentBreakdownTests {
    @Test("Computes saved + percent")
    func computesSavedAndPercent() {
        let row = AgentBreakdown(
            agent: .claude,
            sessions: 3,
            filesTracked: 12,
            tokensFull: 10000,
            tokensSent: 2500,
            lastActiveAt: nil
        )
        #expect(row.tokensSaved == 7500)
        #expect(row.reductionPct == 75)
        #expect(row.hasActivity)
    }

    @Test("Empty rows report zero")
    func emptyRowsReportZero() {
        let row = AgentBreakdown(
            agent: .codex,
            sessions: 0,
            filesTracked: 0,
            tokensFull: 0,
            tokensSent: 0,
            lastActiveAt: nil
        )
        #expect(row.tokensSaved == 0)
        #expect(row.reductionPct == 0)
        #expect(!row.hasActivity)
    }
}
