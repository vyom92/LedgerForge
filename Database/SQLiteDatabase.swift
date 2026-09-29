// Database/SQLiteDatabase.swift
// Lightweight SQLite helper and migration runner for LedgerForge

import Foundation
import SQLite3
import Darwin

nonisolated private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

nonisolated public enum SQLiteOperation: String, Equatable, Sendable { case open, transaction, statement, query, migration, backup, checkpoint, close }

nonisolated public struct SQLiteExecutionError: Error, Equatable, Sendable, CustomStringConvertible {
    public let primaryCode: Int32
    public let extendedCode: Int32
    public let operation: SQLiteOperation
    public init(primaryCode: Int32, extendedCode: Int32, operation: SQLiteOperation) { self.primaryCode = primaryCode; self.extendedCode = extendedCode; self.operation = operation }
    public var isRetryableContention: Bool { primaryCode == SQLITE_BUSY || primaryCode == SQLITE_LOCKED }
    // SQLITE_CONSTRAINT_UNIQUE is a C macro that Swift does not import.
    public var isUniqueConstraint: Bool { primaryCode == SQLITE_CONSTRAINT && extendedCode == 2067 }
    public var description: String { "SQLite \(operation.rawValue) failed (\(primaryCode)/\(extendedCode))." }
}

nonisolated public enum SQLiteDatabaseError: Error, LocalizedError {
    case databaseNotOpen
    case prepareFailed(operation: SQLiteOperation)
    case execution(SQLiteExecutionError)
    case backupFailed(String)
    case checkpointFailed(Int32)
    case closeFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "SQLite database is not open."
        case .prepareFailed(let operation):
            return "SQLite \(operation.rawValue) could not be prepared."
        case .execution(let error):
            return error.description
        case .backupFailed:
            return "SQLite backup could not be completed."
        case .checkpointFailed:
            return "SQLite checkpoint could not be completed."
        case .closeFailed:
            return "SQLite close could not be completed."
        }
    }
}

/// Owned values copied while the connection owns the prepared statement.
/// A returned row never retains a SQLite statement or column pointer.
nonisolated public struct SQLiteRow: Sendable {
    private struct Column: Sendable {
        let string: String?
        let int64: Int64?
        let bool: Bool
        let data: Data?
    }
    private let columns: [Column]

    fileprivate init(statement: OpaquePointer?) {
        columns = (0..<sqlite3_column_count(statement)).map { index in
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
                return Column(string: nil, int64: nil, bool: false, data: nil)
            }
            if sqlite3_column_type(statement, index) == SQLITE_BLOB {
                let count = Int(sqlite3_column_bytes(statement, index))
                let data = sqlite3_column_blob(statement, index).map { Data(bytes: $0, count: count) } ?? Data()
                return Column(string: nil, int64: nil, bool: false, data: data)
            }
            let string = sqlite3_column_text(statement, index).map { String(cString: $0) }
            return Column(
                string: string,
                int64: sqlite3_column_int64(statement, index),
                bool: sqlite3_column_int(statement, index) != 0,
                data: nil
            )
        }
    }

    private func column(at index: Int32) -> Column? {
        guard index >= 0, Int(index) < columns.count else { return nil }
        return columns[Int(index)]
    }

    public func string(at index: Int32) -> String? {
        column(at: index)?.string
    }

    public func int64(at index: Int32) -> Int64? {
        column(at: index)?.int64
    }

    public func bool(at index: Int32) -> Bool {
        column(at: index)?.bool ?? false
    }

    public func data(at index: Int32) -> Data? {
        column(at: index)?.data
    }
}

