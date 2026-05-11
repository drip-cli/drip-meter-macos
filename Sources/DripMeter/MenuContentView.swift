import DripMeterCore
import SwiftUI

/// Popover root. CodexBar-style layout:
///
///   ┌──────────────────────────┐
///   │ DripMeter   Updated 5m   │   ← thin header strip
///   │ [Overview] [Agents] [..] │   ← segmented control AT THE TOP
///   ├──────────────────────────┤
///   │ (tab content, scrolls)   │
///   └──────────────────────────┘
///
/// The big "X tokens saved" hero card lives inside the Overview tab now.
struct MenuContentView: View {
    @Environment(DripStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @State private var tab: MenuTab = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch store.installStatus {
            case .binaryMissing:
                BinaryMissingView()
                    .padding(20)
            case .databaseMissing where store.report.tokensFull == 0:
                DatabaseMissingView()
                    .padding(20)
            default:
                contentLayout
            }
            FooterBarView()
        }
        .frame(width: settings.popoverWidth)
    }

    @ViewBuilder
    private var contentLayout: some View {
        VStack(spacing: 0) {
            TopHeaderBar()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            SegmentedTabBar(selection: $tab)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .overview:
                        OverviewTabView()
                    case .stats:
                        StatsTabView()
                    case .agents:
                        AgentsTabView()
                    case .files:
                        FilesTabView()
                    case .live:
                        LiveTabView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            // Default popover height bumped from 480 → 640 so the
            // Streak panel + per-agent block fit on screen without
            // forcing the user to discover the scroll. Cap stays at
            // 720 so the panel never grows taller than a sub-1080p
            // display can render cleanly above the dock.
            .frame(minHeight: 640, maxHeight: 720)
        }
    }
}

// MARK: - Top header strip (CodexBar idiom)

private struct TopHeaderBar: View {
    @Environment(DripStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            BrandingLogoView(size: 18)
            Text("DripMeter")
                .font(.system(.headline, design: .rounded).weight(.semibold))
            Spacer()
            statusBadge
        }
    }

    /// Subtitle line. Background refreshes leave `loadState = .loaded(at:)`
    /// untouched — only `isRefreshing` toggles — so the timestamp text is
    /// rock-stable and never flickers during FSEvents-driven repaints.
    @ViewBuilder
    private var statusBadge: some View {
        switch store.loadState {
        case let .error(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.orange)
        case .coldLoading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Refreshing…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case let .loaded(at):
            TimelineView(.periodic(from: at, by: 60)) { context in
                Text("Updated \(DripFormatter.relativeTime(unixSeconds: Int64(at.timeIntervalSince1970), now: context.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .idle:
            Text("Loading…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Empty states

private struct BinaryMissingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("DRIP not found", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text("DripMeter needs the `drip` binary in your PATH to read stats.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("brew install drip-cli/drip/drip")
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .textSelection(.enabled)
            Link("Install docs →",
                 destination: URL(string: "https://github.com/drip-cli/drip#install")!)
                .font(.callout)
        }
        .frame(width: 320, alignment: .leading)
    }
}

private struct DatabaseMissingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No DRIP activity yet", systemImage: "drop")
                .font(.headline)
            Text("Wire DRIP into an agent and your savings will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("drip init                       # Claude Code")
                .font(.system(.body, design: .monospaced))
            Text("drip init --agent codex         # Codex CLI")
                .font(.system(.body, design: .monospaced))
            Text("drip init --agent gemini        # Gemini CLI")
                .font(.system(.body, design: .monospaced))
        }
        .frame(width: 320, alignment: .leading)
    }
}

// MARK: - Footer

private struct FooterBarView: View {
    @Environment(DripStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 6) {
            FooterButton(symbol: "arrow.clockwise", label: "Refresh") {
                Task { await store.refresh() }
            }
            FooterButton(symbol: "gearshape", label: "Settings") {
                // Order matters here:
                // 1. Dismiss the MenuBarExtra popover. SwiftUI doesn't expose
                //    an official API so we walk NSApp.windows and order out
                //    the one whose private class name marks it as the menu
                //    bar extra panel.
                // 2. Open the settings window via SwiftUI's scene graph.
                // 3. Activate the app so the LSUIElement bundle pulls the
                //    new window in front.
                MenuBarExtraDismisser.dismiss()
                openWindow(id: WindowIDs.settings)
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            FooterButton(symbol: "power", label: "Quit", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

private struct FooterButton: View {
    let symbol: String
    let label: String
    var role: Role = .neutral
    let action: () -> Void

    enum Role { case neutral, destructive }

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        switch role {
        case .neutral: isHovering ? .primary : .secondary
        case .destructive: isHovering ? .red : .secondary
        }
    }

    private var background: Color {
        guard isHovering else { return .clear }
        return role == .destructive
            ? Color.red.opacity(0.12)
            : DripPalette.segmentTrackHover
    }
}
