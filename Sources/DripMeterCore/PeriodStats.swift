import Foundation

/// Rolled-up statistics for a slice of the `meter --history` time series.
/// Used by the weekly / monthly panels and by the usage-report exporter.
///
/// "Active days" counts buckets with at least one read — distinguishes
/// "you saved 0 tokens by reading nothing" from "you read everything from
/// scratch". Average is **over the full window length, not active days**
/// — that's the metric users intuitively read as "my daily average".
public struct PeriodStats: Sendable, Equatable {
    public let label: String
    public let windowDays: Int
    public let tokensSaved: Int64
    public let tokensFull: Int64
    public let tokensSent: Int64
    public let reads: Int64
    public let activeDays: Int
    public let peakDay: MeterReport.DayBucket?
    public let buckets: [MeterReport.DayBucket]

    public var avgPerDay: Int64 {
        guard windowDays > 0 else { return 0 }
        return Int64((Double(tokensSaved) / Double(windowDays)).rounded())
    }

    public var avgPerActiveDay: Int64 {
        guard activeDays > 0 else { return 0 }
        return Int64((Double(tokensSaved) / Double(activeDays)).rounded())
    }

    public var reductionPct: Int {
        guard tokensFull > 0 else { return 0 }
        return Int((Double(tokensSaved) / Double(tokensFull) * 100).rounded())
    }
}

public extension [MeterReport.DayBucket] {
    /// Roll up the last `windowDays` buckets (most recent at the tail of
    /// the array, the way `drip meter --history` emits them) into a
    /// `PeriodStats` summary.
    ///
    /// `label` is a free-form display string ("This week", "Last 30 days").
    /// We pass it in instead of deriving from `windowDays` so callers can
    /// localise without dragging strings into the data layer.
    func rollup(windowDays: Int, label: String) -> PeriodStats {
        let slice = Array(suffix(windowDays))
        var tokensSaved: Int64 = 0
        var tokensFull: Int64 = 0
        var tokensSent: Int64 = 0
        var reads: Int64 = 0
        var activeDays = 0
        var peak: MeterReport.DayBucket?
        for bucket in slice {
            tokensSaved += bucket.tokensSaved
            tokensFull += bucket.tokensFull
            tokensSent += bucket.tokensSent
            reads += bucket.reads
            if bucket.reads > 0 { activeDays += 1 }
            if peak == nil || bucket.tokensSaved > peak!.tokensSaved {
                peak = bucket
            }
        }
        return PeriodStats(
            label: label,
            windowDays: windowDays,
            tokensSaved: tokensSaved,
            tokensFull: tokensFull,
            tokensSent: tokensSent,
            reads: reads,
            activeDays: activeDays,
            peakDay: peak,
            buckets: slice
        )
    }
}
