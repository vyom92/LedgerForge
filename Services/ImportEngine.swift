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

    init(algorithm: String, digest: String, byteCount: Int64) {
        self.algorithm = algorithm
        self.digest = digest
        self.byteCount = byteCount
    }
}

enum ConfirmedImportRecoveryRoute: Equatable, Sendable {
    case none
    case prepareAgain(ConfirmedImportRecoveryReason)
    case retryCanonicalReconciliation
    case retryCanonicalReconciliationThenPrepareAgain
    case reviewRequired(ConfirmedImportRecoveryReason)
    case unavailable
}

enum ConfirmedImportRecoveryReason: Equatable, Sendable {
    case sourceSnapshotIntegrityFailed
    case staleProviderGeneration
    case reviewedPartialPlanStale
    case persistenceContention
    case persistenceUnavailable

    case validationFailed
    case exactStatementDuplicate
    case transactionEventBlock
    case accountChoiceRequired
    case accountChoiceStale
    case identityAmbiguous
    case identityConflict
    case identifierOwnershipConflict
    case repositoryIntegrityConflict
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
    let sourceRowCount: Int?
    let recognizedExistingRowCount: Int?
    let isPartialImport: Bool
    let accountOutcome: ImportAccountOutcome
    let recoveryRoute: ConfirmedImportRecoveryRoute
#if DEBUG
    private(set) var developmentProtectedActionOutcome: DevelopmentProtectedActionOutcome?
#endif

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
        hydrationOutcome: HydrationOutcome? = nil,
        sourceRowCount: Int? = nil,
        recognizedExistingRowCount: Int? = nil,
        isPartialImport: Bool = false,
        accountOutcome: ImportAccountOutcome = .unavailable,
        recoveryRoute: ConfirmedImportRecoveryRoute = .unavailable
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
        self.sourceRowCount = sourceRowCount
        self.recognizedExistingRowCount = recognizedExistingRowCount
        self.isPartialImport = isPartialImport
        self.accountOutcome = accountOutcome
        self.recoveryRoute = recoveryRoute
#if DEBUG
        self.developmentProtectedActionOutcome = nil
#endif
    }

    var succeeded: Bool {
        validationPassed
            && persisted
            && hydrationOutcome == .committedAndHydrated
            && errorMessage == nil
    }

    var requiresHydration: Bool {
        false
    }

    var requiresImportAttemptRefresh: Bool { importAttemptId != nil && !persisted }

    var requiresReconciliation: Bool {
        recoveryRoute == .retryCanonicalReconciliation
    }

#if DEBUG
    func settingDevelopmentProtectedActionOutcome(
        _ outcome: DevelopmentProtectedActionOutcome
    ) -> ImportEngineResult {
        var result = self
        result.developmentProtectedActionOutcome = outcome
        return result
    }
#endif
}