/// Synchronous connection ownership shared by the app and subprocess helper.
///
/// `ownershipLock` protects every access to `db`, all statement/backup lifetimes,
/// and complete migration runs. Multi-call transactions must additionally hold
/// `withExclusiveAccess` from BEGIN through COMMIT or ROLLBACK. The recursive
/// lock permits existing nested repository queries on the same thread; callers
/// must not wait for another thread to use this connection from inside a scope.
/// Query callbacks execute synchronously under ownership and receive only copied
/// values. No SQLite pointer leaves this type. These invariants, rather than
/// SQLITE_OPEN_FULLMUTEX alone, justify the unchecked Sendable conformance.
nonisolated public final class SQLiteDatabase: @unchecked Sendable {
    public enum Access: Sendable { case createIfMissing, existing, readOnlySnapshot }
    private let path: String
    private let ownershipLock = NSRecursiveLock()
    private var db: OpaquePointer?
    private let ledgerAccess: LedgerAccessCoordinator
    private let accessStateLock = NSLock()
    private var storedStamp: LedgerActivationStamp?
    private var selectedSnapshotMode: Bool?
    private var storedPermit: LedgerLifecyclePermit?
    private var activationStamp: LedgerActivationStamp? {
        get { accessStateLock.lock(); defer { accessStateLock.unlock() }; return storedStamp }
        set { accessStateLock.lock(); defer { accessStateLock.unlock() }; storedStamp = newValue }
    }
    private var immutableSnapshot: Bool {
        accessStateLock.lock(); defer { accessStateLock.unlock() }; return selectedSnapshotMode == true
    }
    private func selectAccessMode(_ access: Access) throws {
        accessStateLock.lock(); defer { accessStateLock.unlock() }
        let snapshot = access == .readOnlySnapshot
        if let selectedSnapshotMode, selectedSnapshotMode != snapshot { throw LedgerAccessError.incompatible }
        selectedSnapshotMode = snapshot
    }
    private var storedOpeningOrMigrating = false
    private var openingOrMigrating: Bool {
        get { accessStateLock.lock(); defer { accessStateLock.unlock() }; return storedOpeningOrMigrating }
        set { accessStateLock.lock(); defer { accessStateLock.unlock() }; storedOpeningOrMigrating = newValue }
    }
    var lifecyclePermit: LedgerLifecyclePermit? {
        get { accessStateLock.lock(); defer { accessStateLock.unlock() }; return storedPermit }
        set {
            accessStateLock.lock(); let previous = storedPermit; storedPermit = newValue; accessStateLock.unlock()
            withExtendedLifetime(previous) {}
        }
    }
    private var storedOwnsMigrationRecovery = false
    private var ownsMigrationRecovery: Bool {
        get { accessStateLock.lock(); defer { accessStateLock.unlock() }; return storedOwnsMigrationRecovery }
        set { accessStateLock.lock(); defer { accessStateLock.unlock() }; storedOwnsMigrationRecovery = newValue }
    }
    private let allowMigrationRecovery: Bool
    private let requiredActivation: LedgerActivationStamp?
    // The helper verifies an exact existing ledger once, then keeps no SQLite
    // handle alive between synchronous repository operations. This lets the
    // established access gate exclude a restore before the helper can reopen
    // after a network await. Foreground providers retain their ordinary
    // connection lifetime.
    private var enrolledScopedConnection = false
    private var enrolledScopedConnectionClosed = false

    var currentActivationStamp: LedgerActivationStamp? { activationStamp }
    func validatedActivationStamp() throws -> LedgerActivationStamp {
        try withExclusiveAccess {
            guard let stamp = activationStamp else { throw LedgerAccessError.missingAuthority }
            return stamp
        }
    }

    private func withLedgerAccess<T>(_ operation: () throws -> T) throws -> T {
        if immutableSnapshot || path == ":memory:" { return try operation() }
        return try ledgerAccess.withAccess(permit: lifecyclePermit) {
            ownershipLock.lock(); defer { ownershipLock.unlock() }
            guard !enrolledScopedConnectionClosed else { throw LedgerAccessError.unavailable }
            let openedForScopedOperation = enrolledScopedConnection && db == nil
            do {
                if openedForScopedOperation {
                    guard !enrolledScopedConnectionClosed else { throw LedgerAccessError.unavailable }
                    try openConnectionLocked(access: .existing)
                }
                if db != nil && !openingOrMigrating {
                    _ = try ledgerAccess.validate(expected: activationStamp, permit: lifecyclePermit)
                }
                let result = try operation()
                if openedForScopedOperation { try closeConnectionLocked() }
                return result
            } catch let operationError {
                if openedForScopedOperation {
                    do { try closeConnectionLocked() }
                    catch let closeError {
                        enrolledScopedConnectionClosed = true
                        throw closeError
                    }
                }
                throw operationError
            }
        }
    }

    func verifyAuthoritySchema(_ version: Int) throws {
        try withLedgerAccess {
            guard !immutableSnapshot, path != ":memory:", lifecyclePermit == nil else { return }
            if activationStamp?.schemaVersion == 0 && requiredActivation == nil {
                activationStamp = try ledgerAccess.publish(schemaVersion: version, transitioning: false)
            } else if activationStamp?.schemaVersion != version { throw LedgerAccessError.incompatible }
        }
    }
    func adoptCompletedLifecycle(_ stamp: LedgerActivationStamp) throws {
        try ledgerAccess.withAccess {
            _ = try ledgerAccess.validate(expected: stamp, permit: nil)
            ownershipLock.lock(); defer { ownershipLock.unlock() }
            activationStamp = stamp; lifecyclePermit = nil
        }
    }


    public convenience init(path: String) { self.init(path: path, lifecyclePermit: nil, requiredActivation: nil) }
    init(path: String, lifecyclePermit: LedgerLifecyclePermit?, requiredActivation: LedgerActivationStamp? = nil, allowMigrationRecovery: Bool = false) {
        self.path = path
        self.ledgerAccess = .shared(path: path)
        self.storedPermit = lifecyclePermit
        self.requiredActivation = requiredActivation
        self.allowMigrationRecovery = allowMigrationRecovery
    }

    deinit {
        close()
    }

    /// Keeps a synchronous, multi-call operation on this connection indivisible.
    /// Retain the repository's existing transaction decisions inside this scope.
    func withExclusiveAccess<Result>(_ operation: () throws -> Result) throws -> Result {
        try withLedgerAccess {
            ownershipLock.lock(); defer { ownershipLock.unlock() }
            return try operation()
        }
    }

    public func open(access: Access = .createIfMissing) throws {
        ownershipLock.lock()
        let scopedConnection = enrolledScopedConnection
        ownershipLock.unlock()
        guard !scopedConnection else { throw LedgerAccessError.unavailable }
        try selectAccessMode(access)
        if allowMigrationRecovery, lifecyclePermit == nil,
           let stamp = try? ledgerAccess.readStamp(), stamp.transitioning, stamp.transitionKind == "migration" {
            lifecyclePermit = try ledgerAccess.beginLifecycle(recovering: true)
            ownsMigrationRecovery = true
        }

        return try withLedgerAccess {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        try openConnectionLocked(access: access)
        }
    }

    /// Switches the fully verified enrolled helper provider to a connection
    /// scope. It is deliberately unavailable to ordinary providers, snapshots
    /// and migration paths. The caller already holds the access gate, so this
    /// checked close happens before that outer gate can be released.
    func beginEnrolledExistingConnectionScope() throws {
        guard requiredActivation != nil, !immutableSnapshot, path != ":memory:" else {
            throw LedgerAccessError.incompatible
        }
        try ledgerAccess.withAccess(permit: lifecyclePermit) {
            ownershipLock.lock(); defer { ownershipLock.unlock() }
            guard !enrolledScopedConnection, db != nil else { throw LedgerAccessError.unavailable }
            try closeConnectionLocked()
            enrolledScopedConnection = true
            enrolledScopedConnectionClosed = false
        }
    }

    private func openConnectionLocked(access: Access) throws {
        if db != nil { return }
        if !immutableSnapshot && path != ":memory:" {
            if let requiredActivation {
                _ = try ledgerAccess.validate(expected: requiredActivation, permit: nil)
            } else if FileManager.default.fileExists(atPath: ledgerAccess.activationURL.path) {
                _ = try ledgerAccess.validate(expected: nil, permit: lifecyclePermit)
            }
        }
        openingOrMigrating = true
        defer { openingOrMigrating = false }
        let flags: Int32
        let filename: String
        switch access {
        case .createIfMissing:
            flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
            filename = path
        case .existing:
            flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
            filename = path
        case .readOnlySnapshot:
            // Only closed, operation-owned immutable snapshots may use this mode.
            // It ignores WAL and never creates a database or sidecars.
            flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
            filename = URL(fileURLWithPath: path).absoluteString + "?mode=ro&immutable=1"
        }
        if sqlite3_open_v2(filename, &db, flags, nil) != SQLITE_OK {
            let extended = sqlite3_extended_errcode(db)
            if let db {
                let closeResult = sqlite3_close(db)
                guard closeResult == SQLITE_OK else {
                    if enrolledScopedConnection { enrolledScopedConnectionClosed = true }
                    throw SQLiteDatabaseError.closeFailed(closeResult)
                }
                self.db = nil
            }
            throw SQLiteDatabaseError.execution(SQLiteExecutionError(primaryCode: extended & 0xff, extendedCode: extended, operation: .open))
        }
        // Protect every startup statement from concurrent openers, including
        // the first WAL-mode pragma used by independent providers.
        do {
            sqlite3_busy_timeout(db, 5000)
            if access == .readOnlySnapshot {
                try execute(sql: "PRAGMA query_only = ON;")
                return
            }
            // Configure recommended PRAGMAs for production-safe defaults.
            try execute(sql: "PRAGMA journal_mode = WAL;")
            var persistWAL: Int32 = 1
            guard path == ":memory:" || sqlite3_file_control(db, "main", SQLITE_FCNTL_PERSIST_WAL, &persistWAL) == SQLITE_OK else {
                throw LedgerAccessError.unavailable
            }
            // Enable foreign keys enforcement
            try execute(sql: "PRAGMA foreign_keys = ON;")
            // Use NORMAL synchronous for balanced durability/performance
            try execute(sql: "PRAGMA synchronous = NORMAL;")
            if !immutableSnapshot && path != ":memory:" {
                activationStamp = lifecyclePermit != nil
                    ? try ledgerAccess.readStamp()
                    : try ledgerAccess.initializeIfNeeded(schemaVersion: 0)
            }
        } catch let operationError {
            do { try closeConnectionLocked() }
            catch let closeError {
                if enrolledScopedConnection { enrolledScopedConnectionClosed = true }
                throw closeError
            }
            throw operationError
        }
    }

    public func close() { try? closeChecked() }

    public func createBackup(at destinationPath: String) throws {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db else { throw SQLiteDatabaseError.databaseNotOpen }
        let file = Darwin.open(destinationPath, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard file >= 0 else { throw SQLiteDatabaseError.backupFailed("destination-exists-or-unavailable") }
        guard Darwin.close(file) == 0 else { throw SQLiteDatabaseError.backupFailed("destination-file-close") }
        var destination: OpaquePointer?
        guard sqlite3_open_v2(destinationPath, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let destination else {
            if let destination { sqlite3_close(destination) }
            throw SQLiteDatabaseError.backupFailed("destination-open")
        }
        var destinationClosed = false
        defer { if !destinationClosed { sqlite3_close(destination) } }
        sqlite3_busy_timeout(destination, 5000)
        guard let backup = sqlite3_backup_init(destination, "main", db, "main") else {
            throw SQLiteDatabaseError.backupFailed("initialization")
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw SQLiteDatabaseError.backupFailed("copy")
        }
        guard sqlite3_close(destination) == SQLITE_OK else {
            throw SQLiteDatabaseError.backupFailed("destination-close")
        }
        destinationClosed = true

        }
    }

    public func closeChecked() throws {
        func closeExplicitly() throws {
            ownershipLock.lock(); defer { ownershipLock.unlock() }
            if enrolledScopedConnection { enrolledScopedConnectionClosed = true }
            try closeConnectionLocked()
        }
        if immutableSnapshot || path == ":memory:" { try closeExplicitly() }
        else { try ledgerAccess.withAccess(permit: lifecyclePermit) { try closeExplicitly() } }
    }

    private func closeConnectionLocked() throws {
        guard let db else { return }
        let result = sqlite3_close(db)
        guard result == SQLITE_OK else { throw SQLiteDatabaseError.closeFailed(result) }
        self.db = nil
    }

    func totalChangeCounter() throws -> Int64 {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db else { throw SQLiteDatabaseError.databaseNotOpen }
        // Monotonic for this connection: local writes plus SQLite's external
        // commit version. Restore must notice writes from the enrolled helper.
        let externalVersion = try querySingleInt(sql: "PRAGMA data_version;")
        let result = sqlite3_total_changes64(db).addingReportingOverflow(Int64(externalVersion))
        guard !result.overflow else { throw LedgerAccessError.unavailable }
        return result.partialValue

        }
    }

    public func checkpointAndClose() throws {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db else { throw SQLiteDatabaseError.databaseNotOpen }
        if enrolledScopedConnection { enrolledScopedConnectionClosed = true }
        var logFrames: Int32 = 0
        var checkpointedFrames: Int32 = 0
        let checkpointResult = sqlite3_wal_checkpoint_v2(
            db,
            nil,
            SQLITE_CHECKPOINT_TRUNCATE,
            &logFrames,
            &checkpointedFrames
        )
        guard checkpointResult == SQLITE_OK else {
            throw SQLiteDatabaseError.checkpointFailed(checkpointResult)
        }
        let closeResult = sqlite3_close(db)
        guard closeResult == SQLITE_OK else {
            throw SQLiteDatabaseError.closeFailed(closeResult)
        }
        self.db = nil

        }
    }

    public func execute(sql: String) throws {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db = db else { throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "DB not open"]) }
        var errMsg: UnsafeMutablePointer<Int8>? = nil
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            sqlite3_free(errMsg)
            throw executionError(resultCode: result, operation: operation(for: sql))
        }

        }
    }

    // Execute a prepared statement with parameter bindings. Parameters are bound in order.
    public func executePrepared(sql: String, params: [Any?] = []) throws {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepareFailed(operation: operation(for: sql))
        }

        bind(params, to: stmt)

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            throw executionError(resultCode: rc, operation: operation(for: sql))
        }

        }
    }

    public func query<T>(sql: String, params: [Any?] = [], map: (SQLiteRow) throws -> T) throws -> [T] {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepareFailed(operation: .query)
        }

        bind(params, to: stmt)

        var rows: [T] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                rows.append(try map(SQLiteRow(statement: stmt)))
            } else if rc == SQLITE_DONE {
                return rows
            } else {
                throw executionError(resultCode: rc, operation: .query)
            }
        }

        }
    }

    public func runMigrations(_ migrations: [Migration]) throws {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        try MigrationChainValidator.validateRegistered(migrations)
        try open()
        openingOrMigrating = true
        defer { openingOrMigrating = false }
        defer {
            // An ordinary failed migration rolls back its transaction. Publish
            // a new epoch only if the surviving registered prefix is verified;
            // crash/interrupted or unverifiable state remains pending.
            if path != ":memory:", lifecyclePermit == nil, activationStamp?.transitioning == true,
               let prefix = try? validatedMigrationHistory(against: migrations, requiresCompleteChain: false),
               let stable = try? ledgerAccess.publish(schemaVersion: prefix.count, transitioning: false) {
                activationStamp = stable
            }
        }
        let priorSchema = (try? querySingleInt(sql: "SELECT MAX(version) FROM schema_migrations;")) ?? 0
        if path != ":memory:" && priorSchema != migrations.count {
            activationStamp = try ledgerAccess.publish(schemaVersion: priorSchema, transitioning: true)
        }

        let hasMigrationTable = try tableExists("schema_migrations")
        let hasApplicationSchema = try querySingleInt(sql: """
            SELECT COUNT(*) FROM sqlite_master
            WHERE type = 'table'
              AND name NOT IN ('schema_migrations', 'sqlite_sequence');
            """) > 0

        if !hasMigrationTable, hasApplicationSchema {
            throw MigrationIntegrityError.missingPersistedVersion(1)
        }

        var persistedRecords = hasMigrationTable ? try migrationRecords() : []
        if persistedRecords.isEmpty, hasApplicationSchema {
            throw MigrationIntegrityError.missingPersistedVersion(1)
        }
        if !persistedRecords.isEmpty {
            try MigrationChainValidator.validatePersisted(
                persistedRecords,
                against: migrations,
                requiresCompleteChain: false
            )
        }

        try execute(sql: "CREATE TABLE IF NOT EXISTS schema_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, version INTEGER NOT NULL, name TEXT, applied_at DATETIME NOT NULL, checksum TEXT);")

        for migration in migrations.dropFirst(persistedRecords.count) {
            // Some schema rebuilds must temporarily opt into SQLite's legacy
            // ALTER TABLE behavior. PRAGMA state is connection-scoped rather
            // than transactional, so a failed multi-statement migration can
            // otherwise leak that temporary mode after ROLLBACK. Preserve the
            // caller's entry state on failure; a successful migration retains
            // responsibility for its declared final connection state.
            let legacyAlterTableWasEnabled = try querySingleInt(
                sql: "PRAGMA legacy_alter_table;"
            ) != 0
            if migration.requiresForeignKeysDisabled {
                try execute(sql: "PRAGMA foreign_keys = OFF;")
            }
            do {
                try beginTransaction()
                for check in migration.preflightChecks {
                    guard try check.run(self) else {
                        throw MigrationPreflightError.failed(issueCode: check.issueCode)
                    }
                }
                try execute(sql: migration.sql)
                if migration.requiresForeignKeysDisabled {
                    let foreignKeyViolations = try query(
                        sql: "PRAGMA foreign_key_check;",
                        params: []
                    ) { _ in true }
                    guard foreignKeyViolations.isEmpty else {
                        throw MigrationPreflightError.failed(issueCode: "migration.foreign-key-check")
                    }
                }
                let now = iso8601Now()
                try executePrepared(
                    sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                    params: [migration.version, migration.name, now, migration.checksum]
                )
                try commit()
                if migration.requiresForeignKeysDisabled {
                    try execute(sql: "PRAGMA foreign_keys = ON;")
                }
            } catch {
                try? rollback()
                if migration.requiresForeignKeysDisabled {
                    try? execute(sql: "PRAGMA foreign_keys = ON;")
                }
                try? execute(sql: legacyAlterTableWasEnabled
                    ? "PRAGMA legacy_alter_table = ON;"
                    : "PRAGMA legacy_alter_table = OFF;")
                throw error
            }
        }

        persistedRecords = try migrationRecords()
        try MigrationChainValidator.validatePersisted(
            persistedRecords,
            against: migrations,
            requiresCompleteChain: true
        )

        if ownsMigrationRecovery, let permit = lifecyclePermit {
            activationStamp = try permit.finish(schemaVersion: migrations.count)
            lifecyclePermit = nil; ownsMigrationRecovery = false
        }
        if path != ":memory:" && lifecyclePermit == nil {
            if activationStamp?.schemaVersion != migrations.count || activationStamp?.transitioning == true {
                activationStamp = try ledgerAccess.publish(schemaVersion: migrations.count, transitioning: false)
            }
        }

        }
    }

    // MARK: - Helpers
    private func beginTransaction() throws {
        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
    }
    private func commit() throws {
        try execute(sql: "COMMIT;")
    }
    private func rollback() throws {
        try execute(sql: "ROLLBACK;")
    }

    private func querySingleInt(sql: String) throws -> Int {
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepareFailed(operation: .query)
        }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    public func queryInt(_ sql: String) throws -> Int {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        return try querySingleInt(sql: sql)

        }
    }

    func validatedMigrationHistory(
        against migrations: [Migration],
        requiresCompleteChain: Bool
    ) throws -> [PersistedMigrationRecord] {
        return try withLedgerAccess {

        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        try MigrationChainValidator.validateRegistered(migrations)
        guard try tableExists("schema_migrations") else {
            throw MigrationIntegrityError.missingPersistedVersion(1)
        }
        let records = try migrationRecords()
        try MigrationChainValidator.validatePersisted(
            records,
            against: migrations,
            requiresCompleteChain: requiresCompleteChain
        )
        return records

        }
    }

    private func bind(_ params: [Any?], to stmt: OpaquePointer?) {
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            guard let value = p, !(value is NSNull) else {
                sqlite3_bind_null(stmt, idx)
                continue
            }
            switch value {
            case let bytes as Data:
                _ = bytes.withUnsafeBytes { buffer in
                    sqlite3_bind_blob64(stmt, idx, buffer.baseAddress, UInt64(buffer.count), SQLITE_TRANSIENT)
                }
            case let s as String:
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case let i as Int:
                sqlite3_bind_int64(stmt, idx, sqlite3_int64(i))
            case let i as Int64:
                sqlite3_bind_int64(stmt, idx, sqlite3_int64(i))
            case let d as Double:
                sqlite3_bind_double(stmt, idx, d)
            case let b as Bool:
                sqlite3_bind_int(stmt, idx, b ? 1 : 0)
            default:
                let s = String(describing: value)
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            }
        }
    }

    private func executionError(resultCode: Int32, operation: SQLiteOperation) -> SQLiteDatabaseError {
        let extended = db.map(sqlite3_extended_errcode) ?? resultCode
        return .execution(SQLiteExecutionError(primaryCode: resultCode & 0xFF, extendedCode: extended, operation: operation))
    }

    private func operation(for sql: String) -> SQLiteOperation {
        let verb = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if verb.hasPrefix("BEGIN") || verb.hasPrefix("COMMIT") || verb.hasPrefix("ROLLBACK") { return .transaction }
        if verb.hasPrefix("SELECT") || verb.hasPrefix("PRAGMA") { return .query }
        return .statement
    }

    private func iso8601Now() -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: Date())
    }

    private func tableExists(_ name: String) throws -> Bool {
        try querySingleInt(
            sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = '\(name)';"
        ) == 1
    }

    private func migrationRecords() throws -> [PersistedMigrationRecord] {
        do {
            return try query(sql: "SELECT version, name, checksum, applied_at FROM schema_migrations ORDER BY id;") { row in
                PersistedMigrationRecord(
                    version: row.int64(at: 0).map(Int.init),
                    name: row.string(at: 1),
                    checksum: row.string(at: 2),
                    appliedAt: row.string(at: 3)
                )
            }
        } catch let error as MigrationIntegrityError {
            throw error
        } catch {
            throw MigrationIntegrityError.persistedRecordIncomplete(nil)
        }
    }
}
