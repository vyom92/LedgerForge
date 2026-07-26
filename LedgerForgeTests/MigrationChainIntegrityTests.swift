import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct MigrationChainIntegrityTests {
    @Test func registeredChainRejectsDuplicateVersion() {
        let migrations = [
            Migration(version: 1, name: "one", sql: "SELECT 1;"),
            Migration(version: 1, name: "duplicate", sql: "SELECT 2;")
        ]

        #expect(throws: MigrationIntegrityError.duplicateRegisteredVersion(1)) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test func registeredChainRejectsMissingAndNonContiguousVersion() {
        let migrations = [
            Migration(version: 1, name: "one", sql: "SELECT 1;"),
            Migration(version: 3, name: "three", sql: "SELECT 3;")
        ]

        #expect(throws: MigrationIntegrityError.missingRegisteredVersion(2)) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test func registeredChainRejectsNondeterministicInputOrdering() {
        let migrations = [
            Migration(version: 2, name: "two", sql: "SELECT 2;"),
            Migration(version: 1, name: "one", sql: "SELECT 1;")
        ]

        #expect(throws: MigrationIntegrityError.registeredOrderInvalid) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test func currentV1ThroughV8RegistrationIsValidAndDeterministic() throws {
        try MigrationChainValidator.validateRegistered(allMigrations)

        #expect(allMigrations.map(\.version) == [1, 2, 3, 4, 5, 6, 7, 8])
        #expect(allMigrations.map(\.checksum).allSatisfy { $0.count == 64 })
        #expect(allMigrations.map(\.checksum) == allMigrations.map(\.checksum))
    }

    @Test func cleanInstallContainsCompleteV8SchemaAndReopens() throws {
        try withTemporaryDatabase(named: "V8CleanInstall") { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            let objects = try provider.database.query(
                sql: "SELECT type, name FROM sqlite_master WHERE name IN ('partial_import_summaries', 'incoming_row_dispositions', 'validate_incoming_row_disposition', 'validate_partial_import_summary') ORDER BY name;",
                params: []
            ) { row in
                "\(row.string(at: 0) ?? ""):\(row.string(at: 1) ?? "")"
            }
            #expect(Set(objects) == Set([
                "table:partial_import_summaries",
                "table:incoming_row_dispositions",
                "trigger:validate_incoming_row_disposition",
                "trigger:validate_partial_import_summary"
            ]))
            let attemptColumns = try provider.database.query(
                sql: "PRAGMA table_info(import_attempts);",
                params: []
            ) { $0.string(at: 1) ?? "" }
            for column in [
                "source_row_count",
                "imported_transaction_count",
                "recognized_existing_row_count",
                "blocked_row_count"
            ] {
                #expect(attemptColumns.contains(column))
            }
            let dispositionIndexes = try provider.database.query(
                sql: "PRAGMA index_list(incoming_row_dispositions);",
                params: []
            ) { $0.string(at: 1) ?? "" }
            #expect(dispositionIndexes.count >= 3)
            provider.database.close()

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 8)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('categories', 'transaction_category_assignments');") == 2)
        }
    }

    @Test func populatedV6FullImportUpgradesToCurrentWithoutInventingPartialOrCategoryTruth() throws {
        try withTemporaryDatabase(named: "V6ToV8") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(6)))
            try database.execute(sql: """
            INSERT INTO workspaces(id,name,created_at) VALUES('w','Workspace','2026-07-20T00:00:00Z');
            INSERT INTO accounts(id,workspace_id,name,native_currency,created_at) VALUES('a','w','Account','INR','2026-07-20T00:00:00Z');
            INSERT INTO import_sessions(id,workspace_id,user_visible_name,started_at,completed_at,validation_status,created_at,parser_version)
              VALUES('s','w','Sanitized statement','2026-07-20T00:00:00Z','2026-07-20T00:00:01Z','passed','2026-07-20T00:00:00Z','AxisBankAccountParser');
            INSERT INTO documents(id,workspace_id,import_session_id,filename,mime_type,size_bytes,sha256,created_at)
              VALUES('d','w','s','sanitized.csv','text/csv',1,'source-sha','2026-07-20T00:00:00Z');
            INSERT INTO normalized_documents(id,import_session_id,document_id,normalized_json,created_at,profile_id,profile_version)
              VALUES('nd','s','d','{}','2026-07-20T00:00:00Z','axis.bank-account.csv','1');
            INSERT INTO normalized_rows(id,normalized_document_id,row_index,row_original,created_at,record_digest)
              VALUES('nr','nd',1,'sanitized','2026-07-20T00:00:00Z','row-digest');
            INSERT INTO transactions(id,workspace_id,account_id,import_session_id,document_id,posted_date,native_currency,amount_minor,amount_decimal,direction,running_balance_minor,is_trusted,trusted_at,created_at,financial_date_role,statement_timezone_evidence)
              VALUES('t','w','a','s','d','2026-07-20','INR',100,'1.00','credit',100,1,'2026-07-20T00:00:01Z','2026-07-20T00:00:00Z','transaction_date','iana:Asia/Kolkata');
            INSERT INTO transaction_raw_rows(id,transaction_id,normalized_row_id,contribution_type,created_at)
              VALUES('trr','t','nr','financial','2026-07-20T00:00:00Z');
            INSERT INTO import_attempts(id,workspace_id,created_at,outcome_code,coverage_code,account_decision_code,guidance_code,persistence_code,transaction_count,account_id,import_session_id,document_id)
              VALUES('attempt','w','2026-07-20T00:00:01Z','successful_import','evaluated_supported_only','resolved_or_created','import_completed','committed',1,'a','s','d');
            """)
            let transactionBefore = try database.query(
                sql: "SELECT id, amount_minor, amount_decimal, direction, running_balance_minor FROM transactions;",
                params: []
            ) { row in
                "\(row.string(at: 0) ?? "")|\(row.int64(at: 1) ?? 0)|\(row.string(at: 2) ?? "")|\(row.string(at: 3) ?? "")|\(row.int64(at: 4) ?? 0)"
            }
            try database.runMigrations(allMigrations)
            #expect(try database.queryInt("SELECT COUNT(*) FROM partial_import_summaries;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM incoming_row_dispositions;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM categories;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM transaction_category_assignments;") == 0)
            let nullableCounts = try database.query(
                sql: "SELECT source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count FROM import_attempts WHERE id = 'attempt';",
                params: []
            ) { row in
                [row.int64(at: 0), row.int64(at: 1), row.int64(at: 2), row.int64(at: 3)]
            }
            #expect(nullableCounts == [[nil, nil, nil, nil]])
            let transactionAfter = try database.query(
                sql: "SELECT id, amount_minor, amount_decimal, direction, running_balance_minor FROM transactions;",
                params: []
            ) { row in
                "\(row.string(at: 0) ?? "")|\(row.int64(at: 1) ?? 0)|\(row.string(at: 2) ?? "")|\(row.string(at: 3) ?? "")|\(row.int64(at: 4) ?? 0)"
            }
            #expect(transactionAfter == transactionBefore)
            database.close()

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            let accountStore = AccountStore()
            let transactionStore = TransactionStore()
            let sessionStore = ImportSessionStore()
            let attemptStore = ImportAttemptStore()
            let hydration = try RepositoryStoreHydrator(
                accountRepo: reopened.accountRepo,
                importSessionRepo: reopened.importSessionRepo,
                transactionRepo: reopened.transactionRepo,
                accountStore: accountStore,
                transactionStore: transactionStore,
                importSessionStore: sessionStore,
                importAttemptStore: attemptStore,
                workspaceId: "w",
                persistenceState: .verifiedSQLite
            ).hydrateIfNeeded(forceRefresh: true)
            #expect(hydration.transactionCount == 1)
            #expect(hydration.importSessionCount == 1)
            #expect(hydration.importAttemptCount == 1)
            #expect(sessionStore.importSessions.first?.partialImportSummary == nil)
        }
    }

    @Test func persistedHistoryRejectsDuplicateVersion() {
        let records = [record(for: migrationV1), record(for: migrationV1)]

        #expect(throws: MigrationIntegrityError.duplicatePersistedVersion(1)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsMissingLowerMigration() {
        let records = [record(for: migrationV1), record(for: migrationV3)]

        #expect(throws: MigrationIntegrityError.missingPersistedVersion(2)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsMismatchedName() {
        let records = [PersistedMigrationRecord(version: 1, name: "renamed", checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z")]

        #expect(throws: MigrationIntegrityError.persistedNameMismatch(1)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsMismatchedChecksum() {
        let records = [PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: String(repeating: "0", count: 64), appliedAt: "2026-07-20T00:00:00Z")]

        #expect(throws: MigrationIntegrityError.persistedChecksumMismatch(1)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsNullOrIncompleteRecord() {
        let incompleteRecords = [
            PersistedMigrationRecord(version: nil, name: migrationV1.name, checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z"),
            PersistedMigrationRecord(version: 1, name: nil, checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z"),
            PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: nil, appliedAt: "2026-07-20T00:00:00Z"),
            PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: migrationV1.checksum, appliedAt: nil)
        ]

        for incomplete in incompleteRecords {
            #expect(throws: MigrationIntegrityError.persistedRecordIncomplete(incomplete.version)) {
                try MigrationChainValidator.validatePersisted([incomplete], against: allMigrations, requiresCompleteChain: false)
            }
        }
    }

    @Test func persistedHistoryRejectsUnsupportedFutureVersion() {
        let future = PersistedMigrationRecord(version: 9, name: "future", checksum: String(repeating: "f", count: 64), appliedAt: "2026-07-20T00:00:00Z")

        #expect(throws: MigrationIntegrityError.unsupportedFutureVersion(9)) {
            try MigrationChainValidator.validatePersisted(allMigrations.map(record(for:)) + [future], against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func editedPreviouslyAppliedMigrationIsRejected() {
        let editedV1 = Migration(version: 1, name: migrationV1.name, sql: migrationV1.sql + "\nSELECT 1;")

        #expect(throws: MigrationIntegrityError.persistedChecksumMismatch(1)) {
            try MigrationChainValidator.validatePersisted([record(for: migrationV1)], against: [editedV1], requiresCompleteChain: true)
        }
    }

    @Test func validPersistedPrefixAndCompleteChainAreAccepted() throws {
        try MigrationChainValidator.validatePersisted(
            [record(for: migrationV1), record(for: migrationV2)],
            against: allMigrations,
            requiresCompleteChain: false
        )
        try MigrationChainValidator.validatePersisted(
            allMigrations.map(record(for:)),
            against: allMigrations,
            requiresCompleteChain: true
        )
    }

    @Test func freshDatabaseCreatesOneExactV1ThroughV8History() throws {
        try withTemporaryDatabase(named: "Fresh") { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            defer { provider.database.close() }

            try expectCurrentHistory(in: provider.database)
        }
    }

    @Test(arguments: [1, 2, 3, 4, 5])
    func everySupportedPriorVersionUpgradesOrReopensToCurrent(_ priorVersion: Int) throws {
        try withTemporaryDatabase(named: "Upgrade-V\(priorVersion)") { path in
            let seed = SQLiteDatabase(path: path)
            try seed.runMigrations(Array(allMigrations.prefix(priorVersion)))
            seed.close()

            let provider = try SQLiteRepositoryProvider(path: path)
            defer { provider.database.close() }

            try expectCurrentHistory(in: provider.database)
        }
    }

    @Test func nonemptyV5FinancialHistoryFailsClosedWithExplicitPreproductionResetRequirement() throws {
        try withTemporaryDatabase(named: "Nonempty-V5") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(5)))
            try database.executePrepared(
                sql: "INSERT INTO workspaces(id, name, created_at) VALUES(?, ?, ?);",
                params: ["workspace-v5-history", "V5 history", "2026-07-20T00:00:00Z"]
            )
            try database.executePrepared(
                sql: "INSERT INTO transactions(id, workspace_id, posted_date, native_currency, amount_minor, amount_decimal, direction, created_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?);",
                params: ["transaction-v5-history", "workspace-v5-history", "2026-06-06", "INR", 100, "1.00", "credit", "2026-07-20T00:00:00Z"]
            )

            #expect(throws: MigrationPreflightError.failed(issueCode: "preproduction-reset-required")) {
                try database.runMigrations(allMigrations)
            }
            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 5)
            #expect(try database.queryInt("SELECT COUNT(*) FROM transactions;") == 1)
            database.close()
        }
    }

    @Test func duplicatePersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Duplicate") { database in
            try database.executePrepared(
                sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                params: [1, migrationV1.name, "2026-07-20T00:00:00Z", migrationV1.checksum]
            )
        } assertReopen: {
            MigrationIntegrityError.duplicatePersistedVersion(1)
        }
    }

    @Test func missingLowerPersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Missing") { database in
            try database.executePrepared(sql: "DELETE FROM schema_migrations WHERE version = ?;", params: [2])
        } assertReopen: {
            MigrationIntegrityError.missingPersistedVersion(2)
        }
    }

    @Test func mismatchedPersistedNameFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Name") { database in
            try database.executePrepared(sql: "UPDATE schema_migrations SET name = ? WHERE version = ?;", params: ["renamed", 2])
        } assertReopen: {
            MigrationIntegrityError.persistedNameMismatch(2)
        }
    }

    @Test func mismatchedPersistedChecksumAndEditedMigrationFailOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Checksum") { database in
            try database.executePrepared(
                sql: "UPDATE schema_migrations SET checksum = ? WHERE version = ?;",
                params: [String(repeating: "0", count: 64), 3]
            )
        } assertReopen: {
            MigrationIntegrityError.persistedChecksumMismatch(3)
        }
    }

    @Test(arguments: ["name", "checksum"])
    func incompletePersistedRecordFailsOnReopen(_ column: String) throws {
        try withTamperedCurrentDatabase(named: "Incomplete-\(column)") { database in
            try database.execute(sql: "UPDATE schema_migrations SET \(column) = NULL WHERE version = 1;")
        } assertReopen: {
            MigrationIntegrityError.persistedRecordIncomplete(1)
        }
    }

    @Test func unsupportedFuturePersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Future") { database in
            try database.executePrepared(
                sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                params: [9, "future", "2026-07-20T00:00:00Z", String(repeating: "f", count: 64)]
            )
        } assertReopen: {
            MigrationIntegrityError.unsupportedFutureVersion(9)
        }
    }

    @Test func applicationSchemaWithoutMigrationHistoryIsNotAcceptedAsFresh() throws {
        try withTemporaryDatabase(named: "MissingHistory") { path in
            let database = SQLiteDatabase(path: path)
            try database.open()
            try database.execute(sql: "CREATE TABLE workspaces (id TEXT PRIMARY KEY);")
            database.close()

            #expect(throws: MigrationIntegrityError.missingPersistedVersion(1)) {
                let reopened = SQLiteDatabase(path: path)
                defer { reopened.close() }
                try reopened.runMigrations(allMigrations)
            }
        }
    }

    private func record(for migration: Migration) -> PersistedMigrationRecord {
        PersistedMigrationRecord(
            version: migration.version,
            name: migration.name,
            checksum: migration.checksum,
            appliedAt: "2026-07-20T00:00:00Z"
        )
    }

    private func persistedRecords(in database: SQLiteDatabase) throws -> [PersistedMigrationRecord] {
        try database.query(sql: "SELECT version, name, checksum, applied_at FROM schema_migrations ORDER BY version;") { row in
            PersistedMigrationRecord(
                version: row.int64(at: 0).map(Int.init),
                name: row.string(at: 1),
                checksum: row.string(at: 2),
                appliedAt: row.string(at: 3)
            )
        }
    }

    private func expectCurrentHistory(in database: SQLiteDatabase) throws {
        let records = try persistedRecords(in: database)
        #expect(records.map(\.version) == allMigrations.map { Optional($0.version) })
        #expect(records.map(\.name) == allMigrations.map { Optional($0.name) })
        #expect(records.map(\.checksum) == allMigrations.map { Optional($0.checksum) })
        #expect(records.allSatisfy { !($0.appliedAt ?? "").isEmpty })
    }

    private func withTemporaryDatabase(
        named name: String,
        _ body: (String) throws -> Void
    ) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-MigrationIntegrityTests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder.appendingPathComponent("database.sqlite").path)
    }

    private func withTamperedCurrentDatabase(
        named name: String,
        tamper: (SQLiteDatabase) throws -> Void,
        assertReopen expectedError: () -> MigrationIntegrityError
    ) throws {
        try withTemporaryDatabase(named: name) { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            try tamper(provider.database)
            provider.database.close()

            #expect(throws: expectedError()) {
                let reopened = SQLiteDatabase(path: path)
                defer { reopened.close() }
                try reopened.runMigrations(allMigrations)
            }
        }
    }
}
