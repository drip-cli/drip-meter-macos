import DripMeterCore
import SwiftUI

/// Per-agent rows: Claude / Codex / Gemini, with savings count and last-active
/// pill. Uses the official provider logo + a per-agent install badge.
struct AgentBreakdownView: View {
    let agents: [AgentBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Per agent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            VStack(spacing: 6) {
                ForEach(agents, id: \.agent) { breakdown in
                    AgentRow(breakdown: breakdown)
                }
            }
        }
    }
}

private struct AgentRow: View {
    let breakdown: AgentBreakdown
    @Environment(DripStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(agentTint.opacity(0.18))
                    .frame(width: 30, height: 30)
                AgentLogo(agent: breakdown.agent, size: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(breakdown.agent.displayName)
                        .font(.body.weight(.medium))
                    if let install = installStatus, install.isWired {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if !breakdown.hasActivity {
                        Text("not yet wired")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DripFormatter.compactInteger(breakdown.tokensSaved))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("\(breakdown.reductionPct) %")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var installStatus: AgentInstallStatus? {
        store.agentInstall.first { $0.agent == breakdown.agent }
    }

    private var agentTint: Color {
        switch breakdown.agent {
        case .claude: Color(red: 0.85, green: 0.46, blue: 0.34)
        case .codex: Color(red: 0.06, green: 0.64, blue: 0.50)
        case .gemini: Color(red: 0.10, green: 0.45, blue: 0.91)
        }
    }

    private var subtitle: String {
        if breakdown.hasActivity {
            let sessions = breakdown.sessions == 1 ? "1 session" : "\(breakdown.sessions) sessions"
            let lastActive = DripFormatter.relativeTime(unixSeconds: breakdown.lastActiveAt)
            return "\(sessions) · \(lastActive)"
        }
        // No activity yet — pick the right hint based on whether DRIP is
        // already wired into the agent's config files.
        if installStatus?.isWired == true {
            return "Hooks installed · waiting for first read"
        }
        return "Run \(installCommand) to enable"
    }

    private var installCommand: String {
        installStatus?.initCommand ?? "drip init --agent \(breakdown.agent.rawValue)"
    }
}
