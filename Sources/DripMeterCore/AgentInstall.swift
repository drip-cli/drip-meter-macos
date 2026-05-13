import Foundation
import OSLog

/// Snapshot of whether a given agent has been wired up via `drip init`.
///
/// We don't run the agents themselves — we just inspect the config files
/// they read at startup. Logic mirrors `drip doctor` so the meter and the
/// CLI agree on what "installed" means.
public struct AgentInstallStatus: Sendable, Equatable, Identifiable {
    public enum State: String, Sendable, Equatable {
        case notInstalled // config file absent
        case configFoundNoDrip // config exists, but no drip hook/MCP entry
        case wired // drip is referenced in the config
        case unknown // probe failed (permissions, parse error)
    }

    public let agent: DripAgent
    public let state: State
    public let configPath: String?
    public let detail: String?

    public var id: DripAgent {
        agent
    }

    public var isWired: Bool {
        state == .wired
    }

    public var initCommand: String {
        switch agent {
        case .claude: "drip init -g"
        case .codex: "drip init --agent codex"
        case .gemini: "drip init -g --agent gemini"
        }
    }
}

/// Reads the per-agent config files that `drip init` writes to. Pure I/O,
/// no UI — a separate observable wraps this to cache + refresh.
public enum AgentInstallProbe {
    private static let logger = DripLogger.app

    public static func probeAll() -> [AgentInstallStatus] {
        DripAgent.allCases.map(probe)
    }

    public static func probe(_ agent: DripAgent) -> AgentInstallStatus {
        switch agent {
        case .claude: probeClaude()
        case .codex: probeCodex()
        case .gemini: probeGemini()
        }
    }

    private static func probeClaude() -> AgentInstallStatus {
        let path = "\(NSHomeDirectory())/.claude/settings.json"
        guard FileManager.default.fileExists(atPath: path) else {
            return AgentInstallStatus(
                agent: .claude,
                state: .notInstalled,
                configPath: path,
                detail: "settings.json not found"
            )
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return AgentInstallStatus(
                agent: .claude,
                state: .unknown,
                configPath: path,
                detail: "settings.json could not be parsed"
            )
        }
        // `drip init` adds entries under `hooks.PreToolUse[*].hooks[*].command`
        // that contain `drip hook claude`. Sniff for that string.
        let serialised = String(data: data, encoding: .utf8) ?? ""
        let wired = serialised.contains("drip hook claude") || serialised.contains("drip mcp")
        // Side-effect-free use of `json` so the parse isn't optimised away.
        _ = json["hooks"]
        return AgentInstallStatus(
            agent: .claude,
            state: wired ? .wired : .configFoundNoDrip,
            configPath: path,
            detail: wired ? nil : "DRIP hooks not found in settings.json"
        )
    }

    private static func probeCodex() -> AgentInstallStatus {
        let path = "\(NSHomeDirectory())/.codex/config.toml"
        guard FileManager.default.fileExists(atPath: path) else {
            return AgentInstallStatus(
                agent: .codex,
                state: .notInstalled,
                configPath: path,
                detail: "config.toml not found"
            )
        }
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return AgentInstallStatus(
                agent: .codex,
                state: .unknown,
                configPath: path,
                detail: "config.toml could not be read"
            )
        }
        // `drip init --agent codex` registers an MCP server with command
        // `drip` and arg `mcp`. The TOML key is `mcp_servers.drip`.
        let wired = contents.contains("[mcp_servers.drip]") || contents.contains("mcp_servers.drip")
        return AgentInstallStatus(
            agent: .codex,
            state: wired ? .wired : .configFoundNoDrip,
            configPath: path,
            detail: wired ? nil : "drip MCP server not registered in config.toml"
        )
    }

    private static func probeGemini() -> AgentInstallStatus {
        let path = "\(NSHomeDirectory())/.gemini/settings.json"
        guard FileManager.default.fileExists(atPath: path) else {
            return AgentInstallStatus(
                agent: .gemini,
                state: .notInstalled,
                configPath: path,
                detail: "settings.json not found"
            )
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let serialised = String(data: data, encoding: .utf8)
        else {
            return AgentInstallStatus(
                agent: .gemini,
                state: .unknown,
                configPath: path,
                detail: "settings.json could not be read"
            )
        }
        let wired = serialised.contains("\"drip\"") && serialised.contains("mcp")
        return AgentInstallStatus(
            agent: .gemini,
            state: wired ? .wired : .configFoundNoDrip,
            configPath: path,
            detail: wired ? nil : "drip MCP server not registered in settings.json"
        )
    }
}
