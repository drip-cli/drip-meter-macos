import Charts
import DripMeterCore
import SwiftUI

/// 7-day / 30-day rollup with average / peak / active days. Sits between
/// the streak panel and the per-agent breakdown so the user sees their
/// rhythm at a glance, not just the headline lifetime total.
struct PeriodStatsView: View {
    enum Window: String, CaseIterable, Identifiable {
        case week
        case month

        var id: String { rawValue }
        var label: String { self == .week ? "7 days" : "30 days" }
        var windowDays: Int { self == .week ? 7 : 30 }
        var displayLabel: String {
            self == .week ? "This week" : "Last 30 days"
        }
    }

    let history: [MeterReport.DayBucket]
    @State private var selected: Window = .week

    var body: some View {
        let stats = history.rollup(windowDays: selected.windowDays, label: selected.displayLabel)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rollup")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                WindowToggle(selected: $selected)
            }

            // Four-up KPI tile row. Each tile shows a metric label + a
            // monospaced number so columns align across the row.
            HStack(spacing: 8) {
                KPITile(label: "Saved", value: DripFormatter.compactInteger(stats.tokensSaved), accent: DripPalette.green)
                KPITile(label: "Avg / day", value: DripFormatter.compactInteger(stats.avgPerDay), accent: DripPalette.greenDark)
                KPITile(label: "Peak", value: DripFormatter.compactInteger(stats.peakDay?.tokensSaved ?? 0), accent: .orange, sub: peakDayLabel(stats.peakDay))
                KPITile(label: "Active", value: "\(stats.activeDays)/\(stats.windowDays)", accent: .blue, sub: "days")
            }

            if !stats.buckets.isEmpty {
                MiniBars(buckets: stats.buckets, peak: stats.peakDay?.tokensSaved ?? 0)
            }

            if stats.tokensFull > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .font(.caption2)
                    Text("\(stats.reductionPct)% reduction · \(DripFormatter.compactInteger(stats.tokensFull)) → \(DripFormatter.compactInteger(stats.tokensSent))")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    private func peakDayLabel(_ bucket: MeterReport.DayBucket?) -> String {
        guard let day = bucket?.day, let date = isoDate(day) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func isoDate(_ s: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: s)
    }
}

private struct WindowToggle: View {
    @Binding var selected: PeriodStatsView.Window

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PeriodStatsView.Window.allCases) { window in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selected = window
                    }
                } label: {
                    Text(window.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(selected == window ? Color.primary : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selected == window ? Color.primary.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(DripPalette.segmentTrack)
        )
    }
}

private struct KPITile: View {
    let label: String
    let value: String
    let accent: Color
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            if let sub, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else {
                // Reserve baseline space so all four tiles have the same
                // height regardless of whether `sub` is populated.
                Text(" ")
                    .font(.system(size: 9))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.6)
        )
    }
}

/// Tiny inline bar chart driven by Swift Charts. Highlights the peak day
/// in orange so the eye lands on it without needing a legend.
private struct MiniBars: View {
    let buckets: [MeterReport.DayBucket]
    let peak: Int64

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Day", bucket.day),
                y: .value("Saved", bucket.tokensSaved)
            )
            .foregroundStyle(
                bucket.tokensSaved == peak && peak > 0
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.orange, .orange.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom))
                    : AnyShapeStyle(LinearGradient(
                        colors: [DripPalette.green, DripPalette.greenDark.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom))
            )
            .cornerRadius(2)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .frame(height: 52)
    }
}