enum ImportEngineCommitError: Error, LocalizedError, Equatable {
    case validationFailed
    case alreadyCommitted
    case persistenceSkipped
    case fingerprintMismatch
    case sourceSnapshotIntegrityFailed

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
        case .sourceSnapshotIntegrityFailed:
            return "Prepared source content could not be verified. Prepare the import again."
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
    let sourceSnapshot: SourceContentSnapshot
    let fingerprintSet: PreparedDocumentFingerprintSet
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
        sourceSnapshot: SourceContentSnapshot? = nil,
        fingerprintSet: PreparedDocumentFingerprintSet? = nil,
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
        let resolvedFingerprint = fingerprint ?? ExactStatementFingerprint(text: rawContents)
        let resolvedSnapshot = sourceSnapshot ?? SourceContentSnapshot(bytes: Data(rawContents.utf8))
        self.fingerprint = resolvedFingerprint
        self.sourceSnapshot = resolvedSnapshot
        self.fingerprintSet = fingerprintSet ?? PreparedDocumentFingerprintSet(
            rawText: resolvedFingerprint,
            sourceBytes: resolvedSnapshot.sourceByteFingerprint
        )
        self.advisoryPreviousImport = advisoryPreviousImport
        self.providerGeneration = providerGeneration
    }

    var transactionCount: Int {
        financialDocument.transactions.count
    }

    var detectedCurrency: String? {
        financialDocument.bookedCurrency?.code ?? validation.statementCurrency?.code
    }

    var statementPeriod: ClosedRange<StatementDate>? {
        if let declared = financialDocument.declaredStatementPeriod {
            return declared.start...declared.end
        }
        let dates = financialDocument.transactions.compactMap(\.statementDate).sorted()
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
    private let sourceSnapshotAcquirer: (URL) throws -> SourceContentSnapshot
    private let importPersistenceCoordinatorFactory: () -> ImportPersistenceCoordinating
    private let persistenceStateProvider: () -> PersistenceState
    private let providerGenerationProvider: () -> ProviderGenerationToken
    private let forcedHydration: () throws -> RepositoryStoreHydrationResult
    private let rejectedAttemptHydration: () throws -> Void
    private let reconciliationGate: ConfirmedImportReconciliationGate
    private let developerConsole: DeveloperConsole
#if DEBUG
    private let developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif
    private let committedPreparedImportLock = NSLock()
    private var committedPreparedImportIDs: Set<UUID> = []
#if DEBUG
    private struct LivePreparedImport {
        let sourceSnapshot: SourceContentSnapshot
        let lifecycleLease: DevelopmentDatabaseActivityLease
    }

    private var livePreparedImports: [UUID: LivePreparedImport] = [:]
#endif

#if DEBUG
    init(
        importCoordinator: any ImportFramework.ImportCoordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(),
            passwordProvider: DefaultPasswordProvider()
        ),
        sourceSnapshotAcquirer: ((URL) throws -> SourceContentSnapshot)? = nil,
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
        reconciliationGate: ConfirmedImportReconciliationGate = ConfirmedImportReconciliationGate(),
        developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        self.importCoordinator = importCoordinator
        self.sourceSnapshotAcquirer = sourceSnapshotAcquirer ?? Self.acquireSourceSnapshot
        self.developerConsole = developerConsole
        self.persistenceStateProvider = persistenceStateProvider
        self.providerGenerationProvider = providerGenerationProvider
        self.forcedHydration = forcedHydration
        self.rejectedAttemptHydration = rejectedAttemptHydration
        self.reconciliationGate = reconciliationGate
        self.developmentProfileAcknowledgementGate = developmentProfileAcknowledgementGate ?? .shared
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
#else
    init(
        importCoordinator: any ImportFramework.ImportCoordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(),
            passwordProvider: DefaultPasswordProvider()
        ),
        sourceSnapshotAcquirer: ((URL) throws -> SourceContentSnapshot)? = nil,
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
        self.sourceSnapshotAcquirer = sourceSnapshotAcquirer ?? Self.acquireSourceSnapshot
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
#endif

    func importFile(from url: URL) {
        Task {
            _ = await importFileAndReturnResult(from: url)
        }
    }

    func importFileAndReturnResult(from url: URL) async -> ImportEngineResult {
        let entryCountBeforeImport = developerConsole.entries.count
        developerConsole.info(.`import`, "Import started")

        do {
            let preparedImport = try await prepareImport(from: url)

            let result = await commitPreparedImport(preparedImport)
            if result.succeeded {
                developerConsole.info(.`import`, "Import completed", metadata: ["transactions": "\(result.transactionCount)"])
            } else if result.previousImport != nil {
                developerConsole.info(.`import`, "Previously imported statement blocked", metadata: ["transactions": "\(result.transactionCount)"])
            } else if result.transactionEventBlock != nil {
                developerConsole.info(.`import`, "Verified transaction event blocked")
            } else {
                developerConsole.error(.`import`, "Import failed")
            }
            return result

        } catch let error as SourceContentSnapshotError {
            developerConsole.error(
                .`import`,
                "Import failed",
                metadata: ["outcome": ImportAttemptOutcome.sourceSnapshotAcquisitionFailed.rawValue]
            )
            return ImportEngineResult(
                fileName: "Selected document",
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: Self.boundedPreparationFailureMessage(for: error)
            )
        } catch {

            if developerConsole.entries.count == entryCountBeforeImport + 1 {
                developerConsole.error(.`import`, "Import preparation failed")
            }
            developerConsole.error(.`import`, "Import failed")
            return ImportEngineResult(
                fileName: url.lastPathComponent,
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: Self.boundedPreparationFailureMessage(for: error),
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
        let preparationGeneration = providerGenerationProvider()
#if DEBUG
        try developmentProfileAcknowledgementGate.requireAuthorization(
            for: .importPreparation,
            providerGeneration: preparationGeneration
        )
#endif
        guard persistenceStateProvider().isUsable else {
            throw PersistenceWorkflowError.unavailable
        }
#if DEBUG
        let lifecycleLease = try DevelopmentDatabaseActivityGate.shared.begin(.importPreparation)
        var transfersLifecycleLease = false
        defer {
            if !transfersLifecycleLease { lifecycleLease.finish() }
        }
#endif
        try publishPreparationProgress(.openingSource, requestId: requestId, progress: progress)
        let snapshot: SourceContentSnapshot
        do {
            snapshot = try acquireSourceSnapshot(from: url)
        } catch {
            let record = importPersistenceCoordinatorFactory().recordSourceSnapshotRejection(.acquisitionFailed)
            if record.importAttemptId != nil {
                try? rejectedAttemptHydration()
            }
            developerConsole.error(.`import`, "Source snapshot acquisition failed")
            throw error
        }
        var transfersSnapshot = false
        defer {
            if !transfersSnapshot { snapshot.invalidate() }
        }
        try Task.checkCancellation()
        let rawDocument = try await readDocument(from: url, snapshot: snapshot)
        try Task.checkCancellation()
        let contents = rawDocument.searchableText
        let sourceFormat = try Self.preparedSourceFormat(fileType: rawDocument.fileExtension)
        let rawTextFingerprint = ExactStatementFingerprint(text: contents)
        let fingerprintSet = try Self.preparedFingerprintSet(
            rawText: rawTextFingerprint,
            sourceBytes: snapshot.sourceByteFingerprint,
            sourceFormat: sourceFormat
        )
        guard let duplicateAuthority = fingerprintSet.duplicateAuthority else {
            throw ImportError.invalidDocument(message: "Import fingerprint authority is unavailable.")
        }
        let fingerprint = ExactStatementFingerprint(
            algorithm: duplicateAuthority.algorithm,
            digest: duplicateAuthority.digest,
            byteCount: duplicateAuthority.byteCount
        )

        guard !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            developerConsole.error(.`import`, "Imported document is empty.")
            throw ImportError.invalidDocument(message: "Imported document is empty.")
        }

        try publishPreparationProgress(.detectingInstitution, requestId: requestId, progress: progress)
        let detection = InstitutionDetector().detectWithReasons(from: contents)
        let institutionCandidate = detection.importCandidate

        try publishPreparationProgress(.classifyingStatement, requestId: requestId, progress: progress)
        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institutionCandidate
        )

        let document: Document
        let normalizedRows: [NormalizedRow]
        let normalizedHeader: NormalizedRow?
        let sourceContext: NormalizedDocument.SourceContext
        switch sourceFormat {
        case .csv:
            let csvDocument = CSVAnalyzer().analyze(text: contents, fileURL: url)
            let normalization = CSVNormalizer().normalizeWithSourceContext(
                text: contents,
                document: csvDocument
            )
            document = csvDocument
            normalizedRows = normalization.rows
            normalizedHeader = normalization.header
            sourceContext = normalization.sourceContext
        case .pdf:
            let normalization = try AxisBankAccountPDFNormalizer().normalize(
                text: contents,
                fileURL: url
            )
            document = normalization.document
            normalizedRows = normalization.rows
            normalizedHeader = normalization.header
            sourceContext = normalization.sourceContext
        case .xls:
            let normalization = try AxisBankAccountXLSNormalizer().normalize(
                rawDocument: rawDocument
            )
            document = normalization.document
            normalizedRows = normalization.rows
            normalizedHeader = normalization.header
            sourceContext = normalization.sourceContext
        case .xlsx, .unknown:
            throw ImportError.unsupportedFile(extension: rawDocument.fileExtension)
        }

        try publishPreparationProgress(.selectingParser, requestId: requestId, progress: progress)
        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: institutionCandidate,
            classification: classification
        )
        let parser = selection.parser
        let metadata = selection.legacyMetadata

        developerConsole.info(.`import`, "Institution detected", metadata: ["institution": metadata.institution.rawValue])
        developerConsole.info(
            .`import`,
            "Parser selected",
            metadata: ["selection": parser == nil ? "Unavailable" : "Recognized"]
        )

        developerConsole.debug(.parser, "Document structure recognized", metadata: [
            "format": metadata.fileFormat.rawValue,
            "rows": "\(document.rowCount)",
            "columns": "\(document.columnCount)",
            "headerRow": "\(document.headerRow ?? -1)",
            "firstTransactionRow": "\(document.firstTransactionRow ?? -1)"
        ])
        developerConsole.debug(.parser, "Normalization completed", metadata: [
            "rows": "\(normalizedRows.count)"
        ])

        guard let parser else {
            developerConsole.warning(.`import`, "No suitable parser found.")
            throw ImportError.invalidDocument(message: "No suitable parser found.")
        }

        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: normalizedRows,
            header: normalizedHeader,
            sourceContext: sourceContext
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
            sourceSnapshot: snapshot,
            fingerprintSet: fingerprintSet,
            advisoryPreviousImport: advisoryPreviousImport,
            providerGeneration: preparationGeneration
        )
