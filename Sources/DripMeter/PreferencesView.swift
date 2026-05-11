import DripMeterCore
import SwiftUI

/// Sections shown in the Settings sidebar. Single source of truth for the
/// title + symbol pair so the navigation list and the title stay in sync.
enum PreferencesSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case agents
    case cost
    case alerts
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .agents: "Agents"
        case .cost: "Cost"
        case .alerts: "Alerts"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .agents: "person.2"
        case .cost: "dollarsign.circle"
        case .alerts: "bell"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

/// Settings window. Sidebar on the left (`NavigationSplitView`), detail pane
/// on the right. Tightened typography and a fixed 600 × 380 footprint that
/// matches the rest of the system Settings windows.
struct PreferencesView: View {
    @State private var selection: PreferencesSection = .general

    var body: some View {
        NavigationSplitView {
            List(PreferencesSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 170, max: 200)
            .navigationTitle("Settings")
        } detail: {
            // About is short marketing content — render it as a hero card
            // that fills the detail pane and centres vertically. Every
            // other section is form-style, top-aligned, in a ScrollView.
            Group {
                if selection == .about {
                    AboutPane()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        detailPane
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .navigationTitle(selection.title)
            .navigationSubtitle("DripMeter")
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, idealWidth: 640, minHeight: 380, idealHeight: 420)
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selection {
        case .general: GeneralPane()
        case .appearance: AppearancePane()
        case .agents: AgentsPane()
        case .cost: CostPane()
        case .alerts: NotificationsPane()
        case .advanced: AdvancedPane()
        case .about: AboutPane()
        }
    }
}

// MARK: - Reusable section primitives

private struct PaneSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder var content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.bottom, 8)
    }
}

private struct PaneRow<Trailing: View>: View {
    let label: String
    var help: String?
    @ViewBuilder var trailing: Trailing

    init(_ label: String, help: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.help = help
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout)
                if let help {
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DripStore.self) private var store

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            PaneSection("Refresh") {
                PaneRow("Cadence", help: "How often DripMeter polls `drip meter`.") {
                    Picker("", selection: $settings.refreshCadence) {
                        ForEach(RefreshCadence.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                    .onChange(of: settings.refreshCadence) { _, _ in store.reconfigure() }
                }
                Divider()
                PaneRow(
                    "Watch database",
                    help: "Refresh in real time when DRIP commits a change to its SQLite store."
                ) {
                    Toggle("", isOn: $settings.liveWatchEnabled)
                        .labelsHidden()
                        .onChange(of: settings.liveWatchEnabled) { _, _ in store.reconfigure() }
                }
            }
            PaneSection("Lifecycle") {
                PaneRow("Launch at login", help: "Start DripMeter automatically when you sign in.") {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .labelsHidden()
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            LaunchAtLoginManager.setEnabled(newValue)
                        }
                }
            }
        }
    }
}

// MARK: - Appearance

