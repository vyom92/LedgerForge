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

    @Test func sqliteSameIDWorkspaceUpsertPreservesDurableGraph() throws {
        try withTemporarySQLiteParentUpsertProvider { provider in
            let graph = try seedParentUpsertGraph(in: provider)
            let updatedWorkspace = WorkspaceDTO(
                id: graph.workspace.id,
                name: "Updated Parent Workspace",
                createdAtISO: "2026-07-18T10:00:00Z",
                updatedAtISO: "2026-07-18T10:05:00Z"
            )

            #expect(try provider.workspaceRepo.upsertWorkspace(updatedWorkspace) == updatedWorkspace.id)

            #expect(try provider.workspaceRepo.workspace(id: graph.workspace.id) == updatedWorkspace)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM accounts WHERE workspace_id = 'workspace-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM account_identifiers WHERE account_id = 'account-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM documents WHERE workspace_id = 'workspace-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM import_sessions WHERE workspace_id = 'workspace-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM normalized_documents WHERE import_session_id = 'session-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM normalized_rows WHERE normalized_document_id = 'normalized-document-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM transactions WHERE workspace_id = 'workspace-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM transaction_raw_rows WHERE transaction_id = 'transaction-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM import_attempts WHERE workspace_id = 'workspace-parent-upsert';") == 1)
            #expect(try provider.accountRepo.account(id: graph.account.id) == graph.account)
            #expect(try provider.accountRepo.identifiers(accountId: graph.account.id, workspaceId: graph.workspace.id) == [graph.identifier])
            #expect(try provider.transactionRepo.transactions(workspaceId: graph.workspace.id, importSessionId: graph.importSession.id) == [graph.transaction])
            #expect(try provider.importSessionRepo.importSession(id: graph.importSession.id)?.id == graph.importSession.id)
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: graph.workspace.id) == [graph.importAttempt])
            #expect(try foreignKeyViolations(in: provider.database).isEmpty)
        }
    }

    @Test func sqliteSameIDAccountUpsertPreservesDurableGraphAndUnownedColumns() throws {
        try withTemporarySQLiteParentUpsertProvider { provider in
            let graph = try seedParentUpsertGraph(in: provider)
            let closedAt = "2026-07-18T10:10:00Z"
            try provider.database.executePrepared(
                sql: "UPDATE accounts SET closed_at = ?, created_from_import_session_id = ? WHERE id = ?;",
                params: [closedAt, graph.importSession.id, graph.account.id]
            )
            let updatedAccount = AccountDTO(
                id: graph.account.id,
                workspaceId: graph.workspace.id,
                name: "Updated Parent Account",
                institutionId: "Updated Institution",
                accountType: "bank",
                nativeCurrency: "INR",
                description: "Updated DTO-owned metadata",
                createdAtISO: "2026-07-18T10:15:00Z"
            )

            #expect(try provider.accountRepo.upsertAccount(updatedAccount) == updatedAccount.id)

            #expect(try provider.accountRepo.account(id: graph.account.id) == updatedAccount)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM accounts WHERE id = 'account-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM account_identifiers WHERE account_id = 'account-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM transactions WHERE account_id = 'account-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM transaction_raw_rows WHERE transaction_id = 'transaction-parent-upsert';") == 1)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM import_attempts WHERE account_id = 'account-parent-upsert';") == 1)
            #expect(try provider.accountRepo.identifiers(accountId: graph.account.id, workspaceId: graph.workspace.id) == [graph.identifier])
            #expect(try provider.transactionRepo.transactions(workspaceId: graph.workspace.id, importSessionId: graph.importSession.id) == [graph.transaction])
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: graph.workspace.id) == [graph.importAttempt])
            let unownedColumns = try provider.database.query(
                sql: "SELECT closed_at, created_from_import_session_id FROM accounts WHERE id = ?;",
                params: [graph.account.id]
            ) { row in
                [row.string(at: 0), row.string(at: 1)]
            }.first
            #expect(unownedColumns?[0] == closedAt)
            #expect(unownedColumns?[1] == graph.importSession.id)
            #expect(try foreignKeyViolations(in: provider.database).isEmpty)
        }
    }

    @Test func sameIDParentUpsertsPreserveRepositoryGraphWithProviderParity() throws {
        try runForEachProvider { provider in
            let workspace = WorkspaceDTO(
                id: "workspace-parent-parity",
                name: "Parent Parity Workspace",
                createdAtISO: "2026-07-18T11:00:00Z"
            )
            let account = AccountDTO(
                id: "account-parent-parity",
                workspaceId: workspace.id,
                name: "Parent Parity Account",
                institutionId: "Parity Institution",
                accountType: "bank",
                nativeCurrency: "INR",
                description: "Original parity metadata",
                createdAtISO: "2026-07-18T11:01:00Z"
            )
            let session = ImportSessionDTO(
                id: "session-parent-parity",
                workspaceId: workspace.id,
                userVisibleName: "Parent Parity Import",
                startedAtISO: "2026-07-18T11:02:00Z",
                validationStatus: "passed"
            )
            let identifier = AccountIdentifierDTO(
                id: "identifier-parent-parity",
                accountId: account.id,
                workspaceId: workspace.id,
                scheme: FinancialIdentifierKind.institutionAccountId.rawValue,
                identifier: "parent-parity-identifier",
                strength: FinancialIdentifierStrength.strong.rawValue,
                verificationState: FinancialIdentifierVerificationState.verified.rawValue,
                provenance: FinancialIdentifierProvenance.institutionStructuredField.rawValue,
                createdAtISO: "2026-07-18T11:03:00Z"
            )
            let transaction = transaction(
                id: "transaction-parent-parity",
                workspaceId: workspace.id,
                accountId: account.id,
                importSessionId: session.id,
                documentId: "document-parent-parity",
                amountMinor: 1_300,
                amountDecimal: "13.00",
                direction: "credit"
            )
            let attempt = ImportAttemptDTO(
                id: "attempt-parent-parity",
                workspaceId: workspace.id,
                createdAtISO: "2026-07-18T11:04:00Z",
                outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
                coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue,
                guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
                persistenceCode: ImportAttemptPersistence.committed.rawValue,
                transactionCount: 1,
                accountId: account.id,
                importSessionId: session.id,
                documentId: nil
            )

            _ = try provider.workspaceRepo.upsertWorkspace(workspace)
            _ = try provider.accountRepo.upsertAccount(account)
            _ = try provider.importSessionRepo.createImportSession(session)
            _ = try provider.accountRepo.attachIdentifier(identifier)
            try provider.transactionRepo.replaceTransactions(
                workspaceId: workspace.id,
                importSessionId: session.id,
                transactions: [transaction]
            )
            _ = try provider.importSessionRepo.recordImportAttempt(attempt)

            let updatedWorkspace = WorkspaceDTO(
                id: workspace.id,
                name: "Updated Parent Parity Workspace",
                createdAtISO: "2026-07-18T11:05:00Z",
                updatedAtISO: "2026-07-18T11:06:00Z"
            )
            _ = try provider.workspaceRepo.upsertWorkspace(updatedWorkspace)
            _ = try provider.workspaceRepo.upsertWorkspace(updatedWorkspace)

            #expect(try provider.workspaceRepo.workspace(id: workspace.id) == updatedWorkspace)
            #expect(try provider.accountRepo.account(id: account.id) == account)
            #expect(try provider.accountRepo.identifiers(accountId: account.id, workspaceId: workspace.id) == [identifier])
            #expect(try provider.importSessionRepo.importSession(id: session.id)?.id == session.id)
            #expect(try provider.transactionRepo.transactions(workspaceId: workspace.id, importSessionId: session.id) == [transaction])
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspace.id) == [attempt])

            let updatedAccount = AccountDTO(
                id: account.id,
                workspaceId: workspace.id,
                name: "Updated Parent Parity Account",
                institutionId: "Updated Parity Institution",
                accountType: "bank",
                nativeCurrency: "QAR",
                description: "Updated parity metadata",
                createdAtISO: "2026-07-18T11:07:00Z"
            )
            _ = try provider.accountRepo.upsertAccount(updatedAccount)
            _ = try provider.accountRepo.upsertAccount(updatedAccount)

            #expect(try provider.accountRepo.account(id: account.id) == updatedAccount)
            #expect(try provider.accountRepo.identifiers(accountId: account.id, workspaceId: workspace.id) == [identifier])
            #expect(try provider.importSessionRepo.importSession(id: session.id)?.id == session.id)
            #expect(try provider.transactionRepo.transactions(workspaceId: workspace.id, importSessionId: session.id) == [transaction])
            #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspace.id) == [attempt])
        }
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

    @Test func sqliteV3DatabaseMigratesToV4WithAuthoritativeAttemptBackfillAndNoInventedHistory() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForgeV3ToV4MigrationTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let databasePath = folder.appendingPathComponent("v3.sqlite").path
        let v3Database = SQLiteDatabase(path: databasePath)
        try v3Database.open()
        try v3Database.runMigrations(Array(allMigrations.prefix(3)))

        let workspaceID = "workspace-v3"
        let accountID = "account-v3"
        let sessionID = "session-v3-completed"
        let documentID = "document-v3"
        let identifierID = "identifier-v3"
        let fingerprintID = "fingerprint-v3"
        let eventID = "event-v3"
        let completedAt = "2026-07-16T09:05:00Z"
        let fingerprint = "fictional-fingerprint-v3"
        let eventDigest = "fictional-event-digest-v3"

        try v3Database.executePrepared(
            sql: "INSERT INTO workspaces (id, name, created_at) VALUES (?,?,?);",
            params: [workspaceID, "Migration Workspace", "2026-07-16T09:00:00Z"]
        )
        try v3Database.executePrepared(
            sql: "INSERT INTO accounts (id, workspace_id, name, native_currency, created_at) VALUES (?,?,?,?,?);",
            params: [accountID, workspaceID, "Migration Account", "INR", "2026-07-16T09:00:00Z"]
        )
        try v3Database.executePrepared(
            sql: "INSERT INTO account_identifiers (id, account_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?);",
            params: [identifierID, accountID, "institution_account_id", "fictional-verified-account", "fixture", "2026-07-16T09:00:00Z"]
        )
        try v3Database.executePrepared(
            sql: "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, completed_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?,?);",
            params: [sessionID, workspaceID, "Migration Import", "2026-07-16T09:00:00Z", completedAt, "passed", "2026-07-16T09:00:00Z", "reader-v3", "parser-v3", "layout-v3"]
        )
        try v3Database.executePrepared(
            sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, sha256, storage_path, extracted_text_snippet, created_at) VALUES (?,?,?,?,?,?,?,?);",
            params: [documentID, workspaceID, sessionID, "fictional-source.csv", fingerprint, "fictional/private/path", "fictional source fragment", "2026-07-16T09:00:00Z"]
        )
        try v3Database.executePrepared(
            sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at) VALUES (?,?,?,?,?,?);",
            params: [fingerprintID, documentID, sessionID, "fictional.algorithm.v1", fingerprint, "2026-07-16T09:00:00Z"]
        )
        for (index, amount, balance) in [("transaction-v3-a", 2_500, 2_500), ("transaction-v3-b", -700, 1_800)] {
            try v3Database.executePrepared(
                sql: "INSERT INTO transactions (id, workspace_id, account_id, import_session_id, document_id, posted_date, description, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_trusted, trusted_at, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                params: [index, workspaceID, accountID, sessionID, documentID, "2026-07-16", "fictional narrative", "fictional-reference", "INR", amount, try Money.fromMinorUnits(Int64(amount), currency: "INR").canonicalDecimalString(), amount < 0 ? "debit" : "credit", balance, 1, completedAt, "2026-07-16T09:00:00Z"]
            )
        }
        try v3Database.executePrepared(
            sql: "INSERT INTO transaction_event_identities (id, transaction_id, account_id, document_id, import_session_id, algorithm, digest, created_at) VALUES (?,?,?,?,?,?,?,?);",
            params: [eventID, "transaction-v3-a", accountID, documentID, sessionID, "fictional.event.v1", eventDigest, "2026-07-16T09:00:00Z"]
        )
        #expect(try v3Database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 3)
        #expect(try v3Database.queryInt("SELECT COUNT(*) FROM import_sessions;") == 1)
        #expect(try v3Database.queryInt("SELECT COUNT(*) FROM transactions;") == 2)
        v3Database.close()

        let provider = try SQLiteRepositoryProvider(path: databasePath, migrations: Array(allMigrations.prefix(5)))
        defer { provider.database.close() }
        #expect(try provider.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == migrationV5.version)
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM import_attempts;") == 1)
        #expect(try provider.database.query(sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_import_attempts_workspace_created';") { _ in true }.count == 1)
        let foreignKeyTables = try provider.database.query(sql: "PRAGMA foreign_key_list(import_attempts);") { $0.string(at: 2) ?? "" }
        #expect(Set(foreignKeyTables) == ["workspaces", "accounts", "import_sessions", "documents"])

        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        #expect(attempts.count == 1)
        let attempt = try #require(attempts.first)
        #expect(attempt.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue)
        #expect(attempt.workspaceId == workspaceID)
        #expect(attempt.importSessionId == sessionID)
        #expect(attempt.documentId == documentID)
        #expect(attempt.accountId == accountID)
        #expect(attempt.transactionCount == 2)
        #expect(attempt.createdAtISO == completedAt)
        #expect(!attempts.contains { $0.outcomeCode != ImportAttemptOutcome.successfulImport.rawValue })

        #expect(try provider.workspaceRepo.workspace(id: workspaceID)?.id == workspaceID)
        #expect(try provider.accountRepo.account(id: accountID)?.id == accountID)
        #expect(try provider.accountRepo.identifiers(accountId: accountID, workspaceId: workspaceID).map(\.id) == [identifierID])
        #expect(try provider.importSessionRepo.importSession(id: sessionID)?.completedAtISO == completedAt)
        let preservedTransactions = try provider.database.query(
            sql: "SELECT id, amount_minor, workspace_id, account_id, import_session_id, document_id FROM transactions WHERE import_session_id = ? ORDER BY amount_minor ASC;",
            params: [sessionID]
        ) { row in
            (row.string(at: 0) ?? "", row.int64(at: 1) ?? 0, row.string(at: 2), row.string(at: 3), row.string(at: 4), row.string(at: 5))
        }
        #expect(preservedTransactions.map(\.0) == ["transaction-v3-b", "transaction-v3-a"])
        #expect(preservedTransactions.map(\.1) == [-700, 2_500])
        #expect(preservedTransactions.allSatisfy { $0.2 == workspaceID && $0.3 == accountID && $0.4 == sessionID && $0.5 == documentID })
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM documents WHERE id = 'document-v3';") == 1)
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM document_fingerprints WHERE id = 'fingerprint-v3' AND fingerprint = 'fictional-fingerprint-v3';") == 1)
        #expect(try provider.database.queryInt("SELECT COUNT(*) FROM transaction_event_identities WHERE id = 'event-v3' AND digest = 'fictional-event-digest-v3';") == 1)
        #expect(try provider.database.queryInt("SELECT SUM(amount_minor) FROM transactions WHERE import_session_id = 'session-v3-completed';") == 1_800)

        let persistedAttemptColumns = try provider.database.query(sql: "PRAGMA table_info(import_attempts);") { $0.string(at: 1) ?? "" }
        #expect(persistedAttemptColumns == ["id", "workspace_id", "created_at", "outcome_code", "coverage_code", "account_decision_code", "guidance_code", "persistence_code", "transaction_count", "account_id", "import_session_id", "document_id", "related_import_session_id"])
        let persistedAttemptText = try provider.database.query(sql: "SELECT id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id FROM import_attempts;") { row in
            (0...12).compactMap { row.string(at: Int32($0)) }.joined(separator: "|")
        }.joined(separator: "\n")
        for prohibited in ["fictional-source.csv", "fictional/private/path", "fictional source fragment", fingerprint, eventDigest, "fictional-reference", "fictional narrative", "fictional-verified-account"] {
            #expect(!persistedAttemptText.contains(prohibited))
        }

        let reopenedProvider = try SQLiteRepositoryProvider(path: databasePath, migrations: Array(allMigrations.prefix(5)))
        defer { reopenedProvider.database.close() }
        #expect(try reopenedProvider.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == migrationV5.version)
        #expect(try reopenedProvider.importSessionRepo.importAttempts(workspaceId: workspaceID) == attempts)
        #expect(try reopenedProvider.database.queryInt("SELECT COUNT(*) FROM import_attempts;") == 1)
        #expect(try reopenedProvider.database.queryInt("SELECT COUNT(*) FROM transactions;") == 2)

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

