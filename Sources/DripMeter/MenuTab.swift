import SwiftUI

/// Segmented tabs at the top of the popover. Mirrors CodexBar's idiom of a
/// single segmented control that switches the lower scroll region.
enum MenuTab: String, CaseIterable, Identifiable {
    case overview
    case stats
    case agents
    case files
    case live

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: "Overview"
        case .stats: "Stats"
        case .agents: "Agents"
        case .files: "Files"
        case .live: "Live"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "chart.bar.fill"
        case .stats: "calendar"
        case .agents: "person.2.fill"
        case .files: "doc.on.doc.fill"
        case .live: "dot.radiowaves.left.and.right"
        }
    }
}
