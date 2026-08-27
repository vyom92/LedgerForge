// Database/SQLiteRepositoryProvider.swift
// SQLite-backed repository provider for LedgerForge (Sprint 10 Phase 2B)

import Foundation
import SQLite3
#if DEBUG
import Combine
#endif

#if DEBUG
enum DevelopmentDatabaseNamespaceError: Error, Equatable, LocalizedError {
    case invalid

    var errorDescription: String? {
        "The requested development database namespace is invalid."
    }
}

private struct DevelopmentDatabaseNamespace: Equatable {
    let value: String

    init(validating value: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard !value.isEmpty,
              value.utf8.count <= 48,
              value.unicodeScalars.allSatisfy(allowed.contains),
              value.first != "-",
              value.last != "-",
              !value.contains("--") else {
            throw DevelopmentDatabaseNamespaceError.invalid
        }
        self.value = value
    }
}

enum DevelopmentDatabaseProfileIdentityError: Error, Equatable {
    case invalidProfile
}

struct DevelopmentDatabaseProfileTarget: Equatable {
    let profile: DevelopmentDatabaseProfile
    let databaseURL: URL

    var isCleanupOwned: Bool {
        profile.kind == .temporarySession || profile.kind == .migrationSandbox
    }
}

struct DevelopmentDatabaseIdentity: Equatable {
    static let namespaceEnvironmentKey = "LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE"
    static let namespaceOverrideIsCompiled = true

    let canonicalDevelopmentURL: URL
    let persistentDebugURL: URL
    let nonDevelopmentURL: URL
    let backupURL: URL
    let temporaryDirectoryURL: URL
    let migrationSandboxDirectoryURL: URL

    private let namespace: DevelopmentDatabaseNamespace?
    private let authorizedResolvedCurrentURL: URL
    private let authorizedResolvedPersistentDebugURL: URL
    private let authorizedDevelopmentRootURL: URL

    init(applicationSupportDirectory: URL) {
        self.init(applicationSupportDirectory: applicationSupportDirectory, namespace: nil)
    }

