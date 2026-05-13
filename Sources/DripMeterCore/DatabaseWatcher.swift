import Foundation
import OSLog

/// Watches DRIP's `sessions.db` for content changes via `DispatchSource`'s
/// vnode kqueue events. Cheaper than polling and reacts within milliseconds
/// of the CLI committing a transaction.
///
/// macOS atomically replaces sqlite files on some operations, which removes
/// the original file descriptor — we re-arm on `.delete` events accordingly.
public final class DatabaseWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "io.drip-cli.dripmeter.dbwatcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var rearmTask: DispatchWorkItem?
    private let logger = DripLogger.database

    public init(url: URL = DripPaths.sessionsDatabaseURL(), onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    public func start() {
        queue.async { [weak self] in
            self?.armSource()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.tearDown()
        }
    }

    private func armSource() {
        tearDown()
        guard FileManager.default.fileExists(atPath: url.path) else {
            // DB doesn't exist yet — schedule a re-arm in 5 s. The user
            // probably hasn't run `drip init` yet; we'll pick it up later.
            scheduleRearm(after: 5)
            return
        }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.warning("Failed to open sessions.db for watching: errno=\(errno)")
            scheduleRearm(after: 10)
            return
        }
        // We deliberately omit `.attrib` from the mask. atime / inode-stat
        // updates fire every time anyone (including DripMeter itself when
        // it shells out to `drip meter`) opens the DB, which would create a
        // tight refresh loop: read → atime change → FSEvents → refresh →
        // read. We only care about content/topology changes.
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            onChange()
            // SQLite often atomically renames over the file. If the inode is
            // gone, re-arm on the new one after a short coalescing delay.
            let mask = source.data
            if mask.contains(.delete) || mask.contains(.rename) {
                scheduleRearm(after: 0.5)
            }
        }
        source.setCancelHandler { [fd] in
            close(fd)
        }
        source.resume()
        self.source = source
        fileDescriptor = fd
    }

    private func scheduleRearm(after seconds: TimeInterval) {
        rearmTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.armSource()
        }
        rearmTask = task
        queue.asyncAfter(deadline: .now() + seconds, execute: task)
    }

    private func tearDown() {
        rearmTask?.cancel()
        rearmTask = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