#if DEBUG
        await lifecycleLease.transition(to: .preparedAwaitingConfirmation)
        livePreparedImports[preparedImport.id] = LivePreparedImport(
            sourceSnapshot: snapshot,
            lifecycleLease: lifecycleLease
        )
        transfersLifecycleLease = true
#endif
        transfersSnapshot = true
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

    func reviewPreparedPartialImport(
        _ preparedImport: PreparedImport,
        accountChoice: ImportAccountChoice? = nil
    ) throws -> PartialImportReviewResult {
        guard persistenceStateProvider().isUsable,
              preparedImport.validation.passed,
              preparedImport.advisoryPreviousImport == nil,
              !reconciliationGate.isBlocked else {
            return .unsupportedEvidence
        }
        return try importPersistenceCoordinatorFactory().reviewPartialImport(
            financialDocument: preparedImport.financialDocument,
            importSession: preparedImport.importSession,
            validation: preparedImport.validation,
            fingerprintSet: preparedImport.fingerprintSet,
            accountChoice: accountChoice,
            providerGeneration: preparedImport.providerGeneration
        )
    }

    func commitPreparedImport(
        _ preparedImport: PreparedImport,
        accountChoice: ImportAccountChoice?,
        reviewedPartialPlan: ReviewedPartialImportPlanDTO? = nil
    ) async -> ImportEngineResult {
#if DEBUG
        do {
            try developmentProfileAcknowledgementGate.requireAuthorization(
                for: .importConfirmation,
                providerGeneration: providerGenerationProvider()
            )
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired {
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: "Acknowledge the active development database profile before confirming this import."
            ).settingDevelopmentProtectedActionOutcome(.acknowledgementRequired)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: "The active development database changed. Prepare the import again."
            ).settingDevelopmentProtectedActionOutcome(.staleGeneration)
        } catch {
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: "The development database is unavailable."
            ).settingDevelopmentProtectedActionOutcome(.developmentDatabaseUnavailable)
        }
