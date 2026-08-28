import Foundation
import Testing
@testable import LedgerForge

/// Database-only acceptance coverage for the V15 boundary.  These tests use
/// synthetic, non-financial identifiers and never depend on private statement
/// originals or parser output.
struct AxisCreditCardMigrationV15Tests {
    @Test func freshV1ThroughV15InstallsAnExactChainAndAxisSchema() throws {
        try withDatabase(named: "FreshV15") { database in
            try database.runMigrations(Array(allMigrations.prefix(15)))

            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 15)
            #expect(try database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 15)
            #expect(Array(allMigrations.prefix(15)).map(\.version) == Array(1...15))
            #expect(migrationV15.name == "Axis card observations and representation-neutral semantic events")

            let observationSQL = try database.query(
                sql: "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'card_source_identity_observations';",
                params: []
            ) { $0.string(at: 0) ?? "" }.first ?? ""
            #expect(!observationSQL.contains("axis_card_account_mask"))
            #expect(!observationSQL.contains("axis_masked_card_number"))

            let eventColumns = try database.query(
                sql: "PRAGMA table_info(card_statement_semantic_projection_events);",
                params: []
            ) { $0.string(at: 1) ?? "" }
            #expect(eventColumns.contains("financial_date"))
            #expect(eventColumns.contains("financial_date_role"))
            #expect(eventColumns.contains("source_transaction_date"))
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_semantic_projection_events;") == 0)
        }
    }

    @Test func v14ToV15PreservesHistoricalAmexSemanticEvidence() throws {
        try withDatabase(named: "V14Preservation") { database in
            try database.runMigrations(Array(allMigrations.prefix(14)))
            try seedV14AmexSemanticGraph(in: database)

            let beforeSource = try rows(in: database, sql: "SELECT id,observation_kind,source_value FROM card_source_identity_observations ORDER BY id;", columns: 3)
            let beforeSections = try rows(in: database, sql: "SELECT id,observation_kind,source_value FROM card_statement_section_observations ORDER BY id;", columns: 3)
            let beforeSummary = try rows(in: database, sql: "SELECT id,component_code,money_currency,money_minor,money_decimal,date_value FROM card_statement_summary_components ORDER BY id;", columns: 6)

            let beforeProjectionEvents = try rows(
                in: database,
                sql: "SELECT id,posting_date,source_transaction_date,row_scope FROM card_statement_semantic_projection_events ORDER BY id;",
                columns: 4
            )

            try database.runMigrations(Array(allMigrations.prefix(15)))

            #expect(try rows(in: database, sql: "SELECT id,observation_kind,source_value FROM card_source_identity_observations ORDER BY id;", columns: 3) == beforeSource)
            #expect(try rows(in: database, sql: "SELECT id,observation_kind,source_value FROM card_statement_section_observations ORDER BY id;", columns: 3) == beforeSections)
            #expect(try rows(in: database, sql: "SELECT id,component_code,money_currency,money_minor,money_decimal,date_value FROM card_statement_summary_components ORDER BY id;", columns: 6) == beforeSummary)
            #expect(try rows(
                in: database,
                sql: "SELECT id,financial_date,source_transaction_date,row_scope FROM card_statement_semantic_projection_events ORDER BY id;",
                columns: 4
            ) == beforeProjectionEvents)
            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 15)
        }
    }

    @Test func v15AllowsMetadataFreeAxisStatementsAndDigestOwnedGroups() throws {
        try withDatabase(named: "V15MetadataFreeAxis") { database in
            try database.runMigrations(allMigrations)
            try seedV15ZeroSectionAxisShell(in: database)
            try database.execute(sql: """
            UPDATE card_statements
            SET statement_date = NULL, statement_start_date = NULL,
                statement_end_date = NULL, selected_statement_month = NULL
            WHERE id = 'statement-1';
            INSERT INTO card_statement_semantic_projections(
              id,workspace_id,liability_account_id,card_statement_id,document_id,import_session_id,
              algorithm,digest,institution_code,statement_family_code,parser_profile_id,
              parser_profile_version,statement_date,statement_start_date,statement_end_date,
              selected_statement_month,cycle_month,native_currency,event_count,section_count,
              reconciliation_rule_code,created_at
            ) VALUES(
              'projection-metadata-free','workspace-1','account-1','statement-1','document-1','session-1',
              'ledgerforge.axis-card-statement-multiset.sha256.v1',
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'Axis Bank','axis.credit-card@1','axis.credit-card.pdf','1',
              NULL,NULL,NULL,NULL,NULL,'INR',1,0,
              'axis.inr.previous-plus-row-ledger-equals-total-due.v1','2026-07-20T00:00:00Z'
            );
            """)

            #expect(throws: (any Error).self) {
                try database.execute(sql: """
                INSERT INTO card_statement_semantic_groups(
                  id,workspace_id,liability_account_id,institution_code,statement_family_code,
                  statement_start_date,statement_end_date,cycle_month,native_currency,
                  projection_algorithm,projection_digest,authoritative_projection_id,created_at
                ) VALUES(
                  'invalid-metadata-free-group','workspace-1','account-1','Axis Bank','axis.credit-card@1',
                  NULL,NULL,NULL,'INR','unrelated.algorithm',
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                  'projection-metadata-free','2026-07-20T00:00:00Z'
                );
                """)
            }

            try database.execute(sql: """
            INSERT INTO card_statement_semantic_groups(
              id,workspace_id,liability_account_id,institution_code,statement_family_code,
              statement_start_date,statement_end_date,cycle_month,native_currency,
              projection_algorithm,projection_digest,authoritative_projection_id,created_at
            ) VALUES(
              'metadata-free-group','workspace-1','account-1','Axis Bank','axis.credit-card@1',
              NULL,NULL,NULL,'INR','ledgerforge.axis-card-statement-multiset.sha256.v1',
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'projection-metadata-free','2026-07-20T00:00:00Z'
            );
            """)

            #expect(try database.queryInt(
                "SELECT COUNT(*) FROM card_statements WHERE id = 'statement-1' AND statement_date IS NULL AND statement_start_date IS NULL AND statement_end_date IS NULL AND selected_statement_month IS NULL;"
            ) == 1)
            #expect(try database.queryInt(
                "SELECT COUNT(*) FROM card_statement_semantic_groups WHERE id = 'metadata-free-group' AND statement_start_date IS NULL AND statement_end_date IS NULL AND cycle_month IS NULL;"
            ) == 1)
        }
    }

    @Test func v15BackfillsHistoricalAmexPostingDatesAndAllowsNullableSourceTransactionDate() throws {
        try withDatabase(named: "V15SemanticBackfill") { database in
            try database.runMigrations(Array(allMigrations.prefix(14)))
            try seedV14AmexSemanticGraph(in: database)

            try database.runMigrations(allMigrations)

            let backfilled = try database.query(
                sql: "SELECT financial_date,financial_date_role,source_transaction_date FROM card_statement_semantic_projection_events WHERE id = 'event-amex-old';",
                params: []
            ) { ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2)) }.first
            #expect(backfilled?.0 == "2026-07-20")
            #expect(backfilled?.1 == "posting_date")
            #expect(backfilled?.2 == "2026-07-19")

            try insertSecondAmexSemanticTransaction(in: database)
            try database.executePrepared(
                sql: "INSERT INTO card_statement_semantic_projection_events(id,projection_id,canonical_transaction_id,normalized_row_id,source_ordinal,financial_date,financial_date_role,source_transaction_date,liability_effect,posted_currency,posted_amount_minor,posted_amount_decimal,original_currency,original_amount_minor,original_amount_decimal,source_reference,row_scope,document_scoped_section_id,document_section_ordinal) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                params: ["event-null-source-date", "projection-amex", "transaction-posting-null-source", "row-posting-null-source", 2, "2026-07-21", "posting_date", NSNull(), "card_increase_owed", "USD", 250, "2.50", NSNull(), NSNull(), NSNull(), NSNull(), "instrument_level", "amex-section-1", 1]
            )
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_semantic_projection_events WHERE source_transaction_date IS NULL;") == 1)

            #expect(throws: (any Error).self) {
                try database.executePrepared(
                    sql: "INSERT INTO card_statement_semantic_projection_events(id,projection_id,canonical_transaction_id,normalized_row_id,source_ordinal,financial_date,financial_date_role,source_transaction_date,liability_effect,posted_currency,posted_amount_minor,posted_amount_decimal,original_currency,original_amount_minor,original_amount_decimal,source_reference,row_scope,document_scoped_section_id,document_section_ordinal) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                    params: ["event-unknown-role", "projection-amex", "transaction-posting-null-source", "row-posting-null-source", 3, "2026-07-21", "unknown_role", NSNull(), "card_increase_owed", "USD", 250, "2.50", NSNull(), NSNull(), NSNull(), NSNull(), "instrument_level", "amex-section-1", 1]
                )
            }
        }
    }

    @Test func v15RejectsLegacyAxisObservationAndSummaryCodesAndUnknownValues() throws {
            try withDatabase(named: "V15AxisChecks") { database in
                try database.runMigrations(allMigrations)
                try seedV15ZeroSectionAxisShell(in: database)
                try database.execute(sql: "UPDATE card_statements SET selected_statement_month = '2026-06' WHERE id = 'statement-1';")

                try database.executePrepared(
                    sql: "INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal) VALUES(?,?,?,?,?,?);",
                    params: ["axis-total-due", "statement-1", "axis_total_payment_due", "INR", 100, "1.00"]
                )

                for (index, kind) in ["axis_card_account_mask", "axis_masked_card_number"].enumerated() {
                    #expect(throws: (any Error).self) {
                        try database.executePrepared(
                            sql: "INSERT INTO card_source_identity_observations(id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,subject_kind,subject_id,observation_kind,source_value,association_authority,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?);",
                            params: ["axis-observation-\(index)", "workspace-1", "document-1", "session-1", "normalized-1", "axis.credit-card.pdf", "1", index == 0 ? "liability_account" : "instrument", index == 0 ? "account-1" : "instrument-1", kind, "AXIS-SANITIZED-\(index)", "user_confirmed", "2026-07-20T00:00:00Z"]
                        )
                    }
                }
                for (index, code) in [
                    "axis_payments", "axis_credits", "axis_purchases", "axis_cash_advance",
                    "axis_other_debit_charges", "axis_minimum_payment_due"
                ].enumerated() {
                    #expect(throws: (any Error).self) {
                        try database.executePrepared(
                            sql: "INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal) VALUES(?,?,?,?,?,?);",
                            params: ["axis-summary-\(index)", "statement-1", code, "INR", 200 + index, "\(200 + index).00"]
                        )
                    }
                }
                #expect(throws: (any Error).self) {
                    try database.executePrepared(
                        sql: "INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,date_value) VALUES(?,?,?,?);",
                        params: ["axis-summary-date", "statement-1", "axis_statement_generation_date", "2026-07-20"]
                    )
                }

            #expect(throws: (any Error).self) {
                try database.executePrepared(
                    sql: "INSERT INTO card_source_identity_observations(id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,subject_kind,subject_id,observation_kind,source_value,association_authority,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?);",
                    params: ["axis-observation-unknown", "workspace-1", "document-1", "session-1", "normalized-1", "axis.credit-card.pdf", "1", "liability_account", "account-1", "axis_unknown_kind", "AXIS-SANITIZED-X", "user_confirmed", "2026-07-20T00:00:00Z"]
                )
            }
            #expect(throws: (any Error).self) {
                try database.executePrepared(
                    sql: "INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal) VALUES(?,?,?,?,?,?);",
                    params: ["axis-summary-unknown", "statement-1", "axis_unknown_component", "INR", 1, "1.00"]
                )
            }
        }
    }

    private func seedV14AmexSemanticGraph(in database: SQLiteDatabase) throws {
        try database.execute(sql: """
        INSERT INTO workspaces(id,name,created_at) VALUES('amex-workspace','Sanitized Amex Workspace','2026-07-20T00:00:00Z');
        INSERT INTO accounts(id,workspace_id,name,account_type,native_currency,created_at) VALUES('amex-account','amex-workspace','Sanitized Amex Card','credit_card','USD','2026-07-20T00:00:00Z');
        INSERT INTO import_sessions(id,workspace_id,user_visible_name,started_at,completed_at,validation_status,created_at,parser_version) VALUES('amex-session','amex-workspace','Sanitized Amex Session','2026-07-20T00:00:00Z','2026-07-20T00:00:01Z','passed','2026-07-20T00:00:00Z','AmericanExpressCreditCardPDFParser');
        INSERT INTO documents(id,workspace_id,import_session_id,filename,mime_type,size_bytes,sha256,created_at) VALUES('amex-document','amex-workspace','amex-session','sanitized-amex.pdf','application/pdf',1,'synthetic-v14-amex-sha','2026-07-20T00:00:00Z');
        INSERT INTO normalized_documents(id,import_session_id,document_id,normalized_json,created_at,profile_id,profile_version) VALUES('amex-normalized','amex-session','amex-document','{}','2026-07-20T00:00:00Z','amex.credit-card.pdf','1');
        INSERT INTO normalized_rows(id,normalized_document_id,row_index,row_original,created_at) VALUES('row-amex-1','amex-normalized',1,'synthetic row','2026-07-20T00:00:00Z');
        INSERT INTO card_instruments(id,workspace_id,liability_account_id,lifecycle_state,created_at) VALUES('amex-instrument','amex-workspace','amex-account','active','2026-07-20T00:00:00Z');
        INSERT INTO card_source_identity_observations(id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,subject_kind,subject_id,observation_kind,source_value,association_authority,created_at) VALUES('amex-account-observation','amex-workspace','amex-document','amex-session','amex-normalized','amex.credit-card.pdf','1','liability_account','amex-account','amex_membership_number','AMEX-SANITIZED-MEMBER','user_confirmed','2026-07-20T00:00:00Z');
        INSERT INTO card_source_identity_observations(id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,subject_kind,subject_id,observation_kind,source_value,association_authority,created_at) VALUES('amex-instrument-observation','amex-workspace','amex-document','amex-session','amex-normalized','amex.credit-card.pdf','1','instrument','amex-instrument','amex_card_account_number','AMEX-SANITIZED-CARD','parser_strong_evidence','2026-07-20T00:00:00Z');
        INSERT INTO card_statements(id,workspace_id,liability_account_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,statement_date,statement_start_date,statement_end_date,statement_currency,source_row_count,reconciliation_rule_code,created_at) VALUES('amex-statement','amex-workspace','amex-account','amex-document','amex-session','amex-normalized','amex.credit-card.pdf','1','2026-07-20','2026-06-24','2026-07-23','USD',1,'amex.statement.summary.v1','2026-07-20T00:00:00Z');
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal,date_value) VALUES('amex-summary-previous','amex-statement','previous_balance','USD',100000,'1000.00',NULL);
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal,date_value) VALUES('amex-summary-credits','amex-statement','new_credits','USD',10000,'100.00',NULL);
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal,date_value) VALUES('amex-summary-debits','amex-statement','new_debits','USD',50000,'500.00',NULL);
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal,date_value) VALUES('amex-summary-balance','amex-statement','new_balance','USD',140000,'1400.00',NULL);
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal,date_value) VALUES('amex-summary-instrument','amex-statement','instrument_net_total','USD',50000,'500.00',NULL);
        INSERT INTO card_statement_summary_components(id,card_statement_id,component_code,money_currency,money_minor,money_decimal,date_value) VALUES('amex-summary-due-date','amex-statement','due_date',NULL,NULL,NULL,'2026-07-20');
        INSERT INTO transactions(id,workspace_id,account_id,import_session_id,document_id,posted_date,native_currency,amount_minor,amount_decimal,direction,created_at,financial_date_role,statement_timezone_evidence) VALUES('transaction-amex-old','amex-workspace','amex-account','amex-session','amex-document','2026-07-20','USD',50000,'500.00','card_increase_owed','2026-07-20T00:00:00Z','posting_date','unknown');
        INSERT INTO card_transaction_evidence(id,card_statement_id,transaction_id,row_scope,instrument_id,liability_effect,source_transaction_date,document_scoped_section_id) VALUES('evidence-amex-old','amex-statement','transaction-amex-old','instrument_level','amex-instrument','card_increase_owed','2026-07-19','amex-section-1');
        INSERT INTO card_statement_sections(id,card_statement_id,document_scoped_section_id,source_ordinal,instrument_id,holder_label,signed_total_currency,signed_total_minor,signed_total_decimal,reconciliation_rule_code) VALUES('section-amex-1','amex-statement','amex-section-1',1,'amex-instrument',NULL,'USD',50000,'500.00','amex.section.signed-increases-minus-decreases.v1');
        INSERT INTO card_statement_section_observations(id,card_statement_section_id,workspace_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,observation_kind,source_value,association_authority,created_at) VALUES('observation-amex-section','section-amex-1','amex-workspace','amex-document','amex-session','amex-normalized','amex.credit-card.pdf','1','amex_card_account_number','AMEX-SANITIZED-CARD','parser_strong_evidence','2026-07-20T00:00:00Z');
        INSERT INTO card_statement_semantic_projections(id,workspace_id,liability_account_id,card_statement_id,document_id,import_session_id,algorithm,digest,institution_code,statement_family_code,parser_profile_id,parser_profile_version,statement_date,statement_start_date,statement_end_date,native_currency,event_count,section_count,reconciliation_rule_code,created_at) VALUES('projection-amex','amex-workspace','amex-account','amex-statement','amex-document','amex-session','ledgerforge.amex-card-statement-semantic.sha256.v1','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','American Express','amex.credit-card.pdf@1','amex.credit-card.pdf','1','2026-07-20','2026-06-24','2026-07-23','USD',1,1,'amex.statement.summary.v1','2026-07-20T00:00:00Z');
        INSERT INTO card_statement_semantic_projection_sections(id,projection_id,source_ordinal,document_scoped_section_id,signed_total_currency,signed_total_minor,signed_total_decimal,reconciliation_rule_code) VALUES('projection-amex-section','projection-amex',1,'amex-section-1','USD',50000,'500.00','amex.section.signed-increases-minus-decreases.v1');
        INSERT INTO card_statement_semantic_projection_events(id,projection_id,canonical_transaction_id,normalized_row_id,source_ordinal,posting_date,source_transaction_date,liability_effect,posted_currency,posted_amount_minor,posted_amount_decimal,row_scope,document_scoped_section_id,document_section_ordinal) VALUES('event-amex-old','projection-amex','transaction-amex-old','row-amex-1',1,'2026-07-20','2026-07-19','card_increase_owed','USD',50000,'500.00','instrument_level','amex-section-1',1);
        """)
    }

    private func seedV15ZeroSectionAxisShell(in database: SQLiteDatabase) throws {
        try database.execute(sql: """
        INSERT INTO workspaces(id,name,created_at) VALUES('workspace-1','Sanitized Workspace','2026-07-20T00:00:00Z');
        INSERT INTO accounts(id,workspace_id,name,account_type,native_currency,created_at) VALUES('account-1','workspace-1','Sanitized Card','credit_card','INR','2026-07-20T00:00:00Z');
        INSERT INTO import_sessions(id,workspace_id,user_visible_name,started_at,completed_at,validation_status,created_at,parser_version) VALUES('session-1','workspace-1','Sanitized Card Session','2026-07-20T00:00:00Z','2026-07-20T00:00:01Z','passed','2026-07-20T00:00:00Z','Synthetic');
        INSERT INTO documents(id,workspace_id,import_session_id,filename,mime_type,size_bytes,sha256,created_at) VALUES('document-1','workspace-1','session-1','sanitized-axis-zero.pdf','application/pdf',1,'synthetic-v15-axis-zero-sha','2026-07-20T00:00:00Z');
        INSERT INTO normalized_documents(id,import_session_id,document_id,normalized_json,created_at,profile_id,profile_version) VALUES('normalized-1','session-1','document-1','{}','2026-07-20T00:00:00Z','axis.credit-card.pdf','1');
        INSERT INTO normalized_rows(id,normalized_document_id,row_index,row_original,created_at) VALUES('row-1','normalized-1',1,'synthetic row','2026-07-20T00:00:00Z');
        INSERT INTO card_statements(id,workspace_id,liability_account_id,document_id,import_session_id,normalized_document_id,parser_profile_id,parser_profile_version,statement_date,statement_start_date,statement_end_date,statement_currency,source_row_count,reconciliation_rule_code,created_at) VALUES('statement-1','workspace-1','account-1','document-1','session-1','normalized-1','axis.credit-card.pdf','1','2026-07-21','2026-06-20','2026-07-21','INR',1,'synthetic.axis.rule','2026-07-20T00:00:00Z');
        INSERT INTO transactions(id,workspace_id,account_id,import_session_id,document_id,posted_date,native_currency,amount_minor,amount_decimal,direction,created_at,financial_date_role,statement_timezone_evidence) VALUES('transaction-1','workspace-1','account-1','session-1','document-1','2026-07-20','INR',1000,'10.00','card_increase_owed','2026-07-20T00:00:00Z','transaction_date','unknown');
        """)
    }

    private func insertSecondAmexSemanticTransaction(in database: SQLiteDatabase) throws {
        try database.execute(sql: """
        INSERT INTO normalized_rows(id,normalized_document_id,row_index,row_original,created_at) VALUES('row-posting-null-source','amex-normalized',2,'synthetic row 2','2026-07-21T00:00:00Z');
        INSERT INTO transactions(id,workspace_id,account_id,import_session_id,document_id,posted_date,native_currency,amount_minor,amount_decimal,direction,created_at,financial_date_role,statement_timezone_evidence) VALUES('transaction-posting-null-source','amex-workspace','amex-account','amex-session','amex-document','2026-07-21','USD',250,'2.50','card_increase_owed','2026-07-21T00:00:00Z','posting_date','unknown');
        """)
    }

    private func rows(in database: SQLiteDatabase, sql: String, columns: Int) throws -> [String] {
        try database.query(sql: sql, params: []) { row in
            (0..<columns).map { row.string(at: Int32($0)) ?? "<NULL>" }.joined(separator: "|")
        }
    }

    private func withDatabase(named name: String, _ body: (SQLiteDatabase) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-AxisV15Tests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = SQLiteDatabase(path: folder.appendingPathComponent("database.sqlite").path)
        defer { database.close() }
        try body(database)
    }
}
