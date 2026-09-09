import Foundation
import Testing
@testable import LedgerForge

/// Independently recorded from accepted ab17d4b8dacd35f428b54fc7bb28ffb26df0829e:
/// Database/Migrations.swift and Database/IdentifierOwnershipMigrationV5.swift.
/// Never regenerate these expectations from candidate migrations. Changes to
/// accepted history require a separately approved compatibility decision.
struct MigrationIdentityLockTests {
    private struct Identity: Equatable {
        let version: Int
        let name: String
        let checksum: String
        init(_ version: Int, _ name: String, _ checksum: String) { self.version = version; self.name = name; self.checksum = checksum }
        init(_ migration: Migration) { self.init(migration.version, migration.name, migration.checksum) }
    }
    private let accepted: [Identity] = [
        .init(1, "initial_schema_v1", "9a8ae19022435e43097021ee8a8d44385c4e87086aea31a644c3a5a8b1e634ab"),
        .init(2, "import_session_version_columns", "7868c2cfbc745c13bdcf199f9bf1a42c81f9986b982d5c89938d0bc9b4300fc0"),
        .init(3, "transaction_event_identities", "6fe99f9778a47b241616be876aced1e20c45bcf49cdc115a9cc35d064ffea05f"),
        .init(4, "import_attempt_history", "effee0a04102ef9dcf1249762d44e3608a94376a671b84e7c3327b4c3b6d8cc0"),
        .init(5, "identifier_ownership_and_observations", "93978e9ebf32b1294fa726603c53b4cc178666905bbba7ef0cbc0a7b1b1684aa"),
        .init(6, "trusted_statement_dates_and_source_provenance", "7d5ec89fa71ae84fd093cddc31057bf06f94d25dbb304f537c5679ddbd1c157b"),
        .init(7, "reviewed_partial_overlap_import", "fbdb9e7d698dc44fe4ed70af5443b4a0daad625c2bba8b000b2f555c7e4179dd"),
        .init(8, "durable_transaction_categories", "273be20182c22aee8288fd3fc0992c13d94347a33591cd702c3ed2215608f226"),
        .init(9, "versioned_document_fingerprint_authority", "6d25a10de893e362db1349649d3cdabf149e4d532f98cfb0910c6a232281c9f5"),
        .init(10, "exact_cross_format_statement_equivalence", "c1c7192d787c8b0008560e6878664f766b6692ea7256a77538ede1c4054f19e5"),
        .init(11, "CBQ exact source observations and masked identity evidence", "72c7e7626af1be29a1b612808b1272653eb3af4ed106d9c5c82331192805b8dc"),
        .init(12, "durable credit card instruments and statement evidence", "dce79b98bf5f5996c5bd014181f2aeeb7774f1d37d28aef7221dded94d212ec3"),
        .init(13, "multi-section card statements and exact semantic sources", "bf4a14ce5a188d5afd2b2108ea3a745be950e033ef9516b299f77eb183bc7ba5"),
        .init(14, "generalized card reconciliation and structural section evidence", "b3de565507ec2ac1f9cc0f550024d987c5d17c5f3375805bcb75e84811bd5369"),
        .init(15, "Axis card observations and representation-neutral semantic events", "52a7d4715c09ebc361721cccaf3bc7983fa4ac0eebd167f4859bbab8deb8b35d"),
        .init(16, "Qatar Airways salary actuals and current-month funding plans", "8b64c97024d2ac0992a15505d2022a4b8ed8bbd4f4134c9bfbbe50b18cbe0fc8"),
        .init(17, "zero-activity controls, CBQ minimum amount due, and Axis statement equivalence", "f7250835a4446507ab77b7f1a9eeb65ed8a1568ccbc538fc8b777c4a54a98836")
    ]

    @Test func acceptedHistoryRemainsPinned() {
        #expect(allMigrations.prefix(17).map(Identity.init) == accepted)
    }

    @Test func lockDetectsNameSQLPreflightAndExecutionModeDrift() {
        // Isolated schema definitions only; no financial input or persisted history is changed.
        let original = migrationV17
        let mutations = [
            Migration(version: 17, name: "changed", sql: original.sql, preflightChecks: original.preflightChecks, requiresForeignKeysDisabled: original.requiresForeignKeysDisabled),
            Migration(version: 17, name: original.name, sql: original.sql + "\nSELECT 1;", preflightChecks: original.preflightChecks, requiresForeignKeysDisabled: original.requiresForeignKeysDisabled),
            Migration(version: 17, name: original.name, sql: original.sql, preflightChecks: [MigrationPreflightCheck(issueCode: "changed", run: { _ in true })], requiresForeignKeysDisabled: original.requiresForeignKeysDisabled),
            Migration(version: 17, name: original.name, sql: original.sql, preflightChecks: original.preflightChecks, requiresForeignKeysDisabled: !original.requiresForeignKeysDisabled)
        ]
        for mutation in mutations { #expect(Identity(mutation) != accepted[16]) }
    }
}
