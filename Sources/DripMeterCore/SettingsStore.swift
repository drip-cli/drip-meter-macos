import Foundation
import Observation

public enum RefreshCadence: String, CaseIterable, Codable, Sendable, Identifiable {
    case manual
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case fifteenMinutes

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "Every 1 min"
        case .twoMinutes: "Every 2 min"
        case .fiveMinutes: "Every 5 min"
        case .fifteenMinutes: "Every 15 min"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .manual: nil
        case .oneMinute: 60
        case .twoMinutes: 120
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        }
    }
}

public enum MenuBarLabelStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case iconOnly
    case percent
    case tokensSaved
    case dollarsSaved

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .iconOnly: "Icon only"
        case .percent: "% saved"
        case .tokensSaved: "Tokens saved"
        case .dollarsSaved: "$ saved"
        }
    }
}

public enum HistoryRange: String, CaseIterable, Codable, Sendable, Identifiable {
    case days7
    case days30
    case days90
    case lifetime

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .days7: "7 days"
        case .days30: "30 days"
        case .days90: "90 days"
        case .lifetime: "Lifetime"
        }
    }

    public var bucketLimit: Int {
        switch self {
        case .days7: 7
        case .days30: 30
        case .days90: 90
        case .lifetime: 365
        }
    }
}

