import SwiftUI

/// Reusable "nothing here yet" placeholder. Three slots: an SF Symbol, a
/// short title, and one or two lines of guidance with optional inline
/// monospaced commands. Used by Files / Live / sessions empty states so
/// they all feel like the same family.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var commands: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(DripPalette.green)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !commands.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(commands, id: \.self) { cmd in
                        Text(cmd)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.primary.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }
}
