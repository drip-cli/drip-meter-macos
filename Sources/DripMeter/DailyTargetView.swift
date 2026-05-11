import SwiftUI

/// Shared label style with a 3 pt icon-text gap. Matches the agent install
/// badges in `AgentsTabView` so all small status-pills feel consistent.
struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
