import DripMeterCore
import SwiftUI

/// Richer "are you on a roll?" panel that replaces the old DailyTargetView.
///
/// Layout, top → bottom:
///   1. Header row — eyebrow "TODAY" left, streak badges right ("🔥 12d"
///      and "best 23" when the user has ever broken the current run).
///   2. Hero figure — today's tokens-saved big number + target progress
///      pill, with a thick mint progress bar underneath.
///   3. Week strip — Mon..Sun dots filled in for days with activity, the
///      today dot ringed. Lets you see "did I touch DRIP this week?"
///      without clicking through to a stats tab.
///
/// Animations:
///   - The streak flame pulses (scale + brightness) when streak ≥ 3.
///   - Today's number animates in via CountUp on mount.
///   - The progress bar fills with an ease-out on every refresh.
///   - When today's progress crosses 100 %, a "Target hit" celebration
///     badge slides up with a green checkmark.
struct StreakPanelView: View {
    let today: DailyTotal
    let target: Int64
    let streak: Int
    let bestStreak: Int
    let history: [MeterReport.DayBucket]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            heroRow
            ProgressBar(progress: progress)
            if progress >= 1 {
                Label("Target hit", systemImage: "checkmark.seal.fill")
                    .labelStyle(TightLabelStyle())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            WeekStripView(history: history)
        }
        .animation(.easeOut(duration: 0.35), value: progress)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if streak > 0 {
                FlameBadge(days: streak)
            }
            if bestStreak > streak, bestStreak > 0 {
                Text("best \(bestStreak)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 6)
            } else if bestStreak == streak, streak >= 3 {
                Label("personal best", systemImage: "trophy.fill")
                    .labelStyle(TightLabelStyle())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .padding(.leading, 6)
            }
        }
    }

    private var heroRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(DripFormatter.compactInteger(today.tokensSaved))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(today.tokensSaved)))
            Text("saved today")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("target \(DripFormatter.compactInteger(target))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(today.tokensSaved) / Double(target))
    }
}

/// Pulsing flame icon + day count. The pulse only kicks in at 3+ days
/// so a 1-day streak doesn't look like a fake celebration.
private struct FlameBadge: View {
    let days: Int
    @State private var pulse = false

    var body: some View {
        Label("\(days)-day streak", systemImage: "flame.fill")
            .labelStyle(TightLabelStyle())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .scaleEffect(pulse && days >= 3 ? 1.05 : 1.0)
            .shadow(color: .orange.opacity(pulse && days >= 3 ? 0.45 : 0), radius: 6)
            .onAppear {
                guard days >= 3 else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

/// Mon..Sun activity strip. Each day is a dot — filled mint when there
/// was activity, hollow grey otherwise. Today's dot gets a ring.
private struct WeekStripView: View {
    let history: [MeterReport.DayBucket]

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    var body: some View {
        let days = buildWeek()
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 4) {
                        Text(day.shortLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                        Dot(active: day.active, isToday: day.isToday, isFuture: day.isFuture)
                    }
                    .frame(maxWidth: .infinity)
                    .help(day.helpText)
                }
            }
        }
    }

    private struct DayCell {
        let date: Date
        let shortLabel: String
        let active: Bool
        let isToday: Bool
        let isFuture: Bool
        let tokensSaved: Int64
        var helpText: String {
            if isFuture { return "\(shortLabel) · upcoming" }
            return "\(shortLabel) · \(DripFormatter.compactInteger(tokensSaved)) saved"
        }
    }

    private func buildWeek() -> [DayCell] {
        let today = Date()
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        // Index history by day for O(1) lookup.
        var byDay: [String: MeterReport.DayBucket] = [:]
        for bucket in history {
            byDay[bucket.day] = bucket
        }

        // Compute the Monday-anchored week containing today.
        let weekday = calendar.component(.weekday, from: today)
        // weekday: 1 = Sunday, 2 = Monday, …, 7 = Saturday. With
        // firstWeekday = 2 we want offset 0 for Mon, 6 for Sun.
        let offsetToMonday = ((weekday + 5) % 7)
        let monday = calendar.date(byAdding: .day, value: -offsetToMonday, to: today) ?? today

        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return (0 ..< 7).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: monday) ?? monday
            let key = formatter.string(from: date)
            let bucket = byDay[key]
            return DayCell(
                date: date,
                shortLabel: labels[i],
                active: (bucket?.reads ?? 0) > 0,
                isToday: calendar.isDateInToday(date),
                isFuture: date > today && !calendar.isDateInToday(date),
                tokensSaved: bucket?.tokensSaved ?? 0
            )
        }
    }

    private struct Dot: View {
        let active: Bool
        let isToday: Bool
        let isFuture: Bool

        var body: some View {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 9, height: 9)
                if isToday {
                    Circle()
                        .stroke(DripPalette.green, lineWidth: 1.2)
                        .frame(width: 14, height: 14)
                }
            }
            .frame(width: 16, height: 16)
        }

        private var fill: Color {
            if isFuture { return DripPalette.segmentTrack.opacity(0.4) }
            if active { return DripPalette.green }
            return DripPalette.segmentTrack
        }
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DripPalette.segmentTrack)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [DripPalette.green, DripPalette.greenDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(0, proxy.size.width * CGFloat(progress)))
                    .shadow(color: DripPalette.green.opacity(progress >= 1 ? 0.6 : 0.25), radius: 4)
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 8)
    }
}
