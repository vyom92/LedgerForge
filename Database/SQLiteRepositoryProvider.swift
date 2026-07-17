// Database/SQLiteRepositoryProvider.swift
// SQLite-backed repository provider for LedgerForge (Sprint 10 Phase 2B)

import Foundation
import SQLite3
#if DEBUG
import Combine
#endif

#if DEBUG
struct DevelopmentDatabaseIdentity: Equatable {
    let canonicalDevelopmentURL: URL
    let nonDevelopmentURL: URL
    let backupURL: URL
    let temporaryDirectoryURL: URL

    private let authorizedResolvedDevelopmentURL: URL

    init(applicationSupportDirectory: URL) {
        let applicationDirectory = applicationSupportDirectory
            .appendingPathComponent("LedgerForge", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let developmentDirectory = applicationDirectory
            .appendingPathComponent("Development", isDirectory: true)
        let canonical = developmentDirectory
            .appendingPathComponent("ledgerforge-development.sqlite")
            .standardizedFileURL

        canonicalDevelopmentURL = canonical
        nonDevelopmentURL = applicationDirectory
            .appendingPathComponent("ledgerforge.sqlite")
            .standardizedFileURL
        backupURL = developmentDirectory
            .appendingPathComponent("Lifecycle Backups", isDirectory: true)
            .appendingPathComponent("previous-development.sqlite")
            .standardizedFileURL
        temporaryDirectoryURL = developmentDirectory
            .appendingPathComponent("Temporary Sessions", isDirectory: true)
            .standardizedFileURL
        authorizedResolvedDevelopmentURL = canonical
    }

    static func applicationOwned() -> DevelopmentDatabaseIdentity {
        let fileManager = FileManager.default
        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return DevelopmentDatabaseIdentity(applicationSupportDirectory: applicationSupport)
    }

    func authorizesDestructiveWork(at candidate: URL) -> Bool {
        candidate.standardizedFileURL.resolvingSymlinksInPath() == authorizedResolvedDevelopmentURL
    }

    func databaseSet(at mainURL: URL) -> [URL] {
        [
            mainURL,
            URL(fileURLWithPath: mainURL.path + "-wal"),
            URL(fileURLWithPath: mainURL.path + "-shm")
        ]
    }
}
#endif

/// SQLite-backed provider that runs migrations and exposes repository implementations.
public final class SQLiteRepositoryProvider {
    public let databasePath: String
    public let database: SQLiteDatabase
    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository

    public init(path: String? = nil) throws {
        let dbPath = path ?? Self.defaultDBPath()
        self.databasePath = dbPath
        self.database = SQLiteDatabase(path: dbPath)
        try database.open()
        try database.runMigrations(allMigrations)
        try database.execute(sql: "PRAGMA foreign_keys = ON;")

        self.workspaceRepo = SQLiteWorkspaceRepo(db: database)
        self.transactionRepo = SQLiteTransactionRepo(db: database)
        self.accountRepo = SQLiteAccountRepo(db: database)
        self.importSessionRepo = SQLiteImportSessionRepo(db: database)
    }

    public static func defaultDBPath() -> String {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
#if DEBUG
        if let appSupport {
            let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: appSupport)
            try? fm.createDirectory(
                at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return identity.canonicalDevelopmentURL.path
        }
        return "ledgerforge-development.sqlite"
#else
        let folder = appSupport?.appendingPathComponent("LedgerForge")
        if let folder = folder {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder.appendingPathComponent("ledgerforge.sqlite").path
        }
        return "ledgerforge.sqlite"
#endif
    }
}

#if DEBUG
enum DevelopmentDatabaseActivity: String, Equatable {
    case importPreparation
    case preparedAwaitingConfirmation
    case confirmedPersistence
    case hydration
    case repositoryWrite
    case developerReload
}

enum DevelopmentDatabaseActivityError: Error, LocalizedError {
    case lifecycleOperationInProgress
    case lifecycleUnavailable

    var errorDescription: String? {
        "Database activity is unavailable while the development database lifecycle is changing."
    }
}

@MainActor
final class DevelopmentDatabaseActivityLease {
    private weak var gate: DevelopmentDatabaseActivityGate?
    fileprivate let id: UUID
    fileprivate(set) var activity: DevelopmentDatabaseActivity
    private(set) var generation: Int
    private var isFinished = false

    fileprivate init(gate: DevelopmentDatabaseActivityGate, activity: DevelopmentDatabaseActivity, generation: Int) {
        self.gate = gate
        self.id = UUID()
        self.activity = activity
        self.generation = generation
    }

    func transition(to activity: DevelopmentDatabaseActivity) {
        guard !isFinished else { return }
        self.activity = activity
        gate?.update(self)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        gate?.finish(self)
    }
}

@MainActor
final class DevelopmentDatabaseActivityGate {
    static let shared = DevelopmentDatabaseActivityGate()

    private var leases: [UUID: DevelopmentDatabaseActivity] = [:]
    private(set) var generation = 1
    private(set) var hasExclusiveOperation = false
    private(set) var isUnavailable = false

    var hasActiveOperations: Bool { !leases.isEmpty }

