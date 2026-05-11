import DripMeterCore
import SwiftUI

/// The big-numbers panel at the top of the popover. Tightened layout:
/// mini-stats use a 3-column `Grid` with a 4-pt icon→text gap so the icon
/// sticks visually to its label.
struct HeaderCardView: View {
    let report: MeterReport
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(DripFormatter.compactInteger(report.tokensSaved))
                    .font(.system(size: compact ? 24 : 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("tokens saved")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            // Explicit padding around the efficiency bar — VStack's default
            // `spacing` collapsed the gap and the user reported the bar
            // felt squeezed against the headline + the stats row.
            .padding(.bottom, compact ? 10 : 14)

            EfficiencyBar(percent: report.reductionPct)
                .padding(.bottom, compact ? 10 : 14)

            HStack(spacing: 8) {
                Stat(label: "Saved", value: "\(report.reductionPct) %")
                Divider().frame(height: 22)
                Stat(label: "Money", value: DripFormatter.dollars(report.dollarsSaved))
                Divider().frame(height: 22)
                Stat(label: "CO₂", value: DripFormatter.grams(report.co2GSaved))
            }

            if !compact {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        miniStat(symbol: "doc.text", text: "\(report.filesTracked) files")
                        miniStat(symbol: "arrow.down.circle", text: "\(report.totalReads) reads")
                        miniStat(symbol: "pencil", text: "\(report.totalEdits) edits")
                    }
                }
            }
        }
    }

    private func miniStat(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body.weight(.semibold))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EfficiencyBar: View {
    let percent: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.18))
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [DripPalette.green, DripPalette.greenDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, percent))) / 100)
                    .animation(.easeOut(duration: 0.4), value: percent)
            }
        }
        .frame(height: 8)
    }
}
