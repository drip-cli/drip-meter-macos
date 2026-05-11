import DripMeterCore
import SwiftUI

/// Overview tab. Owns the big "X tokens saved" hero card plus several
/// subordinate panels. Order matters: hero → streak → rollup → heatmap
/// → compaction → per-agent → cost → top files. The heatmap sits right
/// after the rollup so it's reachable without scrolling on a default-
/// height popover. Each panel renders only when there's something
/// meaningful to show.
struct OverviewTabView: View {
    @Environment(DripStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderCardView(report: store.report, compact: settings.compactMode)

            if settings.dailyTokenTarget > 0 {
                Divider()
                StreakPanelView(
                    today: store.todayTotal,
                    target: settings.dailyTokenTarget,
                    streak: store.streakDays,
                    bestStreak: settings.bestStreakDays,
                    history: store.report.history ?? []
                )
            }

            // Rollup renders as soon as DRIP has *any* history bucket.
            // The previous `count >= 2` gate meant a freshly-installed
            // user never saw the panel and assumed it didn't exist.
            // With one day's data the tiles show today's value as both
            // total and peak, avg/day as `tokensSaved / 7`, active 1/7
            // — still informative, and the panel grows naturally as
            // more days roll in.
            if let history = store.report.history, !history.isEmpty {
                Divider()
                PeriodStatsView(history: history)
            }

            // Heatmap renders even on the very first day, when DRIP has
            // a single history bucket — the grid shows mostly-empty
            // cells with today's lit, which is itself a satisfying
            // "you started today" view. Without this the panel would
            // hide for new users and look broken.
            if let history = store.report.history {
                Divider()
                ActivityHeatmapView(
                    history: history,
                    bestStreak: settings.bestStreakDays
                )
            }

            if let compaction = store.report.compaction,
               compaction.totalCompactions > 0 {
                Divider()
                CompactionPanelView(
                    compaction: compaction,
                    totalTokensSaved: store.report.tokensSaved
                )
            }

            Divider()
            AgentBreakdownView(
                agents: store.agents.filter { settings.enabledAgents.contains($0.agent) }
            )
            Divider()
            CostProjectionView(report: store.report)

            if !store.report.top.isEmpty {
                Divider()
                TopFilesView(files: Array(store.report.top.prefix(3)))
            }
        }
    }
}
