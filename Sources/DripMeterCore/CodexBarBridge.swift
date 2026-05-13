import Foundation
import OSLog

/// Reads CodexBar's locally-cached usage history (`~/Library/Application
/// Support/com.steipete.codexbar/history/{provider}.json`) read-only, so
/// DripMeter can surface provider quotas in the Agents tab without
/// re-implementing OAuth flows for Anthropic / OpenAI / Google.
///
/// CodexBar is the source of truth: its scheduled scrape keeps the JSON
/// fresh, DripMeter only reads. If CodexBar isn't installed (or hasn't
/// scraped recently), the bridge returns an empty result and the UI
/// renders a "Install CodexBar to see quotas" banner.
public enum CodexBarBridge {
    public static func dataDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("com.steipete.codexbar/history", isDirectory: true)
    }

    public static var isInstalled: Bool {
        // Two signals — either the published prefs domain exists or the
        // history dir does. Either is enough; the .app itself can be
        // anywhere (Homebrew Cask, /Applications, dragged-elsewhere).
        let prefs = FileManager.default.fileExists(atPath:
            "\(NSHomeDirectory())/Library/Preferences/com.steipete.codexbar.plist")
        let history = FileManager.default.fileExists(atPath: dataDirectory().path)
        return prefs || history
    }

    /// Latest quota snapshot per supported agent. Skips agents whose JSON
    /// file is absent or fails to decode — the UI just doesn't render a
    /// progress bar for them.
    public static func fetchQuotas() -> [AgentQuotaSnapshot] {
        DripAgent.allCases.compactMap { agent in
            fetchQuota(for: agent)
        }
    }

    public static func fetchQuota(for agent: DripAgent) -> AgentQuotaSnapshot? {
        let url = dataDirectory().appendingPathComponent("\(agent.rawValue).json")
        guard
            let data = try? Data(contentsOf: url),
            let payload = try? Self.decoder.decode(HistoryPayload.self, from: data),
            let latest = payload.latestEntry()
        else {
            return nil
        }
        return AgentQuotaSnapshot(
            agent: agent,
            percentUsed: latest.usedPercent,
            capturedAt: latest.capturedAt,
            resetsAt: latest.resetsAt,
            label: latest.label
        )
    }

    private static let decoder: JSONDecoder = {
        // CodexBar writes ISO-8601 timestamps with a trailing Z. Foundation's
        // built-in `.iso8601` strategy handles that natively.
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// One agent's most recent quota point. Mirror of CodexBar's `entries[]`
/// row but flattened — we only ever read the freshest entry.
public struct AgentQuotaSnapshot: Identifiable, Sendable, Equatable {
    public let agent: DripAgent
    public let percentUsed: Int
    public let capturedAt: Date
    public let resetsAt: Date?
    /// Optional human-readable label CodexBar attaches to the entry
    /// (e.g. "5h session" / "weekly" for Claude). Surfaced as a chip
    /// next to the progress bar.
    public let label: String?

    public var id: DripAgent {
        agent
    }

    public var isStale: Bool {
        // CodexBar polls every couple of minutes — anything older than
        // 30 min means the user hasn't opened CodexBar in a while.
        Date().timeIntervalSince(capturedAt) > 30 * 60
    }
}

// MARK: - JSON shape (mirrors CodexBar's snapshot format)

private struct HistoryPayload: Decodable {
    let accounts: [String: [Account]]?

    struct Account: Decodable {
        let entries: [Entry]?
        let label: String?
    }

    struct Entry: Decodable {
        let capturedAt: Date
        let resetsAt: Date?
        let usedPercent: Int?
        let label: String?

        enum CodingKeys: String, CodingKey {
            case capturedAt
            case resetsAt
            case usedPercent
            case label
        }
    }

    /// Walk every account, every entries array, pick the most recent
    /// `capturedAt`. CodexBar may track multiple accounts per provider
    /// — we surface the busiest one (highest `usedPercent` on the latest
    /// timestamp) so the user sees what's most likely to throttle them.
    func latestEntry() -> ResolvedEntry? {
        guard let accounts else { return nil }
        var candidates: [ResolvedEntry] = []
        for (_, perAccount) in accounts {
            for account in perAccount {
                guard let entries = account.entries else { continue }
                guard let last = entries.max(by: { $0.capturedAt < $1.capturedAt }) else { continue }
                candidates.append(ResolvedEntry(
                    capturedAt: last.capturedAt,
                    resetsAt: last.resetsAt,
                    usedPercent: last.usedPercent ?? 0,
                    label: last.label ?? account.label
                ))
            }
        }
        // Most recent capture wins; tie-break on highest %.
        return candidates.max { lhs, rhs in
            if lhs.capturedAt != rhs.capturedAt {
                return lhs.capturedAt < rhs.capturedAt
            }
            return lhs.usedPercent < rhs.usedPercent
        }
    }
}

private struct ResolvedEntry {
    let capturedAt: Date
    let resetsAt: Date?
    let usedPercent: Int
    let label: String?
}
