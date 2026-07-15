// LedgerForgeTests/RepositoryContractTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct RepositoryContractTests {

    @Test func importAttemptsUseBoundedCodesAndProviderParity() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let attempt = ImportAttemptDTO(
                id: "attempt-contract", workspaceId: fixture.workspaceId, createdAtISO: "2026-07-16T00:00:00Z",
                outcomeCode: ImportAttemptOutcome.validationFailure.rawValue,
                coverageCode: ImportAttemptCoverage.unsupportedOrUnevaluated.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
                guidanceCode: ImportAttemptGuidance.correctValidationAndRetry.rawValue,
                persistenceCode: ImportAttemptPersistence.rejectedRecorded.rawValue,
                transactionCount: 0
            )
            #expect(try provider.importSessionRepo.recordImportAttempt(attempt) == attempt.id)
            let stored = try #require(provider.importSessionRepo.importAttempts(workspaceId: fixture.workspaceId).first)
            #expect(stored == attempt)
            #expect(stored.accountId == nil)
            #expect(stored.importSessionId == nil)
            #expect(stored.documentId == nil)
        }
    }

    @Test func accountRepositoryCanUpsertAndRetrieveAccountData() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let original = account(id: "account-contract", workspaceId: fixture.workspaceId, name: "Primary Account", currency: "INR")
            let updated = account(id: "account-contract", workspaceId: fixture.workspaceId, name: "Updated Account", currency: "QAR")

            #expect(try provider.accountRepo.upsertAccount(original) == original.id)
            #expect(try provider.accountRepo.upsertAccount(updated) == updated.id)
            #expect(try provider.accountRepo.account(id: updated.id) == updated)
        }
    }

    @Test func accountRepositoryPreservesInstitutionAttribution() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let attributed = AccountDTO(
                id: "account-attributed",
                workspaceId: fixture.workspaceId,
                name: "Axis Bank INR",
                institutionId: "Axis Bank",
                accountType: "bank",
                nativeCurrency: "INR",
                description: "Attributed account",
                createdAtISO: "2026-07-06T12:01:00Z"
            )

            #expect(try provider.accountRepo.upsertAccount(attributed) == attributed.id)
            #expect(try provider.accountRepo.account(id: attributed.id) == attributed)
            #expect(try provider.accountRepo.accounts(workspaceId: fixture.workspaceId) == [attributed])
        }
    }

    @Test func accountRepositoryCanListAccountsForWorkspace() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let first = account(id: "account-b", workspaceId: fixture.workspaceId, name: "Beta Account", currency: "INR")
            let second = account(id: "account-a", workspaceId: fixture.workspaceId, name: "Alpha Account", currency: "INR")
            let otherWorkspace = WorkspaceDTO(id: "workspace-other", name: "Other Workspace", createdAtISO: "2026-07-06T12:00:00Z")
            let other = account(id: "account-other", workspaceId: otherWorkspace.id, name: "Other Account", currency: "INR")

            #expect(try provider.accountRepo.upsertAccount(first) == first.id)
            #expect(try provider.accountRepo.upsertAccount(second) == second.id)
            #expect(try provider.workspaceRepo.upsertWorkspace(otherWorkspace) == otherWorkspace.id)
            #expect(try provider.accountRepo.upsertAccount(other) == other.id)

            #expect(try provider.accountRepo.accounts(workspaceId: fixture.workspaceId) == [second, first])
        }
    }

    @Test func accountRepositoryUpdatesOnlyTrimmedDisplayName() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let original = AccountDTO(
                id: "account-display-name",
                workspaceId: fixture.workspaceId,
                name: "Original Name",
                institutionId: "Axis Bank",
                accountType: "bank",
                nativeCurrency: "INR",
                description: "Imported source metadata",
                createdAtISO: "2026-07-13T00:00:00Z"
            )
            let sibling = account(id: "account-sibling", workspaceId: fixture.workspaceId, name: "Original Name", currency: "INR")

            #expect(try provider.accountRepo.upsertAccount(original) == original.id)
            #expect(try provider.accountRepo.upsertAccount(sibling) == sibling.id)
            #expect(try provider.accountRepo.updateAccountDisplayName(
                accountId: original.id,
                workspaceId: fixture.workspaceId,
                displayName: "  Renamed Account  "
            ))

            #expect(try provider.accountRepo.account(id: original.id) == AccountDTO(
                id: original.id,
                workspaceId: original.workspaceId,
                name: "Renamed Account",
                institutionId: original.institutionId,
                accountType: original.accountType,
                nativeCurrency: original.nativeCurrency,
                description: original.description,
                createdAtISO: original.createdAtISO
            ))
            #expect(try provider.accountRepo.account(id: sibling.id) == sibling)
            #expect(!(try provider.accountRepo.updateAccountDisplayName(
                accountId: original.id,
                workspaceId: fixture.workspaceId,
                displayName: "Renamed Account"
            )))
            #expect(try provider.accountRepo.updateAccountDisplayName(
                accountId: original.id,
                workspaceId: fixture.workspaceId,
                displayName: "renamed account"
            ))

            #expect(throws: Error.self) {
                _ = try provider.accountRepo.updateAccountDisplayName(
                    accountId: original.id,
                    workspaceId: fixture.workspaceId,
                    displayName: "   "
                )
            }
            #expect(throws: Error.self) {
                _ = try provider.accountRepo.updateAccountDisplayName(
                    accountId: original.id,
                    workspaceId: "other-workspace",
                    displayName: "Different"
                )
            }
            #expect(throws: Error.self) {
                _ = try provider.accountRepo.updateAccountDisplayName(
                    accountId: "missing-account",
                    workspaceId: fixture.workspaceId,
                    displayName: "Different"
                )
            }
        }
    }

    @Test func sqliteDisplayNameUpdatePreservesUnmodelledAccountMetadataAndIdentifierRelationship() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForgeRepositoryContractTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("rename.sqlite").path)
        let workspace = WorkspaceDTO(id: "workspace-rename", name: "Rename Workspace", createdAtISO: "2026-07-13T00:00:00Z")
        let session = importSession(id: "session-rename", workspaceId: workspace.id)
        let original = AccountDTO(
            id: "account-rename",
            workspaceId: workspace.id,
            name: "Original Name",
            institutionId: "Axis",
            accountType: "bank",
            nativeCurrency: "INR",
            description: "Existing metadata",
            createdAtISO: "2026-07-13T00:01:00Z"
        )
        let identifier = AccountIdentifierDTO(
            id: "identifier-rename",
            accountId: original.id,
            workspaceId: workspace.id,
            scheme: FinancialIdentifierKind.institutionAccountId.rawValue,
            identifier: "opaque-verified-identifier",
            strength: FinancialIdentifierStrength.strong.rawValue,
            verificationState: FinancialIdentifierVerificationState.verified.rawValue,
            provenance: FinancialIdentifierProvenance.institutionStructuredField.rawValue,
            createdAtISO: "2026-07-13T00:02:00Z"
        )

        _ = try provider.workspaceRepo.upsertWorkspace(workspace)
        _ = try provider.importSessionRepo.createImportSession(session)
        _ = try provider.accountRepo.upsertAccount(original)
        try provider.database.executePrepared(
            sql: "UPDATE accounts SET closed_at = ?, created_from_import_session_id = ? WHERE id = ?;",
            params: ["2026-07-13T00:03:00Z", session.id, original.id]
        )
        _ = try provider.accountRepo.attachIdentifier(identifier)

        #expect(try provider.accountRepo.updateAccountDisplayName(
            accountId: original.id,
            workspaceId: workspace.id,
            displayName: " Renamed Account "
        ))

        let preservedMetadata = try provider.database.query(
            sql: "SELECT closed_at, created_from_import_session_id FROM accounts WHERE id = ?;",
            params: [original.id]
        ) { row in
            [row.string(at: 0), row.string(at: 1)]
        }.first
        #expect(preservedMetadata == ["2026-07-13T00:03:00Z", session.id])
        #expect(try provider.accountRepo.identifiers(accountId: original.id, workspaceId: workspace.id) == [identifier])
        #expect(try provider.importSessionRepo.importSession(id: session.id)?.id == session.id)
    }

    @Test func importSessionRepositoryCanCreateUpdateAndRetrieveSessionData() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let session = importSession(id: "session-contract", workspaceId: fixture.workspaceId)

            #expect(try provider.importSessionRepo.createImportSession(session) == session.id)
            try provider.importSessionRepo.updateImportSession(
                session.id,
                updates: PartialImportSessionUpdate(validationStatus: "passed", completedAtISO: "2026-07-06T12:05:00Z")
            )

            let stored = try provider.importSessionRepo.importSession(id: session.id)
            #expect(stored?.id == session.id)
            #expect(stored?.workspaceId == fixture.workspaceId)
            #expect(stored?.userVisibleName == session.userVisibleName)
            #expect(stored?.startedAtISO == session.startedAtISO)
            #expect(stored?.completedAtISO == "2026-07-06T12:05:00Z")
            #expect(stored?.validationStatus == "passed")
            #expect(stored?.readerVersion == session.readerVersion)
            #expect(stored?.parserVersion == session.parserVersion)
            #expect(stored?.layoutVersion == session.layoutVersion)
        }
    }

    @Test func transactionRepositoryCanReplaceTransactionsAtomicallyAndPreserveRelationships() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspaceAccountAndSession(provider)

            let firstTransaction = transaction(
                id: "transaction-1",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: 1250,
                amountDecimal: "12.50",
                direction: "credit"
            )

            let secondTransaction = transaction(
                id: "transaction-2",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: -500,
                amountDecimal: "-5.00",
                direction: "debit"
            )

            try provider.transactionRepo.replaceTransactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId,
                transactions: [firstTransaction, secondTransaction]
            )

            let originalStored = try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId
            )
            #expect(
                originalStored.sorted { $0.id < $1.id }
                    == [firstTransaction, secondTransaction]
            )

            let replacement = transaction(
                id: "transaction-3",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-2",
                amountMinor: 999,
                amountDecimal: "9.99",
                direction: "credit"
            )

            try provider.transactionRepo.replaceTransactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId,
                transactions: [replacement]
            )

            let replacedStored = try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId
            )
            #expect(replacedStored == [replacement])
            #expect(replacedStored.first?.workspaceId == fixture.workspaceId)
            #expect(replacedStored.first?.accountId == fixture.accountId)
            #expect(replacedStored.first?.importSessionId == fixture.importSessionId)
            #expect(replacedStored.first?.documentId == "document-2")

            let invalidTransaction = transaction(
                id: "transaction-invalid",
                workspaceId: "missing-workspace",
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-3",
                amountMinor: 1,
                amountDecimal: "0.01",
                direction: "credit"
            )

            do {
                try provider.transactionRepo.replaceTransactions(
                    workspaceId: fixture.workspaceId,
                    importSessionId: fixture.importSessionId,
                    transactions: [replacement, invalidTransaction]
                )
                Issue.record("Expected atomic replacement to fail for an invalid workspace relationship.")
            } catch {
                let afterFailedReplace = try provider.transactionRepo.transactions(
                    workspaceId: fixture.workspaceId,
                    importSessionId: fixture.importSessionId
                )
                #expect(afterFailedReplace == [replacement])
            }
        }
    }

    @Test func transactionRepositoryCanListTrustedTransactionsForDashboard() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspaceAccountAndSession(provider)
            let trusted = transaction(
                id: "transaction-trusted",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: 1250,
                amountDecimal: "12.50",
                direction: "credit",
                isTrusted: true
            )
            let untrusted = transaction(
                id: "transaction-untrusted",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: -500,
                amountDecimal: "-5.00",
                direction: "debit",
                isTrusted: false
            )

            try provider.transactionRepo.replaceTransactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId,
                transactions: [trusted, untrusted]
            )

            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: fixture.workspaceId) == [trusted])
        }
    }

    @Test func providersProduceSameObservableResults() async throws {
        let inMemorySnapshot = try runScenario(provider: makeInMemoryProvider())
        let sqliteSnapshot = try withTemporarySQLiteProvider { provider in
            try runScenario(provider: provider)
        }

        #expect(inMemorySnapshot == sqliteSnapshot)
    }

    @Test func atomicImportHistoryCommitAndDuplicateLookupHaveProviderParity() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let storedAccount = account(
                id: "account-atomic",
                workspaceId: fixture.workspaceId,
                name: "Atomic Account",
                currency: "INR"
            )
            _ = try provider.accountRepo.upsertAccount(storedAccount)
            let payload = atomicImportHistoryPayload(
                workspaceId: fixture.workspaceId,
                accountId: storedAccount.id
            )

            #expect(try provider.importSessionRepo.commitImportHistory(payload) == .committed)
            let prior = try #require(try provider.importSessionRepo.priorImportedStatement(
                algorithm: payload.fingerprint.algorithm,
                fingerprint: payload.fingerprint.fingerprint
            ))
            #expect(prior.importSessionId == payload.importSession.id)
            #expect(prior.completedAtISO == payload.completedAtISO)
            #expect(prior.transactionCount == payload.transactions.count)
            #expect(prior.accountId == storedAccount.id)
            #expect(prior.accountDisplayName == storedAccount.name)
            #expect(try provider.importSessionRepo.commitImportHistory(payload) == .duplicate(prior))
            #expect(try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: payload.importSession.id
            ).map(\.id).sorted() == payload.transactions.map(\.id).sorted())
        }
    }

    @Test func atomicImportHistoryRelationshipFailureLeavesNoDurableFingerprintSessionOrTransactions() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let storedAccount = account(
                id: "account-atomic-failure",
                workspaceId: fixture.workspaceId,
                name: "Atomic Failure Account",
                currency: "INR"
            )
            _ = try provider.accountRepo.upsertAccount(storedAccount)
            let valid = atomicImportHistoryPayload(
                workspaceId: fixture.workspaceId,
                accountId: storedAccount.id,
                suffix: "failure"
            )
            let invalid = AtomicImportHistoryDTO(
                document: valid.document,
                fingerprint: valid.fingerprint,
                importSession: valid.importSession,
                completedAtISO: valid.completedAtISO,
                transactions: valid.transactions.map { transaction in
                    TransactionDTO(
                        id: transaction.id,
                        workspaceId: "missing-workspace",
                        accountId: transaction.accountId,
                        importSessionId: transaction.importSessionId,
                        documentId: transaction.documentId,
                        originalRowId: transaction.originalRowId,
                        postedDateISO: transaction.postedDateISO,
                        valueDateISO: transaction.valueDateISO,
                        description: transaction.description,
                        payee: transaction.payee,
                        reference: transaction.reference,
                        nativeCurrency: transaction.nativeCurrency,
                        amountMinor: transaction.amountMinor,
                        amountDecimal: transaction.amountDecimal,
                        direction: transaction.direction,
                        runningBalanceMinor: transaction.runningBalanceMinor,
                        isReconciled: transaction.isReconciled,
                        isTrusted: transaction.isTrusted,
                        trustedAtISO: transaction.trustedAtISO,
                        createdAtISO: transaction.createdAtISO,
                        updatedAtISO: transaction.updatedAtISO,
                        rawRows: transaction.rawRows
                    )
                },
                successfulAttempt: valid.successfulAttempt
            )

            #expect(throws: Error.self) {
                _ = try provider.importSessionRepo.commitImportHistory(invalid)
            }
            #expect(try provider.importSessionRepo.importSession(id: valid.importSession.id) == nil)
            #expect(try provider.importSessionRepo.priorImportedStatement(
                algorithm: valid.fingerprint.algorithm,
                fingerprint: valid.fingerprint.fingerprint
            ) == nil)
            #expect(try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: valid.importSession.id
            ).isEmpty)
        }
    }

    @Test func atomicImportHistoryRejectsMixedAccountPayloadWithoutResidue() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let firstAccount = account(id: "account-atomic-first", workspaceId: fixture.workspaceId, name: "First Atomic Account", currency: "INR")
            let secondAccount = account(id: "account-atomic-second", workspaceId: fixture.workspaceId, name: "Second Atomic Account", currency: "INR")
            _ = try provider.accountRepo.upsertAccount(firstAccount)
            _ = try provider.accountRepo.upsertAccount(secondAccount)
            let valid = atomicImportHistoryPayload(workspaceId: fixture.workspaceId, accountId: firstAccount.id, suffix: "mixed-account")
            let mixed = AtomicImportHistoryDTO(
                document: valid.document,
                fingerprint: valid.fingerprint,
                importSession: valid.importSession,
                completedAtISO: valid.completedAtISO,
                transactions: valid.transactions + [transaction(
                    id: "transaction-atomic-mixed-account-second",
                    workspaceId: fixture.workspaceId,
                    accountId: secondAccount.id,
                    importSessionId: valid.importSession.id,
                    documentId: valid.document.id,
                    amountMinor: -500,
                    amountDecimal: "-5.00",
                    direction: "debit",
                    isTrusted: false
                )],
                successfulAttempt: valid.successfulAttempt
            )

            #expect(throws: Error.self) {
                _ = try provider.importSessionRepo.commitImportHistory(mixed)
            }
            #expect(try provider.importSessionRepo.importSession(id: valid.importSession.id) == nil)
            #expect(try provider.importSessionRepo.priorImportedStatement(
                algorithm: valid.fingerprint.algorithm,
                fingerprint: valid.fingerprint.fingerprint
            ) == nil)
            #expect(try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: valid.importSession.id
            ).isEmpty)
        }
    }

    @Test func sqliteAtomicImportHistoryRollsBackFingerprintTransactionAndCompletionFailures() throws {
        let failureTriggers = [
            "CREATE TRIGGER fail_fingerprint BEFORE INSERT ON document_fingerprints BEGIN SELECT RAISE(ABORT, 'fingerprint failure'); END;",
            "CREATE TRIGGER fail_transaction BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'transaction failure'); END;",
            "CREATE TRIGGER fail_completion BEFORE UPDATE OF validation_status ON import_sessions WHEN NEW.validation_status = 'passed' BEGIN SELECT RAISE(ABORT, 'completion failure'); END;"
        ]

        for (index, trigger) in failureTriggers.enumerated() {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("LedgerForgeAtomicFailureTests")
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("failure.sqlite").path)
            let workspace = WorkspaceDTO(id: "workspace-contract", name: "Contract Workspace", createdAtISO: "2026-07-14T00:00:00Z")
            let storedAccount = account(id: "account-atomic", workspaceId: workspace.id, name: "Atomic Account", currency: "INR")
            _ = try provider.workspaceRepo.upsertWorkspace(workspace)
            _ = try provider.accountRepo.upsertAccount(storedAccount)
            let unrelated = atomicImportHistoryPayload(
                workspaceId: workspace.id,
                accountId: storedAccount.id,
                suffix: "unrelated-\(index)"
            )
            #expect(try provider.importSessionRepo.commitImportHistory(unrelated) == .committed)
            let payload = atomicImportHistoryPayload(
                workspaceId: workspace.id,
                accountId: storedAccount.id,
                suffix: "trigger-\(index)"
            )
            try provider.database.execute(sql: trigger)

            #expect(throws: Error.self) {
                _ = try provider.importSessionRepo.commitImportHistory(payload)
            }
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM documents;") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM document_fingerprints;") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM import_sessions;") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM transactions;") == 2)
            #expect(try provider.importSessionRepo.priorImportedStatement(
                algorithm: unrelated.fingerprint.algorithm,
                fingerprint: unrelated.fingerprint.fingerprint
            ) != nil)
        }
    }

}

