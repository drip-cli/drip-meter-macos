import DripMeterCore
import SwiftUI

/// Live tab: chronological feed of intercepted reads. Powered by the
/// `read_events` table written by every DRIP hook. Refreshes implicitly
/// via the FSEvents watcher (no extra polling loop here).
struct LiveTabView: View {
    @Environment(DripStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("last hour")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if store.recentEvents.isEmpty {
                EmptyStateView(
                    symbol: "dot.radiowaves.left.and.right",
                    title: "Nothing happening yet",
                    message: "DripMeter watches the read_events table in real time. Start a Claude/Codex/Gemini session and the latest intercepted reads will stream in here."
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(store.recentEvents) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: ReplayEvent
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: event.outcome.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(DripFormatter.shortenPath(event.filePath, maxLength: 34))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.head)
                    if event.isPostCompaction {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                            .help("Read happened right after a context compaction — DRIP rebuilt this baseline.")
                    }
                }
                HStack(spacing: 4) {
                    Text(event.outcome.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(DripFormatter.relativeTime(unixSeconds: event.occurredAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("−" + DripFormatter.compactInteger(event.tokensSaved))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(event.tokensSaved > 0 ? .primary : .secondary)
                Text("\(DripFormatter.compactInteger(event.tokensSent))/\(DripFormatter.compactInteger(event.tokensFull))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            IDELauncher.open(filePath: event.filePath, with: settings.preferredIDE)
        }
    }

    private var tint: Color {
        switch event.outcome {
        case .first, .firstCompressed: .blue
        case .unchanged, .partialUnchanged: .secondary
        case .delta: DripPalette.green
        case .fallback: .orange
        case .deleted: .red
        case .passthrough: .gray
        }
    }
}
