import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Editors DripMeter can hand off to via `open -a` or a custom URL scheme.
/// The list is small on purpose — we only ship integrations users actually
/// have installed in the macOS dev tooling space.
public enum IDEPreference: String, CaseIterable, Identifiable, Sendable, Codable {
    case finder
    case xcode
    case vscode
    case cursor
    case zed
    case sublime
    case nova
    case textmate
    case terminal

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .finder: "Finder"
        case .xcode: "Xcode"
        case .vscode: "Visual Studio Code"
        case .cursor: "Cursor"
        case .zed: "Zed"
        case .sublime: "Sublime Text"
        case .nova: "Nova"
        case .textmate: "TextMate"
        case .terminal: "Terminal"
        }
    }

    /// Bundle identifier used by `open -b`. Reveal-in-Finder uses a
    /// different code path (`NSWorkspace.activateFileViewerSelecting`).
    public var bundleIdentifier: String? {
        switch self {
        case .finder: nil
        case .xcode: "com.apple.dt.Xcode"
        case .vscode: "com.microsoft.VSCode"
        case .cursor: "com.todesktop.230313mzl4w4u92"
        case .zed: "dev.zed.Zed"
        case .sublime: "com.sublimetext.4"
        case .nova: "com.panic.Nova"
        case .textmate: "com.macromates.TextMate"
        case .terminal: "com.apple.Terminal"
        }
    }
}

public enum IDELauncher {
    public static func open(filePath: String, with preference: IDEPreference) {
        let url = URL(fileURLWithPath: filePath)
        if preference == .finder {
            NSWorkspaceShim.revealInFinder(url)
            return
        }
        guard let bundleId = preference.bundleIdentifier else {
            NSWorkspaceShim.revealInFinder(url)
            return
        }
        NSWorkspaceShim.openFile(url, withBundleIdentifier: bundleId)
    }
}

/// Tiny shim over `NSWorkspace`. Lives here so the Core target can stay
/// AppKit-agnostic in tests (we don't use the shim under `XCTest`).
enum NSWorkspaceShim {
    static func revealInFinder(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    static func openFile(_ url: URL, withBundleIdentifier bundleId: String) {
        #if canImport(AppKit)
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, _ in }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        #endif
    }
}
