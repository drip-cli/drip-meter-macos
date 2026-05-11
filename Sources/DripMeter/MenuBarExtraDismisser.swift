import AppKit

/// Forces the MenuBarExtra(.window) popover to close.
///
/// SwiftUI gives no official API for this — `MenuBarExtra` doesn't accept a
/// `Bool` binding for its panel visibility, only for whether the menu bar
/// item is *inserted* at all. Killing the menu bar item to close the panel
/// would steal the icon, which we want to keep.
///
/// What we do instead: walk `NSApp.windows`, find the one whose internal
/// class name marks it as the menu bar extra panel, and `orderOut(nil)` it.
/// The class name is private (`NSStatusBarWindow` and friends), so we match
/// on a substring. If Apple ever renames it, the worst that happens is the
/// popover stops auto-closing on Settings — it'll still dismiss on
/// click-outside, which is the OS-level behaviour.
enum MenuBarExtraDismisser {
    @MainActor
    static func dismiss() {
        for window in NSApp.windows where shouldDismiss(window) {
            window.orderOut(nil)
        }
    }

    private static func shouldDismiss(_ window: NSWindow) -> Bool {
        let className = String(describing: type(of: window)).lowercased()
        // Both names cover the macOS 14 + macOS 15+ MenuBarExtra runtime
        // implementations we've seen in practice. Be permissive — we'd
        // rather close one too many transient windows than leave the
        // popover hanging.
        return className.contains("menubar")
            || className.contains("statusbar")
            || className.contains("popover")
    }
}
