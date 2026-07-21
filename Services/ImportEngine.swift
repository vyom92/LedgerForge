//
// LedgerForge
// ImportEngine.swift
// Version: 0.1.1
//

import CryptoKit
import Foundation

struct ExactStatementFingerprint: Equatable, Sendable {
    static let algorithm = "ledgerforge.raw-text.sha256.v1"

    let algorithm: String
    let digest: String
    let byteCount: Int64

    init(text: String) {
        let bytes = Data(text.utf8)
        self.algorithm = Self.algorithm
        self.digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        self.byteCount = Int64(bytes.count)
    }
}

struct ImportEngineResult: Equatable {
    enum HydrationOutcome: Equatable {
        case notRequired
        case committedAndHydrated
        case committedReconciliationRequired
    }

    let fileName: String
    let transactionCount: Int
    let validationPassed: Bool
    let persisted: Bool
    let errorMessage: String?
    let accountId: String?
    let importSessionId: String?
    let redactedIdentifier: String?
    let previousImport: PreviouslyImportedStatement?
    let transactionEventBlock: TransactionEventBlock?
    let importAttemptId: String?
    let hydrationOutcome: HydrationOutcome

    init(
        fileName: String,
        transactionCount: Int,
        validationPassed: Bool,
        persisted: Bool,
        errorMessage: String?,
        accountId: String? = nil,
        importSessionId: String? = nil,
        redactedIdentifier: String? = nil,
        previousImport: PreviouslyImportedStatement? = nil,
        transactionEventBlock: TransactionEventBlock? = nil,
        importAttemptId: String? = nil,
        hydrationOutcome: HydrationOutcome? = nil
    ) {
        self.fileName = fileName
        self.transactionCount = transactionCount
        self.validationPassed = validationPassed
        self.persisted = persisted
        self.errorMessage = errorMessage
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.redactedIdentifier = redactedIdentifier
        self.previousImport = previousImport
        self.transactionEventBlock = transactionEventBlock
        self.importAttemptId = importAttemptId
        self.hydrationOutcome = hydrationOutcome ?? (persisted ? .committedAndHydrated : .notRequired)
    }

    var succeeded: Bool {
        validationPassed && persisted && hydrationOutcome == .committedAndHydrated && errorMessage == nil
    }

    var requiresHydration: Bool {
        false
    }

    var requiresImportAttemptRefresh: Bool { importAttemptId != nil && !persisted }

    var requiresReconciliation: Bool { hydrationOutcome == .committedReconciliationRequired }
}

enum ImportEngineCommitError: Error, LocalizedError, Equatable {
    case validationFailed
    case alreadyCommitted
    case persistenceSkipped
    case fingerprintMismatch

    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Import validation failed."
        case .alreadyCommitted:
            return "Prepared import has already been committed."
        case .persistenceSkipped:
            return "Import persistence was skipped."
        case .fingerprintMismatch:
            return "Prepared statement content no longer matches its exact-content fingerprint."
        }
    }

}

struct PreparedImport: Identifiable {
    let id: UUID
    let sourceURL: URL
    let rawContents: String
    let fileName: String
    let detectedInstitution: Institution
    let detectedDocumentType: DocumentType
    let parserName: String
    let financialDocument: FinancialDocument
    let validation: ImportValidationResult
    let importSession: ImportSession
    let fingerprint: ExactStatementFingerprint
    let advisoryPreviousImport: PreviouslyImportedStatement?
    let providerGeneration: ProviderGenerationToken

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        rawContents: String,
        fileName: String,
        detectedInstitution: Institution,
        detectedDocumentType: DocumentType,
        parserName: String,
        financialDocument: FinancialDocument,
        validation: ImportValidationResult,
        importSession: ImportSession,
        fingerprint: ExactStatementFingerprint? = nil,
        advisoryPreviousImport: PreviouslyImportedStatement? = nil,
        providerGeneration: ProviderGenerationToken = DatabaseProvider.shared.generationToken
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.rawContents = rawContents
        self.fileName = fileName
        self.detectedInstitution = detectedInstitution
        self.detectedDocumentType = detectedDocumentType
        self.parserName = parserName
        self.financialDocument = financialDocument
        self.validation = validation
        self.importSession = importSession
        self.fingerprint = fingerprint ?? ExactStatementFingerprint(text: rawContents)
        self.advisoryPreviousImport = advisoryPreviousImport
        self.providerGeneration = providerGeneration
    }

    var transactionCount: Int {
        financialDocument.transactions.count
    }

    var detectedCurrency: String? {
        financialDocument.bookedCurrency?.code ?? validation.statementCurrency?.code
    }

    var statementPeriod: ClosedRange<Date>? {
        let dates = financialDocument.transactions.compactMap(\.date).sorted()
        guard let first = dates.first, let last = dates.last else {
            return nil
        }
        return first...last
    }

    var accountMetadata: String? {
        financialDocument.transactions.first?.account
    }

}

