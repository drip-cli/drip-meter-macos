import SwiftUI

/// Centralised colour palette built around the brand green `#18E299`.
/// Exposed as `Color.dripGreen*` so we can swap individual shades without
/// having to grep every callsite.
enum DripPalette {
    /// Brand mint. Same value as the asset-catalog accent colour, kept
    /// here so views that need it explicitly (e.g. tab pills) can reach
    /// it without going through `Color.accentColor` (whose meaning macOS
    /// users can override system-wide).
    static let green = Color(red: 0x18 / 255, green: 0xE2 / 255, blue: 0x99 / 255)
    static let greenLight = Color(red: 0x4F / 255, green: 0xEA / 255, blue: 0xB2 / 255)
    static let greenDark = Color(red: 0x10 / 255, green: 0xB0 / 255, blue: 0x77 / 255)
    static let greenDeep = Color(red: 0x07 / 255, green: 0x80 / 255, blue: 0x55 / 255)

    /// Subtle background tint for unselected segments / containers. Adapts
    /// to dark mode automatically because we layer it on `secondary`.
    static let segmentTrack = Color.primary.opacity(0.06)
    static let segmentTrackHover = Color.primary.opacity(0.10)
}
