import AppKit
import DripMeterCore
import SwiftUI

/// Displays the official Anthropic / OpenAI / Google logos for each agent.
/// SVGs ship in the SPM resource bundle; we load them via `Bundle.module`
/// because they live in the resource bundle's root, not in the asset catalog.
struct AgentLogo: View {
    let agent: DripAgent
    var size: CGFloat = 20
    var template: Bool = false

    var body: some View {
        Group {
            if let image = AgentLogoLoader.image(for: agent) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(template ? .template : .original)
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: agent.symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color(agentHex: agent.accentHex))
            }
        }
        .frame(width: size, height: size)
    }
}

enum AgentLogoLoader {
    static func image(for agent: DripAgent) -> NSImage? {
        let baseName = switch agent {
        case .claude: "ProviderIcon-claude"
        case .codex: "ProviderIcon-codex"
        case .gemini: "ProviderIcon-gemini"
        }
        guard let url = Bundle.module.url(forResource: baseName, withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }
}

extension Color {
    /// `#RRGGBB` parser used for the agent accent fallbacks defined in
    /// `DripAgent.accentHex`.
    init(agentHex: String) {
        var sanitized = agentHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
