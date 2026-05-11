import DripMeterCore
import SwiftUI

/// Shows today's tokens-saved progress vs the user's target, plus a streak
/// counter for consecutive days of activity. Hidden when the target is set
/// to 0 (user opted out via Settings).
struct DailyTargetView: View {
    let today: DailyTotal
    let target: Int64
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if streak > 0 {
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .labelStyle(TightLabelStyle())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(DripFormatter.compactInteger(today.tokensSaved))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text("saved today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("target \(DripFormatter.compactInteger(target))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressBar(progress: progress)

            if progress >= 1 {
                Label("Target hit", systemImage: "checkmark.seal.fill")
                    .labelStyle(TightLabelStyle())
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(today.tokensSaved) / Double(target))
    }
}

/// Shared label style with a 3 pt icon-text gap. Matches the agent install
/// badges in `AgentsTabView` so all small status-pills feel consistent.
struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
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
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: 8)
    }
}