    func begin(_ activity: DevelopmentDatabaseActivity) throws -> DevelopmentDatabaseActivityLease {
        guard !isUnavailable else { throw DevelopmentDatabaseActivityError.lifecycleUnavailable }
        guard !hasExclusiveOperation else { throw DevelopmentDatabaseActivityError.lifecycleOperationInProgress }
        let lease = DevelopmentDatabaseActivityLease(gate: self, activity: activity, generation: generation)
        leases[lease.id] = activity
        return lease
    }

    func beginExclusive() -> Bool {
        guard !isUnavailable, !hasExclusiveOperation, leases.isEmpty else { return false }
        hasExclusiveOperation = true
        return true
    }

    func finishExclusive(providerChanged: Bool) {
        if providerChanged { generation += 1 }
        hasExclusiveOperation = false
    }

    func enterUnavailable() {
        isUnavailable = true
        hasExclusiveOperation = false
    }

    fileprivate func update(_ lease: DevelopmentDatabaseActivityLease) {
        guard leases[lease.id] != nil else { return }
        leases[lease.id] = lease.activity
    }

    fileprivate func finish(_ lease: DevelopmentDatabaseActivityLease) {
        leases.removeValue(forKey: lease.id)
    }

    func resetForTesting() {
        leases.removeAll()
        hasExclusiveOperation = false
        isUnavailable = false
    }
}

enum DevelopmentDatabaseLifecycleResult: Equatable, CustomStringConvertible {
    case temporarySessionStarted(RepositoryStoreHydrationResult)
    case permanentResetCompleted(RepositoryStoreHydrationResult)
    case previousDatabaseRestored(RepositoryStoreHydrationResult)
    case rejectedActivityInProgress
    case rejectedUnsafeIdentity
    case providerQuiescenceFailed
    case backupFailed
    case recreationFailed
    case migrationFailed
    case providerInstallationFailed
    case hydrationFailedRecoverySucceeded
    case recoveryFailed
    case lifecycleUnavailable

    var description: String {
        switch self {
        case .temporarySessionStarted: return "temporary-session-started"
        case .permanentResetCompleted: return "permanent-reset-completed"
        case .previousDatabaseRestored: return "previous-database-restored"
        case .rejectedActivityInProgress: return "activity-in-progress"
        case .rejectedUnsafeIdentity: return "unsafe-identity"
        case .providerQuiescenceFailed: return "provider-quiescence-failed"
        case .backupFailed: return "backup-failed"
        case .recreationFailed: return "recreation-failed"
        case .migrationFailed: return "migration-failed"
        case .providerInstallationFailed: return "provider-installation-failed"
        case .hydrationFailedRecoverySucceeded: return "hydration-failed-recovery-succeeded"
        case .recoveryFailed: return "recovery-failed"
        case .lifecycleUnavailable: return "lifecycle-unavailable"
        }
    }
}

enum DevelopmentDatabaseLifecycleFailurePoint: Hashable {
    case backupCreation
    case backupVerification
    case providerQuiescence
    case recreation
    case migration
    case providerInstallation
    case hydration
    case recovery
}

@MainActor
final class DevelopmentDatabaseLifecycleCoordinator: ObservableObject {
    static let shared = DevelopmentDatabaseLifecycleCoordinator(identity: .applicationOwned())

    let identity: DevelopmentDatabaseIdentity
    @Published private(set) var isOperationInProgress = false
    @Published private(set) var isUnavailable = false
    private(set) var currentDatabaseURL: URL?
    private var sqliteProvider: SQLiteRepositoryProvider?
    private let activityGate: DevelopmentDatabaseActivityGate
    private let injectedFailures: Set<DevelopmentDatabaseLifecycleFailurePoint>

    convenience init(identity: DevelopmentDatabaseIdentity) {
        self.init(identity: identity, activityGate: .shared, injectedFailures: [])
    }

    convenience init(identity: DevelopmentDatabaseIdentity, activityGate: DevelopmentDatabaseActivityGate) {
        self.init(identity: identity, activityGate: activityGate, injectedFailures: [])
    }

    init(
        identity: DevelopmentDatabaseIdentity,
        activityGate: DevelopmentDatabaseActivityGate,
        injectedFailures: Set<DevelopmentDatabaseLifecycleFailurePoint>
    ) {
        self.identity = identity
        self.activityGate = activityGate
        self.injectedFailures = injectedFailures
    }

    func installInitialProvider(_ provider: SQLiteRepositoryProvider) {
        publish(provider)
    }

    func startTemporaryEmptySession() -> DevelopmentDatabaseLifecycleResult {
        guard !isUnavailable else { return .lifecycleUnavailable }
        guard activityGate.beginExclusive() else { return .rejectedActivityInProgress }
        isOperationInProgress = true
        var providerChanged = false
        defer {
            isOperationInProgress = false
            activityGate.finishExclusive(providerChanged: providerChanged)
        }
        do {
            try FileManager.default.createDirectory(at: identity.temporaryDirectoryURL, withIntermediateDirectories: true)
            let url = identity.temporaryDirectoryURL
                .appendingPathComponent("temporary-\(UUID().uuidString).sqlite")
            let provider = try SQLiteRepositoryProvider(path: url.path)
            publish(provider)
            providerChanged = true
            let hydration = try RepositoryStoreHydrator(databaseProvider: DatabaseProvider.shared, participatesInLifecycleGate: false)
                .hydrateIfNeeded(forceRefresh: true)
            return .temporarySessionStarted(hydration)
        } catch {
            return .recreationFailed
        }
    }

