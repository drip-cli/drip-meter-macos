import Foundation
import Observation
import OSLog

/// Top-level observable that drives the menu bar UI. Owns:
///
/// - the latest `MeterReport` (lifetime totals from `drip meter --json`)
/// - the per-agent breakdown (read directly from SQLite)
/// - the per-agent install status (probed from each agent's config files)
/// - the recent replay events for the Live tab
/// - the top files (full list, not capped at 10)
/// - the milestone tracker
/// - an FSEvents-style watcher that refreshes immediately on DB changes
@MainActor
@Observable
public final class DripStore {
    public enum LoadState: Sendable, Equatable {
        case idle
        /// We're talking to `drip` for the *first* time — no snapshot yet.
        /// This is the only state where the UI should show "Refreshing…"
        /// chrome; subsequent background refreshes flip `isRefreshing`
        /// instead so the timestamp pill stays stable.
        case coldLoading
        case loaded(at: Date)
        case error(message: String)
    }

    public enum InstallStatus: Sendable, Equatable {
        case ready(version: String)
        case binaryMissing
        case databaseMissing
        case probing
    }

    public private(set) var report: MeterReport = .empty
    public private(set) var agents: [AgentBreakdown] = DripAgent.allCases.map {
        AgentBreakdown(agent: $0, sessions: 0, filesTracked: 0, tokensFull: 0, tokensSent: 0, lastActiveAt: nil)
    }
    public private(set) var agentInstall: [AgentInstallStatus] = AgentInstallProbe.probeAll()
    public private(set) var recentEvents: [ReplayEvent] = []
    public private(set) var topFiles: [MeterReport.PerFile] = []
    public private(set) var sessions: [SessionRow] = []
    public private(set) var todayTotal: DailyTotal = DailyTotal(
        day: "",
        tokensSaved: 0,
        reads: 0
    )
    public private(set) var streakDays: Int = 0
    /// Provider quota snapshots (Claude 5h/weekly, Codex window, etc.)
    /// pulled read-only from CodexBar's history JSONs. Empty when CodexBar
    /// isn't installed or hasn't scraped recently.
    public private(set) var agentQuotas: [AgentQuotaSnapshot] = []
    public private(set) var codexBarInstalled: Bool = CodexBarBridge.isInstalled
    public private(set) var newlyCrossedMilestones: [Milestone] = []
    public private(set) var installStatus: InstallStatus = .probing
    public private(set) var loadState: LoadState = .idle
    public private(set) var isRefreshing: Bool = false
    public private(set) var lastError: String?

    /// Fires once per crossed milestone. Set by `performRefresh` and consumed
    /// by the AppDelegate's notification dispatcher.
    public var onMilestoneCrossed: (@MainActor (Milestone) -> Void)?
    /// Fires once per crossed compaction-rate threshold (3 / 5 / 10).
    public var onCompactionThresholdCrossed: (@MainActor (CompactionWatcher.Threshold) -> Void)?

    private let settings: SettingsStore
    private var cli: DripCLI
    private let database: DripDatabase
    private let milestones: MilestoneTracker
    private let compactions: CompactionWatcher
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var watcher: DatabaseWatcher?
    private let logger = DripLogger.store

    public init(
        settings: SettingsStore = .shared,
        database: DripDatabase = DripDatabase()
    ) {
        self.settings = settings
        self.database = database
        self.cli = DripCLI(binaryPath: settings.resolvedBinaryOverride())
        self.milestones = MilestoneTracker()
        self.compactions = CompactionWatcher()
    }

    public func start() {
        Task { [weak self] in await self?.refresh() }
        startPolling()
        startWatcher()
    }

    public func stop() {
        refreshTask?.cancel()
        pollingTask?.cancel()
        refreshTask = nil
        pollingTask = nil
        watcher?.stop()
        watcher = nil
    }

    public func reconfigure() {
        cli = DripCLI(binaryPath: settings.resolvedBinaryOverride())
        startPolling()
        startWatcher()
        Task { [weak self] in await self?.refresh() }
    }