/// User-tunable settings. Backed by `UserDefaults` so they survive restarts and
/// can be reset via Settings → Reset.
@MainActor
@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    // MARK: General

    public var refreshCadence: RefreshCadence {
        didSet { defaults.set(refreshCadence.rawValue, forKey: Keys.refreshCadence) }
    }

    public var liveWatchEnabled: Bool {
        didSet { defaults.set(liveWatchEnabled, forKey: Keys.liveWatchEnabled) }
    }

    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    // MARK: Appearance

    public var menuBarLabelStyle: MenuBarLabelStyle {
        didSet { defaults.set(menuBarLabelStyle.rawValue, forKey: Keys.menuBarLabelStyle) }
    }

    public var popoverWidth: Double {
        didSet { defaults.set(popoverWidth, forKey: Keys.popoverWidth) }
    }

    public var compactMode: Bool {
        didSet { defaults.set(compactMode, forKey: Keys.compactMode) }
    }

    public var defaultHistoryRange: HistoryRange {
        didSet { defaults.set(defaultHistoryRange.rawValue, forKey: Keys.defaultHistoryRange) }
    }

    // MARK: Agents

    public var enabledAgents: Set<DripAgent> {
        didSet { defaults.set(enabledAgents.map(\.rawValue), forKey: Keys.enabledAgents) }
    }

    // MARK: Cost

    public var costModelId: String {
        didSet { defaults.set(costModelId, forKey: Keys.costModelId) }
    }

    public var customPricePerMtok: Double? {
        didSet {
            if let value = customPricePerMtok {
                defaults.set(value, forKey: Keys.customPricePerMtok)
            } else {
                defaults.removeObject(forKey: Keys.customPricePerMtok)
            }
        }
    }

    public var costModel: CostModel {
        if let custom = customPricePerMtok {
            return CostModel(id: "custom", displayName: "Custom rate", pricePerMtok: custom)
        }
        return CostModel.presets.first { $0.id == costModelId } ?? .sonnet46
    }

    // MARK: Notifications

    public var milestoneNotificationsEnabled: Bool {
        didSet { defaults.set(milestoneNotificationsEnabled, forKey: Keys.milestoneNotificationsEnabled) }
    }

    // MARK: Click-through

    public var preferredIDE: IDEPreference {
        didSet { defaults.set(preferredIDE.rawValue, forKey: Keys.preferredIDE) }
    }

    // MARK: Advanced

    public var dripBinaryPathOverride: String {
        didSet { defaults.set(dripBinaryPathOverride, forKey: Keys.dripBinaryPathOverride) }
    }

    /// Daily target the user is aiming to save, in tokens. Drives the
    /// progress bar on the Overview tab. `0` disables the feature.
    public var dailyTokenTarget: Int64 {
        didSet { defaults.set(dailyTokenTarget, forKey: Keys.dailyTokenTarget) }
    }

    /// Longest consecutive-day streak the user has ever hit. Persisted
    /// across launches so the "best ever" badge survives a quiet week.
    /// Bumped by `DripStore.performRefresh` whenever the current streak
    /// exceeds the stored best.
    public var bestStreakDays: Int {
        didSet { defaults.set(bestStreakDays, forKey: Keys.bestStreakDays) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // One-shot migration: prior versions defaulted to `.percent` in the
        // menu bar. We changed the default to icon-only — push the change
        // through the once for users who never visited Settings.
        let migrationKey = "io.drip-cli.dripmeter.defaultsMigration.v2"
        if !defaults.bool(forKey: migrationKey) {
            defaults.removeObject(forKey: Keys.menuBarLabelStyle)
            defaults.set(true, forKey: migrationKey)
        }

        let cadenceRaw = defaults.string(forKey: Keys.refreshCadence) ?? RefreshCadence.twoMinutes.rawValue
        refreshCadence = RefreshCadence(rawValue: cadenceRaw) ?? .twoMinutes
        liveWatchEnabled = (defaults.object(forKey: Keys.liveWatchEnabled) as? Bool) ?? true
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        let labelRaw = defaults.string(forKey: Keys.menuBarLabelStyle) ?? MenuBarLabelStyle.iconOnly.rawValue
        menuBarLabelStyle = MenuBarLabelStyle(rawValue: labelRaw) ?? .iconOnly
        let storedWidth = defaults.double(forKey: Keys.popoverWidth)
        popoverWidth = storedWidth >= 320 ? storedWidth : 380
        compactMode = defaults.bool(forKey: Keys.compactMode)
        let historyRaw = defaults.string(forKey: Keys.defaultHistoryRange) ?? HistoryRange.days7.rawValue
        defaultHistoryRange = HistoryRange(rawValue: historyRaw) ?? .days7

        if let stored = defaults.array(forKey: Keys.enabledAgents) as? [String] {
            enabledAgents = Set(stored.compactMap { DripAgent(rawValue: $0) })
        } else {
            enabledAgents = Set(DripAgent.allCases)
        }

        costModelId = defaults.string(forKey: Keys.costModelId) ?? CostModel.sonnet46.id
        if defaults.object(forKey: Keys.customPricePerMtok) != nil {
            let value = defaults.double(forKey: Keys.customPricePerMtok)
            customPricePerMtok = value > 0 ? value : nil
        } else {
            customPricePerMtok = nil
        }

        milestoneNotificationsEnabled = (defaults.object(forKey: Keys.milestoneNotificationsEnabled) as? Bool) ?? true

        let ideRaw = defaults.string(forKey: Keys.preferredIDE) ?? IDEPreference.finder.rawValue
        preferredIDE = IDEPreference(rawValue: ideRaw) ?? .finder

        dripBinaryPathOverride = defaults.string(forKey: Keys.dripBinaryPathOverride) ?? ""

        // Default 25K — calibrated against typical solo-dev sessions where a
        // wired-up Claude Code refactor saves 30-100K tokens of input. Users
        // can lower it on quiet days or zero it to hide the feature.
        let storedTarget = defaults.integer(forKey: Keys.dailyTokenTarget)
        dailyTokenTarget = storedTarget > 0 ? Int64(storedTarget) : 25000

        bestStreakDays = defaults.integer(forKey: Keys.bestStreakDays)
    }

    public func resolvedBinaryOverride() -> String? {
        let trimmed = dripBinaryPathOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum Keys {
        static let refreshCadence = "io.drip-cli.dripmeter.refreshCadence"
        static let liveWatchEnabled = "io.drip-cli.dripmeter.liveWatchEnabled"
        static let launchAtLogin = "io.drip-cli.dripmeter.launchAtLogin"
        static let menuBarLabelStyle = "io.drip-cli.dripmeter.menuBarLabelStyle"
        static let popoverWidth = "io.drip-cli.dripmeter.popoverWidth"
        static let compactMode = "io.drip-cli.dripmeter.compactMode"
        static let defaultHistoryRange = "io.drip-cli.dripmeter.defaultHistoryRange"
        static let enabledAgents = "io.drip-cli.dripmeter.enabledAgents"
        static let costModelId = "io.drip-cli.dripmeter.costModelId"
        static let customPricePerMtok = "io.drip-cli.dripmeter.customPricePerMtok"
        static let milestoneNotificationsEnabled = "io.drip-cli.dripmeter.milestoneNotificationsEnabled"
        static let preferredIDE = "io.drip-cli.dripmeter.preferredIDE"
        static let dripBinaryPathOverride = "io.drip-cli.dripmeter.dripBinaryPathOverride"
        static let dailyTokenTarget = "io.drip-cli.dripmeter.dailyTokenTarget"
        static let bestStreakDays = "io.drip-cli.dripmeter.bestStreakDays"
    }
}
