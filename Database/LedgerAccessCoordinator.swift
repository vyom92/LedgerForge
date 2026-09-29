import Foundation
import Darwin

/// Operational identity only. Never restored from a backup and never used as
/// financial identity. The stable lock inode is not among RestoreLayout's files.
nonisolated struct LedgerActivationStamp: Codable, Equatable, Sendable {
    let epoch: UUID
    let device: UInt64
    let inode: UInt64
    let schemaVersion: Int
    let compatibilityVersion: Int
    let transitioning: Bool
    var transitionKind: String? = nil
}

nonisolated enum LedgerAccessError: Error {
    case contention, unavailable, staleActivation, transitionPending, incompatible, missingAuthority
}

nonisolated final class LedgerLifecyclePermit: @unchecked Sendable {
    fileprivate let id = UUID()
    fileprivate let coordinator: LedgerAccessCoordinator
    fileprivate init(_ coordinator: LedgerAccessCoordinator) { self.coordinator = coordinator }
    /// Releasing a failed transition leaves its durable pending record intact.
    deinit { coordinator.releaseLifecycle(id) }
    func release() { coordinator.releaseLifecycle(id) }
    func finish(schemaVersion: Int) throws -> LedgerActivationStamp {
        try coordinator.finishLifecycle(self, schemaVersion: schemaVersion)
    }
}

