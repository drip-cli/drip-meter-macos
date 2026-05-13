import DripMeterCore
import SwiftUI

/// Stats tab — historical rollup, activity heatmap, best days, lifetime
/// summary. Lives in its own tab so the Overview tab can stay focused
/// on the live snapshot. Everything here reads from
/// `store.report.history` (the daily bucket array from
/// `drip meter --history --json`).
struct StatsTabView: View {
    @Environment(DripStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let history = store.report.history ?? []
        VStack(alignment: .leading, spacing: 16) {
            LifetimeSummaryCard(
                report: store.report,
                currentStreak: store.streakDays,
                bestStreak: settings.bestStreakDays
            )

            if !history.isEmpty {
                Divider()
                PeriodStatsView(history: history)
                Divider()
                ActivityHeatmapView(
                    history: history,
                    bestStreak: settings.bestStreakDays
                )
                Divider()
                BestDaysListView(history: history)
            } else {
                Divider()
                EmptyHistoryHint()
            }
        }
    }
}

/// Top-of-tab summary: lifetime totals + streak in 4 KPI tiles. Sits
/// above the rollup so the visitor sees the big numbers before drilling
/// down to per-day stats.
private struct LifetimeSummaryCard: View {
    let report: MeterReport
    let currentStreak: Int
    let bestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lifetime")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if report.totalReads > 0 {
                    Text(
                        "\(DripFormatter.compactInteger(report.totalReads)) reads · \(DripFormatter.compactInteger(report.filesTracked)) files"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 8) {
                LifetimeTile(
                    label: "Saved",
                    value: DripFormatter.compactInteger(report.tokensSaved),
                    sub: "\(report.reductionPct)% reduction",
                    accent: DripPalette.green
                )
                LifetimeTile(
                    label: "Dollars",
                    value: String(format: "$%.2f", report.dollarsSaved),
                    sub: String(format: "%.2f $/Mtok", report.pricePerMtok),
                    accent: .yellow
                )
                LifetimeTile(
                    label: "CO₂",
                    value: String(format: "%.0fg", report.co2GSaved),
                    sub: "carbon spared",
                    accent: .cyan
                )
                LifetimeTile(
                    label: "Streak",
                    value: "\(currentStreak)d",
                    sub: bestStreak > 0 ? "best \(bestStreak)d" : nil,
                    accent: .orange
                )
            }
        }
    }
}

private struct LifetimeTile: View {
    let label: String
    let value: String
    var sub: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(sub ?? " ")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.6)
        )
    }
}

/// Top-5 best days of all time. Drives a sense of "I want to beat my
/// peak" — same psychology as the streak panel but for non-consecutive
/// records.
private struct BestDaysListView: View {
    let history: [MeterReport.DayBucket]

    private var sorted: [MeterReport.DayBucket] {
        history.sorted { $0.tokensSaved > $1.tokensSaved }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Best days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("top 5")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ForEach(Array(sorted.prefix(5).enumerated()), id: \.element.day) { index, bucket in
                BestDayRow(rank: index + 1, bucket: bucket, max: sorted.first?.tokensSaved ?? 0)
            }
        }
    }
}

private struct BestDayRow: View {
    let rank: Int
    let bucket: MeterReport.DayBucket
    let max: Int64

    private var ratio: CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(Double(bucket.tokensSaved) / Double(max))
    }

    private var prettyDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: bucket.day) else { return bucket.day }
        formatter.dateFormat = "EEE MMM d"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(rank)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .leading)
            Text(prettyDate)
                .font(.caption.weight(.medium))
                .frame(width: 92, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DripPalette.segmentTrack)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [DripPalette.green, DripPalette.greenDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: Swift.max(0, proxy.size.width * ratio))
                }
            }
            .frame(height: 6)
            Text(DripFormatter.compactInteger(bucket.tokensSaved))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
    }
}

private struct EmptyHistoryHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No history yet", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(
                "Wire DRIP into an agent and your daily savings will start filling this tab — rollup, heatmap and best days will surface automatically."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
