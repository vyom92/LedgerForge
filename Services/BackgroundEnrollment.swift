import Darwin
import Foundation

/// Operational enrollment belongs to this Mac, outside the backup package.
nonisolated struct BackgroundEnrollment: Codable, Equatable, Sendable {
    let revision: UUID
    let databasePath: String
    let workspaceID: String
    let activation: LedgerActivationStamp
    let enabled: Bool
    var authorizationRequestedAt: Date? = nil
}

nonisolated struct BackgroundEnrollmentStore: Sendable {
    let url: URL
    init(url: URL = Self.defaultURL) { self.url = url }

    static var defaultURL: URL {
        // getpwuid is the actual user home in both the sandboxed app and agent.
        let home: String
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            home = String(cString: directory)
        } else { home = NSHomeDirectory() }
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Containers/com.vyom.LedgerForge/Data/Library/Application Support/LedgerForge/BackgroundWorker/enrollment.json")
    }

    func load() throws -> BackgroundEnrollment? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count <= 16_384 else { throw LedgerAccessError.incompatible }
        let value = try JSONDecoder().decode(BackgroundEnrollment.self, from: data)
        guard value.databasePath.hasPrefix("/"), !value.workspaceID.isEmpty else { throw LedgerAccessError.incompatible }
        return value
    }

    func save(_ value: BackgroundEnrollment) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try withLock { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
    }

    /// Acquire only inside the ledger gate when publishing financial results.
    /// Enrollment changes take this lock alone, never in the reverse order.
    func withValid<T>(_ expected: BackgroundEnrollment, _ body: () throws -> T) throws -> T {
        try withLock {
            guard let current = try load(), current == expected, current.enabled else { throw LedgerAccessError.staleActivation }
            return try body()
        }
    }

    func reconcile(path: String, activation: LedgerActivationStamp) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try withLock {
            guard let current = try load(), current.databasePath == path, current.activation != activation else { return }
            let replacement = BackgroundEnrollment(revision: UUID(), databasePath: path, workspaceID: current.workspaceID,
                activation: activation, enabled: current.enabled)
            try JSONEncoder().encode(replacement).write(to: url, options: .atomic)
        }
    }

    /// A foreground migration may advance the same existing ledger's schema.
    /// Only enrollment for its exact prior stable identity follows that change;
    /// stale, replaced or differently enrolled ledgers remain refused.
    func reconcileMigration(path: String, from previous: LedgerActivationStamp, to updated: LedgerActivationStamp) throws {
        guard !previous.transitioning, !updated.transitioning,
              previous.device == updated.device, previous.inode == updated.inode,
              previous.compatibilityVersion == updated.compatibilityVersion,
              previous.schemaVersion < updated.schemaVersion,
              previous.epoch != updated.epoch,
              FileManager.default.fileExists(atPath: url.path) else { return }
        try withLock {
            guard let current = try load(), current.databasePath == path, current.activation == previous else { return }
            let replacement = BackgroundEnrollment(revision: UUID(), databasePath: current.databasePath,
                workspaceID: current.workspaceID, activation: updated, enabled: current.enabled,
                authorizationRequestedAt: current.authorizationRequestedAt)
            try JSONEncoder().encode(replacement).write(to: url, options: .atomic)
        }
    }

    /// Consume an explicit one-time authorization request before touching
    /// Keychain. A crash or later scheduled launch cannot repeat its prompt.
    func consumeAuthorization(_ expected: BackgroundEnrollment) throws -> BackgroundEnrollment {
        try withLock {
            guard let current = try load(), current == expected, current.enabled else { throw LedgerAccessError.staleActivation }
            var consumed = current; consumed.authorizationRequestedAt = nil
            try JSONEncoder().encode(consumed).write(to: url, options: .atomic)
            return consumed
        }
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        let fd = Darwin.open(url.path + ".lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw LedgerAccessError.unavailable }
        defer { Darwin.close(fd) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN else { throw LedgerAccessError.unavailable }
            guard ContinuousClock.now < deadline else { throw LedgerAccessError.contention }
            usleep(10_000)
        }
        defer { _ = flock(fd, LOCK_UN) }
        return try body()
    }
}

/// An open file description owns this lease, independent of the Swift task's
/// current thread. Kernel release on process exit makes abandoned claims
/// recoverable without guessing a timeout or stealing a live network request.
nonisolated final class BackgroundJobLease: @unchecked Sendable {
    private let descriptor: Int32
    private init(_ descriptor: Int32) { self.descriptor = descriptor }
    static func acquire(path: String, kind: BackgroundJobKind) throws -> BackgroundJobLease? {
        let file = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
            + ".background-" + kind.rawValue + ".lock"
        let fd = Darwin.open(file, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw LedgerAccessError.unavailable }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let value = errno; Darwin.close(fd)
            if value == EWOULDBLOCK || value == EAGAIN { return nil }
            throw LedgerAccessError.unavailable
        }
        return BackgroundJobLease(fd)
    }
    deinit { _ = flock(descriptor, LOCK_UN); Darwin.close(descriptor) }
}
