//
// LedgerForge
// ImportEngine.swift
// Version: 0.1.1
//

import Foundation

struct ImportEngineResult: Equatable {
    let fileName: String
    let transactionCount: Int
    let validationPassed: Bool
    let persisted: Bool
    let errorMessage: String?

    var succeeded: Bool {
        validationPassed && persisted && errorMessage == nil
    }
}

enum ImportEngineCommitError: Error, LocalizedError, Equatable {
    case validationFailed
    case alreadyCommitted
    case persistenceSkipped

    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Import validation failed."
        case .alreadyCommitted:
            return "Prepared import has already been committed."
        case .persistenceSkipped:
            return "Import persistence was skipped."
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
        importSession: ImportSession
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
    }

    var transactionCount: Int {
        financialDocument.transactions.count
    }

    var detectedCurrency: String? {
        financialDocument.transactions.first?.currency
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

private struct ImportFormatProcessingResult {
    let document: Document
    let metadata: DocumentMetadata
    let normalization: CSVNormalizationResult
    let parser: StatementParser?
}

final class ImportEngine {

    static let shared = ImportEngine()

    private let importCoordinator: any ImportFramework.ImportCoordinator
    private let importPersistenceCoordinatorFactory: () -> ImportPersistenceCoordinating
    private let developerConsole: DeveloperConsole
    private let committedPreparedImportLock = NSLock()
    private var committedPreparedImportIDs: Set<UUID> = []

    init(
        importCoordinator: any ImportFramework.ImportCoordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(),
            passwordProvider: DefaultPasswordProvider()
        ),
        importPersistenceCoordinator: ImportPersistenceCoordinating? = nil,
        developerConsole: DeveloperConsole = .shared
    ) {
        self.importCoordinator = importCoordinator
        self.developerConsole = developerConsole
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
                errorMessage: error.localizedDescription
            )

        }

    }

    func prepareImport(from url: URL) async throws -> PreparedImport {
        let contents = try await readTextDocument(from: url)

        guard !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            developerConsole.error(.`import`, "Imported document is empty.")
            throw ImportError.invalidDocument(message: "Imported document is empty.")
        }

        let processedDocument = processCSVDocument(contents: contents, url: url)

        developerConsole.info(.`import`, "Institution detected", metadata: ["institution": processedDocument.metadata.institution.rawValue])
        developerConsole.info(.`import`, "Parser selected", metadata: ["parser": processedDocument.parser?.name ?? "None"])

        // Parser internals (Debug)
        developerConsole.debug(.parser, "Detected document", metadata: [
            "file": processedDocument.document.filename,
            "rows": "\(processedDocument.document.rowCount)",
            "columns": "\(processedDocument.document.columnCount)",
            "headerRow": "\(processedDocument.document.headerRow ?? -1)",
            "firstTxnRow": "\(processedDocument.document.firstTransactionRow ?? -1)",
            "delimiter": String(processedDocument.document.delimiter ?? "?"),
            "encoding": processedDocument.document.encoding ?? "Unknown"
        ])
        developerConsole.debug(.parser, "Normalization details", metadata: [
            "normalizedRows": "\(processedDocument.normalization.rows.count)"
        ])

        guard let parser = processedDocument.parser else {
            developerConsole.warning(.`import`, "No suitable parser found.")
            throw ImportError.invalidDocument(message: "No suitable parser found.")
        }

        let normalizedDocument = NormalizedDocument(
            document: processedDocument.document,
            metadata: processedDocument.metadata,
            rows: processedDocument.normalization.rows,
            sourceContext: processedDocument.normalization.sourceContext
        )

        let financialDocument = try parser.parse(
            document: normalizedDocument
        )
        developerConsole.debug(.parser, "Row count", metadata: ["transactions": "\(financialDocument.transactions.count)"])

        let validation = ImportValidator.validate(
            financialDocument: financialDocument
        )
        developerConsole.info(.validation, "Validation completed", metadata: ["passed": validation.passed ? "true" : "false", "issues": "\(validation.issues.count)"])

        let importSession = ImportSession(
            fileName: processedDocument.document.filename,
            institution: processedDocument.metadata.institution,
            documentType: processedDocument.metadata.documentType,
            parserName: parser.name,
            transactionCount: financialDocument.transactions.count,
            validation: validation
        )

        return PreparedImport(
            sourceURL: url,
            rawContents: contents,
            fileName: processedDocument.document.filename,
            detectedInstitution: processedDocument.metadata.institution,
            detectedDocumentType: processedDocument.metadata.documentType,
            parserName: parser.name,
            financialDocument: financialDocument,
            validation: validation,
            importSession: importSession
        )
    }

    func commitPreparedImport(_ preparedImport: PreparedImport) async -> ImportEngineResult {
        guard preparedImport.validation.passed else {
            developerConsole.error(.validation, "Validation failed", metadata: ["file": preparedImport.fileName])
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: false,
                persisted: false,
                errorMessage: ImportEngineCommitError.validationFailed.localizedDescription
            )
        }

        guard markPreparedImportCommitted(preparedImport.id) else {
            developerConsole.warning(.`import`, "Prepared import already committed", metadata: ["file": preparedImport.fileName])
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: true,
                persisted: false,
                errorMessage: ImportEngineCommitError.alreadyCommitted.localizedDescription
            )
        }

        var persistenceResult = ImportPersistenceResult.skipped
        var persistenceErrorMessage: String?
        do {
            let importPersistenceCoordinator = importPersistenceCoordinatorFactory()
            persistenceResult = try importPersistenceCoordinator.persistValidatedImport(
                financialDocument: preparedImport.financialDocument,
                importSession: preparedImport.importSession,
                validation: preparedImport.validation
            )
            if persistenceResult.persisted {
                developerConsole.info(.database, "Repository persistence completed")
            } else {
                persistenceErrorMessage = ImportEngineCommitError.persistenceSkipped.localizedDescription
                developerConsole.error(.database, "Repository persistence skipped")
            }
        } catch {
            developerConsole.error(.database, "Repository persistence failed", metadata: ["error": error.localizedDescription])
            persistenceErrorMessage = error.localizedDescription
        }

        if persistenceResult.persisted {
            await MainActor.run {
                AccountStore.shared.integrateImport(
                    importSession: preparedImport.importSession,
                    transactions: preparedImport.financialDocument.transactions
                )
            }

            // AccountStore's legacy integration path publishes newly created accounts
            // asynchronously. Wait for that queued publication before callers perform
            // repository hydration, so hydration cannot be followed by a stale append.
            await waitForPendingRuntimeStorePublication()

            await MainActor.run {
                DocumentStore.shared.update(with: preparedImport.rawContents)
                TransactionStore.shared.replaceTransactions(
                    preparedImport.financialDocument.transactions,
                    validation: preparedImport.validation
                )
            }

            developerConsole.info(.runtime, "Runtime refresh completed")
        }

        return ImportEngineResult(
            fileName: preparedImport.fileName,
            transactionCount: preparedImport.transactionCount,
            validationPassed: true,
            persisted: persistenceResult.persisted,
            errorMessage: persistenceErrorMessage
        )
    }

    private func waitForPendingRuntimeStorePublication() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
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

    private func processCSVDocument(contents: String, url: URL) -> ImportFormatProcessingResult {
        let metadata = InstitutionDetector().detect(from: contents)
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

        let parser = StatementParserRegistry.shared.parser(
            for: document,
            metadata: metadata
        )

        return ImportFormatProcessingResult(
            document: document,
            metadata: metadata,
            normalization: normalization,
            parser: parser
        )
    }

    private func readTextDocument(from url: URL) async throws -> String {
        let request = ImportRequest(fileURL: url)
        let result = await importCoordinator.importDocument(request)

        guard result.status == .succeeded, let rawDocument = result.rawDocument else {
            throw result.error ?? ImportError.unknown(message: "Import coordinator returned no document.")
        }

        guard case .text(let contents) = rawDocument.content else {
            throw ImportError.invalidDocument(message: "CSV import expected text document content.")
        }

        return contents
    }
}
