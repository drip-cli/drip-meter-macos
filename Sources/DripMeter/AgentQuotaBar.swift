import DripMeterCore
import SwiftUI

/// Provider quota progress bar shown inside the per-agent card. Reads
/// from CodexBar's snapshots — see `CodexBarBridge`. Renders nothing when
/// no snapshot is available; callers can use `AgentQuotaBar.empty()` to
/// branch on that.
struct AgentQuotaBar: View {
    let snapshot: AgentQuotaSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(snapshot.percentUsed)% used")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                if let label = snapshot.label, !label.isEmpty {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let resetsAt = snapshot.resetsAt {
                    Label(resetCountdown(resetsAt), systemImage: "clock")
                        .labelStyle(TightLabelStyle())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            QuotaBar(percent: snapshot.percentUsed)
            if snapshot.isStale {
                Text("Stale — open CodexBar to refresh")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func resetCountdown(_ resetsAt: Date) -> String {
        let interval = resetsAt.timeIntervalSinceNow
        if interval <= 0 { return "resetting…" }
        let hours = Int(interval / 3600)
        let mins = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 24 {
            return "resets in \(hours / 24)d"
        }
        if hours >= 1 {
            return "resets in \(hours)h \(mins)m"
        }
        return "resets in \(mins)m"
    }
}

private struct QuotaBar: View {
    let percent: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(DripPalette.segmentTrack)
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: proxy.size.width * fraction)
                    .animation(.easeOut(duration: 0.3), value: percent)
            }
        }
        .frame(height: 6)
    }

    private var fraction: CGFloat {
        CGFloat(max(0, min(100, percent))) / 100.0
    }

    /// Colour ramp: green up to 60 %, orange 60-85 %, red above. Matches
    /// the visual idiom Apple uses for storage / battery indicators.
    private var gradient: [Color] {
        switch percent {
        case ..<60: [DripPalette.green, DripPalette.greenDark]
        case 60 ..< 85: [.orange, .orange.opacity(0.85)]
        default: [.red, .red.opacity(0.85)]
        }
    }
}
