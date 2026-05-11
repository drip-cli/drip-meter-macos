import DripMeterCore
import SwiftUI

/// Single button-styled row inside a PaneSection. Used in Settings →
/// Advanced → Maintenance to expose `drip cache compact`, `drip reset`,
/// etc. without dropping to a terminal. Shows a spinner while the action
/// is in-flight and surfaces destructive variants in red.
struct ActionRow: View {
    enum Role { case neutral, destructive }

    let title: String
    let help: String
    let symbol: String
    let role: Role
    let action: DripQuickAction
    let inFlight: DripQuickAction?
    let onTap: (DripQuickAction) -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onTap(action)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 28, height: 28)
                    if inFlight == action {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(iconForeground)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(role == .destructive ? .red : .primary)
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(inFlight != nil && inFlight != action)
        .onHover { isHovering = $0 }
    }

    private var iconForeground: Color {
        switch role {
        case .neutral: DripPalette.greenDark
        case .destructive: .red
        }
    }

    private var iconBackground: Color {
        switch role {
        case .neutral: DripPalette.green.opacity(0.18)
        case .destructive: Color.red.opacity(0.14)
        }
    }
}
