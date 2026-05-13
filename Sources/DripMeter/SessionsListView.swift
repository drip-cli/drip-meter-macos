import DripMeterCore
import SwiftUI

/// Compact list of recent DRIP sessions, used inside the Agents tab below
/// the per-agent cards. Click on a row to reveal the working directory in
/// Finder so the user can jump back to the project that produced those
/// savings.
struct SessionsListView: View {
    let sessions: [SessionRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent sessions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(sessions.count) total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if sessions.isEmpty {
                Text("No sessions yet — DRIP creates one per project root once an agent reads a file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(sessions.prefix(8))) { session in
                        SessionRowView(session: session)
                    }
                }
            }
        }
    }
}

private struct SessionRowView: View {
    let session: SessionRow

    var body: some View {
        HStack(spacing: 8) {
            agentMark
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(session.label)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if session.compactionCount > 0 {
                        compactionBadge
                    }
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(DripFormatter.compactInteger(session.tokensSaved))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                Text("\(session.reductionPct) %")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let cwd = session.cwd else { return }
            IDELauncher.open(filePath: cwd, with: .finder)
        }
    }

    /// Tiny pill rendering `↺ N` in orange when this session has been
    /// context-compacted at least once. Tooltip explains what it means
    /// for users not familiar with v9 visibility ledger.
    private var compactionBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 9, weight: .semibold))
            Text("\(session.compactionCount)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            Capsule().fill(Color.orange.opacity(0.14))
        )
        .help(
            "Context was compacted \(session.compactionCount) time\(session.compactionCount == 1 ? "" : "s") in this session — DRIP had to rebuild some baselines."
        )
    }

    @ViewBuilder
    private var agentMark: some View {
        if let agent = session.agent {
            ZStack {
                Circle()
                    .fill(Color(agentHex: agent.accentHex).opacity(0.18))
                    .frame(width: 22, height: 22)
                AgentLogo(agent: agent, size: 14)
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 22, height: 22)
                Image(systemName: "terminal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        let agentLabel = session.agent?.displayName ?? "shell"
        let when = DripFormatter.relativeTime(unixSeconds: session.lastActiveAt)
        return "\(agentLabel) · \(when) · \(session.filesTracked) files"
    }
}