#endif
        guard markPreparedImportCommitted(preparedImport.id) else {
            developerConsole.warning(.`import`, "Prepared import already consumed")
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: ImportEngineCommitError.alreadyCommitted.localizedDescription
            )
        }
        defer { preparedImport.sourceSnapshot.invalidate() }
#if DEBUG
        let lifecycleLease = livePreparedImports[preparedImport.id]?.lifecycleLease
        await lifecycleLease?.transition(to: .confirmedPersistence)
        defer {
            lifecycleLease?.finish()
            livePreparedImports.removeValue(forKey: preparedImport.id)
        }
#endif
        guard !reconciliationGate.isBlocked else {
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: "Canonical reconciliation is required before another import can be confirmed.",
                recoveryRoute: .retryCanonicalReconciliationThenPrepareAgain
            )
        }
        let recomputedRawFingerprint = ExactStatementFingerprint(text: preparedImport.rawContents)
        let recomputedFingerprintSet: PreparedDocumentFingerprintSet?
        do {
            recomputedFingerprintSet = try Self.preparedFingerprintSet(
                rawText: recomputedRawFingerprint,
                sourceBytes: try preparedImport.sourceSnapshot.recomputedSourceByteFingerprint(),
                sourceFormat: preparedImport.financialDocument.metadata.fileFormat
            )
        } catch {
            recomputedFingerprintSet = nil
        }
        let preparedFingerprints = preparedImport.fingerprintSet.fingerprints
        let preparedRawFingerprint = preparedFingerprints.first {
            $0.algorithm == ExactStatementFingerprint.algorithm
        }
        let preparedSourceFingerprint = preparedFingerprints.first {
            $0.algorithm == SourceContentSnapshot.algorithm
        }
        let preparedAuthority = preparedImport.fingerprintSet.duplicateAuthority.map {
            ExactStatementFingerprint(
                algorithm: $0.algorithm,
                digest: $0.digest,
                byteCount: $0.byteCount
            )
        }
        let sourceDocumentFormat = try? Self.preparedSourceFormat(
            fileType: preparedImport.financialDocument.sourceDocument.fileType
        )
        guard preparedImport.fingerprintSet.isValid,
              preparedFingerprints.count == 2,
              sourceDocumentFormat == preparedImport.financialDocument.metadata.fileFormat,
              preparedAuthority == preparedImport.fingerprint,
              preparedRawFingerprint?.digest == recomputedRawFingerprint.digest,
              preparedRawFingerprint?.byteCount == recomputedRawFingerprint.byteCount,
              preparedSourceFingerprint != nil else {
            developerConsole.error(.`import`, "Prepared fingerprint contract is invalid")
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription
            )
        }
        guard recomputedFingerprintSet == preparedImport.fingerprintSet else {
            let record = importPersistenceCoordinatorFactory().recordSourceSnapshotRejection(.integrityFailed)
            if record.importAttemptId != nil {
                try? rejectedAttemptHydration()
            }
            developerConsole.error(.`import`, "Prepared source snapshot integrity verification failed")
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: ImportEngineCommitError.sourceSnapshotIntegrityFailed.localizedDescription,
                accountId: nil,
                importSessionId: nil,
                redactedIdentifier: nil,
                previousImport: nil,
                importAttemptId: record.importAttemptId,
                recoveryRoute: .prepareAgain(.sourceSnapshotIntegrityFailed)
            )
        }
        guard persistenceStateProvider().isUsable else {
            developerConsole.error(.database, "Import blocked because persistence is unavailable")
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: preparedImport.validation.passed,
                persisted: false,
                errorMessage: PersistenceWorkflowError.unavailable.localizedDescription,
                recoveryRoute: .prepareAgain(.persistenceUnavailable)
            )
        }
        guard preparedImport.validation.passed else {
            let attemptID = importPersistenceCoordinatorFactory().recordValidationFailure(fileName: preparedImport.fileName, transactionCount: preparedImport.transactionCount)
            developerConsole.error(.validation, "Validation failed")
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
                importAttemptId: attemptID,
                recoveryRoute: .reviewRequired(.validationFailed)
            )
        }

        var persistenceResult = ImportPersistenceResult.skipped
        var persistenceErrorMessage: String?
        var failureRecoveryRoute: ConfirmedImportRecoveryRoute?
        do {
            let importPersistenceCoordinator = importPersistenceCoordinatorFactory()
            if let reviewedPartialPlan {
                persistenceResult = try importPersistenceCoordinator.persistReviewedPartialImport(
                    reviewedPartialPlan
                )
            } else {
                persistenceResult = try importPersistenceCoordinator.persistValidatedImport(
                    financialDocument: preparedImport.financialDocument,
                    importSession: preparedImport.importSession,
                    validation: preparedImport.validation,
                    fingerprintSet: preparedImport.fingerprintSet,
                    accountChoice: accountChoice,
                    providerGeneration: preparedImport.providerGeneration
                )
            }
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
            developerConsole.error(.database, "Repository persistence failed")
            if let failure = error as? ImportPersistenceCommitFailure {
                persistenceErrorMessage = Self.boundedPersistenceFailureMessage(for: failure.originalError)
                failureRecoveryRoute = Self.recoveryRoute(for: failure)
                persistenceResult = ImportPersistenceResult(
                    persisted: false,
                    workspaceId: nil,
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: preparedImport.transactionCount,
                    importAttemptId: failure.importAttemptId,
                    accountOutcome: failure.accountOutcome
                )
            } else if let coordinationError = error as? ImportPersistenceCoordinationError {
                persistenceErrorMessage = Self.boundedPersistenceFailureMessage(for: coordinationError)
                failureRecoveryRoute = Self.recoveryRoute(for: coordinationError)
            } else {
                persistenceErrorMessage = Self.boundedPersistenceFailureMessage(for: error)
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

        let recoveryRoute: ConfirmedImportRecoveryRoute
        if persistenceResult.persisted {
            if persistenceResult.previousImport != nil
                || persistenceResult.transactionEventBlock != nil
                || failureRecoveryRoute != nil
                || !Self.isCommittedAccountOutcome(persistenceResult.accountOutcome) {
                recoveryRoute = .unavailable
            } else {
                switch hydrationOutcome {
                case .committedAndHydrated:
                    recoveryRoute = .none
                case .committedReconciliationRequired:
                    recoveryRoute = .retryCanonicalReconciliation
                case .notRequired:
                    recoveryRoute = .unavailable
                }
            }
        } else if persistenceResult.previousImport != nil {
            recoveryRoute = persistenceResult.transactionEventBlock == nil
                && failureRecoveryRoute == nil
                && persistenceResult.accountOutcome == .unavailable
                ? .reviewRequired(.exactStatementDuplicate)
                : .unavailable
        } else if let block = persistenceResult.transactionEventBlock {
            recoveryRoute = failureRecoveryRoute == nil
                && persistenceResult.accountOutcome == .unavailable
                ? Self.recoveryRoute(for: block)
                : .unavailable
        } else if let failureRecoveryRoute {
            recoveryRoute = failureRecoveryRoute
        } else {
            recoveryRoute = Self.recoveryRoute(for: persistenceResult.accountOutcome) ?? .unavailable
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
            hydrationOutcome: hydrationOutcome,
            sourceRowCount: persistenceResult.sourceRowCount,
            recognizedExistingRowCount: persistenceResult.recognizedExistingRowCount,
            isPartialImport: persistenceResult.isPartialImport,
            accountOutcome: persistenceResult.accountOutcome,
            recoveryRoute: recoveryRoute
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

    private static func boundedPreparationFailureMessage(for error: Error) -> String {
        ImportFailureSummary.from(error).displayText
    }

    private static func boundedPersistenceFailureMessage(for error: Error) -> String {
        switch error {
        case let error as ImportPersistenceCoordinationError:
            return error.localizedDescription
        case let error as ImportEngineCommitError:
            return error.localizedDescription
        case let error as PersistenceWorkflowError:
            return error.localizedDescription
        default:
            return "The confirmed import could not be completed."
        }
    }

    private static func recoveryRoute(
        for failure: ImportPersistenceCommitFailure
    ) -> ConfirmedImportRecoveryRoute {
        guard let coordinationError = failure.originalError as? ImportPersistenceCoordinationError else {
            return .unavailable
        }
        let errorRoute = recoveryRoute(for: coordinationError)
        guard errorRoute != .unavailable else { return .unavailable }
        switch failure.accountOutcome {
        case .matchedExisting, .userSelectedExisting, .createdNew:
            return .unavailable
        case .unavailable:
            return errorRoute
        default:
            break
        }
        let accountRoute = recoveryRoute(for: failure.accountOutcome)
        return accountRoute == errorRoute ? errorRoute : .unavailable
    }

    private static func recoveryRoute(
        for error: ImportPersistenceCoordinationError
    ) -> ConfirmedImportRecoveryRoute {
        switch error {
        case .ambiguousIdentity:
            return .reviewRequired(.identityAmbiguous)
        case .conflictingIdentity:
            return .reviewRequired(.identityConflict)
        case .explicitChoiceRequired:
            return .reviewRequired(.accountChoiceRequired)
        case .selectedAccountUnavailable, .selectedAccountWorkspaceMismatch,
                .selectedAccountAlreadyIdentified, .staleIdentityDecision:
            return .reviewRequired(.accountChoiceStale)
        case .identifierOwnershipConflict:
            return .reviewRequired(.identifierOwnershipConflict)
        case .staleProviderGeneration:
            return .prepareAgain(.staleProviderGeneration)
        case .reviewedPartialPlanStale:
            return .prepareAgain(.reviewedPartialPlanStale)
        case .retryableContention:
            return .prepareAgain(.persistenceContention)
        case .persistenceUnavailable:
            return .prepareAgain(.persistenceUnavailable)
        case .repositoryIntegrityConflict:
            return .reviewRequired(.repositoryIntegrityConflict)
        case .transactionEventBlock:
            return .reviewRequired(.transactionEventBlock)
        case .resolvedAccountUnavailable, .resolvedAccountWorkspaceMismatch,
                .resolvedWorkspaceUnavailable, .ineligibleIdentifierSet,
                .fingerprintRequired, .invalidFingerprint, .unclassified:
            return .unavailable
        }
    }

    private static func recoveryRoute(
        for outcome: ImportAccountOutcome
    ) -> ConfirmedImportRecoveryRoute? {
        switch outcome {
        case .choiceRequired:
            return .reviewRequired(.accountChoiceRequired)
        case .identityAmbiguous:
            return .reviewRequired(.identityAmbiguous)
        case .identityConflict:
            return .reviewRequired(.identityConflict)
        case .identifierOwnershipConflict:
            return .reviewRequired(.identifierOwnershipConflict)
        case .staleAccountChoice:
            return .reviewRequired(.accountChoiceStale)
        case .staleProviderGeneration:
            return .prepareAgain(.staleProviderGeneration)
        case .matchedExisting, .userSelectedExisting, .createdNew, .unavailable:
            return nil
        }
    }

    private static func recoveryRoute(
        for block: TransactionEventBlock
    ) -> ConfirmedImportRecoveryRoute {
        switch block {
        case .existing, .repeatedIncoming, .ownershipConflict:
            return .reviewRequired(.transactionEventBlock)
        case .repositoryIntegrityConflict:
            return .reviewRequired(.repositoryIntegrityConflict)
        }
    }

    private static func isCommittedAccountOutcome(_ outcome: ImportAccountOutcome) -> Bool {
        switch outcome {
        case .matchedExisting, .userSelectedExisting, .createdNew, .unavailable:
            return true
        case .choiceRequired, .identityAmbiguous, .identityConflict,
                .identifierOwnershipConflict, .staleAccountChoice,
                .staleProviderGeneration:
            return false
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

    func cancelPreparedImport(_ preparedImport: PreparedImport) {
        guard markPreparedImportCommitted(preparedImport.id) else { return }
        preparedImport.sourceSnapshot.invalidate()
#if DEBUG
        livePreparedImports.removeValue(forKey: preparedImport.id)?.lifecycleLease.finish()
#endif
    }

#if DEBUG
    /// Consumes only prepared-awaiting-confirmation objects while the lifecycle
    /// gate's exclusive-pending barrier prevents new provider work.
    func invalidatePreparedImportsForProfileSwitch(
        _ permit: DevelopmentDatabasePreparedImportDrainPermit
    ) -> DevelopmentPreparedImportInvalidationResult {
        let prepared = livePreparedImports.sorted { $0.key.uuidString < $1.key.uuidString }
        var invalidatedCount = 0
        for (id, ownership) in prepared {
            guard markPreparedImportCommitted(id) else {
                livePreparedImports.removeValue(forKey: id)?.lifecycleLease.finish()
                continue
            }
            ownership.sourceSnapshot.invalidate()
            ownership.lifecycleLease.finish()
            livePreparedImports.removeValue(forKey: id)
            invalidatedCount += 1
        }
        return DevelopmentPreparedImportInvalidationResult(invalidatedCount: invalidatedCount)
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

    private func acquireSourceSnapshot(from url: URL) throws -> SourceContentSnapshot {
        do {
            return try sourceSnapshotAcquirer(url)
        } catch let error as SourceContentSnapshotError {
            throw error
        } catch {
            throw SourceContentSnapshotError.acquisitionFailed
        }
    }

    nonisolated private static func acquireSourceSnapshot(from url: URL) throws -> SourceContentSnapshot {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return SourceContentSnapshot(bytes: try Data(contentsOf: url))
        } catch {
            throw SourceContentSnapshotError.acquisitionFailed
        }
    }

    private func readDocument(
        from url: URL,
        snapshot: SourceContentSnapshot
    ) async throws -> RawDocument {
        try Task.checkCancellation()
        let request = ImportRequest(fileURL: url)
        let result = await importCoordinator.importDocument(request, snapshot: snapshot)
        try Task.checkCancellation()

        guard result.status == .succeeded, let rawDocument = result.rawDocument else {
            throw result.error ?? ImportError.unknown(message: "Import coordinator returned no document.")
        }

        switch rawDocument.content {
        case .text:
            break
        case .tabular where !rawDocument.searchableText.isEmpty:
            break
        case .tabular, .data:
            throw ImportError.invalidDocument(message: "Import expected extractable text document content.")
        }

        return rawDocument
    }

    /// The extension routes into one format-specific reader, but it is not
    /// financial support evidence by itself. A value reaches this seam only
    /// after that reader has validated and extracted the retained snapshot;
    /// detection, classification, normalization and parser checks still own
    /// the supported-statement decision.
    nonisolated private static func preparedSourceFormat(fileType: String) throws -> FileFormat {
        switch fileType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case FileFormat.csv.rawValue:
            return .csv
        case FileFormat.pdf.rawValue:
            return .pdf
        case FileFormat.xls.rawValue:
            return .xls
        default:
            throw ImportError.unsupportedFile(extension: fileType.lowercased())
        }
    }

    nonisolated private static func preparedFingerprintSet(
        rawText: ExactStatementFingerprint,
        sourceBytes: VersionedDocumentFingerprint,
        sourceFormat: FileFormat
    ) throws -> PreparedDocumentFingerprintSet {
        let rawTextIsAuthority: Bool
        let sourceBytesIsAuthority: Bool
        switch sourceFormat {
        case .csv:
            rawTextIsAuthority = true
            sourceBytesIsAuthority = false
        case .pdf, .xls:
            rawTextIsAuthority = false
            sourceBytesIsAuthority = true
        case .xlsx, .unknown:
            throw ImportError.unsupportedFile(extension: sourceFormat.rawValue.lowercased())
        }

        return PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: rawText.algorithm,
                digest: rawText.digest,
                byteCount: rawText.byteCount,
                isDuplicateAuthority: rawTextIsAuthority
            ),
            VersionedDocumentFingerprint(
                algorithm: sourceBytes.algorithm,
                digest: sourceBytes.digest,
                byteCount: sourceBytes.byteCount,
                isDuplicateAuthority: sourceBytesIsAuthority
            )
        ])
    }
}