private struct RepositoryHandles {
    let name: String
    let workspaceRepo: WorkspaceRepository
    let accountRepo: AccountRepository
    let importSessionRepo: ImportSessionRepository
    let transactionRepo: TransactionRepository
}

private struct RepositoryFixture {
    let workspaceId: String
    let accountId: String?
    let importSessionId: String?
}

private struct RepositorySnapshot: Equatable {
    let workspace: WorkspaceDTO?
    let account: AccountDTO?
    let importSession: ImportSessionRecordDTO?
    let transactions: [TransactionDTO]
}

private func runForEachProvider(_ body: (RepositoryHandles) throws -> Void) throws {
    try body(makeInMemoryProvider())
    try withTemporarySQLiteProvider(body)
}

private func makeInMemoryProvider() -> RepositoryHandles {
    let provider = InMemoryRepositoryProvider()
    return RepositoryHandles(
        name: "InMemoryRepositoryProvider",
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
}

private func withTemporarySQLiteProvider<T>(_ body: (RepositoryHandles) throws -> T) throws -> T {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeRepositoryContractTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: folder)
    }

    let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("contract.sqlite").path)
    let handles = RepositoryHandles(
        name: "SQLiteRepositoryProvider",
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
    return try body(handles)
}

private func seedWorkspace(_ provider: RepositoryHandles) throws -> RepositoryFixture {
    let workspace = WorkspaceDTO(id: "workspace-contract", name: "Contract Workspace", createdAtISO: "2026-07-06T12:00:00Z")
    #expect(try provider.workspaceRepo.upsertWorkspace(workspace) == workspace.id)
    #expect(try provider.workspaceRepo.workspace(id: workspace.id) == workspace)
    return RepositoryFixture(workspaceId: workspace.id, accountId: nil, importSessionId: nil)
}