private struct AppearancePane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            PaneSection("Menu bar") {
                PaneRow("Label style", help: "What to show next to the icon.") {
                    Picker("", selection: $settings.menuBarLabelStyle) {
                        ForEach(MenuBarLabelStyle.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }
            }
            PaneSection("Popover") {
                PaneRow("Width", help: "Compact for tight menu bars, wide for more detail.") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.popoverWidth, in: 320 ... 480, step: 10)
                            .frame(width: 140)
                        Text("\(Int(settings.popoverWidth)) pt")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Divider()
                PaneRow("Compact header", help: "Use the smaller hero card on the Overview tab.") {
                    Toggle("", isOn: $settings.compactMode).labelsHidden()
                }
            }
            PaneSection("History") {
                PaneRow("Default range", help: "How many days of history the sparkline shows.") {
                    Picker("", selection: $settings.defaultHistoryRange) {
                        ForEach(HistoryRange.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }
            }
            PaneSection(
                "Daily target",
                footer: "DripMeter shows your today-vs-target progress on the Overview tab. Set to 0 to hide it."
            ) {
                PaneRow("Target", help: "Tokens you'd like DRIP to save you each day.") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(settings.dailyTokenTarget) },
                                set: { settings.dailyTokenTarget = Int64($0) }
                            ),
                            in: 0 ... 200_000,
                            step: 5_000
                        )
                        .frame(width: 140)
                        Text(settings.dailyTokenTarget == 0
                             ? "off"
                             : DripFormatter.compactInteger(settings.dailyTokenTarget))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Agents

private struct AgentsPane: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DripStore.self) private var store

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            PaneSection("Show in popover") {
                ForEach(Array(DripAgent.allCases.enumerated()), id: \.element) { index, agent in
                    if index > 0 { Divider() }
                    PaneRow(agent.displayName) {
                        Toggle("", isOn: Binding(
                            get: { settings.enabledAgents.contains(agent) },
                            set: { newValue in
                                var updated = settings.enabledAgents
                                if newValue { updated.insert(agent) } else { updated.remove(agent) }
                                settings.enabledAgents = updated
                            }
                        ))
                        .labelsHidden()
                    }
                }
            }
            PaneSection(
                "Install status",
                footer: "DripMeter inspects each agent's config file. Wire one up via the Agents tab in the popover."
            ) {
                ForEach(Array(store.agentInstall.enumerated()), id: \.element.agent) { index, install in
                    if index > 0 { Divider() }
                    PaneRow(install.agent.displayName) {
                        Label(installSummary(install), systemImage: installSymbol(install))
                            .labelStyle(.titleAndIcon)
                            .font(.callout)
                            .foregroundStyle(installColor(install))
                    }
                }
                Divider()
                Button("Re-probe") { store.refreshAgentInstall() }
            }
        }
    }

    private func installSummary(_ install: AgentInstallStatus) -> String {
        switch install.state {
        case .wired: return "Wired"
        case .configFoundNoDrip: return "Config found, drip not registered"
        case .notInstalled: return "Not installed"
        case .unknown: return "Unknown"
        }
    }

    private func installSymbol(_ install: AgentInstallStatus) -> String {
        switch install.state {
        case .wired: return "checkmark.seal.fill"
        case .configFoundNoDrip: return "exclamationmark.circle.fill"
        case .notInstalled: return "minus.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    private func installColor(_ install: AgentInstallStatus) -> Color {
        switch install.state {
        case .wired: return .green
        case .configFoundNoDrip: return .orange
        case .notInstalled, .unknown: return .secondary
        }
    }
}

// MARK: - Cost

