import Charts
import DripMeterCore
import SwiftUI

/// Savings sparkline drawn from `meter.history`. The user picks the window
/// length in Settings → Appearance (default 7 days); we slice the available
/// buckets accordingly.
struct HistorySparklineView: View {
    let history: [MeterReport.DayBucket]
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last \(settings.defaultHistoryRange.displayName.lowercased())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(totalLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Chart(recentBuckets) { bucket in
                BarMark(
                    x: .value("Day", bucket.day),
                    y: .value("Tokens saved", bucket.tokensSaved)
                )
                .foregroundStyle(LinearGradient(
                    colors: [DripPalette.green, DripPalette.greenDark.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .cornerRadius(2)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 60)
        }
    }

    private var recentBuckets: [MeterReport.DayBucket] {
        Array(history.suffix(settings.defaultHistoryRange.bucketLimit))
    }

    private var totalLabel: String {
        let total = recentBuckets.reduce(Int64(0)) { $0 + $1.tokensSaved }
        return "\(DripFormatter.compactInteger(total)) saved"
    }
}
