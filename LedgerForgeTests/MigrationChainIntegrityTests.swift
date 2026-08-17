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

    @Test func currentV1ThroughV13RegistrationIsValidAndDeterministic() throws {
        try MigrationChainValidator.validateRegistered(allMigrations)

        #expect(allMigrations.map(\.version) == Array(1...13))
        #expect(allMigrations.map(\.checksum).allSatisfy { $0.count == 64 })
        #expect(allMigrations.map(\.checksum) == allMigrations.map(\.checksum))
        #expect(migrationV13.name == "multi-section card statements and exact semantic sources")
    }

    @Test func cleanInstallContainsCompleteV13SchemaAndReopens() throws {
        try withTemporaryDatabase(named: "V13CleanInstall") { path in
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
            let fingerprintColumns = try provider.database.query(
                sql: "PRAGMA table_info(document_fingerprints);",
                params: []
            ) { $0.string(at: 1) ?? "" }
            #expect(fingerprintColumns.contains("is_duplicate_authority"))
            let fingerprintIndexes = try provider.database.query(
                sql: "PRAGMA index_list(document_fingerprints);",
                params: []
            ) { $0.string(at: 1) ?? "" }
            for index in [
                "idx_document_fingerprints_document_algorithm",
                "idx_document_fingerprints_one_authority",
                "idx_document_fingerprints_authority_lookup"
            ] {
                #expect(fingerprintIndexes.contains(index))
            }
            provider.database.close()

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 13)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('categories', 'transaction_category_assignments');") == 2)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('statement_financial_projections', 'statement_financial_projection_events', 'statement_equivalence_groups', 'statement_equivalence_members');") == 4)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM statement_financial_projections;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM statement_equivalence_groups;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name IN ('idx_statement_projection_group_lookup', 'idx_statement_equivalence_one_authoritative_member');") == 2)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'trigger' AND name IN ('validate_statement_projection_relationships', 'validate_statement_equivalence_group', 'validate_statement_equivalence_member');") == 3)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('cbq_source_identity_observations', 'statement_source_observations', 'transaction_source_observations');") == 3)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM cbq_source_identity_observations;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM statement_source_observations;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM transaction_source_observations;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('card_instruments', 'card_instrument_identifiers', 'card_source_identity_observations', 'card_instrument_relationships', 'card_statements', 'card_statement_summary_components', 'card_transaction_evidence');") == 7)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('card_statement_sections', 'card_statement_section_observations', 'card_statement_semantic_projections', 'card_statement_semantic_projection_sections', 'card_statement_semantic_projection_events', 'card_statement_semantic_groups', 'card_statement_semantic_members');") == 7)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM card_instruments;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM card_statements;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM card_transaction_evidence;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM card_statement_sections;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM card_statement_semantic_projections;") == 0)
        }
    }

    @Test func cleanV9UpgradesToV13WithoutInventingEquivalenceCBQOrCardEvidence() throws {
        try withTemporaryDatabase(named: "V9ToV13") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(9)))
            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 9)
            try database.runMigrations(allMigrations)
            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 13)
            #expect(try database.queryInt("SELECT COUNT(*) FROM statement_financial_projections;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM statement_financial_projection_events;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM statement_equivalence_groups;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM statement_equivalence_members;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM statement_source_observations;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM transaction_source_observations;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_instruments;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statements;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_sections;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_semantic_projections;") == 0)
            try database.checkpointAndClose()

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            try expectCurrentHistory(in: reopened.database)
        }
    }

    @Test func populatedV6FullImportUpgradesToCurrentWithoutInventingPartialOrCategoryTruth() throws {
        try withTemporaryDatabase(named: "V6ToV13") { path in
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
        let future = PersistedMigrationRecord(version: 14, name: "future", checksum: String(repeating: "f", count: 64), appliedAt: "2026-07-20T00:00:00Z")

        #expect(throws: MigrationIntegrityError.unsupportedFutureVersion(14)) {
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

    @Test func freshDatabaseCreatesOneExactV1ThroughV13History() throws {
        try withTemporaryDatabase(named: "Fresh") { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            defer { provider.database.close() }

            try expectCurrentHistory(in: provider.database)
        }
    }

    @Test(arguments: Array(1...12))
    func everyRegisteredHistoricalPrefixIsExactBeforeOrdinaryReopenToCurrent(
        _ priorVersion: Int
    ) throws {
        try withTemporaryDatabase(named: "Upgrade-V\(priorVersion)") { path in
            let seed = SQLiteDatabase(path: path)
            let prefix = Array(allMigrations.prefix(priorVersion))
            try seed.runMigrations(prefix)
            let prefixRecords = try seed.validatedMigrationHistory(
                against: prefix,
                requiresCompleteChain: true
            )
            #expect(prefixRecords.compactMap(\.version) == Array(1...priorVersion))
            #expect(try seed.queryInt("SELECT MAX(version) FROM schema_migrations;") == priorVersion)
            try seed.checkpointAndClose()

            let provider = try SQLiteRepositoryProvider(path: path)
            try expectCurrentHistory(in: provider.database)
            #expect(try provider.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 13)
            try provider.database.checkpointAndClose()
        }
    }

    @Test func v12ToV13BackfillsOnlyUniquelyProvenSingularAmexEvidence() throws {
        try withTemporaryDatabase(named: "V12ToV13AmexBackfill") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(12)))
            try seedV12AmexCard(in: database)

            try database.runMigrations(allMigrations)

            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_sections;") == 1)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_section_observations;") == 1)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_semantic_projections;") == 0)
            let sections = try database.query(
                sql: "SELECT document_scoped_section_id, source_ordinal, instrument_id, holder_label, signed_total_currency, signed_total_minor, signed_total_decimal FROM card_statement_sections;",
                params: []
            ) { row in
                (row.string(at: 0), row.int64(at: 1), row.string(at: 2), row.string(at: 3), row.string(at: 4), row.int64(at: 5), row.string(at: 6))
            }
            #expect(sections.count == 1)
            #expect(sections.first?.0 == "instrument-section-1")
            #expect(sections.first?.1 == 1)
            #expect(sections.first?.2 == "i1")
            #expect(sections.first?.3 == nil)
            #expect(sections.first?.4 == "USD")
            #expect(sections.first?.5 == 12345)
            #expect(sections.first?.6 == "123.45")
            database.close()
        }
    }

    @Test func v12ToV13DoesNotFabricateSectionForIncompleteAmexEvidence() throws {
        try withTemporaryDatabase(named: "V12ToV13AmexIncomplete") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(12)))
            try seedV12AmexCard(in: database, includeInstrumentObservation: false)

            try database.runMigrations(allMigrations)

            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_sections;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_section_observations;") == 0)
            database.close()
        }
    }

    @Test func v12ToV13DoesNotFabricateSectionForAmbiguousAmexEvidence() throws {
        try withTemporaryDatabase(named: "V12ToV13AmexAmbiguous") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(12)))
            try seedV12AmexCard(in: database)
            try database.execute(sql: """
            INSERT INTO card_instruments(id,workspace_id,liability_account_id,lifecycle_state,created_at)
              VALUES('i2','w','a','active','2026-07-20T00:00:00Z');
            INSERT INTO transactions(id,workspace_id,account_id,import_session_id,document_id,posted_date,native_currency,amount_minor,amount_decimal,direction,created_at)
              VALUES('t2','w','a','s','d','2026-07-20','USD',2345,'23.45','card_increase_owed','2026-07-20T00:00:00Z');
            INSERT INTO card_transaction_evidence(id,card_statement_id,transaction_id,row_scope,instrument_id,liability_effect,source_transaction_date,document_scoped_section_id)
              VALUES('evidence-2','cs','t2','instrument_level','i2','card_increase_owed','2026-07-20','instrument-section-1');
            """)

            try database.runMigrations(allMigrations)

            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_sections;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_section_observations;") == 0)
            database.close()
        }
    }

    @Test func v13AllowsSameObservationKindAcrossSectionsButRejectsDuplicatesAndMismatchedSources() throws {
        try withTemporaryDatabase(named: "V13SectionObservations") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(12)))
            try seedV12AmexCard(in: database, includeInstrumentObservation: false)
            try database.runMigrations(allMigrations)
            try database.execute(sql: """
            INSERT INTO card_instruments(id,workspace_id,liability_account_id,lifecycle_state,created_at)
              VALUES('i2','w','a','active','2026-07-20T00:00:00Z');
            INSERT INTO card_statement_sections(id,card_statement_id,document_scoped_section_id,source_ordinal,instrument_id,holder_label,signed_total_currency,signed_total_minor,signed_total_decimal,reconciliation_rule_code)
              VALUES('section-1','cs','amex-instrument-section-1',1,'i1',NULL,'USD',12345,'123.45','amex.section.signed-increases-minus-decreases.v1');
            INSERT INTO card_statement_sections(id,card_statement_id,document_scoped_section_id,source_ordinal,instrument_id,holder_label,signed_total_currency,signed_total_minor,signed_total_decimal,reconciliation_rule_code)
              VALUES('section-2','cs','amex-instrument-section-2',2,'i2',NULL,'USD',2345,'23.45','amex.section.signed-increases-minus-decreases.v1');
            """)

            try database.executePrepared(
                sql: "INSERT INTO card_statement_section_observations(id,card_statement_section_id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,observation_kind,source_value,association_authority,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?);",
                params: ["section-observation-1", "section-1", "w", "d", "s", "nd", "amex.credit-card.pdf", "1", "amex_card_account_number", "card-1111", "parser_strong_evidence", "2026-07-20T00:00:00Z"]
            )
            try database.executePrepared(
                sql: "INSERT INTO card_statement_section_observations(id,card_statement_section_id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,observation_kind,source_value,association_authority,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?);",
                params: ["section-observation-2", "section-2", "w", "d", "s", "nd", "amex.credit-card.pdf", "1", "amex_card_account_number", "card-2222", "parser_strong_evidence", "2026-07-20T00:00:00Z"]
            )
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_section_observations;") == 2)

            #expect(throws: Error.self) {
                try database.executePrepared(
                    sql: "INSERT INTO card_statement_section_observations(id,card_statement_section_id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,observation_kind,source_value,association_authority,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?);",
                    params: ["section-observation-duplicate", "section-2", "w", "d", "s", "nd", "amex.credit-card.pdf", "1", "amex_card_account_number", "card-2222", "parser_strong_evidence", "2026-07-20T00:00:00Z"]
                )
            }
            #expect(throws: Error.self) {
                try database.executePrepared(
                    sql: "INSERT INTO card_statement_section_observations(id,card_statement_section_id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,observation_kind,source_value,association_authority,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?);",
                    params: ["section-observation-invalid", "section-2", "w", "d", "s", "nd", "wrong.profile", "1", "amex_card_account_number", "card-3333", "parser_strong_evidence", "2026-07-20T00:00:00Z"]
                )
            }
            database.close()
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
                params: [14, "future", "2026-07-20T00:00:00Z", String(repeating: "f", count: 64)]
            )
        } assertReopen: {
            MigrationIntegrityError.unsupportedFutureVersion(14)
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

    private func seedV12AmexCard(
        in database: SQLiteDatabase,
        includeInstrumentObservation: Bool = true
    ) throws {
        try database.execute(sql: """
        INSERT INTO workspaces(id,name,created_at) VALUES('w','Workspace','2026-07-20T00:00:00Z');
        INSERT INTO accounts(id,workspace_id,name,account_type,native_currency,created_at)
          VALUES('a','w','American Express','credit_card','USD','2026-07-20T00:00:00Z');
        INSERT INTO import_sessions(id,workspace_id,user_visible_name,started_at,completed_at,validation_status,created_at,parser_version)
          VALUES('s','w','Sanitized Amex statement','2026-07-20T00:00:00Z','2026-07-20T00:00:01Z','passed','2026-07-20T00:00:00Z','AmericanExpressCreditCardPDFParser');
        INSERT INTO documents(id,workspace_id,import_session_id,filename,mime_type,size_bytes,sha256,created_at)
          VALUES('d','w','s','sanitized.pdf','application/pdf',1,'v12-amex-sha','2026-07-20T00:00:00Z');
        INSERT INTO normalized_documents(id,import_session_id,document_id,normalized_json,created_at,profile_id,profile_version)
          VALUES('nd','s','d','{}','2026-07-20T00:00:00Z','amex.credit-card.pdf','1');
        INSERT INTO normalized_rows(id,normalized_document_id,row_index,row_original,created_at)
          VALUES('nr','nd',1,'sanitized','2026-07-20T00:00:00Z');
        INSERT INTO card_instruments(id,workspace_id,liability_account_id,lifecycle_state,created_at)
          VALUES('i1','w','a','active','2026-07-20T00:00:00Z');
        INSERT INTO card_statements(id,workspace_id,liability_account_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,statement_date,statement_start_date,statement_end_date,statement_currency,source_row_count,reconciliation_rule_code,created_at)
          VALUES('cs','w','a','d','s','nd','amex.credit-card.pdf','1','2026-07-20','2026-06-24','2026-07-23','USD',1,'amex.statement.summary.v1','2026-07-20T00:00:00Z');
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal)
          VALUES('summary-total','cs','instrument_net_total','USD',12345,'123.45');
        INSERT INTO transactions(id,workspace_id,account_id,import_session_id,document_id,posted_date,native_currency,amount_minor,amount_decimal,direction,created_at)
          VALUES('t1','w','a','s','d','2026-07-20','USD',12345,'123.45','card_increase_owed','2026-07-20T00:00:00Z');
        INSERT INTO card_transaction_evidence(id,card_statement_id,transaction_id,row_scope,instrument_id,liability_effect,source_transaction_date,document_scoped_section_id)
          VALUES('evidence-1','cs','t1','instrument_level','i1','card_increase_owed','2026-07-20','instrument-section-1');
        """)
        if includeInstrumentObservation {
            try database.execute(sql: """
            INSERT INTO card_source_identity_observations(id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,subject_kind,subject_id,observation_kind,source_value,association_authority,created_at)
              VALUES('observation-i1','w','d','s','nd','amex.credit-card.pdf','1','instrument','i1','amex_card_account_number','card-1111','parser_strong_evidence','2026-07-20T00:00:00Z');
            """)
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
