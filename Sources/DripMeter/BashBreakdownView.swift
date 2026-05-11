import DripMeterCore
import SwiftUI

/// Splits the headline savings number into "file reads" vs "bash commands".
/// Compact two-column layout — each card shows its own value, share of the
/// total, and a thin mini-bar so you read it left-to-right without
/// scanning a stacked legend.
struct BashBreakdownView: View {
    let breakdown: MeterReport.SavingsBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Where savings come from")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("total \(DripFormatter.compactInteger(breakdown.total.tokensSaved))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(alignment: .top, spacing: 10) {
                BreakdownCard(
                    label: "File reads",
                    value: breakdown.fileReads.tokensSaved,
                    total: breakdown.total.tokensSaved,
                    accent: DripPalette.green
                )
                BreakdownCard(
                    label: "Bash",
                    value: breakdown.bashCommands.tokensSaved,
                    total: breakdown.total.tokensSaved,
                    accent: DripPalette.greenDeep,
                    sub: bashSub
                )
            }
        }
    }

    private var bashSub: String? {
        let count = breakdown.bashCommands.commandsIntercepted
        guard count > 0 else { return nil }
        return count == 1 ? "1 cmd" : "\(count) cmds"
    }
}

private struct BreakdownCard: View {
    let label: String
    let value: Int64
    let total: Int64
    let accent: Color
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(percent) %")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(DripFormatter.compactInteger(value))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(value > 0 ? .primary : .secondary)
                if let sub {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            MiniBar(percent: percent, accent: accent)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(value) / Double(total) * 100).rounded())
    }
}

private struct MiniBar: View {
    let percent: Int
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DripPalette.segmentTrack)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: proxy.size.width * fraction)
                    .animation(.easeOut(duration: 0.3), value: percent)
            }
        }
        .frame(height: 4)
    }

    private var fraction: CGFloat {
        CGFloat(max(0, min(100, percent))) / 100
    }
}