    func resetDevelopmentDatabase() -> DevelopmentDatabaseLifecycleResult {
        guard !isUnavailable else { return .lifecycleUnavailable }
        guard identity.authorizesDestructiveWork(at: identity.canonicalDevelopmentURL),
              currentDatabaseURL == identity.canonicalDevelopmentURL,
              let originalProvider = sqliteProvider else {
            return .rejectedUnsafeIdentity
        }
        guard activityGate.beginExclusive() else { return .rejectedActivityInProgress }
        isOperationInProgress = true
        var providerChanged = false
        defer {
            isOperationInProgress = false
            activityGate.finishExclusive(providerChanged: providerChanged)
        }

        do {
            try createAndVerifyBackup(from: originalProvider)
        } catch {
            return .backupFailed
        }

        do {
            try failIfInjected(.providerQuiescence)
            try originalProvider.database.checkpointAndClose()
        } catch {
            return .providerQuiescenceFailed
        }

        do {
            try removeDatabaseSet(at: identity.canonicalDevelopmentURL)
            if injectedFailures.contains(.recreation) {
                return recover(afterHydrationFailure: false, originalFailure: .recreationFailed)
            }
            let replacement = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
            if injectedFailures.contains(.migration) {
                try? replacement.database.checkpointAndClose()
                return recover(afterHydrationFailure: false, originalFailure: .migrationFailed)
            }
            if injectedFailures.contains(.providerInstallation) {
                try? replacement.database.checkpointAndClose()
                return recover(afterHydrationFailure: false, originalFailure: .providerInstallationFailed)
            }
            publish(replacement)
            providerChanged = true
            do {
                try failIfInjected(.hydration)
                let hydration = try RepositoryStoreHydrator(databaseProvider: DatabaseProvider.shared, participatesInLifecycleGate: false)
                    .hydrateIfNeeded(forceRefresh: true)
                return .permanentResetCompleted(hydration)
            } catch {
                return recover(afterHydrationFailure: true, originalFailure: .hydrationFailedRecoverySucceeded)
            }
        } catch {
            return recover(afterHydrationFailure: false, originalFailure: .recreationFailed)
        }
    }

    private func recover(
        afterHydrationFailure: Bool,
        originalFailure: DevelopmentDatabaseLifecycleResult
    ) -> DevelopmentDatabaseLifecycleResult {
        do {
            try failIfInjected(.recovery)
            try? sqliteProvider?.database.checkpointAndClose()
            try removeDatabaseSet(at: identity.canonicalDevelopmentURL)
            try FileManager.default.copyItem(at: identity.backupURL, to: identity.canonicalDevelopmentURL)
            let restored = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
            publish(restored)
            _ = try RepositoryStoreHydrator(databaseProvider: DatabaseProvider.shared, participatesInLifecycleGate: false)
                .hydrateIfNeeded(forceRefresh: true)
            return afterHydrationFailure ? .hydrationFailedRecoverySucceeded : originalFailure
        } catch {
            isUnavailable = true
            activityGate.enterUnavailable()
            DatabaseProvider.shared.invalidateGeneration()
            return .recoveryFailed
        }
    }

    private func createAndVerifyBackup(from provider: SQLiteRepositoryProvider) throws {
        try failIfInjected(.backupCreation)
        try FileManager.default.createDirectory(
            at: identity.backupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try removeDatabaseSet(at: identity.backupURL)
        try provider.database.createBackup(at: identity.backupURL.path)
        try failIfInjected(.backupVerification)
        let verification = SQLiteDatabase(path: identity.backupURL.path)
        try verification.open()
        defer { verification.close() }
        let version = try verification.queryInt("SELECT COALESCE(MAX(version), 0) FROM schema_migrations;")
        guard version == allMigrations.map(\.version).max() else {
            throw SQLiteDatabaseError.backupFailed("migration-state")
        }
        let requiredTables = ["accounts", "transactions", "import_sessions", "import_attempts"]
        for table in requiredTables {
            let count = try verification.queryInt(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = '\(table)';"
            )
            guard count == 1 else {
                throw SQLiteDatabaseError.backupFailed("schema")
            }
        }
    }

    private func failIfInjected(_ point: DevelopmentDatabaseLifecycleFailurePoint) throws {
        if injectedFailures.contains(point) {
            throw SQLiteDatabaseError.backupFailed("injected-\(point)")
        }
    }

    private func publish(_ provider: SQLiteRepositoryProvider) {
#if DEBUG
        DatabaseProvider.shared.invalidateGeneration()
#endif
        DatabaseProvider.shared = DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            protectsGeneration: true
        )
        sqliteProvider = provider
        currentDatabaseURL = URL(fileURLWithPath: provider.databasePath).standardizedFileURL
    }

