import Foundation
import Testing
import SQLite3
@testable import LedgerForge

struct ConfirmedImportRepositoryContractTests {
    @Test func mismatchedTransactionWorkspaceIsRejectedWithNoAcceptedResidueAcrossProviders() throws {
        try assertPlanRejectedAcrossProviders { token in
            let plan = confirmedImportPlan(generationToken: token, suffix: "mismatched-transaction")
            let template = plan.transactionTemplates[0]
            let mismatched = TransactionDTO(
                id: template.transaction.id,
                workspaceId: "wrong-workspace",
                postedDateISO: template.transaction.postedDateISO,
                nativeCurrency: template.transaction.nativeCurrency,
                amountMinor: template.transaction.amountMinor,
                amountDecimal: template.transaction.amountDecimal,
                direction: template.transaction.direction,
                createdAtISO: template.transaction.createdAtISO
            )
            return ConfirmedImportPlanDTO(
                providerGeneration: plan.providerGeneration,
                workspace: plan.workspace,
                proposedAccount: plan.proposedAccount,
                accountChoice: plan.accountChoice,
                advisoryIdentity: plan.advisoryIdentity,
                identifiers: plan.identifiers,
                historyTemplate: plan.historyTemplate,
                transactionTemplates: [ConfirmedImportTransactionTemplateDTO(transaction: mismatched, eventEvidence: template.eventEvidence)]
            )
        }
    }

    @Test func mismatchedSuccessfulAttemptWorkspaceIsRejectedWithNoAcceptedResidueAcrossProviders() throws {
        try assertPlanRejectedAcrossProviders { token in
            let plan = confirmedImportPlan(generationToken: token, suffix: "mismatched-attempt")
            let attempt = plan.historyTemplate.successfulAttempt
            let mismatchedAttempt = ImportAttemptDTO(
                id: attempt.id,
                workspaceId: "wrong-workspace",
                createdAtISO: attempt.createdAtISO,
                outcomeCode: attempt.outcomeCode,
                coverageCode: attempt.coverageCode,
                accountDecisionCode: attempt.accountDecisionCode,
                guidanceCode: attempt.guidanceCode,
                persistenceCode: attempt.persistenceCode,
                transactionCount: attempt.transactionCount,
                accountId: attempt.accountId,
                importSessionId: attempt.importSessionId,
                documentId: attempt.documentId
            )
            let history = ConfirmedImportHistoryTemplateDTO(
                document: plan.historyTemplate.document,
                fingerprint: plan.historyTemplate.fingerprint,
                importSession: plan.historyTemplate.importSession,
                completedAtISO: plan.historyTemplate.completedAtISO,
                successfulAttempt: mismatchedAttempt
            )
            return ConfirmedImportPlanDTO(
                providerGeneration: plan.providerGeneration,
                workspace: plan.workspace,
                proposedAccount: plan.proposedAccount,
                accountChoice: plan.accountChoice,
                advisoryIdentity: plan.advisoryIdentity,
                identifiers: plan.identifiers,
                historyTemplate: history,
                transactionTemplates: plan.transactionTemplates
            )
        }
    }

    @Test func duplicateIncomingTransactionIDsAreRejectedDeterministicallyAcrossProviders() throws {
        try assertPlanRejectedAcrossProviders { token in
            let plan = confirmedImportPlan(generationToken: token, suffix: "duplicate-transactions")
            return ConfirmedImportPlanDTO(
                providerGeneration: plan.providerGeneration,
                workspace: plan.workspace,
                proposedAccount: plan.proposedAccount,
                accountChoice: plan.accountChoice,
                advisoryIdentity: plan.advisoryIdentity,
                identifiers: plan.identifiers,
                historyTemplate: plan.historyTemplate,
                transactionTemplates: [plan.transactionTemplates[0], plan.transactionTemplates[0]]
            )
        }
    }

    @Test func duplicateIncomingIdentifierCandidatesAreRejectedDeterministicallyAcrossProviders() throws {
        try assertPlanRejectedAcrossProviders { token in
            let plan = confirmedImportPlan(generationToken: token, suffix: "duplicate-identifiers")
            return ConfirmedImportPlanDTO(
                providerGeneration: plan.providerGeneration,
                workspace: plan.workspace,
                proposedAccount: plan.proposedAccount,
                accountChoice: plan.accountChoice,
                advisoryIdentity: plan.advisoryIdentity,
                identifiers: [plan.identifiers[0], plan.identifiers[0]],
                historyTemplate: plan.historyTemplate,
                transactionTemplates: plan.transactionTemplates
            )
        }
    }