    public func refresh() async {
        if refreshTask != nil { return }
        let task = Task<Void, Never> { [weak self] in
            await self?.performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    /// Re-probe agent install state. Cheap (a few file reads).
    public func refreshAgentInstall() {
        agentInstall = AgentInstallProbe.probeAll()
    }

    private func performRefresh() async {
        // Cold-load (no snapshot yet) is the only path that should mutate
        // `loadState` to a transient value — every subsequent refresh flips
        // `isRefreshing` so views relying on `loadState` (the timestamp,
        // the last successful update time) stay rock-stable.
        let isCold = loadState == .idle || (loadState == .coldLoading)
        if isCold {
            loadState = .coldLoading
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let cli = self.cli
        let database = self.database

        do {
            let version = try await cli.version()
            installStatus = .ready(version: version)
        } catch DripCLIError.binaryNotFound {
            installStatus = .binaryMissing
            loadState = .error(message: "drip binary not found")
            return
        } catch {
            logger.warning("drip --version failed: \(error.localizedDescription, privacy: .public)")
        }

        if !database.exists, case .ready = installStatus {
            installStatus = .databaseMissing
        }

        do {
            let report = try await cli.meterReport()
            let agents = (try? database.fetchAgentBreakdown()) ?? []
            let events = (try? database.fetchRecentEvents(since: Int64(Date().timeIntervalSince1970) - 3_600, limit: 50)) ?? []
            let topFiles = (try? database.fetchTopFiles(limit: 50)) ?? []
            let sessions = (try? database.fetchSessions(limit: 30)) ?? []
            let today = (try? database.fetchTodayTotal()) ?? DailyTotal(day: "", tokensSaved: 0, reads: 0)
            let streak = (try? database.fetchStreakDays()) ?? 0
            self.report = report
            self.agents = backfillMissingAgents(agents)
            self.recentEvents = events
            self.topFiles = topFiles.isEmpty ? report.top : topFiles
            self.sessions = sessions
            self.todayTotal = today
            self.streakDays = streak
            self.agentQuotas = CodexBarBridge.fetchQuotas()
            self.codexBarInstalled = CodexBarBridge.isInstalled
            self.loadState = .loaded(at: Date())
            self.lastError = nil
            self.refreshAgentInstall()
            self.notifyMilestonesIfNeeded(report: report)
            self.notifyCompactionThresholdsIfNeeded(report: report)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            self.loadState = .error(message: message)
            self.lastError = message
            logger.error("Refresh failed: \(message, privacy: .public)")
        }
    }

    private func notifyMilestonesIfNeeded(report: MeterReport) {
        guard settings.milestoneNotificationsEnabled else { return }
        let crossed = milestones.newlyCrossed(
            tokensSaved: report.tokensSaved,
            dollarsSaved: report.dollarsSaved
        )
        guard !crossed.isEmpty else { return }
        newlyCrossedMilestones = crossed
        for milestone in crossed {
            milestones.markCelebrated(milestone)
            onMilestoneCrossed?(milestone)
        }
    }

    private func notifyCompactionThresholdsIfNeeded(report: MeterReport) {
        guard settings.milestoneNotificationsEnabled,
              let compaction = report.compaction,
              compaction.totalCompactions > 0
        else { return }
        let crossed = compactions.newlyCrossed(totalCompactions: compaction.totalCompactions)
        for threshold in crossed {
            compactions.markFired(threshold)
            onCompactionThresholdCrossed?(threshold)
        }
    }

    private func backfillMissingAgents(_ rows: [AgentBreakdown]) -> [AgentBreakdown] {
        let seen = Set(rows.map(\.agent))
        var merged = rows
        for agent in DripAgent.allCases where !seen.contains(agent) {
            merged.append(AgentBreakdown(
                agent: agent,
                sessions: 0,
                filesTracked: 0,
                tokensFull: 0,
                tokensSent: 0,
                lastActiveAt: nil
            ))
        }
        return merged.sorted { $0.agent.rawValue < $1.agent.rawValue }
    }

    private func startPolling() {
        pollingTask?.cancel()
        guard let interval = settings.refreshCadence.interval else {
            pollingTask = nil
            return
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    private func startWatcher() {
        watcher?.stop()
        guard settings.liveWatchEnabled else {
            watcher = nil
            return
        }
        // Coalesce DB events: SQLite often produces a burst of writes per
        // transaction, and we don't want to thrash the CLI with one
        // refresh per byte. Wait 350 ms after the last event.
        let coalescing = CoalescingScheduler(delay: 0.35)
        // Capture a weak holder so we don't retain the store from the
        // FSEvents-side callback; reference it from the @Sendable boundary.
        let weakBox = WeakStoreBox(store: self)
        let watcher = DatabaseWatcher(url: DripPaths.sessionsDatabaseURL()) {
            coalescing.fire { @Sendable in
                Task { @MainActor in
                    await weakBox.store?.refresh()
                }
            }
        }
        watcher.start()
        self.watcher = watcher
    }
}

/// Erases the actor isolation of `DripStore` so the FSEvents callback —
/// which lives on a non-main `DispatchQueue` — can pass a weak reference
/// across the `@Sendable` boundary without forcing the store to be Sendable.
private final class WeakStoreBox: @unchecked Sendable {
    weak var store: DripStore?
    init(store: DripStore) { self.store = store }
}

/// Trailing-edge debouncer for FSEvents bursts.
private final class CoalescingScheduler: @unchecked Sendable {
    private let delay: TimeInterval
    private let queue = DispatchQueue(label: "io.drip-cli.dripmeter.coalesce")
    private var pending: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func fire(_ block: @escaping @Sendable () -> Void) {
        queue.async {
            self.pending?.cancel()
            let item = DispatchWorkItem(block: block)
            self.pending = item
            self.queue.asyncAfter(deadline: .now() + self.delay, execute: item)
        }
    }
}