    private func removeDatabaseSet(at url: URL) throws {
        for member in identity.databaseSet(at: url) {
            if FileManager.default.fileExists(atPath: member.path) {
                try FileManager.default.removeItem(at: member)
            }
        }
    }
}
#endif

// MARK: - Repo implementations (minimal for Phase 2B)
fileprivate final class SQLiteWorkspaceRepo: WorkspaceRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String {
        let sql = "INSERT OR REPLACE INTO workspaces (id, name, created_at, updated_at) VALUES (?,?,?,?);"
        try db.executePrepared(sql: sql, params: [workspace.id, workspace.name, workspace.createdAtISO, workspace.updatedAtISO ?? NSNull()])
        return workspace.id
    }

    func workspace(id: String) throws -> WorkspaceDTO? {
        let sql = "SELECT id, name, created_at, updated_at FROM workspaces WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            WorkspaceDTO(
                id: row.string(at: 0) ?? "",
                name: row.string(at: 1) ?? "",
                createdAtISO: row.string(at: 2) ?? "",
                updatedAtISO: row.string(at: 3)
            )
        }.first
    }
}

fileprivate final class SQLiteAccountRepo: AccountRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        try ensureInstitutionExists(id: account.institutionId, createdAtISO: account.createdAtISO)

        let now = account.createdAtISO
        let sql = "INSERT OR REPLACE INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at, closed_at, created_from_import_session_id) VALUES (?,?,?,?,?,?,?,?,?,?);"
        try db.executePrepared(sql: sql, params: [account.id, account.workspaceId, account.name, account.institutionId ?? NSNull(), account.accountType ?? NSNull(), account.nativeCurrency, account.description ?? NSNull(), now, NSNull(), NSNull()])
        return account.id
    }

    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            throw RepositoryError.relationshipViolation("Account display name cannot be empty.")
        }
        guard let existing = try account(id: accountId) else {
            throw RepositoryError.recordNotFound("Account \(accountId) does not exist.")
        }
        guard existing.workspaceId == workspaceId else {
            throw RepositoryError.relationshipViolation("Account \(accountId) does not belong to workspace \(workspaceId).")
        }
        guard existing.name != trimmedDisplayName else {
            return false
        }

        try db.executePrepared(
            sql: "UPDATE accounts SET name = ? WHERE id = ? AND workspace_id = ?;",
            params: [trimmedDisplayName, accountId, workspaceId]
        )
        return true
    }

    func account(id: String) throws -> AccountDTO? {
        let sql = "SELECT id, workspace_id, name, institution_id, account_type, native_currency, description, created_at FROM accounts WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            AccountDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                name: row.string(at: 2) ?? "",
                institutionId: row.string(at: 3),
                accountType: row.string(at: 4),
                nativeCurrency: row.string(at: 5) ?? "",
                description: row.string(at: 6),
                createdAtISO: row.string(at: 7) ?? ""
            )
        }.first
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        let sql = "SELECT id, workspace_id, name, institution_id, account_type, native_currency, description, created_at FROM accounts WHERE workspace_id = ? ORDER BY name, id;"
        return try db.query(sql: sql, params: [workspaceId]) { row in
            AccountDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                name: row.string(at: 2) ?? "",
                institutionId: row.string(at: 3),
                accountType: row.string(at: 4),
                nativeCurrency: row.string(at: 5) ?? "",
                description: row.string(at: 6),
                createdAtISO: row.string(at: 7) ?? ""
            )
        }
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            guard let account = try account(id: identifier.accountId) else {
                throw RepositoryError.relationshipViolation("Account \(identifier.accountId) does not exist for identifier \(identifier.id).")
            }
            guard account.workspaceId == identifier.workspaceId else {
                throw RepositoryError.relationshipViolation("Account \(identifier.accountId) belongs to workspace \(account.workspaceId), not \(identifier.workspaceId).")
            }

            let existing = try storedIdentifiers(
                workspaceId: identifier.workspaceId,
                scheme: identifier.scheme,
                identifier: identifier.identifier
            )

            if let conflict = existing.first(where: { $0.accountId != identifier.accountId }) {
                throw RepositoryError.conflictingAccountIdentifier(
                    workspaceId: identifier.workspaceId,
                    scheme: identifier.scheme,
                    identifier: identifier.identifier,
                    existingAccountId: conflict.accountId,
                    attemptedAccountId: identifier.accountId
                )
            }

            if let current = existing.sorted(by: { $0.id < $1.id }).first {
                try db.execute(sql: "COMMIT;")
                DeveloperConsole.shared.info(.database, "Existing account identifier reused", metadata: [
                    "scheme": identifier.scheme,
                    "identifier": FinancialIdentifier.redacted(identifier.identifier)
                ])
                return current.id
            }

            let insert = "INSERT INTO account_identifiers (id, account_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?);"
            try db.executePrepared(sql: insert, params: [
                identifier.id,
                identifier.accountId,
                identifier.scheme,
                identifier.identifier,
                Self.provenanceJSON(for: identifier),
                identifier.createdAtISO
            ])
            try db.execute(sql: "COMMIT;")
            DeveloperConsole.shared.info(.database, "Account identifier attached", metadata: [
                "scheme": identifier.scheme,
                "identifier": FinancialIdentifier.redacted(identifier.identifier)
            ])
            return identifier.id
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            if case RepositoryError.conflictingAccountIdentifier(_, let scheme, let identifierValue, _, _) = error {
                DeveloperConsole.shared.warning(.database, "Conflicting account identifier rejected", metadata: [
                    "scheme": scheme,
                    "identifier": FinancialIdentifier.redacted(identifierValue)
                ])
            }
            throw error
        }
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        let sql = """
        SELECT ai.id, ai.account_id, a.workspace_id, ai.scheme, ai.identifier, ai.provenance, ai.created_at
        FROM account_identifiers ai
        INNER JOIN accounts a ON a.id = ai.account_id
        WHERE ai.account_id = ? AND a.workspace_id = ?
        ORDER BY ai.scheme, ai.identifier, ai.id;
        """
        return try db.query(sql: sql, params: [accountId, workspaceId]) { row in
            Self.identifierDTO(from: row)
        }
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        try storedIdentifiers(workspaceId: workspaceId, scheme: scheme, identifier: identifier)
            .map(\.accountId)
            .sorted()
    }

    private func storedIdentifiers(workspaceId: String, scheme: String, identifier: String) throws -> [AccountIdentifierDTO] {
        let sql = """
        SELECT ai.id, ai.account_id, a.workspace_id, ai.scheme, ai.identifier, ai.provenance, ai.created_at
        FROM account_identifiers ai
        INNER JOIN accounts a ON a.id = ai.account_id
        WHERE a.workspace_id = ? AND ai.scheme = ? AND ai.identifier = ?
        ORDER BY ai.account_id, ai.id;
        """
        return try db.query(sql: sql, params: [workspaceId, scheme, identifier]) { row in
            Self.identifierDTO(from: row)
        }
    }

    private static func identifierDTO(from row: SQLiteRow) -> AccountIdentifierDTO {
        let provenance = row.string(at: 5) ?? ""
        let metadata = provenanceMetadata(from: provenance)
        return AccountIdentifierDTO(
            id: row.string(at: 0) ?? "",
            accountId: row.string(at: 1) ?? "",
            workspaceId: row.string(at: 2) ?? "",
            scheme: row.string(at: 3) ?? "",
            identifier: row.string(at: 4) ?? "",
            strength: metadata["strength"] ?? "",
            verificationState: metadata["verificationState"] ?? "",
            provenance: metadata["provenance"] ?? provenance,
            createdAtISO: row.string(at: 6) ?? ""
        )
    }

    private static func provenanceJSON(for identifier: AccountIdentifierDTO) -> String {
        let payload = [
            "strength": identifier.strength,
            "verificationState": identifier.verificationState,
            "provenance": identifier.provenance
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return identifier.provenance
        }
        return json
    }

    private static func provenanceMetadata(from value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return ["provenance": value]
        }
        return object
    }

    private func ensureInstitutionExists(id: String?, createdAtISO: String) throws {
        guard let id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let code = id
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber {
                    return character
                }
                return "-"
            }

        let sql = "INSERT OR IGNORE INTO institutions (id, code, name, country, created_at) VALUES (?,?,?,?,?);"
        try db.executePrepared(sql: sql, params: [id, String(code), id, NSNull(), createdAtISO])
    }
}