    @Test func sqliteBusyAndLockedErrorsAreRecognizedWithoutDiagnosticLeakage() {
        let busy = SQLiteExecutionError(primaryCode: SQLITE_BUSY, extendedCode: SQLITE_BUSY, operation: .transaction)
        let locked = SQLiteExecutionError(primaryCode: SQLITE_LOCKED, extendedCode: SQLITE_LOCKED, operation: .statement)

        #expect(busy.isRetryableContention)
        #expect(locked.isRetryableContention)
        #expect(!busy.description.contains("SELECT"))
    }

    @Test func sqliteUniqueConstraintIsRecognizedWithoutSQLInDescription() {
        let error = SQLiteExecutionError(
            primaryCode: SQLITE_CONSTRAINT,
            extendedCode: 2067,
            operation: .statement
        )

        #expect(error.isUniqueConstraint)
        #expect(!error.description.contains("identifier"))
        #expect(!error.description.contains("SELECT"))
    }

    @Test func confirmedImportResultsUsePrivacySafeDescriptions() {
        let results: [ConfirmedImportRepositoryResult] = [
            .exactDuplicate,
            .identifierOwnershipConflict,
            .retryableContention,
            .persistenceUnavailable
        ]

        for result in results {
            #expect(!result.description.lowercased().contains("sql"))
            #expect(!result.description.lowercased().contains("fingerprint"))
            #expect(!result.description.lowercased().contains("identifier"))
        }
    }

    @Test func accountIndependentTemplateCarriesNoEvidence() {
        let template = ConfirmedImportTransactionTemplateDTO(transaction: transaction())

        #expect(template.eventEvidence == nil)
        #expect(template.isAccountIndependent)
    }

    @Test func accountIndependentTemplateCarriesParserProducedAxisEvidence() throws {
        let evidence = ConfirmedImportTransactionEventEvidenceDTO.axisUPI(
            ConfirmedImportAxisUPIEventEvidenceDTO(operation: .p2a, reference: "123456789012", subtype: .posting)
        )
        let template = ConfirmedImportTransactionTemplateDTO(transaction: transaction(), eventEvidence: evidence)

        #expect(template.eventEvidence == evidence)
        let identity = try TransactionEventIdentity.make(
            transactionID: template.transaction.id,
            evidence: evidence,
            accountID: "account-a"
        )
        #expect(identity.accountID == "account-a")
    }

    @Test func accountPreassignmentIsDetectedBeforeProviderExecution() {
        let template = ConfirmedImportTransactionTemplateDTO(
            transaction: transaction(accountId: "preassigned-account")
        )

        #expect(!template.isAccountIndependent)
    }

    @Test func selectedAccountParticipatesInFinalEventDigest() throws {
        let evidence = ConfirmedImportTransactionEventEvidenceDTO.axisUPI(
            ConfirmedImportAxisUPIEventEvidenceDTO(operation: .p2m, reference: "123456789012", subtype: .creditAdjustment)
        )

        let first = try TransactionEventIdentity.make(transactionID: UUID().uuidString, evidence: evidence, accountID: "account-a")
        let second = try TransactionEventIdentity.make(transactionID: UUID().uuidString, evidence: evidence, accountID: "account-b")

        #expect(first.digest != second.digest)
    }

    private func transaction(accountId: String? = nil) -> TransactionDTO {
        TransactionDTO(
            workspaceId: "workspace",
            accountId: accountId,
            postedDateISO: "2026-07-20",
            nativeCurrency: "INR",
            amountMinor: 100,
            amountDecimal: "1.00",
            direction: "debit",
            createdAtISO: "2026-07-20T00:00:00Z"
        )
    }
}

private func assertPlanRejectedAcrossProviders(
    _ makePlan: (ProviderGenerationToken) -> ConfirmedImportPlanDTO
) throws {
    let memory = InMemoryRepositoryProvider()
    let memoryPlan = makePlan(memory.generationToken)
    #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .repositoryIntegrityConflict)
    #expect(try memory.workspaceRepo.workspace(id: memoryPlan.workspace.id) == nil)
    #expect(try memory.accountRepo.accounts(workspaceId: memoryPlan.workspace.id).isEmpty)
    #expect(try memory.importSessionRepo.importAttempts(workspaceId: memoryPlan.workspace.id).isEmpty)

    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("contract.sqlite").path, migrations: allMigrations)
    defer { sqlite.database.close() }
    let sqlitePlan = makePlan(sqlite.generationToken)
    #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .repositoryIntegrityConflict)
    #expect(try sqlite.workspaceRepo.workspace(id: sqlitePlan.workspace.id) == nil)
    #expect(try sqlite.accountRepo.accounts(workspaceId: sqlitePlan.workspace.id).isEmpty)
    #expect(try sqlite.importSessionRepo.importAttempts(workspaceId: sqlitePlan.workspace.id).isEmpty)
}
