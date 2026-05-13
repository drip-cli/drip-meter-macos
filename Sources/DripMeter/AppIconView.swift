import AppKit
import SwiftUI

/// Loads the bundled macOS app icon (the squircle "with-background" art) so
/// we can show it on the About pane. NSImage's `applicationIconImage` won't
/// resolve in a non-running test process, so we fall back through every
/// reasonable source: the bundle's AppIcon.icns, then the system icon, then
/// the brand mark, then an SF Symbol.
struct AppIconView: View {
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let nsImage = AppIconLoader.image() {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                BrandingLogoView(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

enum AppIconLoader {
    // `@MainActor` is required because `NSApp` and
    // `NSApplication.applicationIconImage` are declared with
    // `NS_SWIFT_UI_ACTOR` (main-actor isolated). Under Swift 6 strict
    // concurrency — which Package.swift opts into via
    // `.enableUpcomingFeature("StrictConcurrency")` — a nonisolated
    // static method can't read those without explicit isolation.
    // The function is only ever called from SwiftUI view bodies, so
    // we're always on the main actor at the call site anyway.
    @MainActor
    static func image() -> NSImage? {
        // 1. Bundle's compiled .icns shipped at Contents/Resources/AppIcon.icns
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // 2. NSApplication's running-app icon — set automatically when the
        //    bundle has CFBundleIconFile or the asset catalog wires up the
        //    AppIcon set.
        let runtimeIcon = NSApp?.applicationIconImage
        if let runtimeIcon, runtimeIcon.size.width > 0 {
            return runtimeIcon
        }
        return nil
    }
}