fileprivate final class SQLiteImportSessionRepo: ImportSessionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        let sql = "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);"
        try db.executePrepared(sql: sql, params: [payload.id, payload.workspaceId, payload.userVisibleName ?? NSNull(), payload.startedAtISO, payload.validationStatus, payload.startedAtISO, payload.readerVersion ?? NSNull(), payload.parserVersion ?? NSNull(), payload.layoutVersion ?? NSNull()])
        return payload.id
    }

    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        var sets = [String]()
        var params: [Any?] = []
        if let status = updates.validationStatus { sets.append("validation_status = ?"); params.append(status) }
        if let completed = updates.completedAtISO { sets.append("completed_at = ?"); params.append(completed) }
        if sets.isEmpty { return }
        let updatedAt = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE import_sessions SET \(sets.joined(separator: ",")), updated_at = ? WHERE id = ?;"
        params.append(updatedAt)
        params.append(id)
        try db.executePrepared(sql: sql, params: params)
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        let sql = "SELECT id, workspace_id, user_visible_name, started_at, completed_at, validation_status, reader_version, parser_version, layout_version FROM import_sessions WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            ImportSessionRecordDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                userVisibleName: row.string(at: 2),
                startedAtISO: row.string(at: 3) ?? "",
                completedAtISO: row.string(at: 4),
                validationStatus: row.string(at: 5) ?? "",
                readerVersion: row.string(at: 6),
                parserVersion: row.string(at: 7),
                layoutVersion: row.string(at: 8)
            )
        }.first
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        try priorImportedStatementWithoutTransaction(algorithm: algorithm, fingerprint: fingerprint)
    }

    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        var result: [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] = [:]
        for key in keys {
            let rows = try db.query(
                sql: "SELECT account_id, transaction_id, document_id, import_session_id FROM transaction_event_identities WHERE algorithm = ? AND digest = ?;",
                params: [key.algorithm, key.digest]
            ) { row in
                TransactionEventIdentityOwnerDTO(accountId: row.string(at: 0) ?? "", transactionId: row.string(at: 1) ?? "", documentId: row.string(at: 2) ?? "", importSessionId: row.string(at: 3) ?? "")
            }
            if let owner = rows.first { result[key] = owner }
        }
        return result
    }

    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String {
        try insertImportAttempt(payload)
        return payload.id
    }

    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] {
        try db.query(sql: "SELECT id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id FROM import_attempts WHERE workspace_id = ? ORDER BY created_at DESC, id DESC;", params: [workspaceId]) { row in
            ImportAttemptDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", createdAtISO: row.string(at: 2) ?? "", outcomeCode: row.string(at: 3) ?? "", coverageCode: row.string(at: 4) ?? "", accountDecisionCode: row.string(at: 5) ?? "", guidanceCode: row.string(at: 6) ?? "", persistenceCode: row.string(at: 7) ?? "", transactionCount: Int(row.int64(at: 8) ?? 0), accountId: row.string(at: 9), importSessionId: row.string(at: 10), documentId: row.string(at: 11), relatedImportSessionId: row.string(at: 12))
        }
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            if let duplicate = try priorImportedStatementWithoutTransaction(
                algorithm: payload.fingerprint.algorithm,
                fingerprint: payload.fingerprint.fingerprint
            ) {
                try db.execute(sql: "COMMIT;")
                return .duplicate(duplicate)
            }

            try validateAtomicImportHistory(payload)
            try db.executePrepared(
                sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, mime_type, size_bytes, sha256, storage_path, extracted_text_snippet, page_count, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?);",
                params: [
                    payload.document.id,
                    payload.document.workspaceId,
                    payload.document.importSessionId,
                    payload.document.filename,
                    payload.document.mimeType ?? NSNull(),
                    payload.document.sizeBytes ?? NSNull(),
                    payload.document.sha256,
                    NSNull(),
                    NSNull(),
                    NSNull(),
                    payload.document.createdAtISO
                ]
            )
            try db.executePrepared(
                sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, fingerprint_data, created_at) VALUES (?,?,?,?,?,?,?);",
                params: [
                    payload.fingerprint.id,
                    payload.fingerprint.documentId,
                    payload.fingerprint.importSessionId,
                    payload.fingerprint.algorithm,
                    payload.fingerprint.fingerprint,
                    payload.fingerprint.fingerprintData ?? NSNull(),
                    payload.fingerprint.createdAtISO
                ]
            )
            try db.executePrepared(
                sql: "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);",
                params: [
                    payload.importSession.id,
                    payload.importSession.workspaceId,
                    payload.importSession.userVisibleName ?? NSNull(),
                    payload.importSession.startedAtISO,
                    payload.importSession.validationStatus,
                    payload.importSession.startedAtISO,
                    payload.importSession.readerVersion ?? NSNull(),
                    payload.importSession.parserVersion ?? NSNull(),
                    payload.importSession.layoutVersion ?? NSNull()
                ]
            )

            let insertTransaction = "INSERT INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);"
            let insertRawRow = "INSERT INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);"
            for transaction in payload.transactions {
                try db.executePrepared(sql: insertTransaction, params: [
                    transaction.id,
                    transaction.workspaceId,
                    transaction.accountId ?? NSNull(),
                    transaction.importSessionId ?? NSNull(),
                    transaction.documentId ?? NSNull(),
                    transaction.originalRowId ?? NSNull(),
                    transaction.postedDateISO,
                    transaction.valueDateISO ?? NSNull(),
                    transaction.description ?? NSNull(),
                    transaction.payee ?? NSNull(),
                    transaction.reference ?? NSNull(),
                    transaction.nativeCurrency,
                    transaction.amountMinor,
                    transaction.amountDecimal,
                    transaction.direction,
                    transaction.runningBalanceMinor ?? NSNull(),
                    transaction.isReconciled ? 1 : 0,
                    transaction.isTrusted ? 1 : 0,
                    transaction.trustedAtISO ?? NSNull(),
                    transaction.createdAtISO,
                    transaction.updatedAtISO ?? NSNull()
                ])
                for rawRow in transaction.rawRows {
                    try db.executePrepared(sql: insertRawRow, params: [
                        rawRow.id,
                        transaction.id,
                        rawRow.normalizedRowId,
                        rawRow.contributionType ?? NSNull(),
                        transaction.createdAtISO
                    ])
                }
            }

            let insertEvent = "INSERT INTO transaction_event_identities (id, transaction_id, account_id, document_id, import_session_id, algorithm, digest, created_at) VALUES (?,?,?,?,?,?,?,?);"
            for event in payload.transactionEventIdentities {
                try db.executePrepared(sql: insertEvent, params: [
                    event.id, event.transactionId, event.accountId, event.documentId,
                    event.importSessionId, event.algorithm, event.digest, event.createdAtISO
                ])
            }

            guard payload.successfulAttempt.workspaceId == payload.importSession.workspaceId,
                  payload.successfulAttempt.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue,
                  payload.successfulAttempt.importSessionId == payload.importSession.id,
                  payload.successfulAttempt.documentId == payload.document.id else {
                throw RepositoryError.relationshipViolation("Atomic import attempt relationships are inconsistent.")
            }
            try insertImportAttempt(payload.successfulAttempt)

            try db.executePrepared(
                sql: "UPDATE import_sessions SET validation_status = ?, completed_at = ?, updated_at = ? WHERE id = ?;",
                params: ["passed", payload.completedAtISO, payload.completedAtISO, payload.importSession.id]
            )
            try db.execute(sql: "COMMIT;")
            return .committed
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            throw error
        }
    }

    private func priorImportedStatementWithoutTransaction(
        algorithm: String,
        fingerprint: String
    ) throws -> PriorImportedStatementDTO? {
        let sql = """
        SELECT
          df.import_session_id,
          s.completed_at,
          (SELECT COUNT(*) FROM transactions t WHERE t.import_session_id = df.import_session_id),
          (SELECT t.account_id FROM transactions t WHERE t.import_session_id = df.import_session_id AND t.account_id IS NOT NULL ORDER BY t.id LIMIT 1),
          (SELECT a.name FROM accounts a WHERE a.id = (SELECT t.account_id FROM transactions t WHERE t.import_session_id = df.import_session_id AND t.account_id IS NOT NULL ORDER BY t.id LIMIT 1))
        FROM document_fingerprints df
        INNER JOIN import_sessions s ON s.id = df.import_session_id
        WHERE df.algorithm = ? AND df.fingerprint = ? AND s.validation_status = 'passed'
        LIMIT 1;
        """
        return try db.query(sql: sql, params: [algorithm, fingerprint]) { row in
            PriorImportedStatementDTO(
                importSessionId: row.string(at: 0) ?? "",
                completedAtISO: row.string(at: 1),
                transactionCount: Int(row.int64(at: 2) ?? 0),
                accountId: row.string(at: 3),
                accountDisplayName: row.string(at: 4)
            )
        }.first
    }

    private func validateAtomicImportHistory(_ payload: AtomicImportHistoryDTO) throws {
        guard payload.document.importSessionId == payload.importSession.id,
              payload.importSession.workspaceId == payload.document.workspaceId,
              payload.fingerprint.documentId == payload.document.id,
              payload.fingerprint.importSessionId == payload.importSession.id,
              payload.document.sha256 == payload.fingerprint.fingerprint,
              payload.fingerprint.fingerprintData == nil else {
            throw RepositoryError.relationshipViolation("Atomic import-history document relationships are inconsistent.")
        }
        guard try db.queryInt("SELECT COUNT(*) FROM workspaces WHERE id = '\(escape(payload.document.workspaceId))';") == 1 else {
            throw RepositoryError.relationshipViolation("Workspace does not exist for atomic import history.")
        }
        let accountIds = Set(payload.transactions.compactMap(\.accountId))
        guard accountIds.count == 1,
              payload.transactions.allSatisfy({ $0.accountId != nil }),
              let accountId = accountIds.first,
              try db.queryInt("SELECT COUNT(*) FROM accounts WHERE id = '\(escape(accountId))';") == 1 else {
            throw RepositoryError.relationshipViolation("Atomic import-history transactions must use one existing account.")
        }
        for transaction in payload.transactions {
            guard transaction.workspaceId == payload.document.workspaceId,
                  transaction.importSessionId == payload.importSession.id,
                  transaction.documentId == payload.document.id else {
                throw RepositoryError.relationshipViolation("Atomic import-history transaction relationships are inconsistent.")
            }
        }
        let transactionsByID = Dictionary(uniqueKeysWithValues: payload.transactions.map { ($0.id, $0) })
        let keys = payload.transactionEventIdentities.map { TransactionEventIdentityKeyDTO(algorithm: $0.algorithm, digest: $0.digest) }
        guard Set(keys).count == keys.count,
              payload.transactionEventIdentities.allSatisfy({ event in
                  transactionsByID[event.transactionId]?.accountId == event.accountId &&
                  event.documentId == payload.document.id && event.importSessionId == payload.importSession.id
              }) else {
            throw RepositoryError.relationshipViolation("Atomic import-history transaction event identities are inconsistent.")
        }
    }

    private func insertImportAttempt(_ payload: ImportAttemptDTO) throws {
        try db.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [payload.id, payload.workspaceId, payload.createdAtISO, payload.outcomeCode, payload.coverageCode, payload.accountDecisionCode, payload.guidanceCode, payload.persistenceCode, payload.transactionCount, payload.accountId ?? NSNull(), payload.importSessionId ?? NSNull(), payload.documentId ?? NSNull(), payload.relatedImportSessionId ?? NSNull()])
    }
}

