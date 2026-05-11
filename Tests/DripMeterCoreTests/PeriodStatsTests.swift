import Foundation
import Testing
@testable import DripMeterCore

@Suite("PeriodStats rollup")
struct PeriodStatsTests {
    private func bucket(_ day: String, full: Int64, sent: Int64, reads: Int64) -> MeterReport.DayBucket {
        let saved = max(0, full - sent)
        let pct = full > 0 ? Int((Double(saved) / Double(full) * 100).rounded()) : 0
        return MeterReport.DayBucket(
            day: day,
            reads: reads,
            tokensFull: full,
            tokensSent: sent,
            tokensSaved: saved,
            reductionPct: pct
        )
    }

    @Test("Empty history rolls up to all zeros")
    func emptyHistory() {
        let stats: [MeterReport.DayBucket] = []
        let rolled = stats.rollup(windowDays: 7, label: "")
        #expect(rolled.tokensSaved == 0)
        #expect(rolled.activeDays == 0)
        #expect(rolled.avgPerDay == 0)
        #expect(rolled.peakDay == nil)
        #expect(rolled.buckets.isEmpty)
    }

    @Test("Window larger than history just sums what's there")
    func windowLargerThanHistory() {
        let buckets = [
            bucket("2026-05-01", full: 1_000, sent: 200, reads: 10),
            bucket("2026-05-02", full: 4_000, sent: 1_000, reads: 30),
        ]
        let rolled = buckets.rollup(windowDays: 30, label: "")
        #expect(rolled.tokensSaved == 3_800)
        #expect(rolled.activeDays == 2)
        // Average is over the **full** 30-day window, not the 2 days
        // present — `3800 / 30 = 126.67 → 127`.
        #expect(rolled.avgPerDay == 127)
        #expect(rolled.avgPerActiveDay == 1_900)
    }

    @Test("Peak day picks the bucket with max tokensSaved")
    func peakDay() {
        let buckets = [
            bucket("2026-05-01", full: 1_000, sent: 200, reads: 10),
            bucket("2026-05-02", full: 9_000, sent: 1_000, reads: 50),
            bucket("2026-05-03", full: 2_000, sent: 200, reads: 20),
        ]
        let rolled = buckets.rollup(windowDays: 7, label: "")
        #expect(rolled.peakDay?.day == "2026-05-02")
        #expect(rolled.peakDay?.tokensSaved == 8_000)
    }

    @Test("Zero-read buckets don't count as active even if tokensSaved is non-zero")
    func zeroReadIsInactive() {
        // Edge case: a phantom bucket with savings but no reads (shouldn't
        // happen in practice but the rollup contract is "active = reads > 0").
        let buckets = [
            bucket("2026-05-01", full: 1_000, sent: 200, reads: 0),
            bucket("2026-05-02", full: 4_000, sent: 1_000, reads: 30),
        ]
        let rolled = buckets.rollup(windowDays: 7, label: "")
        #expect(rolled.activeDays == 1)
        #expect(rolled.tokensSaved == 3_800)
    }

    @Test("Reduction percentage matches the headline formula")
    func reductionPct() {
        let buckets = [
            bucket("2026-05-01", full: 10_000, sent: 2_000, reads: 50),
            bucket("2026-05-02", full: 10_000, sent: 2_000, reads: 50),
        ]
        let rolled = buckets.rollup(windowDays: 7, label: "")
        #expect(rolled.reductionPct == 80)
    }
}

@Suite("UsageReport markdown")
struct UsageReportTests {
    @Test("Renders title + lifetime + streak sections")
    func renders() {
        let report = MeterReport(
            scope: .lifetime,
            sessionId: "lifetime",
            startedAt: 0,
            elapsedSecs: 86_400,
            filesTracked: 12,
            totalReads: 200,
            filesEdited: 4,
            totalEdits: 20,
            tokensFull: 100_000,
            tokensSent: 20_000,
            tokensSaved: 80_000,
            reductionPct: 80,
            dollarsSaved: 0.24,
            pricePerMtok: 3.0,
            co2GSaved: 32,
            co2GPerKtok: 0.4,
            top: [],
            history: [
                MeterReport.DayBucket(day: "2026-05-10", reads: 50, tokensFull: 20_000, tokensSent: 4_000, tokensSaved: 16_000, reductionPct: 80),
                MeterReport.DayBucket(day: "2026-05-11", reads: 100, tokensFull: 50_000, tokensSent: 10_000, tokensSaved: 40_000, reductionPct: 80),
            ]
        )
        let input = UsageReport.Input(
            report: report,
            agents: [
                AgentBreakdown(agent: .claude, sessions: 2, filesTracked: 12, tokensFull: 100_000, tokensSent: 20_000, lastActiveAt: nil),
            ],
            topFiles: [],
            currentStreak: 5,
            bestStreak: 12,
            activeDaysThisWeek: 5,
            pricePerMtok: 3.0
        )
        let md = UsageReport.markdown(input)
        #expect(md.contains("# DRIP usage report"))
        #expect(md.contains("## Lifetime totals"))
        #expect(md.contains("**80,000**"))
        #expect(md.contains("Current streak: **5 days**"))
        #expect(md.contains("Best ever: **12 days**"))
        #expect(md.contains("Active days this week (Mon–Sun): **5/7**"))
        #expect(md.contains("## Last 7 days"))
        #expect(md.contains("## Last 30 days"))
        #expect(md.contains("Claude Code"))
    }

    @Test("Suggested filename has the ISO-ish stamp shape")
    func filename() {
        let date = Date(timeIntervalSince1970: 1_731_504_000) // 2024-11-13 12:00 UTC
        let name = UsageReport.suggestedFilename(for: date)
        #expect(name.hasPrefix("DRIP-usage-"))
        #expect(name.hasSuffix(".md"))
    }
}
