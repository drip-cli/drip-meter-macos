import DripMeterCore
import SwiftUI

/// GitHub-style "contributions" grid for the last 90 days. Each cell is
/// a tiny rounded square coloured by how many tokens DRIP saved that day
/// (5-bucket logarithmic scale so a 200K outlier doesn't squash the rest
/// of the grid into invisibility).
///
/// Layout is column-major (one column = one week, columns flow left →
/// right oldest → newest), matching GitHub's familiar shape so the user
/// doesn't have to relearn what "up" means.
struct ActivityHeatmapView: View {
    let history: [MeterReport.DayBucket]
    let bestStreak: Int

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        cal.firstWeekday = 2
        return cal
    }()

    var body: some View {
        let grid = buildGrid()
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(grid.activeDays) active days")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            HStack(alignment: .top, spacing: 3) {
                ForEach(grid.weeks.indices, id: \.self) { weekIdx in
                    VStack(spacing: 3) {
                        ForEach(grid.weeks[weekIdx].indices, id: \.self) { dayIdx in
                            HeatCell(cell: grid.weeks[weekIdx][dayIdx])
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("less")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                ForEach(0 ..< 5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HeatCell.color(for: level))
                        .frame(width: 9, height: 9)
                }
                Text("more")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                if bestStreak > 0 {
                    Label("best streak: \(bestStreak)d", systemImage: "trophy.fill")
                        .labelStyle(TightLabelStyle())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            }
        }
    }

    fileprivate struct Cell {
        let date: Date
        let label: String
        let tokensSaved: Int64
        let level: Int // 0..4
        let isPlaceholder: Bool // padding cells before history start
        let isToday: Bool
    }

    private struct Grid {
        let weeks: [[Cell]] // weeks[col][row]
        let activeDays: Int
    }

    private func buildGrid() -> Grid {
        let totalDays = 90
        let today = Date()
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"

        var byDay: [String: MeterReport.DayBucket] = [:]
        for bucket in history { byDay[bucket.day] = bucket }

        // Bucket boundaries (tokensSaved) — log-ish so 1K -> level 1, 10K
        // -> level 2, 50K -> level 3, 200K+ -> level 4. Picked from a few
        // weeks of usage; tune as we see real-world variance.
        let bucketBoundaries: [Int64] = [1, 5_000, 25_000, 100_000]

        // Walk backwards from today (inclusive) for `totalDays` days,
        // then pre-pad to start the first column on Monday so the grid
        // reads like GitHub's.
        var dayBuckets: [(date: Date, bucket: MeterReport.DayBucket?)] = []
        for offset in 0 ..< totalDays {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = formatter.string(from: date)
            dayBuckets.append((date, byDay[key]))
        }
        dayBuckets.reverse() // oldest first

        // Pre-pad with placeholder cells until the first real cell falls
        // on a Monday row.
        if let first = dayBuckets.first {
            let weekday = calendar.component(.weekday, from: first.date)
            let offsetToMonday = (weekday + 5) % 7
            for _ in 0 ..< offsetToMonday {
                dayBuckets.insert((Date.distantPast, nil), at: 0)
            }
        }

        var weeks: [[Cell]] = []
        var current: [Cell] = []
        var activeDays = 0
        for entry in dayBuckets {
            let isPlaceholder = entry.date == .distantPast
            let saved = entry.bucket?.tokensSaved ?? 0
            let level: Int = {
                guard !isPlaceholder, let bucket = entry.bucket, bucket.reads > 0 else { return 0 }
                if saved >= bucketBoundaries[3] { return 4 }
                if saved >= bucketBoundaries[2] { return 3 }
                if saved >= bucketBoundaries[1] { return 2 }
                return 1
            }()
            if !isPlaceholder, (entry.bucket?.reads ?? 0) > 0 { activeDays += 1 }
            let label = isPlaceholder ? "" : dayFormatter.string(from: entry.date)
            current.append(Cell(
                date: entry.date,
                label: label,
                tokensSaved: saved,
                level: level,
                isPlaceholder: isPlaceholder,
                isToday: !isPlaceholder && calendar.isDateInToday(entry.date)
            ))
            if current.count == 7 {
                weeks.append(current)
                current = []
            }
        }
        if !current.isEmpty { weeks.append(current) }
        return Grid(weeks: weeks, activeDays: activeDays)
    }
}

private struct HeatCell: View {
    let cell: ActivityHeatmapView.Cell

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cell.isPlaceholder ? Color.clear : Self.color(for: cell.level))
            .frame(width: 9, height: 9)
            .overlay(
                cell.isToday
                    ? RoundedRectangle(cornerRadius: 2.5).stroke(DripPalette.green, lineWidth: 1)
                    : nil
            )
            .help(cell.isPlaceholder ? "" : "\(cell.label) · \(DripFormatter.compactInteger(cell.tokensSaved)) saved")
    }

    static func color(for level: Int) -> Color {
        switch level {
        case 4: DripPalette.green
        case 3: DripPalette.green.opacity(0.78)
        case 2: DripPalette.green.opacity(0.52)
        case 1: DripPalette.green.opacity(0.28)
        default: DripPalette.segmentTrack
        }
    }
}