private func seedWorkspaceAccountAndSession(_ provider: RepositoryHandles) throws -> RepositoryFixture {
    let workspaceFixture = try seedWorkspace(provider)
    let account = account(id: "account-contract", workspaceId: workspaceFixture.workspaceId, name: "Primary Account", currency: "INR")
    let session = importSession(id: "session-contract", workspaceId: workspaceFixture.workspaceId)

    #expect(try provider.accountRepo.upsertAccount(account) == account.id)
    #expect(try provider.importSessionRepo.createImportSession(session) == session.id)

    return RepositoryFixture(workspaceId: workspaceFixture.workspaceId, accountId: account.id, importSessionId: session.id)
}

private func runScenario(provider: RepositoryHandles) throws -> RepositorySnapshot {
    let fixture = try seedWorkspaceAccountAndSession(provider)
    let updatedSessionCompletedAt = "2026-07-06T12:10:00Z"
    try provider.importSessionRepo.updateImportSession(
        fixture.importSessionId ?? "",
        updates: PartialImportSessionUpdate(validationStatus: "warning", completedAtISO: updatedSessionCompletedAt)
    )

    let storedTransaction = transaction(
        id: "transaction-contract",
        workspaceId: fixture.workspaceId,
        accountId: fixture.accountId,
        importSessionId: fixture.importSessionId,
        documentId: "document-contract",
        amountMinor: 4200,
        amountDecimal: "42.00",
        direction: "credit"
    )

    try provider.transactionRepo.replaceTransactions(
        workspaceId: fixture.workspaceId,
        importSessionId: fixture.importSessionId,
        transactions: [storedTransaction]
    )

    return RepositorySnapshot(
        workspace: try provider.workspaceRepo.workspace(id: fixture.workspaceId),
        account: try provider.accountRepo.account(id: fixture.accountId ?? ""),
        importSession: try provider.importSessionRepo.importSession(id: fixture.importSessionId ?? ""),
        transactions: try provider.transactionRepo.transactions(workspaceId: fixture.workspaceId, importSessionId: fixture.importSessionId)
    )
}