fileprivate final class SQLiteTransactionRepo: TransactionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        // Atomic replace of candidate transactions for an import_session_id.
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            if let importId = importSessionId {
                // Remove prior non-trusted transactions for this import_session
                let delRaw = "DELETE FROM transaction_raw_rows WHERE transaction_id IN (SELECT id FROM transactions WHERE import_session_id = ? AND is_trusted = 0);"
                try db.executePrepared(sql: delRaw, params: [importId])
                let delTx = "DELETE FROM transactions WHERE import_session_id = ? AND is_trusted = 0;"
                try db.executePrepared(sql: delTx, params: [importId])
            }

            let insertTx = "INSERT OR REPLACE INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);"

            let insertRaw = "INSERT OR REPLACE INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);"

            for tx in transactions {
                try db.executePrepared(sql: insertTx, params: [tx.id, tx.workspaceId, tx.accountId ?? NSNull(), tx.importSessionId ?? NSNull(), tx.documentId ?? NSNull(), tx.originalRowId ?? NSNull(), tx.postedDateISO, tx.valueDateISO ?? NSNull(), tx.description ?? NSNull(), tx.payee ?? NSNull(), tx.reference ?? NSNull(), tx.nativeCurrency, tx.amountMinor, tx.amountDecimal, tx.direction, tx.runningBalanceMinor ?? NSNull(), tx.isReconciled ? 1 : 0, tx.isTrusted ? 1 : 0, tx.trustedAtISO ?? NSNull(), tx.createdAtISO, tx.updatedAtISO ?? NSNull()])

                for raw in tx.rawRows {
                    try db.executePrepared(sql: insertRaw, params: [raw.id, tx.id, raw.normalizedRowId, raw.contributionType ?? NSNull(), tx.createdAtISO])
                }
            }

            try db.execute(sql: "COMMIT;")
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            throw error
        }
    }

    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] {
        var sql = "SELECT id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at FROM transactions WHERE workspace_id = ?"
        var params: [Any?] = [workspaceId]
        if let importSessionId {
            sql += " AND import_session_id = ?"
            params.append(importSessionId)
        }
        sql += " ORDER BY posted_date DESC, id DESC;"

        return try db.query(sql: sql, params: params) { row in
            let transactionId = row.string(at: 0) ?? ""
            let rawRows = try rawRows(for: transactionId)
            return TransactionDTO(
                id: transactionId,
                workspaceId: row.string(at: 1) ?? "",
                accountId: row.string(at: 2),
                importSessionId: row.string(at: 3),
                documentId: row.string(at: 4),
                originalRowId: row.string(at: 5),
                postedDateISO: row.string(at: 6) ?? "",
                valueDateISO: row.string(at: 7),
                description: row.string(at: 8),
                payee: row.string(at: 9),
                reference: row.string(at: 10),
                nativeCurrency: row.string(at: 11) ?? "",
                amountMinor: row.int64(at: 12) ?? 0,
                amountDecimal: row.string(at: 13) ?? "",
                direction: row.string(at: 14) ?? "",
                runningBalanceMinor: row.int64(at: 15),
                isReconciled: row.bool(at: 16),
                isTrusted: row.bool(at: 17),
                trustedAtISO: row.string(at: 18),
                createdAtISO: row.string(at: 19) ?? "",
                updatedAtISO: row.string(at: 20),
                rawRows: rawRows
            )
        }
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        let sql = "SELECT id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at FROM transactions WHERE workspace_id = ? AND is_trusted = 1 ORDER BY posted_date DESC, id DESC;"
        return try db.query(sql: sql, params: [workspaceId]) { row in
            let transactionId = row.string(at: 0) ?? ""
            let rawRows = try rawRows(for: transactionId)
            return TransactionDTO(
                id: transactionId,
                workspaceId: row.string(at: 1) ?? "",
                accountId: row.string(at: 2),
                importSessionId: row.string(at: 3),
                documentId: row.string(at: 4),
                originalRowId: row.string(at: 5),
                postedDateISO: row.string(at: 6) ?? "",
                valueDateISO: row.string(at: 7),
                description: row.string(at: 8),
                payee: row.string(at: 9),
                reference: row.string(at: 10),
                nativeCurrency: row.string(at: 11) ?? "",
                amountMinor: row.int64(at: 12) ?? 0,
                amountDecimal: row.string(at: 13) ?? "",
                direction: row.string(at: 14) ?? "",
                runningBalanceMinor: row.int64(at: 15),
                isReconciled: row.bool(at: 16),
                isTrusted: row.bool(at: 17),
                trustedAtISO: row.string(at: 18),
                createdAtISO: row.string(at: 19) ?? "",
                updatedAtISO: row.string(at: 20),
                rawRows: rawRows
            )
        }
    }

    private func rawRows(for transactionId: String) throws -> [TransactionRawRowDTO] {
        let sql = "SELECT id, normalized_row_id, contribution_type FROM transaction_raw_rows WHERE transaction_id = ? ORDER BY id;"
        return try db.query(sql: sql, params: [transactionId]) { row in
            TransactionRawRowDTO(
                id: row.string(at: 0) ?? "",
                normalizedRowId: row.string(at: 1) ?? "",
                contributionType: row.string(at: 2)
            )
        }
    }
}

// MARK: - Utilities
fileprivate func escape(_ s: String) -> String {
    return s.replacingOccurrences(of: "'", with: "''")
}
