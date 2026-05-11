import DripMeterCore
import SwiftUI

/// Overview tab. Owns the big "X tokens saved" hero card plus several
/// subordinate panels. Order matters: hero → daily target → compaction →
/// per-agent → cost projection → top files → sparkline. Each one renders
/// only when there's something meaningful to show.
struct OverviewTabView: View {
    @Environment(DripStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderCardView(report: store.report, compact: settings.compactMode)

            if settings.dailyTokenTarget > 0 {
                Divider()
                DailyTargetView(
                    today: store.todayTotal,
                    target: settings.dailyTokenTarget,
                    streak: store.streakDays
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
            if let history = store.report.history, !history.isEmpty {
                Divider()
                HistorySparklineView(history: history)
            }
        }
    }
}