private func account(id: String, workspaceId: String, name: String, currency: String) -> AccountDTO {
    AccountDTO(
        id: id,
        workspaceId: workspaceId,
        name: name,
        institutionId: nil,
        accountType: "bank",
        nativeCurrency: currency,
        description: "Contract test account",
        createdAtISO: "2026-07-06T12:01:00Z"
    )
}

private func importSession(id: String, workspaceId: String) -> ImportSessionDTO {
    ImportSessionDTO(
        id: id,
        workspaceId: workspaceId,
        userVisibleName: "Contract Import",
        startedAtISO: "2026-07-06T12:02:00Z",
        validationStatus: "pending",
        readerVersion: "reader-contract",
        parserVersion: "parser-contract",
        layoutVersion: "layout-contract"
    )
}

private func transaction(id: String,
                         workspaceId: String,
                         accountId: String?,
                         importSessionId: String?,
                         documentId: String,
                         amountMinor: Int64,
                         amountDecimal: String,
                         direction: String,
                         isTrusted: Bool = false) -> TransactionDTO {
    TransactionDTO(
        id: id,
        workspaceId: workspaceId,
        accountId: accountId,
        importSessionId: importSessionId,
        documentId: documentId,
        originalRowId: nil,
        postedDateISO: "2026-07-06",
        valueDateISO: nil,
        description: "Contract transaction \(id)",
        payee: "Contract Payee",
        reference: "REF-\(id)",
        nativeCurrency: "INR",
        amountMinor: amountMinor,
        amountDecimal: amountDecimal,
        direction: direction,
        runningBalanceMinor: nil,
        isReconciled: false,
        isTrusted: isTrusted,
        trustedAtISO: isTrusted ? "2026-07-06T12:04:00Z" : nil,
        createdAtISO: "2026-07-06T12:03:00Z",
        updatedAtISO: nil,
        rawRows: []
    )
}