private struct ParentUpsertGraph {
    let workspace: WorkspaceDTO
    let account: AccountDTO
    let importSession: ImportSessionDTO
    let transaction: TransactionDTO
    let identifier: AccountIdentifierDTO
    let importAttempt: ImportAttemptDTO
}

private func withTemporarySQLiteParentUpsertProvider<T>(_ body: (SQLiteRepositoryProvider) throws -> T) throws -> T {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeParentUpsertTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    return try body(SQLiteRepositoryProvider(path: folder.appendingPathComponent("parent-upsert.sqlite").path))
}

private func seedParentUpsertGraph(in provider: SQLiteRepositoryProvider) throws -> ParentUpsertGraph {
    let workspace = WorkspaceDTO(
        id: "workspace-parent-upsert",
        name: "Parent Upsert Workspace",
        createdAtISO: "2026-07-18T09:00:00Z"
    )
    let account = AccountDTO(
        id: "account-parent-upsert",
        workspaceId: workspace.id,
        name: "Parent Upsert Account",
        institutionId: "Original Institution",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Original DTO-owned metadata",
        createdAtISO: "2026-07-18T09:01:00Z"
    )
    let importSession = ImportSessionDTO(
        id: "session-parent-upsert",
        workspaceId: workspace.id,
        userVisibleName: "Parent Upsert Import",
        startedAtISO: "2026-07-18T09:02:00Z",
        validationStatus: "passed"
    )
    let identifier = AccountIdentifierDTO(
        id: "identifier-parent-upsert",
        accountId: account.id,
        workspaceId: workspace.id,
        scheme: FinancialIdentifierKind.institutionAccountId.rawValue,
        identifier: "parent-upsert-identifier",
        strength: FinancialIdentifierStrength.strong.rawValue,
        verificationState: FinancialIdentifierVerificationState.verified.rawValue,
        provenance: FinancialIdentifierProvenance.institutionStructuredField.rawValue,
        createdAtISO: "2026-07-18T09:03:00Z"
    )
    let transaction = TransactionDTO(
        id: "transaction-parent-upsert",
        workspaceId: workspace.id,
        accountId: account.id,
        importSessionId: importSession.id,
        documentId: "document-parent-upsert",
        originalRowId: nil,
        postedDateISO: "2026-07-18",
        valueDateISO: nil,
        description: "Parent upsert transaction",
        payee: "Parent upsert payee",
        reference: "PARENT-UPSERT",
        nativeCurrency: "INR",
        amountMinor: 1_250,
        amountDecimal: "12.50",
        direction: "credit",
        runningBalanceMinor: 1_250,
        isReconciled: false,
        isTrusted: true,
        trustedAtISO: "2026-07-18T09:04:00Z",
        createdAtISO: "2026-07-18T09:04:00Z",
        updatedAtISO: nil,
        rawRows: [
            TransactionRawRowDTO(
                id: "raw-parent-upsert",
                normalizedRowId: "normalized-row-parent-upsert",
                contributionType: "transaction",
                sourceOrdinal: 0,
                normalizedDocumentId: "normalized-document-parent-upsert"
            )
        ]
    )
    let importAttempt = ImportAttemptDTO(
        id: "attempt-parent-upsert",
        workspaceId: workspace.id,
        createdAtISO: "2026-07-18T09:05:00Z",
        outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
        coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
        accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue,
        guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
        persistenceCode: ImportAttemptPersistence.committed.rawValue,
        transactionCount: 1,
        accountId: account.id,
        importSessionId: importSession.id,
        documentId: "document-parent-upsert"
    )

    _ = try provider.workspaceRepo.upsertWorkspace(workspace)
    _ = try provider.accountRepo.upsertAccount(account)
    _ = try provider.importSessionRepo.createImportSession(importSession)
    try provider.database.executePrepared(
        sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, sha256, created_at) VALUES (?,?,?,?,?,?);",
        params: ["document-parent-upsert", workspace.id, importSession.id, "parent-upsert.csv", "parent-upsert-sha", "2026-07-18T09:02:00Z"]
    )
    try provider.database.executePrepared(
        sql: "INSERT INTO normalized_documents (id, import_session_id, document_id, normalized_json, created_at) VALUES (?,?,?,?,?);",
        params: ["normalized-document-parent-upsert", importSession.id, "document-parent-upsert", "{}", "2026-07-18T09:03:00Z"]
    )
    try provider.database.executePrepared(
        sql: "INSERT INTO normalized_rows (id, normalized_document_id, row_index, row_original, created_at) VALUES (?,?,?,?,?);",
        params: ["normalized-row-parent-upsert", "normalized-document-parent-upsert", 0, "parent-upsert-row", "2026-07-18T09:03:00Z"]
    )
    _ = try provider.accountRepo.attachIdentifier(identifier)
    try provider.transactionRepo.replaceTransactions(
        workspaceId: workspace.id,
        importSessionId: importSession.id,
        transactions: [transaction]
    )
    _ = try provider.importSessionRepo.recordImportAttempt(importAttempt)

    return ParentUpsertGraph(
        workspace: workspace,
        account: account,
        importSession: importSession,
        transaction: transaction,
        identifier: identifier,
        importAttempt: importAttempt
    )
}

private func foreignKeyViolations(in database: SQLiteDatabase) throws -> [String] {
    try database.query(sql: "PRAGMA foreign_key_check;") { row in
        (0...3).compactMap { row.string(at: Int32($0)) }.joined(separator: "|")
    }
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
