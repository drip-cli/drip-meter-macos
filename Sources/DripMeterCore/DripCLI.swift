import Foundation
import OSLog

public enum DripCLIError: Error, LocalizedError {
    case binaryNotFound
    case nonZeroExit(code: Int32, stderr: String)
    case decodeFailed(underlying: Error, payload: String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            "drip binary not found in PATH or common install locations"
        case let .nonZeroExit(code, stderr):
            "drip exited with code \(code): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        case let .decodeFailed(underlying, _):
            "drip output could not be decoded: \(underlying.localizedDescription)"
        }
    }
}

/// Thin shell wrapper around the `drip` CLI. Lives entirely in user space —
/// no special entitlements, no admin escalation. Long-running invocations are
/// safe to cancel because we use a `Process` and rely on the parent task being
/// cooperatively cancellable via the timeout.
public actor DripCLI {
    private let logger = DripLogger.cli
    private let binaryPath: String?
    private let timeout: TimeInterval

    public init(binaryPath: String? = nil, timeout: TimeInterval = 8) {
        self.binaryPath = binaryPath
        self.timeout = timeout
    }

    public func resolveBinaryURL() -> URL? {
        DripPaths.resolveBinary(overridePath: binaryPath)
    }

    public func meterReport() async throws -> MeterReport {
        // Always pass `--history` so the JSON includes the `history`
        // array (per-day buckets). Without it DRIP omits the field
        // entirely and the rollup / heatmap panels stay invisible
        // because they gate on `report.history`. The extra GROUP BY
        // is cheap (single sweep over `lifetime_daily`).
        let payload = try await run(["meter", "--history", "--json"])
        do {
            let data = Data(payload.utf8)
            let report = try JSONDecoder().decode(MeterReport.self, from: data)
            return report
        } catch {
            logger.error("Failed to decode meter --json: \(error.localizedDescription, privacy: .public)")
            throw DripCLIError.decodeFailed(underlying: error, payload: payload)
        }
    }

    public func version() async throws -> String {
        try await run(["--version"]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Public passthrough so `DripQuickAction` can dispatch arbitrary
    /// subcommands (`drip reset`, `drip cache compact`, …) through the same
    /// timeout + env-scrubbing pipeline as the typed calls above.
    public func runPublic(_ args: [String]) async throws -> String {
        try await run(args)
    }

    /// Run `drip <args>` and return stdout. Throws on non-zero exit.
    private func run(_ args: [String]) async throws -> String {
        guard let binary = resolveBinaryURL() else {
            throw DripCLIError.binaryNotFound
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = binary
            process.arguments = args
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = scrubbedEnvironment()

            // Capture concurrently to avoid pipe-buffer back-pressure deadlocks
            // when stderr is chatty.
            let stdoutBox = OutputBox()
            let stderrBox = OutputBox()
            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stdoutBox.append(data)
                }
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stderrBox.append(data)
                }
            }

            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                let outString = stdoutBox.string
                let errString = stderrBox.string
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outString)
                } else {
                    continuation.resume(throwing: DripCLIError.nonZeroExit(
                        code: proc.terminationStatus,
                        stderr: errString
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // Hard timeout: terminate the process if it overstays.
            let deadline = DispatchTime.now() + timeout
            DispatchQueue.global().asyncAfter(deadline: deadline) { [weak process] in
                guard let process, process.isRunning else { return }
                process.terminate()
            }
        }
    }

    /// Strip env-vars that would change DRIP's output shape (colour codes,
    /// debug verbosity) so JSON decoding is deterministic.
    private func scrubbedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        env.removeValue(forKey: "FORCE_COLOR")
        return env
    }
}

/// Tiny thread-safe accumulator for piped output. `Pipe.readabilityHandler`
/// fires on a background queue; we serialise appends through a `NSLock` so
/// the captured string is consistent at termination time.
private final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: buffer, encoding: .utf8) ?? ""
    }
}