final class ImportEngine {

    static let shared = ImportEngine()

    private let importCoordinator: any ImportFramework.ImportCoordinator
    private let importPersistenceCoordinatorFactory: () -> ImportPersistenceCoordinating
    private let persistenceStateProvider: () -> PersistenceState
    private let providerGenerationProvider: () -> ProviderGenerationToken
    private let forcedHydration: () throws -> RepositoryStoreHydrationResult
    private let rejectedAttemptHydration: () throws -> Void
    private let reconciliationGate: ConfirmedImportReconciliationGate
    private let developerConsole: DeveloperConsole
    private let committedPreparedImportLock = NSLock()
    private var committedPreparedImportIDs: Set<UUID> = []
#if DEBUG
    private var lifecycleLeases: [UUID: DevelopmentDatabaseActivityLease] = [:]
#endif

    init(
        importCoordinator: any ImportFramework.ImportCoordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(),
            passwordProvider: DefaultPasswordProvider()
        ),
        importPersistenceCoordinator: ImportPersistenceCoordinating? = nil,
        developerConsole: DeveloperConsole = .shared,
        persistenceStateProvider: @escaping () -> PersistenceState = { DatabaseProvider.shared.persistenceState },
        providerGenerationProvider: @escaping () -> ProviderGenerationToken = { DatabaseProvider.shared.generationToken },
        forcedHydration: @escaping () throws -> RepositoryStoreHydrationResult = {
            try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        },
        rejectedAttemptHydration: @escaping () throws -> Void = {
            try RepositoryStoreHydrator().hydrateImportAttempts()
        },
        reconciliationGate: ConfirmedImportReconciliationGate = ConfirmedImportReconciliationGate()
    ) {
        self.importCoordinator = importCoordinator
        self.developerConsole = developerConsole
        self.persistenceStateProvider = persistenceStateProvider
        self.providerGenerationProvider = providerGenerationProvider
        self.forcedHydration = forcedHydration
        self.rejectedAttemptHydration = rejectedAttemptHydration
        self.reconciliationGate = reconciliationGate
        if let importPersistenceCoordinator {
            self.importPersistenceCoordinatorFactory = {
                importPersistenceCoordinator
            }
        } else {
            self.importPersistenceCoordinatorFactory = {
                DefaultImportPersistenceCoordinator()
            }
        }
    }

    func importFile(from url: URL) {
        Task {
            _ = await importFileAndReturnResult(from: url)
        }
    }

    func importFileAndReturnResult(from url: URL) async -> ImportEngineResult {
        let entryCountBeforeImport = developerConsole.entries.count
        developerConsole.info(.`import`, "Import started", metadata: ["file": url.lastPathComponent])

        do {
            let preparedImport = try await prepareImport(from: url)

            let result = await commitPreparedImport(preparedImport)
            if result.succeeded {
                developerConsole.info(.`import`, "Import completed", metadata: ["file": result.fileName, "transactions": "\(result.transactionCount)"])
            } else if result.previousImport != nil {
                developerConsole.info(.`import`, "Previously imported statement blocked", metadata: ["transactions": "\(result.transactionCount)"])
            } else if result.transactionEventBlock != nil {
                developerConsole.info(.`import`, "Verified transaction event blocked")
            } else {
                developerConsole.error(.`import`, "Import failed", metadata: ["file": result.fileName, "error": result.errorMessage ?? "Unknown error"])
            }
            return result

        } catch {

            if developerConsole.entries.count == entryCountBeforeImport + 1 {
                developerConsole.error(.`import`, error.localizedDescription, metadata: ["file": url.lastPathComponent])
            }
            developerConsole.error(.`import`, "Import failed", metadata: ["file": url.lastPathComponent, "error": error.localizedDescription])
            return ImportEngineResult(
                fileName: url.lastPathComponent,
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: error.localizedDescription,
                accountId: nil,
                importSessionId: nil,
                redactedIdentifier: nil,
                previousImport: nil
            )

        }

    }

    func prepareImport(
        from url: URL,
        requestId: UUID = UUID(),
        progress: @escaping (ImportProgress) -> Void = { _ in }
    ) async throws -> PreparedImport {
        guard persistenceStateProvider().isUsable else {
            throw PersistenceWorkflowError.unavailable
        }
        let preparationGeneration = providerGenerationProvider()
#if DEBUG
        let lifecycleLease = try DevelopmentDatabaseActivityGate.shared.begin(.importPreparation)
        var transfersLifecycleLease = false
        defer {
            if !transfersLifecycleLease { lifecycleLease.finish() }
        }
#endif
        try publishPreparationProgress(.openingSource, requestId: requestId, progress: progress)
        let contents = try await readTextDocument(from: url)
        try Task.checkCancellation()
        let fingerprint = ExactStatementFingerprint(text: contents)

        guard !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            developerConsole.error(.`import`, "Imported document is empty.")
            throw ImportError.invalidDocument(message: "Imported document is empty.")
        }

        try publishPreparationProgress(.detectingInstitution, requestId: requestId, progress: progress)
        let metadata = InstitutionDetector().detect(from: contents)

        try publishPreparationProgress(.classifyingStatement, requestId: requestId, progress: progress)
        let analyzer = CSVAnalyzer()
        let document = analyzer.analyze(
            text: contents,
            fileURL: url
        )

        let normalizer = CSVNormalizer()
        let normalization = normalizer.normalizeWithSourceContext(
            text: contents,
            document: document
        )

        try publishPreparationProgress(.selectingParser, requestId: requestId, progress: progress)
        let parser = StatementParserRegistry.shared.parser(
            for: document,
            metadata: metadata
        )

        developerConsole.info(.`import`, "Institution detected", metadata: ["institution": metadata.institution.rawValue])
        developerConsole.info(.`import`, "Parser selected", metadata: ["parser": parser?.name ?? "None"])

        // Parser internals (Debug)
        developerConsole.debug(.parser, "Detected document", metadata: [
            "file": document.filename,
            "rows": "\(document.rowCount)",
            "columns": "\(document.columnCount)",
            "headerRow": "\(document.headerRow ?? -1)",
            "firstTxnRow": "\(document.firstTransactionRow ?? -1)",
            "delimiter": String(document.delimiter ?? "?"),
            "encoding": document.encoding ?? "Unknown"
        ])
        developerConsole.debug(.parser, "Normalization details", metadata: [
            "normalizedRows": "\(normalization.rows.count)"
        ])

        guard let parser else {
            developerConsole.warning(.`import`, "No suitable parser found.")
            throw ImportError.invalidDocument(message: "No suitable parser found.")
        }

        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: normalization.rows,
            header: normalization.header,
            sourceContext: normalization.sourceContext
        )

        try publishPreparationProgress(.parsingFinancialContent, requestId: requestId, progress: progress)
        let financialDocument = try parser.parse(
            document: normalizedDocument
        )
        try Task.checkCancellation()
        developerConsole.debug(.parser, "Row count", metadata: ["transactions": "\(financialDocument.transactions.count)"])

        try publishPreparationProgress(.validatingPreparedContent, requestId: requestId, progress: progress)
        let validation = ImportValidator.validate(
            financialDocument: financialDocument
        )
        try Task.checkCancellation()
        developerConsole.info(.validation, "Validation completed", metadata: ["passed": validation.passed ? "true" : "false", "issues": "\(validation.issues.count)"])

        let importSession = ImportSession(
            fileName: document.filename,
            institution: metadata.institution,
            documentType: metadata.documentType,
            parserName: parser.name,
            transactionCount: financialDocument.transactions.count,
            validation: validation
        )
        let advisoryPreviousImport = validation.passed
            ? try importPersistenceCoordinatorFactory().priorImportedStatement(fingerprint: fingerprint)
            : nil
        try Task.checkCancellation()

        try publishPreparationProgress(.preparingConfirmationPreview, requestId: requestId, progress: progress)

        let preparedImport = PreparedImport(
            sourceURL: url,
            rawContents: contents,
            fileName: document.filename,
            detectedInstitution: metadata.institution,
            detectedDocumentType: metadata.documentType,
            parserName: parser.name,
            financialDocument: financialDocument,
            validation: validation,
            importSession: importSession,
            fingerprint: fingerprint,
            advisoryPreviousImport: advisoryPreviousImport,
            providerGeneration: preparationGeneration
        )
