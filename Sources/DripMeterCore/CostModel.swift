import Foundation

/// Pricing assumptions for cost projection. Default values come from each
/// provider's published rates per million **input** tokens (DRIP saves on
/// the input side — output tokens are not affected).
public struct CostModel: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let displayName: String
    public let pricePerMtok: Double

    public init(id: String, displayName: String, pricePerMtok: Double) {
        self.id = id
        self.displayName = displayName
        self.pricePerMtok = pricePerMtok
    }

    public static let sonnet46 = CostModel(id: "sonnet-4.6", displayName: "Claude Sonnet 4.6", pricePerMtok: 3.0)
    public static let opus46 = CostModel(id: "opus-4.6", displayName: "Claude Opus 4.6", pricePerMtok: 15.0)
    public static let opus47 = CostModel(id: "opus-4.7", displayName: "Claude Opus 4.7", pricePerMtok: 15.0)
    public static let haiku45 = CostModel(id: "haiku-4.5", displayName: "Claude Haiku 4.5", pricePerMtok: 1.0)
    public static let gpt5 = CostModel(id: "gpt-5", displayName: "GPT-5 / Codex", pricePerMtok: 5.0)
    public static let gpt5Mini = CostModel(id: "gpt-5-mini", displayName: "GPT-5 Mini", pricePerMtok: 1.0)
    public static let gemini25Pro = CostModel(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", pricePerMtok: 7.0)
    public static let gemini25Flash = CostModel(
        id: "gemini-2.5-flash",
        displayName: "Gemini 2.5 Flash",
        pricePerMtok: 0.30
    )

    public static let presets: [CostModel] = [
        .haiku45, .sonnet46, .opus47, .opus46,
        .gpt5Mini, .gpt5,
        .gemini25Flash, .gemini25Pro
    ]

    /// Project savings over a horizon based on observed `tokensSaved` and the
    /// observed wall-time elapsed. Naive linear extrapolation — see
    /// `BENCHMARKS.md` in the DRIP repo for the caveat.
    public func project(savedTokens: Int64, elapsedSecs: Int64, horizon: ProjectionHorizon) -> Double {
        guard elapsedSecs > 0, savedTokens > 0 else { return 0 }
        let perSecond = Double(savedTokens) / Double(elapsedSecs)
        let horizonSecs = horizon.seconds
        let projectedTokens = perSecond * Double(horizonSecs)
        return (projectedTokens / 1_000_000) * pricePerMtok
    }

    public func dollarsSaved(forTokens tokens: Int64) -> Double {
        (Double(tokens) / 1_000_000) * pricePerMtok
    }
}

public enum ProjectionHorizon: String, CaseIterable, Identifiable, Sendable, Codable {
    case day
    case week
    case month
    case year

    public var id: String {
        rawValue
    }

    public var seconds: Int64 {
        switch self {
        case .day: 86400
        case .week: 86400 * 7
        case .month: 86400 * 30
        case .year: 86400 * 365
        }
    }

    public var displayName: String {
        switch self {
        case .day: "/ day"
        case .week: "/ week"
        case .month: "/ month"
        case .year: "/ year"
        }
    }
}
