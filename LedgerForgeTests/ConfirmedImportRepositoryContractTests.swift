import Foundation
import Testing
import SQLite3
@testable import LedgerForge

struct ConfirmedImportRepositoryContractTests {
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
