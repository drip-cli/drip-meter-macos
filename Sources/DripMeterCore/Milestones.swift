import Foundation

/// Milestones the user can crossover. Each one fires at most once — we
/// remember the last threshold we celebrated in UserDefaults so a refresh
/// or relaunch doesn't re-trigger the notification.
public enum Milestone: String, CaseIterable, Sendable, Codable {
    case tokens100K
    case tokens1M
    case tokens10M
    case dollars10
    case dollars50
    case dollars100
    case dollars500

    public var displayName: String {
        switch self {
        case .tokens100K: "100K tokens saved"
        case .tokens1M: "1 million tokens saved"
        case .tokens10M: "10 million tokens saved"
        case .dollars10: "$10 saved"
        case .dollars50: "$50 saved"
        case .dollars100: "$100 saved"
        case .dollars500: "$500 saved"
        }
    }

    public var celebrationCopy: String {
        switch self {
        case .tokens100K: "Your first 100K tokens saved by DRIP. Keep going."
        case .tokens1M: "Million-tokens club. Take a screenshot."
        case .tokens10M: "10M tokens saved. The robots thank you."
        case .dollars10: "DRIP just paid for a coffee."
        case .dollars50: "$50 saved — that's a domain name."
        case .dollars100: "Three figures saved. DRIP earns its keep."
        case .dollars500: "$500. Treat yourself."
        }
    }

    public func isCrossed(tokensSaved: Int64, dollarsSaved: Double) -> Bool {
        switch self {
        case .tokens100K: tokensSaved >= 100_000
        case .tokens1M: tokensSaved >= 1_000_000
        case .tokens10M: tokensSaved >= 10_000_000
        case .dollars10: dollarsSaved >= 10
        case .dollars50: dollarsSaved >= 50
        case .dollars100: dollarsSaved >= 100
        case .dollars500: dollarsSaved >= 500
        }
    }

    /// Stable ordering so we always notify in increasing magnitude.
    public var rank: Int {
        switch self {
        case .tokens100K: 1
        case .dollars10: 2
        case .tokens1M: 3
        case .dollars50: 4
        case .dollars100: 5
        case .tokens10M: 6
        case .dollars500: 7
        }
    }
}

/// Tracks which milestones have already fired. Persisted to UserDefaults so
/// the user doesn't get repeat notifications across app launches.
@MainActor
public final class MilestoneTracker {
    private let defaults: UserDefaults
    private static let key = "io.drip-cli.dripmeter.celebratedMilestones"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func celebrated() -> Set<Milestone> {
        let raw = (defaults.array(forKey: Self.key) as? [String]) ?? []
        return Set(raw.compactMap { Milestone(rawValue: $0) })
    }

    public func markCelebrated(_ milestone: Milestone) {
        var set = celebrated()
        set.insert(milestone)
        defaults.set(set.map(\.rawValue), forKey: Self.key)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.key)
    }

    /// Returns the milestones newly crossed at the given totals, in rank
    /// order. Caller is expected to fire one notification per element and
    /// then call `markCelebrated` for each.
    public func newlyCrossed(tokensSaved: Int64, dollarsSaved: Double) -> [Milestone] {
        let already = celebrated()
        return Milestone.allCases
            .filter { !already.contains($0) }
            .filter { $0.isCrossed(tokensSaved: tokensSaved, dollarsSaved: dollarsSaved) }
            .sorted { $0.rank < $1.rank }
    }
}
