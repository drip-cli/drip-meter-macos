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

        var id: String {
            rawValue
        }

        var label: String {
            self == .week ? "7 days" : "30 days"
        }

        var windowDays: Int {
            self == .week ? 7 : 30
        }

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
                KPITile(
                    label: "Saved",
                    value: DripFormatter.compactInteger(stats.tokensSaved),
                    accent: DripPalette.green
                )
                KPITile(
                    label: "Avg / day",
                    value: DripFormatter.compactInteger(stats.avgPerDay),
                    accent: DripPalette.greenDark
                )
                KPITile(
                    label: "Peak",
                    value: DripFormatter.compactInteger(stats.peakDay?.tokensSaved ?? 0),
                    accent: .orange,
                    sub: peakDayLabel(stats.peakDay)
                )
                KPITile(label: "Active", value: "\(stats.activeDays)/\(stats.windowDays)", accent: .blue, sub: "days")
            }

            // Always render a full N-day strip even if history only has
            // 1 or 2 buckets — pad missing days with zero. Otherwise
            // Swift Charts stretches the lone non-empty bar across the
            // whole frame, which reads as a hideous orange wall.
            MiniBars(
                buckets: paddedWindow(stats.buckets, windowDays: stats.windowDays),
                peak: stats.peakDay?.tokensSaved ?? 0
            )

            if stats.tokensFull > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .font(.caption2)
                    Text(
                        "\(stats.reductionPct)% reduction · \(DripFormatter.compactInteger(stats.tokensFull)) → \(DripFormatter.compactInteger(stats.tokensSent))"
                    )
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

    /// Build a continuous `windowDays`-long strip ending today (UTC).
    /// Any day not present in `buckets` becomes a zero-token entry, so
    /// the chart always shows the same number of bars and the existing
    /// activity is positioned where it actually happened in time —
    /// instead of one giant bar taking up the whole frame.
    private func paddedWindow(_ buckets: [MeterReport.DayBucket], windowDays: Int) -> [MeterReport.DayBucket] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        var byDay: [String: MeterReport.DayBucket] = [:]
        for bucket in buckets {
            byDay[bucket.day] = bucket
        }

        let today = Date()
        return (0 ..< windowDays).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let key = formatter.string(from: date)
            if let real = byDay[key] { return real }
            return MeterReport.DayBucket(
                day: key,
                reads: 0,
                tokensFull: 0,
                tokensSent: 0,
                tokensSaved: 0,
                reductionPct: 0
            )
        }
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
/// in orange so the eye lands on it without needing a legend. X axis
/// renders a short "MMM d" label on 3-4 evenly-spaced ticks instead of
/// the raw ISO date — the full `yyyy-MM-dd` strings overlapped at the
/// 7-bar width.
private struct MiniBars: View {
    let buckets: [MeterReport.DayBucket]
    let peak: Int64

    private struct BarPoint: Identifiable {
        let id: String
        let date: Date
        let tokensSaved: Int64
    }

    private var points: [BarPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return buckets.compactMap { bucket in
            guard let date = formatter.date(from: bucket.day) else { return nil }
            return BarPoint(id: bucket.day, date: date, tokensSaved: bucket.tokensSaved)
        }
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Saved", point.tokensSaved)
            )
            .foregroundStyle(
                point.tokensSaved == peak && peak > 0
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.orange, .orange.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    : AnyShapeStyle(LinearGradient(
                        colors: [DripPalette.green, DripPalette.greenDark.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .cornerRadius(2)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
        }
        .frame(height: 56)
    }
}
