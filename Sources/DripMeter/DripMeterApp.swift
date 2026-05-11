import AppKit
import DripMeterCore
import SwiftUI

@main
struct DripMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(appDelegate.store)
                .environment(appDelegate.settings)
                .onAppear {
                    Task { await appDelegate.store.refresh() }
                }
        } label: {
            MenuBarLabel(store: appDelegate.store, settings: appDelegate.settings)
        }
        .menuBarExtraStyle(.window)
        // Global hotkey: ⌃⌥D toggles the popover from anywhere. Hard-coded
        // for now — making it user-configurable is a follow-up if anyone
        // collides with it in their workflow.
        .keyboardShortcut("d", modifiers: [.control, .option])

        // We use a regular `Window` scene with an explicit identifier rather
        // than the `Settings` scene. Reason: SwiftUI's `Settings` scene goes
        // through the `showSettingsWindow:` AppKit selector under the hood,
        // which silently fails in roughly half the cases when triggered from
        // a MenuBarExtra(.window) dismiss-on-click context — the action
        // walks the responder chain and the popover dismissal often kicks
        // the responder out of scope before the action lands. `openWindow`
        // skips that whole dance and just creates/raises the window
        // directly via SwiftUI's scene graph.
        Window("DripMeter Settings", id: WindowIDs.settings) {
            PreferencesView()
                .environment(appDelegate.settings)
                .environment(appDelegate.store)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 640, height: 420)
    }
}

enum WindowIDs {
    static let settings = "io.drip-cli.dripmeter.settings"
}

/// Renders the menu bar item: brand icon (custom or built-in droplet) + an
/// optional dynamic label. Driven by the store via Observation so it updates
/// itself whenever stats change — no manual `withObservationTracking` loop.
private struct MenuBarLabel: View {
    let store: DripStore
    let settings: SettingsStore

    var body: some View {
        HStack(spacing: 4) {
            menuIcon
            if let label = labelText {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var menuIcon: some View {
        if let custom = MenuBarTemplateLoader.image() {
            Image(nsImage: custom)
        } else {
            Image(systemName: "drop.fill")
        }
    }

    private var labelText: String? {
        switch settings.menuBarLabelStyle {
        case .iconOnly: nil
        case .percent:
            store.report.tokensFull > 0 ? "\(store.report.reductionPct) %" : nil
        case .tokensSaved:
            DripFormatter.compactInteger(store.report.tokensSaved)
        case .dollarsSaved:
            DripFormatter.dollars(store.report.dollarsSaved)
        }
    }
}

/// Loads a user-supplied template PNG/PDF from `Branding/MenuBarIcon.*` if
/// present. Returns `nil` so the SF Symbol fallback can render — Image
/// caller handles that branch.
enum MenuBarTemplateLoader {
    static func image() -> NSImage? {
        for ext in ["pdf", "png"] {
            if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: ext),
               let image = NSImage(contentsOf: url)
            {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                return image
            }
        }
        return nil
    }
}

/// AppDelegate now only owns the store, settings, and milestone notifier —
/// MenuBarExtra handles the status item lifecycle for us.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore.shared
    let store: DripStore

    override init() {
        self.store = DripStore(settings: SettingsStore.shared)
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        LaunchAtLoginManager.setEnabled(settings.launchAtLogin)
        MilestoneNotifier.shared.register(with: store)
        store.start()
    }

    func applicationWillTerminate(_: Notification) {
        store.stop()
    }
}
