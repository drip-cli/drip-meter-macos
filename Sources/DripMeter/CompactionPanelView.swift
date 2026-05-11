import DripMeterCore
import SwiftUI

/// Surfaces DRIP's v9 context-compaction ledger on the Overview tab.
/// Hidden when no compactions have happened yet — the panel exists to
/// explain a *cost*, so showing zeros would just be noise.
struct CompactionPanelView: View {
    let compaction: MeterReport.Compaction
    let totalTokensSaved: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Context compactions", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(TightLabelStyle())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("v9 ledger")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(compaction.totalCompactions)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(compaction.totalCompactions == 1 ? "compaction" : "compactions")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if let age = compaction.lastCompactionAge {
                    Label("last \(age)", systemImage: "clock")
                        .labelStyle(TightLabelStyle())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                miniStat(
                    label: "Tokens re-sent",
                    value: DripFormatter.compactInteger(compaction.tokensResentAfterCompaction),
                    sub: "since the last compaction",
                    tint: .orange
                )
                Divider().frame(height: 30)
                miniStat(
                    label: "Quality",
                    value: qualityLabel,
                    sub: qualitySubtitle,
                    tint: qualityTint
                )
            }

            Text(qualityHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func miniStat(label: String, value: String, sub: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(sub)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pure savings vs cost ratio. We treat `tokens_resent` as a tax on
    /// the headline `tokens_saved`; the higher the ratio of saved-to-resent
    /// the cleaner the install. Capped for display ergonomics.
    private var qualityRatio: Double {
        guard compaction.tokensResentAfterCompaction > 0 else { return 1 }
        guard totalTokensSaved > 0 else { return 0 }
        let net = Double(totalTokensSaved - compaction.tokensResentAfterCompaction)
        let ratio = net / Double(totalTokensSaved)
        return max(0, min(1, ratio))
    }

    private var qualityLabel: String {
        "\(Int((qualityRatio * 100).rounded())) %"
    }

    private var qualitySubtitle: String {
        switch qualityRatio {
        case 0.95...: "almost no waste"
        case 0.85 ..< 0.95: "minor waste"
        case 0.70 ..< 0.85: "noticeable waste"
        default: "high re-cost"
        }
    }

    private var qualityTint: Color {
        switch qualityRatio {
        case 0.95...: DripPalette.greenDark
        case 0.85 ..< 0.95: DripPalette.green
        case 0.70 ..< 0.85: .orange
        default: .red
        }
    }

    private var qualityHint: String {
        compaction.tokensResentAfterCompaction == 0
            ? "DRIP hasn't had to re-send anything since the last compaction yet."
            : "Compactions reset DRIP's baselines, so some files have to be sent in full again. The quality score is what's left of your savings after that re-cost."
    }
}
