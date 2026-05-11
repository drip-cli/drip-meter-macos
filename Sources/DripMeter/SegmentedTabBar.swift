import SwiftUI

/// Custom segmented control. macOS's native `Picker(.segmented)` is too
/// narrow and visually flat in the menu bar context; this one stretches to
/// fill the popover width, uses the brand green for the active pill, and
/// animates the selection so it's clear what changed.
struct SegmentedTabBar: View {
    @Binding var selection: MenuTab
    var namespaceID: String = "tabbar"
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MenuTab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selection == tab,
                    namespace: namespace
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        selection = tab
                    }
                }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(DripPalette.segmentTrack)
        )
    }
}

private struct TabButton: View {
    let tab: MenuTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(tab.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        // The brand mint `#18E299` itself is too bright to
                        // carry white text — contrast lands around 1.4:1.
                        // Use the darker shade for the pill so the label
                        // stays legible while keeping the same hue family.
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LinearGradient(
                                colors: [DripPalette.green, DripPalette.greenDark],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .matchedGeometryEffect(id: "selectedPill", in: namespace)
                    } else if isHovering {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(DripPalette.segmentTrackHover)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
