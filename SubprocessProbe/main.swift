import Foundation
import Darwin

private struct ProbeResult: Codable {
    let slot: String
    let pid: Int32
    let result: String
}

struct LedgerForgeSubprocessProbe {
    static func run() {
        let slot = CommandLine.arguments.count >= 5 ? CommandLine.arguments[4] : "unknown"
        guard CommandLine.arguments.count == 5 else { exit(slot: slot, with: "unavailable") }
        let databasePath = CommandLine.arguments[1]
        let scenario = CommandLine.arguments[2]
        let variant = CommandLine.arguments[3]
        let provider: SQLiteRepositoryProvider
        do {
            provider = try SQLiteRepositoryProvider(path: databasePath, migrations: allMigrations)
        } catch {
            exit(slot: slot, with: "unavailable")
        }
        writeLine("READY")
        guard readLine() == "GO" else { exit(slot: slot, with: "rejected") }

        let now = "2026-07-20T00:00:00Z"
        let shared = scenario == "exact"
        let suffix = shared ? "shared" : variant
        let workspace = WorkspaceDTO(id: "probe-workspace", name: "Probe", createdAtISO: now)
        let accountID = scenario == "event" ? "probe-existing-account" : scenario == "account" ? "probe-account-account-shared" : "probe-account-\(scenario)-\(suffix)"
        let account = AccountDTO(id: accountID, workspaceId: workspace.id, name: "Probe", nativeCurrency: "INR", createdAtISO: now)
        let session = ImportSessionDTO(id: "probe-session-\(scenario)-\(suffix)", workspaceId: workspace.id, startedAtISO: now)
        let document = ImportedDocumentDTO(id: "probe-document-\(scenario)-\(suffix)", workspaceId: workspace.id, importSessionId: session.id, filename: "probe", mimeType: nil, sizeBytes: nil, sha256: "probe-fingerprint-\(scenario)-\(suffix)", createdAtISO: now)
        let fingerprint = DocumentFingerprintDTO(id: "probe-fingerprint-\(scenario)-\(suffix)", documentId: document.id, importSessionId: session.id, algorithm: "sha256", fingerprint: "probe-fingerprint-\(scenario)-\(suffix)", fingerprintData: nil, createdAtISO: now)
        let attempt = ImportAttemptDTO(id: "probe-attempt-\(scenario)-\(suffix)", workspaceId: workspace.id, createdAtISO: now, outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue, accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue, guidanceCode: ImportAttemptGuidance.importCompleted.rawValue, persistenceCode: ImportAttemptPersistence.committed.rawValue, transactionCount: 1, accountId: account.id, importSessionId: session.id, documentId: document.id)
        let transactionID = scenario == "event" ? (variant == "1" ? "11111111-1111-1111-1111-111111111111" : "22222222-2222-2222-2222-222222222222") : "probe-transaction-\(scenario)-\(suffix)"
        let transaction = TransactionDTO(id: transactionID, workspaceId: workspace.id, postedDateISO: "2026-07-20", nativeCurrency: "INR", amountMinor: 100, amountDecimal: "1.00", direction: "debit", createdAtISO: now)
        let choice: ConfirmedImportAccountChoiceDTO = scenario == "event" ? .useExistingAccount(accountId: accountID) : .createProposedAccount
        let identifiers = scenario == "event" ? [] : [ConfirmedImportIdentifierCandidateDTO(scheme: "probe", normalizedValue: scenario == "identifier" ? "probe-owner-shared" : "probe-owner-\(suffix)", provenanceCode: "probe")]
        let event: ConfirmedImportTransactionEventEvidenceDTO? = scenario == "event" ? .axisUPI(ConfirmedImportAxisUPIEventEvidenceDTO(operation: .p2a, reference: "123456789012", subtype: .posting)) : nil
        let plan = ConfirmedImportPlanDTO(providerGeneration: provider.generationToken, workspace: workspace, proposedAccount: account, accountChoice: choice, advisoryIdentity: .noMatch, identifiers: identifiers, historyTemplate: ConfirmedImportHistoryTemplateDTO(document: document, fingerprint: fingerprint, importSession: session, completedAtISO: now, successfulAttempt: attempt), transactionTemplates: [ConfirmedImportTransactionTemplateDTO(transaction: transaction, eventEvidence: event)])
        let result: String
        switch provider.confirmedImportRepo.commitConfirmedImport(plan) {
        case .committed: result = "committed"
        case .exactDuplicate: result = "exact-duplicate"
        case .existingEventDuplicate: result = "existing-event-duplicate"
        case .identifierOwnershipConflict: result = "identifier-ownership-conflict"
        case .repositoryIntegrityConflict: result = "repository-integrity-conflict"
        case .retryableContention: result = "retryable-contention"
        default: result = "rejected"
        }
        provider.database.close()
        exit(slot: slot, with: result)
    }

    private static func exit(slot: String, with result: String) -> Never {
        let payload = ProbeResult(slot: slot, pid: ProcessInfo.processInfo.processIdentifier, result: result)
        let data = try! JSONEncoder().encode(payload)
        FileHandle.standardOutput.write(data + Data([10]))
        Darwin.exit(0)
    }

    private static func writeLine(_ line: String) {
        FileHandle.standardOutput.write(Data(line.utf8) + Data([10]))
    }
}

LedgerForgeSubprocessProbe.run()