    private init(
        applicationSupportDirectory: URL,
        namespace: DevelopmentDatabaseNamespace?
    ) {
        let applicationDirectory = applicationSupportDirectory
            .appendingPathComponent("LedgerForge", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let defaultDevelopmentDirectory = applicationDirectory
            .appendingPathComponent("Development", isDirectory: true)
        let developmentDirectory: URL
        if let namespace {
            developmentDirectory = defaultDevelopmentDirectory
                .appendingPathComponent("Namespaces", isDirectory: true)
                .appendingPathComponent(namespace.value, isDirectory: true)
        } else {
            developmentDirectory = defaultDevelopmentDirectory
        }
        let canonical = developmentDirectory
            .appendingPathComponent("ledgerforge-development.sqlite")
            .standardizedFileURL

        self.namespace = namespace
        canonicalDevelopmentURL = canonical
        persistentDebugURL = developmentDirectory
            .appendingPathComponent("ledgerforge-debug.sqlite")
            .standardizedFileURL
        nonDevelopmentURL = applicationDirectory
            .appendingPathComponent("ledgerforge.sqlite")
            .standardizedFileURL
        backupURL = developmentDirectory
            .appendingPathComponent("Lifecycle Backups", isDirectory: true)
            .appendingPathComponent("previous-persistent-debug.sqlite")
            .standardizedFileURL
        temporaryDirectoryURL = developmentDirectory
            .appendingPathComponent("Temporary Sessions", isDirectory: true)
            .standardizedFileURL
        migrationSandboxDirectoryURL = developmentDirectory
            .appendingPathComponent("Migration Sandboxes", isDirectory: true)
            .standardizedFileURL
        authorizedResolvedCurrentURL = canonical
        authorizedResolvedPersistentDebugURL = persistentDebugURL
        authorizedDevelopmentRootURL = defaultDevelopmentDirectory.standardizedFileURL
    }

    static func applicationOwned() -> DevelopmentDatabaseIdentity {
        lifecycleIdentity(
            applicationSupportDirectory: applicationSupportDirectory(),
            environment: ProcessInfo.processInfo.environment
        )
    }

    static func applicationOwned(environment: [String: String]) throws -> DevelopmentDatabaseIdentity {
        let applicationSupport = applicationSupportDirectory()
        return try resolve(applicationSupportDirectory: applicationSupport, environment: environment)
    }

    static func resolve(
        applicationSupportDirectory: URL,
        environment: [String: String]
    ) throws -> DevelopmentDatabaseIdentity {
        guard let rawNamespace = environment[namespaceEnvironmentKey] else {
            return DevelopmentDatabaseIdentity(applicationSupportDirectory: applicationSupportDirectory)
        }
        let namespace = try DevelopmentDatabaseNamespace(validating: rawNamespace)
        return DevelopmentDatabaseIdentity(
            applicationSupportDirectory: applicationSupportDirectory,
            namespace: namespace
        )
    }

    var isIsolatedCanonicalNamespace: Bool { namespace != nil }

    func authorizesIsolatedCleanup(at candidate: URL) -> Bool {
        guard namespace != nil else { return false }
        return candidate.standardizedFileURL != canonicalDevelopmentURL
            && candidate.standardizedFileURL != persistentDebugURL
            && containsNoSymlink(from: candidate.standardizedFileURL, through: authorizedDevelopmentRootURL)
    }

    func target(for profile: DevelopmentDatabaseProfile) throws -> DevelopmentDatabaseProfileTarget {
        let url: URL
        switch profile.kind {
        case .current:
            guard profile.ownershipID == nil, profile.migrationSourceVersion == nil else {
                throw DevelopmentDatabaseProfileIdentityError.invalidProfile
            }
            url = canonicalDevelopmentURL
        case .persistentDebug:
            guard profile.ownershipID == nil, profile.migrationSourceVersion == nil else {
                throw DevelopmentDatabaseProfileIdentityError.invalidProfile
            }
            url = persistentDebugURL
        case .temporarySession:
            guard let ownershipID = profile.ownershipID, profile.migrationSourceVersion == nil else {
                throw DevelopmentDatabaseProfileIdentityError.invalidProfile
            }
            url = temporaryDirectoryURL
                .appendingPathComponent("temporary-\(ownershipID.uuidString.lowercased()).sqlite")
                .standardizedFileURL
        case .migrationSandbox:
            guard let ownershipID = profile.ownershipID,
                  let sourceVersion = profile.migrationSourceVersion,
                  DevelopmentDatabaseProfile.registeredHistoricalSourceVersions.contains(sourceVersion) else {
                throw DevelopmentDatabaseProfileIdentityError.invalidProfile
            }
            url = migrationSandboxDirectoryURL
                .appendingPathComponent("migration-v\(sourceVersion)-\(ownershipID.uuidString.lowercased()).sqlite")
                .standardizedFileURL
        }
        return DevelopmentDatabaseProfileTarget(profile: profile, databaseURL: url)
    }

    func authorizesCurrentDatabaseIdentity(at candidate: URL) -> Bool {
        let standardizedCandidate = candidate.standardizedFileURL
        return standardizedCandidate == authorizedResolvedCurrentURL
            && containsNoSymlink(from: standardizedCandidate, through: authorizedDevelopmentRootURL)
    }

    func authorizesPersistentDebugReset(at candidate: URL) -> Bool {
        let standardizedCandidate = candidate.standardizedFileURL
        return standardizedCandidate == authorizedResolvedPersistentDebugURL
            && containsNoSymlink(from: standardizedCandidate, through: authorizedDevelopmentRootURL)
    }

    func authorizesCleanup(of target: DevelopmentDatabaseProfileTarget) -> Bool {
        guard target.isCleanupOwned,
              let expected = try? self.target(for: target.profile) else {
            return false
        }
        let candidate = target.databaseURL.standardizedFileURL
        return candidate == expected.databaseURL.standardizedFileURL
            && containsNoSymlink(from: candidate, through: authorizedDevelopmentRootURL)
    }

    static func lifecycleIdentity(
        applicationSupportDirectory: URL,
        environment: [String: String]
    ) -> DevelopmentDatabaseIdentity {
        if let resolved = try? resolve(
            applicationSupportDirectory: applicationSupportDirectory,
            environment: environment
        ) {
            return resolved
        }
        // The provider bootstrap still throws for invalid explicit activation.
        // This non-default sentinel keeps lifecycle authority away from the
        // existing canonical database while persistence remains unavailable.
        let invalidNamespace = try! DevelopmentDatabaseNamespace(validating: "invalid-activation")
        return DevelopmentDatabaseIdentity(
            applicationSupportDirectory: applicationSupportDirectory,
            namespace: invalidNamespace
        )
    }

    private static func applicationSupportDirectory() -> URL {
        let fileManager = FileManager.default
        return (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    func authorizesDestructiveWork(at candidate: URL) -> Bool {
        authorizesPersistentDebugReset(at: candidate)
    }

    func authorizesUnavailableCanonicalReset() -> Bool {
        let fileManager = FileManager.default
        guard authorizesDestructiveWork(at: canonicalDevelopmentURL),
              authorizesLifecycleBackup(at: backupURL),
              isRegularFile(canonicalDevelopmentURL, fileManager: fileManager),
              hasSQLiteHeader(canonicalDevelopmentURL) else {
            return false
        }

        return databaseSet(at: canonicalDevelopmentURL).dropFirst().allSatisfy { member in
            !fileManager.fileExists(atPath: member.path)
                || isRegularFile(member, fileManager: fileManager)
        }
    }

    func authorizesLifecycleBackup(at candidate: URL) -> Bool {
        let standardizedCandidate = candidate.standardizedFileURL
        return standardizedCandidate == backupURL
            && containsNoSymlink(from: standardizedCandidate, through: authorizedDevelopmentRootURL)
    }

    private func isRegularFile(_ url: URL, fileManager: FileManager) -> Bool {
        guard url.isFileURL,
              !url.path.isEmpty,
              fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return false
        }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private func hasSQLiteHeader(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 16) else { return false }
        return header == Data("SQLite format 3\0".utf8)
    }

    private func containsNoSymlink(from candidate: URL, through root: URL) -> Bool {
        let fileManager = FileManager.default
        var current = candidate
        while current.pathComponents.count >= root.pathComponents.count {
            let attributes = try? fileManager.attributesOfItem(atPath: current.path)
            if attributes?[.type] as? FileAttributeType == .typeSymbolicLink {
                return false
            }
            if current == root {
                return true
            }
            let parent = current.deletingLastPathComponent()
            guard parent != current else { return false }
            current = parent
        }
        return false
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

enum SQLiteRepositoryProviderError: Error, Equatable, LocalizedError {
    case databaseOpenFailed
    case databaseInitializationFailed
    case migrationIntegrityFailed(MigrationIntegrityError)
    case migrationFailed

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed:
            return "The durable database could not be opened."
        case .databaseInitializationFailed:
            return "The durable database could not be initialized safely."
        case .migrationIntegrityFailed:
            return "The database migration history did not pass integrity verification."
        case .migrationFailed:
            return "The required database migrations could not be completed."
        }
    }
}

/// SQLite-backed provider that runs migrations and exposes repository implementations.
public final class SQLiteRepositoryProvider {
    public let databasePath: String
    public let database: SQLiteDatabase
    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let categoryRepo: CategoryRepository
    public let accountRepo: AccountRepository
    public let cardRepo: CardRepository
    public let importSessionRepo: ImportSessionRepository
    public let generationToken: ProviderGenerationToken
    public let confirmedImportRepo: ConfirmedImportRepository

    public convenience init(path: String? = nil) throws {
        try self.init(path: path, migrations: allMigrations)
    }

    init(path: String?, migrations: [Migration]) throws {
        do {
            try MigrationChainValidator.validateRegistered(migrations)
        } catch let error as MigrationIntegrityError {
            throw SQLiteRepositoryProviderError.migrationIntegrityFailed(error)
        }
        let dbPath: String
        if let path {
            dbPath = path
        } else {
            dbPath = try Self.defaultDBPath()
        }
        self.databasePath = dbPath
        let database = SQLiteDatabase(path: dbPath)
        do {
            try database.open()
        } catch {
            database.close()
            throw SQLiteRepositoryProviderError.databaseOpenFailed
        }
        do {
            try database.runMigrations(migrations)
        } catch let error as MigrationIntegrityError {
            database.close()
            throw SQLiteRepositoryProviderError.migrationIntegrityFailed(error)
        } catch {
            database.close()
            throw SQLiteRepositoryProviderError.migrationFailed
        }
        do {
            try database.execute(sql: "PRAGMA foreign_keys = ON;")
        } catch {
            database.close()
            throw SQLiteRepositoryProviderError.databaseInitializationFailed
        }
        let generationToken = ProviderGenerationToken()
        let supportsConfirmedImport = (try? database.query(
            sql: "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'account_identifier_observations';",
            params: []
        ) { _ in true }.isEmpty == false) ?? false
        let supportsCards = (try? database.query(
            sql: "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'card_instruments';",
            params: []
        ) { _ in true }.isEmpty == false) ?? false
        self.database = database
        self.generationToken = generationToken

        self.workspaceRepo = SQLiteWorkspaceRepo(db: database)
        self.transactionRepo = SQLiteTransactionRepo(db: database)
        self.categoryRepo = SQLiteCategoryRepo(db: database)
        self.accountRepo = SQLiteAccountRepo(db: database)
        self.cardRepo = supportsCards ? SQLiteCardRepo(db: database) : EmptyCardRepo()
        self.importSessionRepo = SQLiteImportSessionRepo(db: database)
        self.confirmedImportRepo = supportsConfirmedImport
            ? SQLiteConfirmedImportRepository(db: database, generationToken: generationToken)
            : PlaceholderConfirmedImportRepo()
    }

    public static func defaultDBPath() throws -> String {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
#if DEBUG
        if let appSupport {
            let identity = try DevelopmentDatabaseIdentity.resolve(
                applicationSupportDirectory: appSupport,
                environment: ProcessInfo.processInfo.environment
            )
            try? fm.createDirectory(
                at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            guard identity.authorizesCurrentDatabaseIdentity(at: identity.canonicalDevelopmentURL) else {
                throw SQLiteRepositoryProviderError.databaseInitializationFailed
            }
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

private final class SQLiteCardRepo: CardRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func snapshot(workspaceId: String) throws -> CardRepositorySnapshotDTO {
        let instruments = try db.query(
            sql: "SELECT id, workspace_id, liability_account_id, lifecycle_state, created_at FROM card_instruments WHERE workspace_id = ? ORDER BY id;",
            params: [workspaceId]
        ) { row in
            CardInstrumentDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", liabilityAccountId: row.string(at: 2) ?? "", lifecycleStateCode: row.string(at: 3) ?? "", createdAtISO: row.string(at: 4) ?? "")
        }
        let identifiers = try db.query(
            sql: "SELECT id, instrument_id, workspace_id, scheme, identifier, parser_provenance, created_at FROM card_instrument_identifiers WHERE workspace_id = ? ORDER BY id;",
            params: [workspaceId]
        ) { row in
            CardInstrumentIdentifierDTO(id: row.string(at: 0) ?? "", instrumentId: row.string(at: 1) ?? "", workspaceId: row.string(at: 2) ?? "", scheme: row.string(at: 3) ?? "", identifier: row.string(at: 4) ?? "", parserProvenanceCode: row.string(at: 5) ?? "", createdAtISO: row.string(at: 6) ?? "")
        }
        let observations = try db.query(
            sql: "SELECT id, workspace_id, document_id, import_session_id, normalized_document_id, parser_profile_id, parser_profile_version, subject_kind, subject_id, observation_kind, source_value, association_authority, created_at FROM card_source_identity_observations WHERE workspace_id = ? ORDER BY created_at, id;",
            params: [workspaceId]
        ) { row in
            CardSourceIdentityObservationDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", documentId: row.string(at: 2) ?? "", importSessionId: row.string(at: 3) ?? "", normalizedDocumentId: row.string(at: 4) ?? "", parserProfileId: row.string(at: 5) ?? "", parserProfileVersion: row.string(at: 6) ?? "", subjectKind: row.string(at: 7) ?? "", subjectId: row.string(at: 8) ?? "", observationKind: row.string(at: 9) ?? "", sourceValue: row.string(at: 10) ?? "", associationAuthority: row.string(at: 11) ?? "", createdAtISO: row.string(at: 12) ?? "")
        }
        let relationships = try db.query(
            sql: "SELECT id, workspace_id, liability_account_id, predecessor_instrument_id, successor_instrument_id, relationship_kind, authority, effective_date, created_at FROM card_instrument_relationships WHERE workspace_id = ? ORDER BY created_at, id;",
            params: [workspaceId]
        ) { row in
            CardInstrumentRelationshipDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", liabilityAccountId: row.string(at: 2) ?? "", predecessorInstrumentId: row.string(at: 3) ?? "", successorInstrumentId: row.string(at: 4) ?? "", relationshipKind: row.string(at: 5) ?? "", authority: row.string(at: 6) ?? "", effectiveDateISO: row.string(at: 7), createdAtISO: row.string(at: 8) ?? "")
        }
        let statements = try db.query(
            sql: "SELECT id, workspace_id, liability_account_id, document_id, import_session_id, normalized_document_id, parser_profile_id, parser_profile_version, statement_date, statement_start_date, statement_end_date, selected_statement_month, statement_currency, source_row_count, reconciliation_rule_code, created_at FROM card_statements WHERE workspace_id = ? ORDER BY COALESCE(statement_end_date, selected_statement_month), id;",
            params: [workspaceId]
        ) { row in
            CardStatementDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", liabilityAccountId: row.string(at: 2) ?? "", documentId: row.string(at: 3) ?? "", importSessionId: row.string(at: 4) ?? "", normalizedDocumentId: row.string(at: 5) ?? "", parserProfileId: row.string(at: 6) ?? "", parserProfileVersion: row.string(at: 7) ?? "", statementDateISO: row.string(at: 8), statementStartDateISO: row.string(at: 9), statementEndDateISO: row.string(at: 10), selectedStatementMonthISO: row.string(at: 11), statementCurrency: row.string(at: 12) ?? "", sourceRowCount: Int(row.int64(at: 13) ?? 0), reconciliationRuleCode: row.string(at: 14) ?? "", createdAtISO: row.string(at: 15) ?? "")
        }
        let statementIDs = Set(statements.map(\.id))
        let summaries = try db.query(
            sql: "SELECT c.id, c.card_statement_id, c.component_code, c.money_currency, c.money_minor, c.money_decimal, c.date_value FROM card_statement_summary_components c JOIN card_statements s ON s.id = c.card_statement_id WHERE s.workspace_id = ? ORDER BY c.card_statement_id, c.component_code;",
            params: [workspaceId]
        ) { row in
            CardStatementSummaryComponentDTO(id: row.string(at: 0) ?? "", cardStatementId: row.string(at: 1) ?? "", componentCode: row.string(at: 2) ?? "", moneyCurrency: row.string(at: 3), moneyMinor: row.int64(at: 4), moneyDecimal: row.string(at: 5), dateISO: row.string(at: 6))
        }.filter { statementIDs.contains($0.cardStatementId) }
        let evidence = try db.query(
            sql: "SELECT e.id, e.card_statement_id, e.transaction_id, e.row_scope, e.instrument_id, e.liability_effect, e.source_transaction_date, e.document_scoped_section_id, e.original_currency, e.original_amount_minor, e.original_amount_decimal, e.summary_membership_code FROM card_transaction_evidence e JOIN card_statements s ON s.id = e.card_statement_id WHERE s.workspace_id = ? ORDER BY e.card_statement_id, e.id;",
            params: [workspaceId]
        ) { row in
            CardTransactionEvidenceDTO(id: row.string(at: 0) ?? "", cardStatementId: row.string(at: 1) ?? "", transactionId: row.string(at: 2) ?? "", rowScopeCode: row.string(at: 3) ?? "", instrumentId: row.string(at: 4), liabilityEffectCode: row.string(at: 5) ?? "", sourceTransactionDateISO: row.string(at: 6) ?? "", documentScopedSectionId: row.string(at: 7), originalCurrency: row.string(at: 8), originalAmountMinor: row.int64(at: 9), originalAmountDecimal: row.string(at: 10), summaryMembershipCode: row.string(at: 11))
        }
        let sections = try db.query(
            sql: "SELECT cs.id, cs.card_statement_id, cs.document_scoped_section_id, cs.source_ordinal, cs.instrument_id, cs.holder_label, cs.signed_total_currency, cs.signed_total_minor, cs.signed_total_decimal, cs.reconciliation_rule_code FROM card_statement_sections cs JOIN card_statements s ON s.id = cs.card_statement_id WHERE s.workspace_id = ? ORDER BY cs.card_statement_id, cs.source_ordinal;",
            params: [workspaceId]
        ) { row in
            CardStatementSectionDTO(
                id: row.string(at: 0) ?? "", cardStatementId: row.string(at: 1) ?? "",
                documentScopedSectionId: row.string(at: 2) ?? "", sourceOrdinal: Int(row.int64(at: 3) ?? 0),
                instrumentId: row.string(at: 4) ?? "", holderLabel: row.string(at: 5),
                signedTotalCurrency: row.string(at: 6) ?? "", signedTotalMinor: row.int64(at: 7) ?? 0,
                signedTotalDecimal: row.string(at: 8) ?? "", reconciliationRuleCode: row.string(at: 9) ?? ""
            )
        }
        let sectionObservations = try db.query(
            sql: "SELECT id, card_statement_section_id, workspace_id, document_id, import_session_id, normalized_document_id, parser_profile_id, parser_profile_version, observation_kind, source_value, association_authority, created_at FROM card_statement_section_observations WHERE workspace_id = ? ORDER BY created_at, id;",
            params: [workspaceId]
        ) { row in
            CardStatementSectionObservationDTO(
                id: row.string(at: 0) ?? "", cardStatementSectionId: row.string(at: 1) ?? "",
                workspaceId: row.string(at: 2) ?? "", documentId: row.string(at: 3) ?? "",
                importSessionId: row.string(at: 4) ?? "", normalizedDocumentId: row.string(at: 5) ?? "",
                parserProfileId: row.string(at: 6) ?? "", parserProfileVersion: row.string(at: 7) ?? "",
                observationKind: row.string(at: 8) ?? "", sourceValue: row.string(at: 9) ?? "",
                associationAuthority: row.string(at: 10) ?? "", createdAtISO: row.string(at: 11) ?? ""
            )
        }
        let projectionSections = try db.query(
            sql: "SELECT ps.id, ps.projection_id, ps.source_ordinal, ps.document_scoped_section_id, ps.signed_total_currency, ps.signed_total_minor, ps.signed_total_decimal, ps.reconciliation_rule_code FROM card_statement_semantic_projection_sections ps JOIN card_statement_semantic_projections p ON p.id = ps.projection_id WHERE p.workspace_id = ? ORDER BY ps.projection_id, ps.source_ordinal;",
            params: [workspaceId]
        ) { row in
            CardStatementSemanticProjectionSectionDTO(
                id: row.string(at: 0) ?? "", projectionId: row.string(at: 1) ?? "",
                sourceOrdinal: Int(row.int64(at: 2) ?? 0), documentScopedSectionId: row.string(at: 3) ?? "",
                signedTotalCurrency: row.string(at: 4) ?? "", signedTotalMinor: row.int64(at: 5) ?? 0,
                signedTotalDecimal: row.string(at: 6) ?? "", reconciliationRuleCode: row.string(at: 7) ?? ""
            )
        }
        let projectionEvents = try db.query(
            sql: "SELECT pe.id, pe.projection_id, pe.canonical_transaction_id, pe.normalized_row_id, pe.source_ordinal, pe.financial_date, pe.financial_date_role, pe.source_transaction_date, pe.liability_effect, pe.posted_currency, pe.posted_amount_minor, pe.posted_amount_decimal, pe.original_currency, pe.original_amount_minor, pe.original_amount_decimal, pe.source_reference, pe.row_scope, pe.document_scoped_section_id, pe.document_section_ordinal FROM card_statement_semantic_projection_events pe JOIN card_statement_semantic_projections p ON p.id = pe.projection_id WHERE p.workspace_id = ? ORDER BY pe.projection_id, pe.source_ordinal;",
            params: [workspaceId]
        ) { row in
            CardStatementSemanticProjectionEventDTO(
                id: row.string(at: 0) ?? "", projectionId: row.string(at: 1) ?? "",
                canonicalTransactionId: row.string(at: 2), normalizedRowId: row.string(at: 3) ?? "",
                sourceOrdinal: Int(row.int64(at: 4) ?? 0), financialDateISO: row.string(at: 5) ?? "",
                financialDateRoleCode: row.string(at: 6) ?? "", sourceTransactionDateISO: row.string(at: 7),
                liabilityEffectCode: row.string(at: 8) ?? "", postedCurrency: row.string(at: 9) ?? "",
                postedAmountMinor: row.int64(at: 10) ?? 0, postedAmountDecimal: row.string(at: 11) ?? "",
                originalCurrency: row.string(at: 12), originalAmountMinor: row.int64(at: 13),
                originalAmountDecimal: row.string(at: 14), sourceReference: row.string(at: 15),
                rowScopeCode: row.string(at: 16) ?? "", documentScopedSectionId: row.string(at: 17),
                documentSectionOrdinal: row.int64(at: 18).map(Int.init)
            )
        }
        let semanticProjections = try db.query(
            sql: "SELECT id, workspace_id, liability_account_id, card_statement_id, document_id, import_session_id, algorithm, digest, institution_code, statement_family_code, parser_profile_id, parser_profile_version, statement_date, statement_start_date, statement_end_date, selected_statement_month, cycle_month, native_currency, event_count, section_count, reconciliation_rule_code, created_at FROM card_statement_semantic_projections WHERE workspace_id = ? ORDER BY COALESCE(statement_end_date, cycle_month), id;",
            params: [workspaceId]
        ) { row in
            let projectionID = row.string(at: 0) ?? ""
            return CardStatementSemanticProjectionRecordDTO(
                id: projectionID, workspaceId: row.string(at: 1) ?? "", liabilityAccountId: row.string(at: 2) ?? "",
                cardStatementId: row.string(at: 3) ?? "", documentId: row.string(at: 4) ?? "",
                importSessionId: row.string(at: 5) ?? "", algorithm: row.string(at: 6) ?? "",
                digest: row.string(at: 7) ?? "", institutionCode: row.string(at: 8) ?? "",
                statementFamilyCode: row.string(at: 9) ?? "", parserProfileId: row.string(at: 10) ?? "",
                parserProfileVersion: row.string(at: 11) ?? "", statementDateISO: row.string(at: 12),
                statementStartDateISO: row.string(at: 13), statementEndDateISO: row.string(at: 14),
                selectedStatementMonthISO: row.string(at: 15), cycleMonthISO: row.string(at: 16),
                nativeCurrency: row.string(at: 17) ?? "", eventCount: Int(row.int64(at: 18) ?? 0),
                sectionCount: Int(row.int64(at: 19) ?? 0), reconciliationRuleCode: row.string(at: 20) ?? "",
                createdAtISO: row.string(at: 21) ?? "",
                sections: projectionSections.filter { $0.projectionId == projectionID },
                events: projectionEvents.filter { $0.projectionId == projectionID }
            )
        }
        let semanticGroups = try db.query(
            sql: "SELECT id, workspace_id, liability_account_id, institution_code, statement_family_code, statement_start_date, statement_end_date, cycle_month, native_currency, projection_algorithm, projection_digest, authoritative_projection_id, created_at FROM card_statement_semantic_groups WHERE workspace_id = ? ORDER BY COALESCE(statement_end_date, cycle_month), id;",
            params: [workspaceId]
        ) { row in
            CardStatementSemanticGroupDTO(
                id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "",
                liabilityAccountId: row.string(at: 2) ?? "", institutionCode: row.string(at: 3) ?? "",
                statementFamilyCode: row.string(at: 4) ?? "", statementStartDateISO: row.string(at: 5),
                statementEndDateISO: row.string(at: 6), cycleMonthISO: row.string(at: 7), nativeCurrency: row.string(at: 8) ?? "",
                projectionAlgorithm: row.string(at: 9) ?? "", projectionDigest: row.string(at: 10) ?? "",
                authoritativeProjectionId: row.string(at: 11) ?? "", createdAtISO: row.string(at: 12) ?? ""
            )
        }
        let semanticMembers = try db.query(
            sql: "SELECT m.id, m.group_id, m.projection_id, m.role, m.created_at FROM card_statement_semantic_members m JOIN card_statement_semantic_groups g ON g.id = m.group_id WHERE g.workspace_id = ? ORDER BY m.id;",
            params: [workspaceId]
        ) { row in
            guard let role = StatementEquivalenceMemberRole(rawValue: row.string(at: 3) ?? "") else {
                throw RepositoryError.relationshipViolation("Card semantic member role is invalid.")
            }
            return CardStatementSemanticMemberDTO(
                id: row.string(at: 0) ?? "", groupId: row.string(at: 1) ?? "",
                projectionId: row.string(at: 2) ?? "",
                role: role,
                createdAtISO: row.string(at: 4) ?? ""
            )
        }
        return CardRepositorySnapshotDTO(
            instruments: instruments, instrumentIdentifiers: identifiers, sourceObservations: observations,
            relationships: relationships, statements: statements, summaryComponents: summaries,
            transactionEvidence: evidence, sections: sections, sectionObservations: sectionObservations,
            semanticProjections: semanticProjections, semanticGroups: semanticGroups, semanticMembers: semanticMembers
        )
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

    func transition(to activity: DevelopmentDatabaseActivity) async {
        guard !isFinished else { return }
        self.activity = activity
        gate?.update(self)
        await gate?.observeTransitionForTesting(activity)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        gate?.finish(self)
    }
}

struct DevelopmentDatabasePreparedImportDrainPermit {
    fileprivate init() {}
}

enum DevelopmentDatabaseProfileSwitchBarrierResult: Equatable {
    case acquired(DevelopmentPreparedImportInvalidationResult)
    case activityBlocked
    case lifecycleUnavailable
}

@MainActor
final class DevelopmentDatabaseActivityGate {
    static let shared = DevelopmentDatabaseActivityGate()

    private var leases: [UUID: DevelopmentDatabaseActivity] = [:]
    private(set) var generation = 1
    private(set) var hasExclusiveOperation = false
    private(set) var isProfileSwitchPending = false
    private(set) var isUnavailable = false
    private var transitionObserverForTesting: (@MainActor (DevelopmentDatabaseActivity) async -> Void)?

    var hasActiveOperations: Bool { !leases.isEmpty }

    func begin(_ activity: DevelopmentDatabaseActivity) throws -> DevelopmentDatabaseActivityLease {
        guard !isUnavailable else { throw DevelopmentDatabaseActivityError.lifecycleUnavailable }
        guard !hasExclusiveOperation, !isProfileSwitchPending else {
            throw DevelopmentDatabaseActivityError.lifecycleOperationInProgress
        }
        let lease = DevelopmentDatabaseActivityLease(gate: self, activity: activity, generation: generation)
        leases[lease.id] = activity
        return lease
    }

    func beginExclusive() -> Bool {
        guard !isUnavailable, !hasExclusiveOperation, !isProfileSwitchPending, leases.isEmpty else { return false }
        hasExclusiveOperation = true
        return true
    }

    /// Creates one synchronous barrier: new work is blocked before prepared
    /// previews are drained, and exclusive ownership is granted only after all
    /// corresponding leases have been released.
    func beginProfileSwitch(
        drainPreparedImports: (DevelopmentDatabasePreparedImportDrainPermit) -> DevelopmentPreparedImportInvalidationResult
    ) -> DevelopmentDatabaseProfileSwitchBarrierResult {
        guard !isUnavailable else { return .lifecycleUnavailable }
        guard !hasExclusiveOperation, !isProfileSwitchPending else { return .activityBlocked }

        isProfileSwitchPending = true
        let hasNonDrainableActivity = leases.values.contains { $0 != .preparedAwaitingConfirmation }
        guard !hasNonDrainableActivity else {
            isProfileSwitchPending = false
            return .activityBlocked
        }

        let invalidation = drainPreparedImports(DevelopmentDatabasePreparedImportDrainPermit())
        guard leases.isEmpty else {
            isProfileSwitchPending = false
            return .activityBlocked
        }

        hasExclusiveOperation = true
        return .acquired(invalidation)
    }

    func finishExclusive(providerChanged: Bool) {
        if providerChanged { generation += 1 }
        hasExclusiveOperation = false
        isProfileSwitchPending = false
    }

    func enterUnavailable() {
        isUnavailable = true
        hasExclusiveOperation = false
        isProfileSwitchPending = false
    }

    fileprivate func update(_ lease: DevelopmentDatabaseActivityLease) {
        guard leases[lease.id] != nil else { return }
        leases[lease.id] = lease.activity
    }

    fileprivate func observeTransitionForTesting(_ activity: DevelopmentDatabaseActivity) async {
        await transitionObserverForTesting?(activity)
    }

    func setTransitionObserverForTesting(
        _ observer: (@MainActor (DevelopmentDatabaseActivity) async -> Void)?
    ) {
        transitionObserverForTesting = observer
    }

    fileprivate func finish(_ lease: DevelopmentDatabaseActivityLease) {
        leases.removeValue(forKey: lease.id)
    }

    func resetForTesting() {
        leases.removeAll()
        hasExclusiveOperation = false
        isProfileSwitchPending = false
        isUnavailable = false
        generation = 1
        transitionObserverForTesting = nil
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
    case committedCleanupFailed
    case resetNotPermitted
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
        case .committedCleanupFailed: return "committed-cleanup-failed"
        case .resetNotPermitted: return "reset-not-permitted"
        case .lifecycleUnavailable: return "lifecycle-unavailable"
        }
    }
}

enum DevelopmentDatabaseLifecycleFailurePoint: nonisolated Hashable {
    case backupCreation
    case backupVerification
    case providerQuiescence
    case recreation
    case migration
    case providerInstallation
    case hydration
    case recovery
    case priorCleanup
}

private enum DevelopmentDatabaseCandidatePreparationError: Error {
    case creation
    case migration
    case hydration
    case publication
}

@MainActor
private struct DevelopmentDatabasePreparedCandidate {
    let target: DevelopmentDatabaseProfileTarget
    let sqliteProvider: SQLiteRepositoryProvider
    let runtimeProvider: DatabaseProvider
    let hydrator: RepositoryStoreHydrator
    let snapshot: RepositoryRuntimeSnapshot
    let verifiedSchemaVersion: Int
}

@MainActor
final class DevelopmentDatabaseLifecycleCoordinator: ObservableObject {
    static let shared = DevelopmentDatabaseLifecycleCoordinator(identity: .applicationOwned())

    let identity: DevelopmentDatabaseIdentity
    @Published private(set) var isOperationInProgress = false
    @Published private(set) var isUnavailable = false
    @ObserverAtomicPublished private(set) var activeProfile: DevelopmentDatabaseProfileDescriptor?
    @ObserverAtomicPublished private(set) var runtimePublicationEpoch: UInt64 = 0
    @Published private(set) var rememberedDevelopmentProfile: RememberedDevelopmentDatabaseProfile = .persistentDebug
    @Published private(set) var rememberedMigrationSourceVersion = DevelopmentDatabaseProfile.defaultHistoricalSourceVersion
    private(set) var currentDatabaseURL: URL?
    private(set) var committedRuntimeState: DevelopmentDatabaseCommittedRuntimeState?

    private var sqliteProvider: SQLiteRepositoryProvider?
    private var activeTarget: DevelopmentDatabaseProfileTarget?
    private var retainedInactiveProviders: [(SQLiteRepositoryProvider, DevelopmentDatabaseProfileTarget?)] = []
    private let activityGate: DevelopmentDatabaseActivityGate
    private let injectedFailures: Set<DevelopmentDatabaseLifecycleFailurePoint>
    private let preparedImportInvalidator: @MainActor (DevelopmentDatabasePreparedImportDrainPermit) -> DevelopmentPreparedImportInvalidationResult
    private let makeOwnershipID: () -> UUID
    private let migrationSandboxPrefixObserver: @MainActor ([Int]) -> Void

    convenience init(identity: DevelopmentDatabaseIdentity) {
        self.init(identity: identity, activityGate: .shared, injectedFailures: [])
    }

    convenience init(identity: DevelopmentDatabaseIdentity, activityGate: DevelopmentDatabaseActivityGate) {
        self.init(identity: identity, activityGate: activityGate, injectedFailures: [])
    }

    init(
        identity: DevelopmentDatabaseIdentity,
        activityGate: DevelopmentDatabaseActivityGate,
        injectedFailures: Set<DevelopmentDatabaseLifecycleFailurePoint>,
        preparedImportInvalidator: @escaping @MainActor (DevelopmentDatabasePreparedImportDrainPermit) -> DevelopmentPreparedImportInvalidationResult = {
            ImportEngine.shared.invalidatePreparedImportsForProfileSwitch($0)
        },
        makeOwnershipID: @escaping () -> UUID = UUID.init,
        migrationSandboxPrefixObserver: @escaping @MainActor ([Int]) -> Void = { _ in }
    ) {
        self.identity = identity
        self.activityGate = activityGate
        self.injectedFailures = injectedFailures
        self.preparedImportInvalidator = preparedImportInvalidator
        self.makeOwnershipID = makeOwnershipID
        self.migrationSandboxPrefixObserver = migrationSandboxPrefixObserver
    }

    func loadRememberedSelection(from preferences: DevelopmentDatabaseProfilePreferenceAuthority) {
        rememberedDevelopmentProfile = preferences.rememberedDevelopmentProfile
        rememberedMigrationSourceVersion = preferences.rememberedMigrationSourceVersion
    }

    /// Performs the nonthrowing observer-atomic portion of a lifecycle commit.
    /// Candidate creation, migration verification, and staged hydration must all
    /// complete before this method is entered.
    @discardableResult
    private func installCommittedRuntime(
        sqliteProvider: SQLiteRepositoryProvider,
        runtimeProvider: DatabaseProvider,
        target: DevelopmentDatabaseProfileTarget,
        hydrator: RepositoryStoreHydrator,
        snapshot: RepositoryRuntimeSnapshot,
        verifiedSchemaVersion: Int
    ) -> DevelopmentDatabaseProfileDescriptor {
        precondition(snapshot.providerGeneration == runtimeProvider.generationToken)
        precondition(runtimePublicationEpoch < UInt64.max)

        let descriptor = target.profile.descriptor(
            verifiedCurrentSchemaVersion: verifiedSchemaVersion
        )
        let nextEpoch = runtimePublicationEpoch + 1

        // Phase A: no publisher or ObservableObject notification is emitted.
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = runtimeProvider
        hydrator.installSnapshotWithoutObservation(snapshot)
        self.sqliteProvider = sqliteProvider
        activeTarget = target
        currentDatabaseURL = target.databaseURL
        _activeProfile.installWithoutObservation(descriptor)
        committedRuntimeState = DevelopmentDatabaseCommittedRuntimeState(
            publicationEpoch: nextEpoch,
            providerGeneration: runtimeProvider.generationToken,
            activeProfile: descriptor,
            runtimeSnapshot: snapshot
        )
        DevelopmentProfileAcknowledgementGate.shared.noteCommittedGenerationChange()
        _runtimePublicationEpoch.installWithoutObservation(nextEpoch)

        // Phase B: the committed epoch is the first runtime-state signal. All
        // legacy callbacks that follow already read the same complete state.
        _runtimePublicationEpoch.publishInstalledValue()
        objectWillChange.send()
        _activeProfile.publishInstalledValue()
        hydrator.notifyObserversOfInstalledSnapshot()
        return descriptor
    }

    private func clearCommittedRuntimeForTermination() {
        committedRuntimeState = nil
        DevelopmentProfileAcknowledgementGate.shared.noteCommittedGenerationChange()
        _activeProfile.installWithoutObservation(nil)
        objectWillChange.send()
        _activeProfile.publishInstalledValue()
    }

    /// Transfers the already-open startup provider to the sole Debug lifecycle
    /// owner. Ordinary app bootstrap accepts only Current's exact identity.
    @discardableResult
    func installInitialProvider(
        _ provider: SQLiteRepositoryProvider,
        allowsTaskOwnedTestPath: Bool = false
    ) throws -> RepositoryStoreHydrationResult {
        guard sqliteProvider == nil, activeTarget == nil else {
            throw DevelopmentDatabaseProfileIdentityError.invalidProfile
        }

        let profile = try DevelopmentDatabaseProfile.resolve(.current, makeOwnershipID: makeOwnershipID)
        let target = try identity.target(for: profile)
        let providerURL = URL(fileURLWithPath: provider.databasePath).standardizedFileURL
        guard allowsTaskOwnedTestPath || (
            providerURL == target.databaseURL.standardizedFileURL
                && identity.authorizesCurrentDatabaseIdentity(at: providerURL)
        ) else {
            try? provider.database.checkpointAndClose()
            throw DevelopmentDatabaseProfileIdentityError.invalidProfile
        }

        do {
            let version = try validateCompleteMigrationChain(in: provider)
            let runtimeProvider = makeRuntimeProvider(for: provider, profile: profile)
            let hydrator = RepositoryStoreHydrator(
                databaseProvider: runtimeProvider,
                participatesInLifecycleGate: false
            )
            let snapshot = try hydrator.stageHydration()

            installCommittedRuntime(
                sqliteProvider: provider,
                runtimeProvider: runtimeProvider,
                target: DevelopmentDatabaseProfileTarget(
                    profile: profile,
                    databaseURL: providerURL
                ),
                hydrator: hydrator,
                snapshot: snapshot,
                verifiedSchemaVersion: version
            )
            return snapshot.hydrationResult
        } catch {
            try? provider.database.checkpointAndClose()
            throw error
        }
    }

    func activate(
        _ selection: DevelopmentDatabaseProfileSelection
    ) -> DevelopmentDatabaseProfileActivationResult {
        guard !isUnavailable else { return .lifecycleUnavailable }

        let profile: DevelopmentDatabaseProfile
        do {
            profile = try DevelopmentDatabaseProfile.resolve(selection, makeOwnershipID: makeOwnershipID)
        } catch DevelopmentDatabaseProfileDomainError.invalidMigrationSourceVersion {
            return .invalidMigrationSourceVersion
        } catch {
            return .invalidProfile
        }

        let target: DevelopmentDatabaseProfileTarget
        do {
            target = try identity.target(for: profile)
        } catch {
            return .invalidProfile
        }

        if (profile.kind == .current || profile.kind == .persistentDebug),
           activeTarget?.profile.kind == profile.kind,
           let activeProfile {
            return .alreadyActive(activeProfile)
        }

        let barrier = activityGate.beginProfileSwitch(drainPreparedImports: preparedImportInvalidator)
        let preparedInvalidation: DevelopmentPreparedImportInvalidationResult
        switch barrier {
        case .acquired(let invalidation):
            preparedInvalidation = invalidation
        case .activityBlocked:
            return .activityBlocked
        case .lifecycleUnavailable:
            return .lifecycleUnavailable
        }

        isOperationInProgress = true
        var providerChanged = false
        defer {
            isOperationInProgress = false
            activityGate.finishExclusive(providerChanged: providerChanged)
        }

        let candidate: DevelopmentDatabasePreparedCandidate
        do {
            candidate = try prepareCandidate(target: target)
        } catch let failure as DevelopmentDatabaseCandidatePreparationError {
            return activationResult(for: failure)
        } catch {
            return .candidateCreationFailed
        }

        let priorProvider = sqliteProvider
        let priorTarget = activeTarget

        let descriptor = installCommittedRuntime(
            sqliteProvider: candidate.sqliteProvider,
            runtimeProvider: candidate.runtimeProvider,
            target: candidate.target,
            hydrator: candidate.hydrator,
            snapshot: candidate.snapshot,
            verifiedSchemaVersion: candidate.verifiedSchemaVersion
        )
        providerChanged = true

        let activation = DevelopmentDatabaseProfileActivation(
            profile: descriptor,
            hydration: candidate.snapshot.hydrationResult,
            preparedImportInvalidation: preparedInvalidation
        )

        do {
            try closeAndCleanPriorProvider(priorProvider, target: priorTarget)
            return .activated(activation)
        } catch {
            return .committedButPriorCleanupFailed(activation)
        }
    }

    func resetActiveProfile(
        migrationSandboxSourceVersion: Int? = nil
    ) -> DevelopmentDatabaseProfileActivationResult {
        guard !isUnavailable, let activeTarget else { return .lifecycleUnavailable }
        switch activeTarget.profile.kind {
        case .current:
            return .resetNotPermitted
        case .persistentDebug:
            return resetPersistentDebugProfile()
        case .temporarySession:
            return activate(.temporarySession)
        case .migrationSandbox:
            guard let sourceVersion = migrationSandboxSourceVersion
                    ?? activeTarget.profile.migrationSourceVersion else {
                return .invalidProfile
            }
            return activate(.migrationSandbox(sourceVersion: sourceVersion))
        }
    }

    /// Compatibility adapter for the existing Debug command surface. Packet A
    /// adds no UI and Current now correctly rejects reset.
    func startTemporaryEmptySession() -> DevelopmentDatabaseLifecycleResult {
        switch activate(.temporarySession) {
        case .activated(let activation):
            return .temporarySessionStarted(activation.hydration)
        case .committedButPriorCleanupFailed:
            return .committedCleanupFailed
        case .activityBlocked:
            return .rejectedActivityInProgress
        case .invalidProfile, .invalidMigrationSourceVersion, .resetNotPermitted:
            return .rejectedUnsafeIdentity
        case .candidateCreationFailed:
            return .recreationFailed
        case .migrationFailed:
            return .migrationFailed
        case .stagedHydrationFailed:
            return .hydrationFailedRecoverySucceeded
        case .publicationFailedBeforeCommit:
            return .providerInstallationFailed
        case .lifecycleUnavailable:
            return .lifecycleUnavailable
        case .alreadyActive:
            return .rejectedUnsafeIdentity
        }
    }

    func resetDevelopmentDatabase() -> DevelopmentDatabaseLifecycleResult {
        switch resetActiveProfile() {
        case .activated(let activation):
            return .permanentResetCompleted(activation.hydration)
        case .committedButPriorCleanupFailed:
            return .committedCleanupFailed
        case .resetNotPermitted, .invalidProfile, .invalidMigrationSourceVersion, .alreadyActive:
            return .resetNotPermitted
        case .activityBlocked:
            return .rejectedActivityInProgress
        case .candidateCreationFailed:
            return .recreationFailed
        case .migrationFailed:
            return .migrationFailed
        case .stagedHydrationFailed:
            return .hydrationFailedRecoverySucceeded
        case .publicationFailedBeforeCommit:
            return .providerInstallationFailed
        case .lifecycleUnavailable:
            return .lifecycleUnavailable
        }
    }

    /// Releases every SQLite handle still owned by this coordinator. Only an
    /// exactly owned Temporary/Sandbox set is eligible for termination cleanup.
    func closeOwnedProvider(removeProcessOwnedProfile: Bool = true) {
        let activeProvider = sqliteProvider
        let closingTarget = activeTarget

        if let activeProvider,
           DatabaseProvider.shared.generationToken == activeProvider.generationToken {
            DatabaseProvider.shared.invalidateGeneration()
            DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        }

        sqliteProvider = nil
        activeTarget = nil
        currentDatabaseURL = nil
        clearCommittedRuntimeForTermination()

        if let activeProvider {
            closeForTermination(
                activeProvider,
                target: closingTarget,
                removeProcessOwnedProfile: removeProcessOwnedProfile
            )
        }

        let inactive = retainedInactiveProviders
        retainedInactiveProviders.removeAll()
        for (provider, target) in inactive {
            closeForTermination(
                provider,
                target: target,
                removeProcessOwnedProfile: removeProcessOwnedProfile
            )
        }
    }

    private func prepareCandidate(
        target: DevelopmentDatabaseProfileTarget
    ) throws -> DevelopmentDatabasePreparedCandidate {
        var provider: SQLiteRepositoryProvider?
        do {
            let hasAuthorizedIdentity: Bool
            switch target.profile.kind {
            case .current:
                hasAuthorizedIdentity = identity.authorizesCurrentDatabaseIdentity(at: target.databaseURL)
            case .persistentDebug:
                hasAuthorizedIdentity = identity.authorizesPersistentDebugReset(at: target.databaseURL)
            case .temporarySession, .migrationSandbox:
                hasAuthorizedIdentity = identity.authorizesCleanup(of: target)
            }
            guard hasAuthorizedIdentity else {
                throw DevelopmentDatabaseCandidatePreparationError.creation
            }

            try FileManager.default.createDirectory(
                at: target.databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if target.isCleanupOwned {
                guard identity.databaseSet(at: target.databaseURL).allSatisfy({
                          !FileManager.default.fileExists(atPath: $0.path)
                      }) else {
                    throw DevelopmentDatabaseCandidatePreparationError.creation
                }
            }
            if injectedFailures.contains(.recreation) {
                throw DevelopmentDatabaseCandidatePreparationError.creation
            }

            if target.profile.kind == .migrationSandbox {
                do {
                    try createMigrationSandboxPrefix(target: target)
                } catch {
                    throw DevelopmentDatabaseCandidatePreparationError.migration
                }
            }

            if injectedFailures.contains(.migration) {
                throw DevelopmentDatabaseCandidatePreparationError.migration
            }

            do {
                provider = try SQLiteRepositoryProvider(path: target.databaseURL.path)
            } catch SQLiteRepositoryProviderError.databaseOpenFailed {
                throw DevelopmentDatabaseCandidatePreparationError.creation
            } catch {
                throw DevelopmentDatabaseCandidatePreparationError.migration
            }
            guard let provider else {
                throw DevelopmentDatabaseCandidatePreparationError.creation
            }

            let version: Int
            do {
                version = try validateCompleteMigrationChain(in: provider)
            } catch {
                throw DevelopmentDatabaseCandidatePreparationError.migration
            }

            let runtimeProvider = makeRuntimeProvider(for: provider, profile: target.profile)
            let hydrator = RepositoryStoreHydrator(
                databaseProvider: runtimeProvider,
                participatesInLifecycleGate: false
            )
            let snapshot: RepositoryRuntimeSnapshot
            do {
                if injectedFailures.contains(.hydration) {
                    throw DevelopmentDatabaseCandidatePreparationError.hydration
                }
                snapshot = try hydrator.stageHydration()
            } catch {
                throw DevelopmentDatabaseCandidatePreparationError.hydration
            }

            if injectedFailures.contains(.providerInstallation) {
                throw DevelopmentDatabaseCandidatePreparationError.publication
            }

            return DevelopmentDatabasePreparedCandidate(
                target: target,
                sqliteProvider: provider,
                runtimeProvider: runtimeProvider,
                hydrator: hydrator,
                snapshot: snapshot,
                verifiedSchemaVersion: version
            )
        } catch {
            cleanupFailedCandidate(provider, target: target)
            throw error
        }
    }

    private func createMigrationSandboxPrefix(
        target: DevelopmentDatabaseProfileTarget
    ) throws {
        guard target.profile.kind == .migrationSandbox,
              let sourceVersion = target.profile.migrationSourceVersion,
              DevelopmentDatabaseProfile.registeredHistoricalSourceVersions.contains(sourceVersion) else {
            throw DevelopmentDatabaseProfileDomainError.invalidMigrationSourceVersion
        }

        let prefix = Array(allMigrations.prefix(sourceVersion))
        guard prefix.map(\.version) == Array(1...sourceVersion) else {
            throw MigrationIntegrityError.missingRegisteredVersion(sourceVersion)
        }

        let creator = SQLiteDatabase(path: target.databaseURL.path)
        var checkedClosed = false
        defer {
            if !checkedClosed {
                creator.close()
            }
        }
        try creator.runMigrations(prefix)
        let records = try creator.validatedMigrationHistory(
            against: prefix,
            requiresCompleteChain: true
        )
        guard records.compactMap(\.version) == prefix.map(\.version),
              records.count == prefix.count,
              try creator.queryInt("SELECT MAX(version) FROM schema_migrations;") == sourceVersion else {
            throw MigrationIntegrityError.missingPersistedVersion(sourceVersion)
        }
        migrationSandboxPrefixObserver(records.compactMap(\.version))
        try creator.checkpointAndClose()
        checkedClosed = true
    }

    private func resetPersistentDebugProfile() -> DevelopmentDatabaseProfileActivationResult {
        guard let oldTarget = activeTarget,
              oldTarget.profile.kind == .persistentDebug,
              identity.authorizesPersistentDebugReset(at: oldTarget.databaseURL),
              let oldProvider = sqliteProvider else {
            return .resetNotPermitted
        }

        let barrier = activityGate.beginProfileSwitch(drainPreparedImports: preparedImportInvalidator)
        let preparedInvalidation: DevelopmentPreparedImportInvalidationResult
        switch barrier {
        case .acquired(let invalidation):
            preparedInvalidation = invalidation
        case .activityBlocked:
            return .activityBlocked
        case .lifecycleUnavailable:
            return .lifecycleUnavailable
        }

        isOperationInProgress = true
        var providerChanged = false
        defer {
            isOperationInProgress = false
            activityGate.finishExclusive(providerChanged: providerChanged)
        }

        do {
            try createAndVerifyBackup(from: oldProvider)
        } catch {
            return .candidateCreationFailed
        }

        do {
            if injectedFailures.contains(.providerQuiescence) {
                throw SQLiteDatabaseError.backupFailed("injected-provider-quiescence")
            }
            try oldProvider.database.checkpointAndClose()
        } catch {
            return .publicationFailedBeforeCommit
        }
        sqliteProvider = nil

        do {
            try removeDatabaseSet(at: oldTarget.databaseURL)
            let candidate = try prepareCandidate(target: oldTarget)

            let descriptor = installCommittedRuntime(
                sqliteProvider: candidate.sqliteProvider,
                runtimeProvider: candidate.runtimeProvider,
                target: candidate.target,
                hydrator: candidate.hydrator,
                snapshot: candidate.snapshot,
                verifiedSchemaVersion: candidate.verifiedSchemaVersion
            )
            providerChanged = true

            return .activated(
                DevelopmentDatabaseProfileActivation(
                    profile: descriptor,
                    hydration: candidate.snapshot.hydrationResult,
                    preparedImportInvalidation: preparedInvalidation
                )
            )
        } catch let failure as DevelopmentDatabaseCandidatePreparationError {
            guard restorePersistentDebugBackup(target: oldTarget) else {
                enterLifecycleUnavailable()
                return .lifecycleUnavailable
            }
            providerChanged = true
            return activationResult(for: failure)
        } catch {
            guard restorePersistentDebugBackup(target: oldTarget) else {
                enterLifecycleUnavailable()
                return .lifecycleUnavailable
            }
            providerChanged = true
            return .candidateCreationFailed
        }
    }

    private func restorePersistentDebugBackup(
        target: DevelopmentDatabaseProfileTarget
    ) -> Bool {
        do {
            guard identity.authorizesPersistentDebugReset(at: target.databaseURL),
                  identity.authorizesLifecycleBackup(at: identity.backupURL) else {
                return false
            }
            if injectedFailures.contains(.recovery) {
                throw SQLiteDatabaseError.backupFailed("injected-recovery")
            }
            try removeDatabaseSet(at: target.databaseURL)
            try FileManager.default.copyItem(at: identity.backupURL, to: target.databaseURL)
            let restored = try SQLiteRepositoryProvider(path: target.databaseURL.path)
            let version = try validateCompleteMigrationChain(in: restored)
            let runtimeProvider = makeRuntimeProvider(for: restored, profile: target.profile)
            let hydrator = RepositoryStoreHydrator(
                databaseProvider: runtimeProvider,
                participatesInLifecycleGate: false
            )
            let snapshot = try hydrator.stageHydration()

            installCommittedRuntime(
                sqliteProvider: restored,
                runtimeProvider: runtimeProvider,
                target: target,
                hydrator: hydrator,
                snapshot: snapshot,
                verifiedSchemaVersion: version
            )
            return true
        } catch {
            return false
        }
    }

    private func validateCompleteMigrationChain(
        in provider: SQLiteRepositoryProvider
    ) throws -> Int {
        let records = try provider.database.validatedMigrationHistory(
            against: allMigrations,
            requiresCompleteChain: true
        )
        let expectedVersions = allMigrations.map(\.version)
        guard records.compactMap(\.version) == expectedVersions,
              records.count == expectedVersions.count,
              let expectedVersion = expectedVersions.last,
              try provider.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == expectedVersion else {
            throw MigrationIntegrityError.missingPersistedVersion(
                expectedVersions.last ?? 1
            )
        }
        return expectedVersion
    }

    private func makeRuntimeProvider(
        for provider: SQLiteRepositoryProvider,
        profile: DevelopmentDatabaseProfile
    ) -> DatabaseProvider {
        let state: PersistenceState
        switch profile.kind {
        case .current, .persistentDebug:
            state = .verifiedSQLite
        case .temporarySession:
            state = .intentionalNonDurable(.debugTemporarySQLite)
        case .migrationSandbox:
            state = .intentionalNonDurable(.debugMigrationSandboxSQLite)
        }

        return DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            accountRepo: provider.accountRepo,
            cardRepo: provider.cardRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken,
            persistenceState: state,
            protectsGeneration: true
        )
    }

    private func activationResult(
        for failure: DevelopmentDatabaseCandidatePreparationError
    ) -> DevelopmentDatabaseProfileActivationResult {
        switch failure {
        case .creation: return .candidateCreationFailed
        case .migration: return .migrationFailed
        case .hydration: return .stagedHydrationFailed
        case .publication: return .publicationFailedBeforeCommit
        }
    }

    private func closeAndCleanPriorProvider(
        _ provider: SQLiteRepositoryProvider?,
        target: DevelopmentDatabaseProfileTarget?
    ) throws {
        guard let provider else { return }

        if injectedFailures.contains(.priorCleanup) {
            retainedInactiveProviders.append((provider, target))
            throw SQLiteDatabaseError.backupFailed("injected-prior-cleanup")
        }

        do {
            try provider.database.checkpointAndClose()
        } catch {
            retainedInactiveProviders.append((provider, target))
            throw error
        }

        guard let target, target.isCleanupOwned else { return }
        guard identity.authorizesCleanup(of: target) else {
            throw DevelopmentDatabaseProfileIdentityError.invalidProfile
        }
        try removeDatabaseSet(at: target.databaseURL)
    }

    private func cleanupFailedCandidate(
        _ provider: SQLiteRepositoryProvider?,
        target: DevelopmentDatabaseProfileTarget
    ) {
        var safelyClosed = provider == nil
        if let provider {
            do {
                try provider.database.checkpointAndClose()
                safelyClosed = true
            } catch {
                retainedInactiveProviders.append((provider, target))
            }
        }
        guard safelyClosed, target.isCleanupOwned, identity.authorizesCleanup(of: target) else {
            return
        }
        try? removeDatabaseSet(at: target.databaseURL)
    }

    private func closeForTermination(
        _ provider: SQLiteRepositoryProvider,
        target: DevelopmentDatabaseProfileTarget?,
        removeProcessOwnedProfile: Bool
    ) {
        do {
            try provider.database.checkpointAndClose()
        } catch {
            return
        }
        guard removeProcessOwnedProfile,
              let target,
              target.isCleanupOwned,
              identity.authorizesCleanup(of: target) else {
            return
        }
        try? removeDatabaseSet(at: target.databaseURL)
    }

    private func createAndVerifyBackup(
        from provider: SQLiteRepositoryProvider
    ) throws {
        guard identity.authorizesLifecycleBackup(at: identity.backupURL) else {
            throw DevelopmentDatabaseProfileIdentityError.invalidProfile
        }
        if injectedFailures.contains(.backupCreation) {
            throw SQLiteDatabaseError.backupFailed("injected-backup-creation")
        }
        try FileManager.default.createDirectory(
            at: identity.backupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try removeDatabaseSet(at: identity.backupURL)
        try provider.database.createBackup(at: identity.backupURL.path)
        if injectedFailures.contains(.backupVerification) {
            throw SQLiteDatabaseError.backupFailed("injected-backup-verification")
        }

        let verification = SQLiteDatabase(path: identity.backupURL.path)
        var checkedClosed = false
        defer {
            if !checkedClosed {
                verification.close()
            }
        }
        try verification.open()
        let records = try verification.validatedMigrationHistory(
            against: allMigrations,
            requiresCompleteChain: true
        )
        guard records.compactMap(\.version) == allMigrations.map(\.version) else {
            throw SQLiteDatabaseError.backupFailed("migration-history")
        }
        try validateIdentifierOwnershipV5Schema(verification)
        let requiredTables = [
            "accounts",
            "transactions",
            "import_sessions",
            "import_attempts",
            "account_identifiers",
            "account_identifier_observations"
        ]
        for table in requiredTables {
            guard try verification.queryInt(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = '\(table)';"
            ) == 1 else {
                throw SQLiteDatabaseError.backupFailed("schema")
            }
        }
        try verification.checkpointAndClose()
        checkedClosed = true
    }

    private func enterLifecycleUnavailable() {
        isUnavailable = true
        sqliteProvider = nil
        activeTarget = nil
        currentDatabaseURL = nil
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .lifecycleUnavailable)
        clearCommittedRuntimeForTermination()
        activityGate.enterUnavailable()
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
        let sql = """
        INSERT INTO workspaces (id, name, created_at, updated_at) VALUES (?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at;
        """
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

fileprivate final class SQLiteCategoryRepo: CategoryRepository {
    private let db: SQLiteDatabase

    init(db: SQLiteDatabase) {
        self.db = db
    }

    func categories(workspaceId: String) throws -> [CategoryDTO] {
        try db.query(
            sql: "SELECT id, workspace_id, name, normalized_name, is_archived, created_at, updated_at FROM categories WHERE workspace_id = ? ORDER BY normalized_name ASC, id ASC;",
            params: [workspaceId]
        ) { row in
            CategoryDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                name: row.string(at: 2) ?? "",
                normalizedName: row.string(at: 3) ?? "",
                isArchived: row.bool(at: 4),
                createdAtISO: row.string(at: 5) ?? "",
                updatedAtISO: row.string(at: 6)
            )
        }
    }

    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] {
        try db.query(
            sql: "SELECT workspace_id, transaction_id, category_id FROM transaction_category_assignments WHERE workspace_id = ? ORDER BY transaction_id ASC;",
            params: [workspaceId]
        ) { row in
            TransactionCategoryAssignmentDTO(
                workspaceId: row.string(at: 0) ?? "",
                transactionId: row.string(at: 1) ?? "",
                categoryId: row.string(at: 2) ?? ""
            )
        }
    }

    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO {
        let validated = try CategoryName.validated(category.name)
        guard category.normalizedName == validated.normalized else {
            throw CategoryRepositoryError.invalidName
        }
        return try withImmediateTransaction {
            guard try count(
                "SELECT COUNT(*) FROM workspaces WHERE id = ?;",
                [category.workspaceId]
            ) == 1 else {
                throw CategoryRepositoryError.workspaceMismatch
            }
            guard try count(
                "SELECT COUNT(*) FROM categories WHERE workspace_id = ? AND normalized_name = ?;",
                [category.workspaceId, validated.normalized]
            ) == 0 else {
                throw CategoryRepositoryError.duplicateName
            }
            guard try count("SELECT COUNT(*) FROM categories WHERE id = ?;", [category.id]) == 0 else {
                throw CategoryRepositoryError.duplicateName
            }
            try db.executePrepared(
                sql: "INSERT INTO categories(id, workspace_id, name, normalized_name, is_archived, created_at, updated_at) VALUES(?,?,?,?,?,?,?);",
                params: [
                    category.id,
                    category.workspaceId,
                    validated.display,
                    validated.normalized,
                    category.isArchived ? 1 : 0,
                    category.createdAtISO,
                    category.updatedAtISO ?? NSNull()
                ]
            )
            return CategoryDTO(
                id: category.id,
                workspaceId: category.workspaceId,
                name: validated.display,
                normalizedName: validated.normalized,
                isArchived: category.isArchived,
                createdAtISO: category.createdAtISO,
                updatedAtISO: category.updatedAtISO
            )
        }
    }

    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool {
        let validated = try CategoryName.validated(name)
        return try withImmediateTransaction {
            guard let existing = try category(id: id) else {
                throw CategoryRepositoryError.categoryNotFound
            }
            guard existing.workspaceId == workspaceId else {
                throw CategoryRepositoryError.workspaceMismatch
            }
            guard try count(
                "SELECT COUNT(*) FROM categories WHERE workspace_id = ? AND normalized_name = ? AND id <> ?;",
                [workspaceId, validated.normalized, id]
            ) == 0 else {
                throw CategoryRepositoryError.duplicateName
            }
            guard existing.name != validated.display || existing.normalizedName != validated.normalized else {
                return false
            }
            try db.executePrepared(
                sql: "UPDATE categories SET name = ?, normalized_name = ?, updated_at = ? WHERE id = ? AND workspace_id = ?;",
                params: [validated.display, validated.normalized, updatedAtISO, id, workspaceId]
            )
            return true
        }
    }

    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool {
        try withImmediateTransaction {
            guard let existing = try category(id: id) else {
                throw CategoryRepositoryError.categoryNotFound
            }
            guard existing.workspaceId == workspaceId else {
                throw CategoryRepositoryError.workspaceMismatch
            }
            guard existing.isArchived != isArchived else { return false }
            try db.executePrepared(
                sql: "UPDATE categories SET is_archived = ?, updated_at = ? WHERE id = ? AND workspace_id = ?;",
                params: [isArchived ? 1 : 0, updatedAtISO, id, workspaceId]
            )
            return true
        }
    }

    func deleteUnusedCategory(id: String, workspaceId: String) throws {
        try withImmediateTransaction {
            guard let existing = try category(id: id) else {
                throw CategoryRepositoryError.categoryNotFound
            }
            guard existing.workspaceId == workspaceId else {
                throw CategoryRepositoryError.workspaceMismatch
            }
            guard try count(
                "SELECT COUNT(*) FROM transaction_category_assignments WHERE workspace_id = ? AND category_id = ?;",
                [workspaceId, id]
            ) == 0 else {
                throw CategoryRepositoryError.categoryInUse
            }
            try db.executePrepared(
                sql: "DELETE FROM categories WHERE id = ? AND workspace_id = ?;",
                params: [id, workspaceId]
            )
        }
    }

    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool {
        try withImmediateTransaction {
            guard try count(
                "SELECT COUNT(*) FROM transactions WHERE id = ? AND workspace_id = ? AND is_trusted = 1;",
                [transactionId, workspaceId]
            ) == 1 else {
                if try count("SELECT COUNT(*) FROM transactions WHERE id = ?;", [transactionId]) == 0 {
                    throw CategoryRepositoryError.transactionNotFound
                }
                throw CategoryRepositoryError.workspaceMismatch
            }

            let existingCategoryID = try db.query(
                sql: "SELECT category_id FROM transaction_category_assignments WHERE transaction_id = ?;",
                params: [transactionId]
            ) { $0.string(at: 0) ?? "" }.first

            guard let categoryId else {
                guard existingCategoryID != nil else { return false }
                try db.executePrepared(
                    sql: "DELETE FROM transaction_category_assignments WHERE transaction_id = ? AND workspace_id = ?;",
                    params: [transactionId, workspaceId]
                )
                return true
            }

            guard let selectedCategory = try category(id: categoryId) else {
                throw CategoryRepositoryError.categoryNotFound
            }
            guard selectedCategory.workspaceId == workspaceId else {
                throw CategoryRepositoryError.workspaceMismatch
            }
            guard !selectedCategory.isArchived else {
                throw CategoryRepositoryError.categoryArchived
            }
            guard existingCategoryID != categoryId else { return false }
            try db.executePrepared(
                sql: """
                INSERT INTO transaction_category_assignments(workspace_id, transaction_id, category_id)
                VALUES(?,?,?)
                ON CONFLICT(transaction_id) DO UPDATE SET
                  workspace_id = excluded.workspace_id,
                  category_id = excluded.category_id;
                """,
                params: [workspaceId, transactionId, categoryId]
            )
            return true
        }
    }

    private func category(id: String) throws -> CategoryDTO? {
        try db.query(
            sql: "SELECT id, workspace_id, name, normalized_name, is_archived, created_at, updated_at FROM categories WHERE id = ?;",
            params: [id]
        ) { row in
            CategoryDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                name: row.string(at: 2) ?? "",
                normalizedName: row.string(at: 3) ?? "",
                isArchived: row.bool(at: 4),
                createdAtISO: row.string(at: 5) ?? "",
                updatedAtISO: row.string(at: 6)
            )
        }.first
    }

    private func count(_ sql: String, _ params: [Any?]) throws -> Int {
        Int(try db.query(sql: sql, params: params) { $0.int64(at: 0) ?? 0 }.first ?? 0)
    }

    private func withImmediateTransaction<T>(_ body: () throws -> T) throws -> T {
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            let value = try body()
            try db.execute(sql: "COMMIT;")
            return value
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            throw error
        }
    }
}

fileprivate final class SQLiteAccountRepo: AccountRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        try ensureInstitutionExists(id: account.institutionId, createdAtISO: account.createdAtISO)

        let now = account.createdAtISO
        let sql = """
        INSERT INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at)
        VALUES (?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
            workspace_id = excluded.workspace_id,
            name = excluded.name,
            institution_id = excluded.institution_id,
            account_type = excluded.account_type,
            native_currency = excluded.native_currency,
            description = excluded.description,
            created_at = excluded.created_at;
        """
        try db.executePrepared(sql: sql, params: [account.id, account.workspaceId, account.name, account.institutionId ?? NSNull(), account.accountType ?? NSNull(), account.nativeCurrency, account.description ?? NSNull(), now])
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
                    "scheme": Self.diagnosticSchemeClassification(identifier.scheme),
                    "identifier": "[redacted]"
                ])
                return current.id
            }

            let insert = "INSERT INTO account_identifiers (id, account_id, workspace_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?,?);"
            try db.executePrepared(sql: insert, params: [
                identifier.id,
                identifier.accountId,
                identifier.workspaceId,
                identifier.scheme,
                identifier.identifier,
                Self.provenanceJSON(for: identifier),
                identifier.createdAtISO
            ])
            try db.execute(sql: "COMMIT;")
            DeveloperConsole.shared.info(.database, "Account identifier attached", metadata: [
                "scheme": Self.diagnosticSchemeClassification(identifier.scheme),
                "identifier": "[redacted]"
            ])
            return identifier.id
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            if case RepositoryError.conflictingAccountIdentifier(_, let scheme, _, _, _) = error {
                DeveloperConsole.shared.warning(.database, "Conflicting account identifier rejected", metadata: [
                    "scheme": Self.diagnosticSchemeClassification(scheme),
                    "identifier": "[redacted]"
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

    func cbqSourceIdentityRecords(workspaceId: String) throws -> [CBQSourceIdentityRecordDTO] {
        try db.query(
            sql: "SELECT account_id, kind, pattern FROM cbq_source_identity_observations WHERE workspace_id = ? ORDER BY account_id, kind, pattern;",
            params: [workspaceId]
        ) { row in
            CBQSourceIdentityRecordDTO(
                accountId: row.string(at: 0) ?? "",
                kind: row.string(at: 1) ?? "",
                pattern: row.string(at: 2) ?? ""
            )
        }
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

    private static func diagnosticSchemeClassification(_ scheme: String) -> String {
        switch scheme {
        case "iban",
             "institution_account_id",
             "broker_account_id",
             "institution_issued_identifier",
             "masked_pan",
             "card_last_four",
             "account_suffix",
             "display_name",
             "filename",
             "institution_label":
            return "Recognized"
        default:
            return "Unknown"
        }
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

    func importedDocument(id: String) throws -> ImportedDocumentDTO? {
        let sql = "SELECT id, workspace_id, import_session_id, filename, mime_type, size_bytes, sha256, created_at FROM documents WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            ImportedDocumentDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                importSessionId: row.string(at: 2) ?? "",
                filename: row.string(at: 3) ?? "",
                mimeType: row.string(at: 4),
                sizeBytes: row.int64(at: 5),
                legacyRawTextSHA256: row.string(at: 6) ?? "",
                createdAtISO: row.string(at: 7) ?? ""
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
                sql: "SELECT id, account_id, transaction_id, document_id, import_session_id FROM transaction_event_identities WHERE algorithm = ? AND digest = ?;",
                params: [key.algorithm, key.digest]
            ) { row in
                TransactionEventIdentityOwnerDTO(eventIdentityId: row.string(at: 0) ?? "", accountId: row.string(at: 1) ?? "", transactionId: row.string(at: 2) ?? "", documentId: row.string(at: 3) ?? "", importSessionId: row.string(at: 4) ?? "")
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
        let columns = try db.query(sql: "PRAGMA table_info(import_attempts);") { $0.string(at: 1) ?? "" }
        let hasV7Counts = columns.contains("source_row_count")
        let countSelection = hasV7Counts
            ? ", source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count"
            : ""
        return try db.query(sql: "SELECT id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id\(countSelection) FROM import_attempts WHERE workspace_id = ? ORDER BY created_at DESC, id DESC;", params: [workspaceId]) { row in
            ImportAttemptDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", createdAtISO: row.string(at: 2) ?? "", outcomeCode: row.string(at: 3) ?? "", coverageCode: row.string(at: 4) ?? "", accountDecisionCode: row.string(at: 5) ?? "", guidanceCode: row.string(at: 6) ?? "", persistenceCode: row.string(at: 7) ?? "", transactionCount: Int(row.int64(at: 8) ?? 0), accountId: row.string(at: 9), importSessionId: row.string(at: 10), documentId: row.string(at: 11), relatedImportSessionId: row.string(at: 12), sourceRowCount: hasV7Counts ? row.int64(at: 13).map(Int.init) : nil, importedTransactionCount: hasV7Counts ? row.int64(at: 14).map(Int.init) : nil, recognizedExistingRowCount: hasV7Counts ? row.int64(at: 15).map(Int.init) : nil, blockedRowCount: hasV7Counts ? row.int64(at: 16).map(Int.init) : nil)
        }
    }

    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? {
        try db.query(sql: "SELECT import_session_id, document_id, plan_digest_algorithm, plan_digest, statement_start_date, statement_end_date, native_currency, source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count, opening_balance_minor, opening_balance_decimal, closing_balance_minor, closing_balance_decimal, created_at FROM partial_import_summaries WHERE import_session_id = ?;", params: [importSessionId]) { row in
            PartialImportSummaryDTO(importSessionId: row.string(at: 0) ?? "", documentId: row.string(at: 1) ?? "", planDigestAlgorithm: row.string(at: 2) ?? "", planDigest: row.string(at: 3) ?? "", statementStartDateISO: row.string(at: 4) ?? "", statementEndDateISO: row.string(at: 5) ?? "", nativeCurrency: row.string(at: 6) ?? "", sourceRowCount: Int(row.int64(at: 7) ?? 0), importedTransactionCount: Int(row.int64(at: 8) ?? 0), recognizedExistingRowCount: Int(row.int64(at: 9) ?? 0), blockedRowCount: Int(row.int64(at: 10) ?? 0), openingBalanceMinor: row.int64(at: 11) ?? 0, openingBalanceDecimal: row.string(at: 12) ?? "", closingBalanceMinor: row.int64(at: 13) ?? 0, closingBalanceDecimal: row.string(at: 14) ?? "", createdAtISO: row.string(at: 15) ?? "")
        }.first
    }

    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] {
        try db.query(sql: "SELECT d.id, d.import_session_id, d.document_id, d.normalized_row_id, d.source_ordinal, d.disposition_code, d.transaction_id, d.transaction_event_identity_id, d.statement_date, d.financial_date_role, d.statement_timezone_evidence, d.native_currency, d.amount_minor, d.amount_decimal, d.direction, d.running_balance_minor, d.created_at, e.transaction_id FROM incoming_row_dispositions d LEFT JOIN transaction_event_identities e ON e.id = d.transaction_event_identity_id WHERE d.import_session_id = ? ORDER BY d.source_ordinal, d.id;", params: [importSessionId]) { row in
            IncomingRowDispositionDTO(id: row.string(at: 0) ?? "", importSessionId: row.string(at: 1) ?? "", documentId: row.string(at: 2) ?? "", normalizedRowId: row.string(at: 3) ?? "", sourceOrdinal: Int(row.int64(at: 4) ?? 0), dispositionCode: row.string(at: 5) ?? "", transactionId: row.string(at: 6) ?? "", transactionEventIdentityId: row.string(at: 7) ?? "", statementDateISO: row.string(at: 8) ?? "", financialDateRole: row.string(at: 9) ?? "", statementTimezoneEvidence: row.string(at: 10) ?? "", nativeCurrency: row.string(at: 11) ?? "", amountMinor: row.int64(at: 12) ?? 0, amountDecimal: row.string(at: 13) ?? "", direction: row.string(at: 14) ?? "", runningBalanceMinor: row.int64(at: 15) ?? 0, createdAtISO: row.string(at: 16) ?? "", eventTransactionId: row.string(at: 17))
        }
    }

    func statementFinancialProjections(workspaceId: String) throws -> [StatementFinancialProjectionRecordDTO] {
        let rows = try db.query(
            sql: "SELECT id, account_id, document_id, import_session_id, algorithm, digest, institution_code, statement_family_code, parser_profile_id, parser_profile_version, source_format_code, statement_start_date, statement_end_date, native_currency, event_count, opening_balance_minor, opening_balance_decimal, debit_count, credit_count, debit_total_minor, debit_total_decimal, credit_total_minor, credit_total_decimal, closing_balance_minor, closing_balance_decimal, created_at FROM statement_financial_projections WHERE workspace_id = ? ORDER BY created_at, id;",
            params: [workspaceId]
        ) { row in
            (
                row.string(at: 0) ?? "", row.string(at: 1) ?? "", row.string(at: 2) ?? "", row.string(at: 3) ?? "",
                row.string(at: 4) ?? "", row.string(at: 5) ?? "", row.string(at: 6) ?? "", row.string(at: 7) ?? "",
                row.string(at: 8) ?? "", row.string(at: 9) ?? "", row.string(at: 10) ?? "", row.string(at: 11) ?? "",
                row.string(at: 12) ?? "", row.string(at: 13) ?? "", Int(row.int64(at: 14) ?? 0), row.int64(at: 15) ?? 0,
                row.string(at: 16) ?? "", Int(row.int64(at: 17) ?? 0), Int(row.int64(at: 18) ?? 0), row.int64(at: 19) ?? 0,
                row.string(at: 20) ?? "", row.int64(at: 21) ?? 0, row.string(at: 22) ?? "", row.int64(at: 23) ?? 0,
                row.string(at: 24) ?? "", row.string(at: 25) ?? ""
            )
        }
        return try rows.map { record in
            let events = try db.query(
                sql: "SELECT id, event_ordinal, statement_date, value_date, direction, signed_amount_minor, signed_amount_decimal, running_balance_minor, running_balance_decimal, reference FROM statement_financial_projection_events WHERE projection_id = ? ORDER BY event_ordinal;",
                params: [record.0]
            ) { row in
                StatementFinancialProjectionEventDTO(
                    id: row.string(at: 0) ?? "", ordinal: Int(row.int64(at: 1) ?? 0),
                    statementDateISO: row.string(at: 2) ?? "", valueDateISO: row.string(at: 3) ?? "",
                    direction: row.string(at: 4) ?? "", signedAmountMinor: row.int64(at: 5) ?? 0,
                    signedAmountDecimal: row.string(at: 6) ?? "", runningBalanceMinor: row.int64(at: 7) ?? 0,
                    runningBalanceDecimal: row.string(at: 8) ?? "", reference: row.string(at: 9)
                )
            }
            return StatementFinancialProjectionRecordDTO(
                projection: StatementFinancialProjectionDTO(
                    id: record.0, algorithmIdentifier: record.4, digest: record.5,
                    institutionCode: record.6, statementFamilyCode: record.7,
                    parserProfileID: record.8, parserProfileVersion: record.9,
                    sourceFormatCode: record.10, statementStartDateISO: record.11,
                    statementEndDateISO: record.12, nativeCurrency: record.13,
                    eventCount: record.14, openingBalanceMinor: record.15,
                    openingBalanceDecimal: record.16, debitCount: record.17,
                    creditCount: record.18, debitTotalMinor: record.19,
                    debitTotalDecimal: record.20, creditTotalMinor: record.21,
                    creditTotalDecimal: record.22, closingBalanceMinor: record.23,
                    closingBalanceDecimal: record.24, events: events
                ),
                workspaceID: workspaceId,
                accountID: record.1,
                documentID: record.2,
                importSessionID: record.3,
                createdAtISO: record.25
            )
        }
    }

    func statementEquivalenceGroups(workspaceId: String) throws -> [StatementEquivalenceGroupDTO] {
        try db.query(
            sql: "SELECT id, account_id, institution_code, statement_family_code, statement_start_date, statement_end_date, native_currency, projection_algorithm, projection_digest, authoritative_projection_id, created_at FROM statement_equivalence_groups WHERE workspace_id = ? ORDER BY created_at, id;",
            params: [workspaceId]
        ) { row in
            StatementEquivalenceGroupDTO(
                id: row.string(at: 0) ?? "", workspaceID: workspaceId,
                accountID: row.string(at: 1) ?? "", institutionCode: row.string(at: 2) ?? "",
                statementFamilyCode: row.string(at: 3) ?? "", statementStartDateISO: row.string(at: 4) ?? "",
                statementEndDateISO: row.string(at: 5) ?? "", nativeCurrency: row.string(at: 6) ?? "",
                projectionAlgorithm: row.string(at: 7) ?? "", projectionDigest: row.string(at: 8) ?? "",
                authoritativeProjectionID: row.string(at: 9) ?? "", createdAtISO: row.string(at: 10) ?? ""
            )
        }
    }

    func statementEquivalenceMembers(workspaceId: String) throws -> [StatementEquivalenceMemberDTO] {
        try db.query(
            sql: "SELECT m.id, m.group_id, m.projection_id, m.role, m.source_format_code, m.created_at FROM statement_equivalence_members m JOIN statement_equivalence_groups g ON g.id = m.group_id WHERE g.workspace_id = ? ORDER BY m.created_at, m.id;",
            params: [workspaceId]
        ) { row in
            guard let role = StatementEquivalenceMemberRole(rawValue: row.string(at: 3) ?? "") else {
                throw RepositoryError.relationshipViolation("Statement equivalence member role is invalid.")
            }
            return StatementEquivalenceMemberDTO(
                id: row.string(at: 0) ?? "", groupID: row.string(at: 1) ?? "",
                projectionID: row.string(at: 2) ?? "", role: role,
                sourceFormatCode: row.string(at: 4) ?? "", createdAtISO: row.string(at: 5) ?? ""
            )
        }
    }

    func preferredTransactionSources(workspaceId: String) throws -> [PreferredTransactionSourceDTO] {
        let rows = try db.query(
            sql: "SELECT o.canonical_transaction_id, o.document_id, o.import_session_id, s.source_format_code, o.source_transaction_date, o.structured_reference_digest FROM transaction_source_observations o JOIN statement_source_observations s ON s.document_id = o.document_id JOIN transactions t ON t.id = o.canonical_transaction_id WHERE t.workspace_id = ? ORDER BY o.canonical_transaction_id, CASE s.source_format_code WHEN 'monthly-pdf' THEN 3 WHEN 'history-pdf' THEN 2 ELSE 1 END DESC, o.created_at DESC, o.document_id;",
            params: [workspaceId]
        ) { row in
            PreferredTransactionSourceDTO(
                transactionId: row.string(at: 0) ?? "",
                documentId: row.string(at: 1) ?? "",
                importSessionId: row.string(at: 2) ?? "",
                sourceFormatCode: row.string(at: 3) ?? "",
                sourceTransactionDateISO: row.string(at: 4),
                structuredReferenceDigest: row.string(at: 5)
            )
        }
        var seen = Set<String>()
        return rows.filter { seen.insert($0.transactionId).inserted }
    }

    func cbqSourceObservationSummaries(workspaceId: String) throws -> [CBQSourceObservationSummaryDTO] {
        try db.query(
            sql: "SELECT s.document_id, s.import_session_id, s.source_format_code, s.source_row_count, s.newly_imported_transaction_count, s.represented_transaction_count, COUNT(t.id) FROM statement_source_observations s LEFT JOIN transaction_source_observations t ON t.document_id = s.document_id WHERE s.workspace_id = ? GROUP BY s.document_id, s.import_session_id, s.source_format_code, s.source_row_count, s.newly_imported_transaction_count, s.represented_transaction_count ORDER BY s.document_id;",
            params: [workspaceId]
        ) { row in
            CBQSourceObservationSummaryDTO(
                documentId: row.string(at: 0) ?? "",
                importSessionId: row.string(at: 1) ?? "",
                sourceFormatCode: row.string(at: 2) ?? "",
                sourceRowCount: Int(row.int64(at: 3) ?? 0),
                importedTransactionCount: Int(row.int64(at: 4) ?? 0),
                representedTransactionCount: Int(row.int64(at: 5) ?? 0),
                transactionObservationCount: Int(row.int64(at: 6) ?? 0)
            )
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
                    payload.document.legacyRawTextSHA256,
                    NSNull(),
                    NSNull(),
                    NSNull(),
                    payload.document.createdAtISO
                ]
            )
            try db.executePrepared(
                sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, fingerprint_data, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?,?);",
                params: [
                    payload.fingerprint.id,
                    payload.fingerprint.documentId,
                    payload.fingerprint.importSessionId,
                    payload.fingerprint.algorithm,
                    payload.fingerprint.fingerprint,
                    payload.fingerprint.fingerprintData ?? NSNull(),
                    payload.fingerprint.createdAtISO,
                    payload.fingerprint.isDuplicateAuthority ? 1 : 0
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
        WHERE df.algorithm = ? AND df.fingerprint = ?
          AND df.is_duplicate_authority = 1
          AND s.validation_status = 'passed'
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
              payload.document.legacyRawTextSHA256 == payload.fingerprint.fingerprint,
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
        try db.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id, source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [payload.id, payload.workspaceId, payload.createdAtISO, payload.outcomeCode, payload.coverageCode, payload.accountDecisionCode, payload.guidanceCode, payload.persistenceCode, payload.transactionCount, payload.accountId ?? NSNull(), payload.importSessionId ?? NSNull(), payload.documentId ?? NSNull(), payload.relatedImportSessionId ?? NSNull(), payload.sourceRowCount ?? NSNull(), payload.importedTransactionCount ?? NSNull(), payload.recognizedExistingRowCount ?? NSNull(), payload.blockedRowCount ?? NSNull()])
    }
}

fileprivate final class SQLiteTransactionRepo: TransactionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        // Atomic replace of candidate transactions for an import_session_id.
        guard !transactions.contains(where: \.isTrusted) else {
            throw RepositoryError.trustedTransactionWriteForbidden
        }
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            if let importId = importSessionId {
                // Remove prior non-trusted transactions for this import_session
                let delRaw = "DELETE FROM transaction_raw_rows WHERE transaction_id IN (SELECT id FROM transactions WHERE import_session_id = ? AND is_trusted = 0);"
                try db.executePrepared(sql: delRaw, params: [importId])
                let delTx = "DELETE FROM transactions WHERE import_session_id = ? AND is_trusted = 0;"
                try db.executePrepared(sql: delTx, params: [importId])
            }

            let insertTx = "INSERT OR REPLACE INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at, financial_date_role, statement_timezone_evidence) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);"

            let insertRaw = "INSERT OR REPLACE INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);"

            for tx in transactions {
                try db.executePrepared(sql: insertTx, params: [tx.id, tx.workspaceId, tx.accountId ?? NSNull(), tx.importSessionId ?? NSNull(), tx.documentId ?? NSNull(), tx.originalRowId ?? NSNull(), tx.postedDateISO, tx.valueDateISO ?? NSNull(), tx.description ?? NSNull(), tx.payee ?? NSNull(), tx.reference ?? NSNull(), tx.nativeCurrency, tx.amountMinor, tx.amountDecimal, tx.direction, tx.runningBalanceMinor ?? NSNull(), tx.isReconciled ? 1 : 0, tx.isTrusted ? 1 : 0, tx.trustedAtISO ?? NSNull(), tx.createdAtISO, tx.updatedAtISO ?? NSNull(), tx.financialDateRole, tx.statementTimezoneEvidence])

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
        var sql = "SELECT t.id, t.workspace_id, t.account_id, t.import_session_id, t.document_id, t.original_row_id, t.posted_date, t.value_date, t.description, t.payee, t.reference, t.native_currency, t.amount_minor, t.amount_decimal, t.direction, t.running_balance_minor, t.is_reconciled, t.is_trusted, t.trusted_at, t.created_at, t.updated_at, t.financial_date_role, t.statement_timezone_evidence FROM transactions t WHERE t.workspace_id = ?"
        var params: [Any?] = [workspaceId]
        if let importSessionId {
            sql += " AND import_session_id = ?"
            params.append(importSessionId)
        }
        sql += " ORDER BY t.posted_date ASC, (SELECT nr.normalized_document_id FROM transaction_raw_rows trr JOIN normalized_rows nr ON nr.id = trr.normalized_row_id WHERE trr.transaction_id = t.id ORDER BY nr.row_index ASC LIMIT 1) ASC, (SELECT nr.row_index FROM transaction_raw_rows trr JOIN normalized_rows nr ON nr.id = trr.normalized_row_id WHERE trr.transaction_id = t.id ORDER BY nr.row_index ASC LIMIT 1) ASC, t.id ASC;"

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
                financialDateRole: row.string(at: 21) ?? "transaction_date",
                statementTimezoneEvidence: row.string(at: 22) ?? "unknown",
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
        let sql = "SELECT t.id, t.workspace_id, t.account_id, t.import_session_id, t.document_id, t.original_row_id, t.posted_date, t.value_date, t.description, t.payee, t.reference, t.native_currency, t.amount_minor, t.amount_decimal, t.direction, t.running_balance_minor, t.is_reconciled, t.is_trusted, t.trusted_at, t.created_at, t.updated_at, t.financial_date_role, t.statement_timezone_evidence FROM transactions t WHERE t.workspace_id = ? AND t.is_trusted = 1 ORDER BY t.posted_date ASC, (SELECT nr.normalized_document_id FROM transaction_raw_rows trr JOIN normalized_rows nr ON nr.id = trr.normalized_row_id WHERE trr.transaction_id = t.id ORDER BY nr.row_index ASC LIMIT 1) ASC, (SELECT nr.row_index FROM transaction_raw_rows trr JOIN normalized_rows nr ON nr.id = trr.normalized_row_id WHERE trr.transaction_id = t.id ORDER BY nr.row_index ASC LIMIT 1) ASC, t.id ASC;"
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
                financialDateRole: row.string(at: 21) ?? "transaction_date",
                statementTimezoneEvidence: row.string(at: 22) ?? "unknown",
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
        let sql = "SELECT trr.id, trr.normalized_row_id, trr.contribution_type, nr.row_index, nr.record_digest, nr.normalized_document_id, nd.profile_id, nd.profile_version FROM transaction_raw_rows trr INNER JOIN normalized_rows nr ON nr.id = trr.normalized_row_id INNER JOIN normalized_documents nd ON nd.id = nr.normalized_document_id WHERE trr.transaction_id = ? ORDER BY nr.row_index ASC, trr.id ASC;"
        return try db.query(sql: sql, params: [transactionId]) { row in
            TransactionRawRowDTO(
                id: row.string(at: 0) ?? "",
                normalizedRowId: row.string(at: 1) ?? "",
                contributionType: row.string(at: 2),
                sourceOrdinal: row.int64(at: 3).map(Int.init),
                normalizedRecordDigest: row.string(at: 4),
                normalizedDocumentId: row.string(at: 5),
                parserProfileId: row.string(at: 6),
                parserProfileVersion: row.string(at: 7)
            )
        }
    }
}

// MARK: - Utilities
fileprivate func escape(_ s: String) -> String {
    return s.replacingOccurrences(of: "'", with: "''")
}
