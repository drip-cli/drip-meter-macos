import AppKit
import SwiftUI

/// Renders the in-app brand mark. Loads `BrandingLogo.png` / `.pdf` from the
/// SPM resource bundle if the user dropped one in `Branding/`; falls back to
/// the SF Symbol droplet so the About pane never renders empty.
struct BrandingLogoView: View {
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let image = Self.bundledLogo() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "drop.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
    }

    private static func bundledLogo() -> NSImage? {
        for ext in ["png", "pdf"] {
            if let url = AppResources.bundle.url(forResource: "BrandingLogo", withExtension: ext),
               let image = NSImage(contentsOf: url)
            {
                return image
            }
        }
        return nil
    }
}
