import Foundation

/// Display-side helpers. Pulled out of the views so they're trivially testable
/// and reused across the popover, menu bar label, and Settings preview.
public enum DripFormatter {
    /// Compact "12.3K" style. Used for token counts that easily climb into the
    /// hundreds of thousands.
    public static func compactInteger(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        // Force `.` as the decimal separator. Token counts read the same way
        // regardless of user locale — and CLI tooling (drip meter) prints them
        // that way too, so the menu bar value matches the terminal.
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let absValue = abs(value)
        if absValue >= 1_000_000_000 {
            return (formatter.string(from: NSNumber(value: Double(value) / 1_000_000_000)) ?? "0") + "B"
        }
        if absValue >= 1_000_000 {
            return (formatter.string(from: NSNumber(value: Double(value) / 1_000_000)) ?? "0") + "M"
        }
        if absValue >= 1000 {
            return (formatter.string(from: NSNumber(value: Double(value) / 1000)) ?? "0") + "K"
        }
        return "\(value)"
    }

    public static func percent(_ value: Int) -> String {
        "\(value) %"
    }

    public static func dollars(_ value: Double) -> String {
        // We deliberately bypass `NumberFormatter` here. In French locales it
        // renders USD as `0,21 US$` with a trailing currency code, which is
        // technically correct but ugly in a tight menu-bar UI. Force the
        // canonical "$N.NN" form regardless of locale.
        let absValue = abs(value)
        let digits = absValue >= 100 ? 0 : 2
        let sign = value < 0 ? "−" : ""
        return sign + "$" + String(format: "%.\(digits)f", absValue)
    }

    public static func grams(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1f kg", value / 1000)
        }
        return String(format: "%.0f g", value)
    }

    /// Short "5m ago", "2h ago" relative time. `Date.RelativeFormatStyle` would
    /// also work but pads with full words on macOS 14 — too verbose for the menu.
    public static func relativeTime(unixSeconds: Int64?, now: Date = Date()) -> String {
        guard let seconds = unixSeconds else { return "—" }
        let then = Date(timeIntervalSince1970: TimeInterval(seconds))
        let delta = Int(now.timeIntervalSince(then))
        if delta < 60 { return "just now" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        if delta < 86400 { return "\(delta / 3600)h ago" }
        return "\(delta / 86400)d ago"
    }

    /// Truncate a long file path with a leading ellipsis so the tail stays
    /// readable in narrow rows.
    public static func shortenPath(_ path: String, maxLength: Int = 32) -> String {
        if path.count <= maxLength { return path }
        let suffix = path.suffix(maxLength - 1)
        return "…" + suffix
    }
}