private struct CostPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            PaneSection("Pricing model") {
                PaneRow("Default model", help: "Used for the dollar projection in the Overview tab.") {
                    Picker("", selection: $settings.costModelId) {
                        ForEach(CostModel.presets) { Text($0.displayName).tag($0.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
                Divider()
                PaneRow(
                    "Use custom rate",
                    help: "Override with your own $/Mtok if you have a negotiated rate."
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.customPricePerMtok != nil },
                        set: { newValue in
                            settings.customPricePerMtok = newValue
                                ? (settings.customPricePerMtok ?? 3.0)
                                : nil
                        }
                    )).labelsHidden()
                }
                if settings.customPricePerMtok != nil {
                    Divider()
                    HStack {
                        Text("$")
                        TextField("0.00", value: Binding(
                            get: { settings.customPricePerMtok ?? 0 },
                            set: { settings.customPricePerMtok = $0 }
                        ), format: .number)
                            .frame(width: 80)
                        Text("per Mtok")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            PaneSection(
                "Reference rates",
                footer: "Sourced from each provider's published per-Mtok input pricing (May 2026)."
            ) {
                ForEach(Array(CostModel.presets.enumerated()), id: \.element.id) { index, model in
                    if index > 0 { Divider() }
                    PaneRow(model.displayName) {
                        Text(String(format: "$%.2f / Mtok", model.pricePerMtok))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Notifications

private struct NotificationsPane: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            PaneSection(
                "Milestones",
                footer: "DripMeter posts a one-shot macOS notification each time you cross a savings threshold."
            ) {
                PaneRow("Notifications", help: "Toggle off to silence all milestone alerts.") {
                    Toggle("", isOn: $settings.milestoneNotificationsEnabled).labelsHidden()
                }
            }
            PaneSection("Thresholds") {
                ForEach(Array(Milestone.allCases.sorted { $0.rank < $1.rank }.enumerated()), id: \.element) { index, milestone in
                    if index > 0 { Divider() }
                    PaneRow(milestone.displayName) {
                        EmptyView()
                    }
                }
                Divider()
                Button("Reset celebrated milestones") {
                    MilestoneTracker().reset()
                }
                Divider()
                Button("Reset compaction alerts") {
                    CompactionWatcher().reset()
                }
            }
        }
    }
}

// MARK: - Advanced

private struct AdvancedPane: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(DripStore.self) private var store

    @State private var pendingAction: DripQuickAction?
    @State private var actionInFlight: DripQuickAction?
    @State private var lastActionResult: String?

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 0) {
            PaneSection("File click-through") {
                PaneRow("Open files in", help: "Where DripMeter sends you when you click a file row.") {
                    Picker("", selection: $settings.preferredIDE) {
                        ForEach(IDEPreference.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }
            }

            PaneSection(
                "DRIP binary",
                footer: "Leave empty to auto-detect via $PATH and the usual install prefixes."
            ) {
                TextField("Path", text: $settings.dripBinaryPathOverride, prompt: Text("/opt/homebrew/bin/drip"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Apply") { store.reconfigure() }
            }

            if let storage = store.report.storage {
                PaneSection(
                    "Storage",
                    footer: "DRIP keeps everything in a single SQLite + on-disk blob cache."
                ) {
                    StoragePanelView(storage: storage)
                }
            }

            PaneSection(
                "Maintenance",
                footer: "Run DRIP cache and reset commands without opening a terminal."
            ) {
                ActionRow(
                    title: "Compact cache",
                    help: "Hoist large inline rows to the file cache and VACUUM the SQLite database.",
                    symbol: "rectangle.compress.vertical",
                    role: .neutral,
                    action: .cacheCompact,
                    inFlight: actionInFlight,
                    onTap: { runAction($0) }
                )
                Divider()
                ActionRow(
                    title: "Garbage-collect cache",
                    help: "Remove on-disk blobs whose hash no row references anymore.",
                    symbol: "arrow.clockwise.icloud",
                    role: .neutral,
                    action: .cacheGc,
                    inFlight: actionInFlight,
                    onTap: { runAction($0) }
                )
                Divider()
                ActionRow(
                    title: "Reset current session",
                    help: "Drop tracked reads for the current session — next read becomes a fresh first read.",
                    symbol: "arrow.uturn.backward",
                    role: .neutral,
                    action: .reset,
                    inFlight: actionInFlight,
                    onTap: { runAction($0) }
                )
                Divider()
                ActionRow(
                    title: "Wipe all DRIP data",
                    help: "Delete every session, baseline, lifetime counter, and on-disk blob. This cannot be undone.",
                    symbol: "trash",
                    role: .destructive,
                    action: .resetAll,
                    inFlight: actionInFlight,
                    onTap: { pendingAction = $0 }
                )
                if let lastActionResult {
                    Divider()
                    Text(lastActionResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .alert(
                "Wipe all DRIP data?",
                isPresented: Binding(
                    get: { pendingAction == .resetAll },
                    set: { if !$0 { pendingAction = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { pendingAction = nil }
                Button("Wipe everything", role: .destructive) {
                    pendingAction = nil
                    runAction(.resetAll)
                }
            } message: {
                Text("This deletes every session, baseline, pipeline cache row, file-registry entry, and lifetime counter. Your DRIP install itself stays put — just the captured state goes.")
            }

            PaneSection("Status") {
                PaneRow("Install") {
                    Text(installSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Divider()
                PaneRow("Database") {
                    Text(DripPaths.sessionsDatabaseURL().path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: 280, alignment: .trailing)
                        .textSelection(.enabled)
                }
                if case let .error(message) = store.loadState {
                    Divider()
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func runAction(_ action: DripQuickAction) {
        actionInFlight = action
        lastActionResult = nil
        Task {
            do {
                let cli = DripCLI(binaryPath: settings.resolvedBinaryOverride(), timeout: 30)
                let output = try await cli.runQuickAction(action)
                lastActionResult = output.split(separator: "\n").first.map(String.init) ?? "OK"
                await store.refresh()
            } catch {
                lastActionResult = "Failed: \(error.localizedDescription)"
            }
            actionInFlight = nil
        }
    }

    private var installSummary: String {
        switch store.installStatus {
        case .ready(let version): return version
        case .binaryMissing: return "drip binary not found"
        case .databaseMissing: return "binary OK, no database yet"
        case .probing: return "loading…"
        }
    }
}

// MARK: - About

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 8)
            BrandingLogoView(size: 96)
            Text("DripMeter")
                .font(.title2.weight(.semibold))
            Text(version)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Live token-savings meter for DRIP.\nRuns entirely on-device.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            HStack(spacing: 16) {
                Link("DRIP repo", destination: URL(string: "https://github.com/drip-cli/drip")!)
                Link("DripMeter repo", destination: URL(string: "https://github.com/drip-cli/dripmeter")!)
            }
            .font(.callout)
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(short) (\(build))"
    }
}
