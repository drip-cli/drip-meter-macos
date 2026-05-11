import AppKit
import DripMeterCore
import SwiftUI

/// Files tab: full top-N list with search + click-through to the user's
/// preferred IDE/editor. Tap a row to open the file; right-click reveals
/// in Finder.
struct FilesTabView: View {
    @Environment(DripStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search files…", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            if filtered.isEmpty {
                EmptyFilesView(query: query)
            } else {
                VStack(spacing: 4) {
                    ForEach(filtered) { file in
                        FileRow(file: file, ide: settings.preferredIDE)
                    }
                }
            }
        }
    }

    private var filtered: [MeterReport.PerFile] {
        let source = store.topFiles.isEmpty ? store.report.top : store.topFiles
        guard !query.isEmpty else { return source }
        let needle = query.lowercased()
        return source.filter { $0.file.lowercased().contains(needle) }
    }
}

private struct FileRow: View {
    let file: MeterReport.PerFile
    let ide: IDEPreference

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DripFormatter.shortenPath(file.file, maxLength: 48))
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                Text("\(file.reads) reads · \(file.reductionPct) %")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DripFormatter.compactInteger(file.tokensSaved))
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .background(Color.primary.opacity(0.0001), in: RoundedRectangle(cornerRadius: 4))
        .onTapGesture {
            IDELauncher.open(filePath: file.file, with: ide)
        }
        .contextMenu {
            Button("Open in \(ide.displayName)") {
                IDELauncher.open(filePath: file.file, with: ide)
            }
            Button("Reveal in Finder") {
                IDELauncher.open(filePath: file.file, with: .finder)
            }
            Divider()
            Button("Copy path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.file, forType: .string)
            }
        }
    }
}

private struct EmptyFilesView: View {
    let query: String

    var body: some View {
        if query.isEmpty {
            EmptyStateView(
                symbol: "doc.on.doc",
                title: "No files tracked yet",
                message: "Wire DRIP into an agent and start a coding session — every file your agent reads will appear here ranked by tokens saved.",
                commands: [
                    "drip init -g                    # Claude Code",
                    "drip init --agent codex         # Codex CLI",
                    "drip init -g --agent gemini     # Gemini CLI",
                ]
            )
        } else {
            EmptyStateView(
                symbol: "magnifyingglass",
                title: "No matches",
                message: "Nothing in your tracked files contains \"\(query)\". Try a shorter substring or clear the search."
            )
        }
    }
}
