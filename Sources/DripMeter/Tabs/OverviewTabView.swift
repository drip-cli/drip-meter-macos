import DripMeterCore
import SwiftUI

/// Overview tab. The "snapshot" view — what's happening *right now*.
/// Time-series and historical rollup live in the dedicated Stats tab
/// so this view stays focused on today + the live agents/files state.
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
