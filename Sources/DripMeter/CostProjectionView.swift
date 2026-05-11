import DripMeterCore
import SwiftUI

/// Cost projection panel — renders the user's chosen model's $-saved
/// applied to lifetime tokens, plus extrapolated savings over a horizon
/// based on the same elapsed-time linear extrapolation `drip meter` uses.
struct CostProjectionView: View {
    let report: MeterReport
    @Environment(SettingsStore.self) private var settings
    @State private var horizon: ProjectionHorizon = .month

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cost projection")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Picker("Horizon", selection: $horizon) {
                    ForEach(ProjectionHorizon.allCases) { h in
                        Text(h.displayName).tag(h)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 110)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DripFormatter.dollars(extrapolated))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("projected savings \(horizon.displayName.replacingOccurrences(of: "/ ", with: ""))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text("at")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(settings.costModel.displayName)
                    .font(.caption.weight(.medium))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(String(format: "$%.2f / Mtok", settings.costModel.pricePerMtok))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                miniSummary(
                    label: "Saved so far",
                    value: DripFormatter.dollars(savedSoFar)
                )
                Divider().frame(height: 24)
                miniSummary(
                    label: "Per token",
                    value: String(format: "$%.4f / Mtok", settings.costModel.pricePerMtok)
                )
            }
        }
    }

    private var savedSoFar: Double {
        settings.costModel.dollarsSaved(forTokens: report.tokensSaved)
    }

    private var extrapolated: Double {
        settings.costModel.project(
            savedTokens: report.tokensSaved,
            elapsedSecs: max(report.elapsedSecs, 1),
            horizon: horizon
        )
    }

    private func miniSummary(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
    }
}
