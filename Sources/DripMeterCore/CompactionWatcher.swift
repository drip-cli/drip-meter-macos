import Foundation

/// Posts a one-shot signal whenever the user has crossed a compaction-rate
/// threshold. Inputs are pre-aggregated by `DripStore`; the watcher just
/// keeps a UserDefaults-backed memory of which thresholds have already
/// fired so we don't pester the user on every refresh.
@MainActor
public final class CompactionWatcher {
    public struct Threshold: Equatable, Sendable {
        public let count: Int
        public let copy: String

        public static let three = Threshold(
            count: 3,
            copy: "Your agent compacted 3 times in this run — DRIP had to rebuild several baselines. Consider trimming context."
        )
        public static let five = Threshold(
            count: 5,
            copy: "5 compactions and counting. The agent is hitting context limits often — savings are eroding."
        )
        public static let ten = Threshold(
            count: 10,
            copy: "10 compactions logged. DripMeter recommends slicing the task into smaller agent runs."
        )

        public static let all: [Threshold] = [.three, .five, .ten]
    }

    private static let key = "io.drip-cli.dripmeter.firedCompactionThresholds"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns thresholds newly crossed at the supplied count. Caller is
    /// expected to mark each as fired via `markFired` so it doesn't repeat.
    public func newlyCrossed(totalCompactions: Int64) -> [Threshold] {
        let already = firedCounts()
        return Threshold.all
            .filter { totalCompactions >= Int64($0.count) }
            .filter { !already.contains($0.count) }
    }

    public func markFired(_ threshold: Threshold) {
        var counts = firedCounts()
        counts.insert(threshold.count)
        defaults.set(Array(counts), forKey: Self.key)
    }

    /// Wiped after a fresh `drip reset --all` so the user gets the alerts
    /// again on the next run. The Settings → Alerts pane exposes a button
    /// for this so power users can re-test the flow.
    public func reset() {
        defaults.removeObject(forKey: Self.key)
    }

    private func firedCounts() -> Set<Int> {
        let raw = (defaults.array(forKey: Self.key) as? [Int]) ?? []
        return Set(raw)
    }
}