private func atomicImportHistoryPayload(
    workspaceId: String,
    accountId: String,
    suffix: String = "success"
) -> AtomicImportHistoryDTO {
    let sessionId = "session-atomic-\(suffix)"
    let documentId = "document-atomic-\(suffix)"
    let digest = ExactStatementFingerprint(text: "atomic history \(suffix)").digest
    let createdAt = "2026-07-14T09:00:00Z"
    return AtomicImportHistoryDTO(
        document: ImportedDocumentDTO(
            id: documentId,
            workspaceId: workspaceId,
            importSessionId: sessionId,
            filename: "atomic.csv",
            mimeType: "text/csv",
            sizeBytes: 22,
            sha256: digest,
            createdAtISO: createdAt
        ),
        fingerprint: DocumentFingerprintDTO(
            id: "fingerprint-atomic-\(suffix)",
            documentId: documentId,
            importSessionId: sessionId,
            algorithm: ExactStatementFingerprint.algorithm,
            fingerprint: digest,
            fingerprintData: nil,
            createdAtISO: createdAt
        ),
        importSession: ImportSessionDTO(
            id: sessionId,
            workspaceId: workspaceId,
            userVisibleName: "Atomic Import",
            startedAtISO: createdAt,
            validationStatus: "pending"
        ),
        completedAtISO: "2026-07-14T09:01:00Z",
        transactions: [
            transaction(
                id: "transaction-atomic-\(suffix)",
                workspaceId: workspaceId,
                accountId: accountId,
                importSessionId: sessionId,
                documentId: documentId,
                amountMinor: 1_000,
                amountDecimal: "10.00",
                direction: "credit",
                isTrusted: true
            ),
            transaction(
                id: "transaction-atomic-\(suffix)-untrusted",
                workspaceId: workspaceId,
                accountId: accountId,
                importSessionId: sessionId,
                documentId: documentId,
                amountMinor: -500,
                amountDecimal: "-5.00",
                direction: "debit",
                isTrusted: false
            )
        ],
        successfulAttempt: ImportAttemptDTO(
            id: "attempt-atomic-\(suffix)", workspaceId: workspaceId, createdAtISO: "2026-07-14T09:01:00Z",
            outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue,
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: 2, accountId: accountId, importSessionId: sessionId, documentId: documentId
        )
    )
}
