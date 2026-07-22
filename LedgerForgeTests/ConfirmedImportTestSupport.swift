// Shared privacy-safe fixtures for confirmed-import contract tests.

import Foundation
@testable import LedgerForge

func confirmedImportIdentifier(
    kind: FinancialIdentifierKind = .institutionAccountId,
    value: String = "AXIS-CONTRACT-001"
) throws -> FinancialIdentifier {
    try FinancialIdentifier(
        kind: kind,
        rawValue: value,
        verificationState: .verified,
        provenance: .institutionStructuredField
    )
}

func confirmedImportPlan(
    generationToken: ProviderGenerationToken,
    accountChoice: ConfirmedImportAccountChoiceDTO = .createProposedAccount,
    identifier: String = "AXIS-CONTRACT-001",
    fingerprint: String = "confirmed-import-fixture",
    suffix: String = "confirmed",
    institutionID: String? = nil
) -> ConfirmedImportPlanDTO {
    let now = "2026-07-20T00:00:00Z"
    let workspace = WorkspaceDTO(id: "workspace-confirmed", name: "Confirmed", createdAtISO: now)
    let account = AccountDTO(id: "account-\(suffix)", workspaceId: workspace.id, name: "Confirmed", institutionId: institutionID, nativeCurrency: "INR", createdAtISO: now)
    let session = ImportSessionDTO(id: "session-\(suffix)", workspaceId: workspace.id, startedAtISO: now)
    let document = ImportedDocumentDTO(id: "document-\(suffix)", workspaceId: workspace.id, importSessionId: session.id, filename: "fixture.csv", mimeType: "text/csv", sizeBytes: 1, sha256: fingerprint, createdAtISO: now)
    let fingerprintDTO = DocumentFingerprintDTO(id: "fingerprint-\(suffix)", documentId: document.id, importSessionId: session.id, algorithm: "sha256", fingerprint: fingerprint, fingerprintData: nil, createdAtISO: now)
    let attempt = ImportAttemptDTO(id: "attempt-\(suffix)", workspaceId: workspace.id, createdAtISO: now, outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue, accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue, guidanceCode: ImportAttemptGuidance.importCompleted.rawValue, persistenceCode: ImportAttemptPersistence.committed.rawValue, transactionCount: 1, accountId: account.id, importSessionId: session.id, documentId: document.id)
    let transactionID = suffix == "confirmed" ? "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA" : UUID().uuidString
    let normalizedDocument = NormalizedDocumentDTO(id: "normalized-document-\(suffix)", importSessionId: session.id, documentId: document.id, profileId: "fixture", profileVersion: "1")
    let normalizedRow = NormalizedRowDTO(id: "normalized-row-\(suffix)", normalizedDocumentId: normalizedDocument.id, sourceOrdinal: 1, digest: String.normalizedRecordDigest(values: ["confirmed", suffix]))
    let rawRow = TransactionRawRowDTO(id: "transaction-raw-row-\(suffix)", normalizedRowId: normalizedRow.id, contributionType: "transaction", sourceOrdinal: 1, normalizedRecordDigest: normalizedRow.digest, normalizedDocumentId: normalizedDocument.id)
    let transaction = TransactionDTO(id: transactionID, workspaceId: workspace.id, postedDateISO: "2026-07-20", nativeCurrency: "INR", amountMinor: 100, amountDecimal: "1.00", direction: "debit", createdAtISO: now, rawRows: [rawRow])
    return ConfirmedImportPlanDTO(providerGeneration: generationToken, workspace: workspace, proposedAccount: account, accountChoice: accountChoice, advisoryIdentity: .noMatch, identifiers: [ConfirmedImportIdentifierCandidateDTO(scheme: "institution-account", normalizedValue: identifier, provenanceCode: "fixture")], historyTemplate: ConfirmedImportHistoryTemplateDTO(document: document, fingerprint: fingerprintDTO, importSession: session, completedAtISO: now, successfulAttempt: attempt, normalizedDocument: normalizedDocument, normalizedRows: [normalizedRow]), transactionTemplates: [ConfirmedImportTransactionTemplateDTO(transaction: transaction, eventEvidence: .axisUPI(ConfirmedImportAxisUPIEventEvidenceDTO(operation: .p2a, reference: "123456789012", subtype: .posting)))])
}
