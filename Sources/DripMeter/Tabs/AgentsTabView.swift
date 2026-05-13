import DripMeterCore
import SwiftUI

/// Agents tab: full per-agent card with install detection + 1-click `drip
/// init`. The card spells out exactly what state each agent is in so the
/// user knows whether the savings number is meaningful.
struct AgentsTabView: View {
    @Environment(DripStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(visibleAgents, id: \.agent) { breakdown in
                AgentDetailCard(
                    breakdown: breakdown,
                    install: installFor(breakdown.agent),
                    quota: quotaFor(breakdown.agent)
                )
            }
            // CodexBar bridge is opt-in: when CodexBar isn't installed we
            // silently omit anything quota-related rather than nag the
            // user about another app. The per-card AgentQuotaBar only
            // renders when a snapshot was actually returned.
            if !store.sessions.isEmpty {
                Divider()
                SessionsListView(sessions: store.sessions)
            }
        }
    }

    private func quotaFor(_ agent: DripAgent) -> AgentQuotaSnapshot? {
        store.agentQuotas.first { $0.agent == agent }
    }

    private var visibleAgents: [AgentBreakdown] {
        store.agents.filter { settings.enabledAgents.contains($0.agent) }
    }

    private func installFor(_ agent: DripAgent) -> AgentInstallStatus? {
        store.agentInstall.first { $0.agent == agent }
    }
}

private struct AgentDetailCard: View {
    let breakdown: AgentBreakdown
    let install: AgentInstallStatus?
    let quota: AgentQuotaSnapshot?
    @Environment(DripStore.self) private var store
    @State private var isWiring = false
    @State private var wireResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentLogo(agent: breakdown.agent, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(breakdown.agent.displayName)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                installBadge
            }

            HStack(spacing: 12) {
                StatBlock(label: "Saved", value: DripFormatter.compactInteger(breakdown.tokensSaved))
                StatBlock(label: "Reduction", value: "\(breakdown.reductionPct) %")
                StatBlock(label: "Sessions", value: "\(breakdown.sessions)")
                StatBlock(label: "Files", value: "\(breakdown.filesTracked)")
            }

            if let quota {
                Divider()
                AgentQuotaBar(snapshot: quota)
            }

            if let install, !install.isWired {
                wireUpRow(install: install)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func wireUpRow(install: AgentInstallStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(install.detail ?? "Not yet wired with `drip init`")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    runInit()
                } label: {
                    HStack(spacing: 6) {
                        if isWiring {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "link.badge.plus")
                        }
                        Text(install.initCommand)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .disabled(isWiring)
                Spacer()
            }
            if let wireResult {
                Text(wireResult)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private var installBadge: some View {
        if let install {
            switch install.state {
            case .wired:
                badge("Wired", symbol: "checkmark.circle.fill", color: .green)
            case .configFoundNoDrip:
                badge("Config OK", symbol: "exclamationmark.circle.fill", color: .orange)
            case .notInstalled:
                badge("Missing", symbol: "minus.circle", color: .secondary)
            case .unknown:
                badge("Unknown", symbol: "questionmark.circle", color: .secondary)
            }
        }
    }

    private func badge(_ text: String, symbol: String, color: Color) -> some View {
        // SwiftUI's `Label(_, systemImage:)` ships a generous icon-title gap
        // (~6 pt on macOS) that read as too airy in this card. Hand-rolled
        // HStack with a 3 pt gap matches the segmented-tab icon density.
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
    }

    private var subtitle: String {
        if !breakdown.hasActivity {
            return "no activity yet"
        }
        let last = DripFormatter.relativeTime(unixSeconds: breakdown.lastActiveAt)
        return "last active \(last)"
    }

    private func runInit() {
        let action: DripQuickAction = switch breakdown.agent {
        case .claude: .initClaude
        case .codex: .initCodex
        case .gemini: .initGemini
        }
        isWiring = true
        wireResult = nil
        Task {
            do {
                let cli = DripCLI(binaryPath: nil, timeout: 30)
                let output = try await cli.runQuickAction(action)
                wireResult = output.split(separator: "\n").first.map(String.init) ?? "OK"
                store.refreshAgentInstall()
            } catch {
                wireResult = "Failed: \(error.localizedDescription)"
            }
            isWiring = false
        }
    }
}

private struct StatBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