#if DEBUG
        lifecycleLease.transition(to: .preparedAwaitingConfirmation)
        lifecycleLeases[preparedImport.id] = lifecycleLease
        transfersLifecycleLease = true
#endif
        return preparedImport
    }

    func commitPreparedImport(_ preparedImport: PreparedImport) async -> ImportEngineResult {
        await commitPreparedImport(preparedImport, accountChoice: nil)
    }

    func reviewPreparedImport(_ preparedImport: PreparedImport) throws -> ImportIdentityReview {
        guard persistenceStateProvider().isUsable else {
            throw PersistenceWorkflowError.unavailable
        }
        guard !reconciliationGate.isBlocked else { return .unavailable }
        return try importPersistenceCoordinatorFactory().reviewValidatedImport(
            financialDocument: preparedImport.financialDocument,
            validation: preparedImport.validation
        )
    }

    func commitPreparedImport(
        _ preparedImport: PreparedImport,
        accountChoice: ImportAccountChoice?
    ) async -> ImportEngineResult {
#if DEBUG
        let lifecycleLease = lifecycleLeases[preparedImport.id]
        lifecycleLease?.transition(to: .confirmedPersistence)
        defer {
            lifecycleLease?.finish()
            lifecycleLeases.removeValue(forKey: preparedImport.id)
        }
#endif
        guard persistenceStateProvider().isUsable else {
            developerConsole.error(.database, "Import blocked because persistence is unavailable")
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: PersistenceWorkflowError.unavailable.localizedDescription
            )
        }
        guard !reconciliationGate.isBlocked else {
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: "Canonical reconciliation is required before another import can be confirmed.",
                hydrationOutcome: .committedReconciliationRequired
            )
        }
        guard preparedImport.validation.passed else {
            let attemptID = importPersistenceCoordinatorFactory().recordValidationFailure(fileName: preparedImport.fileName, transactionCount: preparedImport.transactionCount)
            developerConsole.error(.validation, "Validation failed", metadata: ["file": preparedImport.fileName])
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: false,
                persisted: false,
                errorMessage: ImportEngineCommitError.validationFailed.localizedDescription,
                accountId: nil,
                importSessionId: nil,
                redactedIdentifier: nil,
                previousImport: nil,
                importAttemptId: attemptID
            )
        }

        guard ExactStatementFingerprint(text: preparedImport.rawContents) == preparedImport.fingerprint else {
            developerConsole.error(.`import`, "Prepared exact-content fingerprint verification failed")
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: true,
                persisted: false,
                errorMessage: ImportEngineCommitError.fingerprintMismatch.localizedDescription,
                accountId: nil,
                importSessionId: nil,
                redactedIdentifier: nil,
                previousImport: nil
            )
        }

        guard markPreparedImportCommitted(preparedImport.id) else {
            developerConsole.warning(.`import`, "Prepared import already committed", metadata: ["file": preparedImport.fileName])
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: true,
                persisted: false,
                errorMessage: ImportEngineCommitError.alreadyCommitted.localizedDescription,
                accountId: nil,
                importSessionId: nil,
                redactedIdentifier: nil,
                previousImport: nil
            )
        }

        var persistenceResult = ImportPersistenceResult.skipped
        var persistenceErrorMessage: String?
        do {
            let importPersistenceCoordinator = importPersistenceCoordinatorFactory()
            persistenceResult = try importPersistenceCoordinator.persistValidatedImport(
                financialDocument: preparedImport.financialDocument,
                importSession: preparedImport.importSession,
                validation: preparedImport.validation,
                fingerprint: preparedImport.fingerprint,
                accountChoice: accountChoice,
                providerGeneration: preparedImport.providerGeneration
            )
            if persistenceResult.persisted {
                developerConsole.info(.database, "Repository persistence completed")
            } else if persistenceResult.previousImport != nil {
                developerConsole.info(.database, "Repository persistence blocked for previously imported statement")
            } else if let block = persistenceResult.transactionEventBlock {
                persistenceErrorMessage = Self.message(for: block)
                developerConsole.info(.database, "Repository persistence blocked for verified transaction event")
            } else {
                persistenceErrorMessage = ImportEngineCommitError.persistenceSkipped.localizedDescription
                developerConsole.error(.database, "Repository persistence skipped")
            }
        } catch {
            developerConsole.error(.database, "Repository persistence failed", metadata: ["error": error.localizedDescription])
            if let failure = error as? ImportPersistenceCommitFailure {
                persistenceErrorMessage = failure.originalError.localizedDescription
                persistenceResult = ImportPersistenceResult(
                    persisted: false,
                    workspaceId: nil,
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: preparedImport.transactionCount,
                    importAttemptId: failure.importAttemptId
                )
            } else {
                persistenceErrorMessage = error.localizedDescription
            }
        }

        var hydrationOutcome: ImportEngineResult.HydrationOutcome = .notRequired
        if persistenceResult.persisted {
            do {
                _ = try forcedHydration()
                reconciliationGate.clearAfterCanonicalHydration()
                hydrationOutcome = .committedAndHydrated
            } catch {
                reconciliationGate.requireReconciliation()
                hydrationOutcome = .committedReconciliationRequired
                persistenceErrorMessage = "Import committed, but canonical reconciliation is required."
                developerConsole.error(.database, "Committed import requires canonical reconciliation")
            }
        } else if persistenceResult.importAttemptId != nil {
            do { try rejectedAttemptHydration() }
            catch { developerConsole.warning(.database, "Import attempt refresh unavailable") }
        }

        return ImportEngineResult(
            fileName: preparedImport.fileName,
            transactionCount: persistenceResult.previousImport?.transactionCount ?? preparedImport.transactionCount,
            validationPassed: true,
            persisted: persistenceResult.persisted,
            errorMessage: persistenceErrorMessage,
            accountId: persistenceResult.accountId,
            importSessionId: persistenceResult.importSessionId,
            redactedIdentifier: persistenceResult.persisted
                ? redactedEligibleIdentifier(in: preparedImport.financialDocument)
                : nil,
            previousImport: persistenceResult.previousImport,
            transactionEventBlock: persistenceResult.transactionEventBlock,
            importAttemptId: persistenceResult.importAttemptId,
            hydrationOutcome: hydrationOutcome
        )
    }

    @discardableResult
    func retryCanonicalHydration() -> Bool {
        guard reconciliationGate.isBlocked else { return true }
        do {
            _ = try forcedHydration()
            reconciliationGate.clearAfterCanonicalHydration()
            return true
        } catch {
            reconciliationGate.requireReconciliation()
            return false
        }
    }

    private static func message(for block: TransactionEventBlock) -> String {
        switch block {
        case .existing:
            return "Overlapping eligible transactions found. Statement blocked."
        case .repeatedIncoming:
            return "Repeated verified transaction evidence found. Statement blocked."
        case .ownershipConflict:
            return "Transaction-event ownership conflict. No transaction history was written."
        case .repositoryIntegrityConflict:
            return "Repository integrity conflict. No transaction history was written."
        }
    }

    private func redactedEligibleIdentifier(in financialDocument: FinancialDocument) -> String? {
        let identifiers = financialDocument.financialIdentifiers.filter {
            $0.strength == .strong && $0.verificationState == .verified
        }
        guard identifiers.count == 1 else { return nil }
        return FinancialIdentifier.redacted(identifiers[0].normalizedValue)
    }

    private func markPreparedImportCommitted(_ id: UUID) -> Bool {
        committedPreparedImportLock.lock()
        defer {
            committedPreparedImportLock.unlock()
        }

        guard !committedPreparedImportIDs.contains(id) else {
            return false
        }

        committedPreparedImportIDs.insert(id)
        return true
    }

#if DEBUG
    func cancelPreparedImport(_ preparedImport: PreparedImport) {
        lifecycleLeases.removeValue(forKey: preparedImport.id)?.finish()
    }
#endif

    private func publishPreparationProgress(
        _ phase: ImportProgressPhase,
        requestId: UUID,
        progress: @escaping (ImportProgress) -> Void
    ) throws {
        try Task.checkCancellation()
        progress(
            ImportProgress(
                requestId: requestId,
                phase: phase,
                completedUnitCount: 0,
                totalUnitCount: 0
            )
        )
    }

    private func readTextDocument(from url: URL) async throws -> String {
        try Task.checkCancellation()
        let request = ImportRequest(fileURL: url)
        let result = await importCoordinator.importDocument(request)
        try Task.checkCancellation()

        guard result.status == .succeeded, let rawDocument = result.rawDocument else {
            throw result.error ?? ImportError.unknown(message: "Import coordinator returned no document.")
        }

        guard case .text(let contents) = rawDocument.content else {
            throw ImportError.invalidDocument(message: "CSV import expected text document content.")
        }

        return contents
    }
}