/// One coordinator per canonical path, shared by every connection in this
/// process. Synchronous recursion is intentional; an async lifecycle uses an
/// explicit permit and does not retain a thread-owned lock across suspension.
nonisolated final class LedgerAccessCoordinator: @unchecked Sendable {
    static let compatibilityVersion = 1
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var registry: [String: LedgerAccessCoordinator] = [:]
    static func shared(path: String) -> LedgerAccessCoordinator {
        let key = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        registryLock.lock(); defer { registryLock.unlock() }
        if let current = registry[key] { return current }
        let value = LedgerAccessCoordinator(path: key); registry[key] = value; return value
    }
    let path: String
    private let local = NSRecursiveLock()
    private var depth = 0
    private var descriptor: Int32 = -1
    private var lifecycleID: UUID?
    var activationURL: URL { URL(fileURLWithPath: path + ".activation.json") }
    var lockPath: String { path + ".access.lock" }
    private init(path: String) { self.path = path }

    func withAccess<T>(permit: LedgerLifecyclePermit? = nil, _ body: () throws -> T) throws -> T {
        local.lock(); defer { local.unlock() }
        if let lifecycleID {
            guard permit?.id == lifecycleID else { throw LedgerAccessError.transitionPending }
        } else if depth == 0 { try acquireOSLock() }
        depth += 1
        defer {
            depth -= 1
            if depth == 0 && lifecycleID == nil { releaseOSLock() }
        }
        return try body()
    }

    private func acquireOSLock() throws {
        descriptor = Darwin.open(lockPath, O_RDWR | O_CREAT | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw LedgerAccessError.unavailable }
        // Match SQLite's bounded busy interval for short cross-process commits.
        // A local lifecycle owner is rejected above without waiting.
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR else {
                Darwin.close(descriptor); descriptor = -1; throw LedgerAccessError.unavailable
            }
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                Darwin.close(descriptor); descriptor = -1; throw LedgerAccessError.contention
            }
            usleep(10_000)
        }
    }
    private func releaseOSLock() {
        if descriptor >= 0 { _ = flock(descriptor, LOCK_UN); Darwin.close(descriptor); descriptor = -1 }
    }
    func readStamp() throws -> LedgerActivationStamp {
        guard FileManager.default.fileExists(atPath: activationURL.path) else { throw LedgerAccessError.missingAuthority }
        return try JSONDecoder().decode(LedgerActivationStamp.self, from: Data(contentsOf: activationURL))
    }
    private func fileIdentity() throws -> (UInt64, UInt64) {
        var value = stat()
        guard lstat(path, &value) == 0, (value.st_mode & S_IFMT) == S_IFREG else { throw LedgerAccessError.unavailable }
        return (UInt64(value.st_dev), UInt64(value.st_ino))
    }
    func validate(expected: LedgerActivationStamp?, permit: LedgerLifecyclePermit?) throws -> LedgerActivationStamp {
        let current = try readStamp()
        guard current.compatibilityVersion == Self.compatibilityVersion else { throw LedgerAccessError.incompatible }
        let ownsLifecycle = lifecycleID != nil && permit != nil && permit?.id == lifecycleID
        guard !current.transitioning || ownsLifecycle else { throw LedgerAccessError.transitionPending }
        // The explicitly owned replacement may temporarily have no canonical
        // inode, including an approved reset before SQLite creates its file.
        if ownsLifecycle { return current }
        let identity = try fileIdentity()
        // A lifecycle permit may open the newly installed inode while pending.
        if permit?.id != lifecycleID || lifecycleID == nil {
            guard current.device == identity.0, current.inode == identity.1 else { throw LedgerAccessError.staleActivation }
            if let expected, current != expected { throw LedgerAccessError.staleActivation }
        }
        return current
    }
    /// Only foreground first-use/migration flow may initialize authority.
    func initializeIfNeeded(schemaVersion: Int) throws -> LedgerActivationStamp {
        if FileManager.default.fileExists(atPath: activationURL.path) {
            return try validate(expected: nil, permit: nil)
        }
        return try publish(schemaVersion: schemaVersion, transitioning: false)
    }
    func publish(schemaVersion: Int, transitioning: Bool) throws -> LedgerActivationStamp {
        let identity = try fileIdentity()
        var value = LedgerActivationStamp(epoch: UUID(), device: identity.0, inode: identity.1,
            schemaVersion: schemaVersion, compatibilityVersion: Self.compatibilityVersion, transitioning: transitioning)
        value.transitionKind = transitioning ? "migration" : nil
        try write(value); return value
    }
    private func write(_ value: LedgerActivationStamp) throws {
        try JSONEncoder().encode(value).write(to: activationURL, options: .atomic)
        let file = Darwin.open(activationURL.path, O_RDONLY | O_NOFOLLOW)
        guard file >= 0 else { throw LedgerAccessError.unavailable }
        defer { Darwin.close(file) }
        guard fsync(file) == 0 else { throw LedgerAccessError.unavailable }
        let directory = Darwin.open(activationURL.deletingLastPathComponent().path, O_RDONLY)
        guard directory >= 0 else { throw LedgerAccessError.unavailable }
        defer { Darwin.close(directory) }
        guard fsync(directory) == 0 else { throw LedgerAccessError.unavailable }
    }
    func beginLifecycle(recovering: Bool = false) throws -> LedgerLifecyclePermit {
        local.lock(); defer { local.unlock() }
        guard depth == 0, lifecycleID == nil else { throw LedgerAccessError.contention }
        try acquireOSLock()
        do {
            let prior: LedgerActivationStamp
            if FileManager.default.fileExists(atPath: activationURL.path) { prior = try readStamp() }
            else {
                prior = LedgerActivationStamp(epoch: UUID(), device: 0, inode: 0, schemaVersion: 0,
                    compatibilityVersion: Self.compatibilityVersion, transitioning: false)
            }
            guard prior.compatibilityVersion == Self.compatibilityVersion else { throw LedgerAccessError.incompatible }
            guard recovering || !prior.transitioning else { throw LedgerAccessError.transitionPending }
            // Recovery may start while the canonical inode is absent.
            var pending = LedgerActivationStamp(epoch: UUID(), device: prior.device, inode: prior.inode,
                schemaVersion: prior.schemaVersion, compatibilityVersion: Self.compatibilityVersion, transitioning: true)
            pending.transitionKind = "replacement"
            try write(pending)
            let permit = LedgerLifecyclePermit(self); lifecycleID = permit.id
            return permit
        } catch { releaseOSLock(); throw error }
    }
    fileprivate func finishLifecycle(_ permit: LedgerLifecyclePermit, schemaVersion: Int) throws -> LedgerActivationStamp {
        try withAccess(permit: permit) {
            guard lifecycleID == permit.id else { throw LedgerAccessError.staleActivation }
            let result = try publish(schemaVersion: schemaVersion, transitioning: false)
            lifecycleID = nil
            return result
        }
    }
    fileprivate func releaseLifecycle(_ id: UUID) {
        local.lock(); defer { local.unlock() }
        guard lifecycleID == id else { return }
        lifecycleID = nil; releaseOSLock()
    }
}
