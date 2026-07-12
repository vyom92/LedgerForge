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

    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Import validation failed."
        case .alreadyCommitted:
            return "Prepared import has already been committed."
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
    let normalizedRows: [NormalizedRow]
    let parser: StatementParser?
}

final class ImportEngine {

    static let shared = ImportEngine()

    private let importCoordinator: any ImportFramework.ImportCoordinator
    private let importPersistenceCoordinatorFactory: () -> ImportPersistenceCoordinating
    private let committedPreparedImportLock = NSLock()
    private var committedPreparedImportIDs: Set<UUID> = []

    init(
        importCoordinator: any ImportFramework.ImportCoordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(),
            passwordProvider: DefaultPasswordProvider()
        ),
        importPersistenceCoordinator: ImportPersistenceCoordinating? = nil
    ) {
        self.importCoordinator = importCoordinator
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

        DeveloperConsole.shared.clear()

        DeveloperConsole.shared.log("Import requested")
        DeveloperConsole.shared.log(url.path)
        DeveloperConsole.shared.log("")

        Task {
            _ = await importFileAndReturnResult(from: url)
        }

    }

    func importFileAndReturnResult(from url: URL) async -> ImportEngineResult {

        do {
            let preparedImport = try await prepareImport(from: url)
            return await commitPreparedImport(preparedImport)

        } catch {

            DeveloperConsole.shared.log("ERROR: \(error.localizedDescription)")
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
            DeveloperConsole.shared.log("ERROR: Imported document is empty.")
            throw ImportError.invalidDocument(message: "Imported document is empty.")
        }

        let processedDocument = processCSVDocument(contents: contents, url: url)
        let metadata = processedDocument.metadata
        let document = processedDocument.document

        DeveloperConsole.shared.log("Detected Institution: \(metadata.institution.rawValue)")
        DeveloperConsole.shared.log("Document Type: \(metadata.documentType.rawValue)")
        DeveloperConsole.shared.log("Confidence: \(Int(metadata.confidence * 100))%")
        DeveloperConsole.shared.log("")

        DeveloperConsole.shared.log("========== DOCUMENT ==========")
        DeveloperConsole.shared.log("File: \(document.filename)")
        DeveloperConsole.shared.log("Rows: \(document.rowCount)")
        DeveloperConsole.shared.log("Columns: \(document.columnCount)")
        DeveloperConsole.shared.log("Header Row: \(document.headerRow ?? -1)")
        DeveloperConsole.shared.log("First Transaction Row: \(document.firstTransactionRow ?? -1)")
        DeveloperConsole.shared.log("Delimiter: \(document.delimiter ?? "?")")
        DeveloperConsole.shared.log("Encoding: \(document.encoding ?? "Unknown")")
        DeveloperConsole.shared.log("==============================")
        DeveloperConsole.shared.log("")

        let normalizedRows = processedDocument.normalizedRows

        DeveloperConsole.shared.log("Normalized Rows: \(normalizedRows.count)")
        DeveloperConsole.shared.log("")

        guard let parser = processedDocument.parser else {
            DeveloperConsole.shared.log("No suitable parser found.")
            throw ImportError.invalidDocument(message: "No suitable parser found.")
        }

        DeveloperConsole.shared.log("Selected Parser: \(parser.name)")

        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: normalizedRows
        )

        let financialDocument = try parser.parse(
            document: normalizedDocument
        )

        let validation = ImportValidator.validate(
            financialDocument: financialDocument
        )

        let importSession = ImportSession(
            fileName: document.filename,
            institution: metadata.institution,
            documentType: metadata.documentType,
            parserName: parser.name,
            transactionCount: financialDocument.transactions.count,
            validation: validation
        )

        DeveloperConsole.shared.log("Transactions Parsed: \(financialDocument.transactions.count)")
        DeveloperConsole.shared.log("Import Prepared")
        DeveloperConsole.shared.log("Validation: \(validation.passed ? "PASSED" : "FAILED")")
        DeveloperConsole.shared.log("Validation Issues: \(validation.issues.count)")
        if !validation.issues.isEmpty {
            DeveloperConsole.shared.log("======== VALIDATION ISSUES ========")

            for issue in validation.issues {
                DeveloperConsole.shared.log(issue.message)
            }

            DeveloperConsole.shared.log("===================================")
        }
        DeveloperConsole.shared.log("File: \(importSession.fileName)")

        return PreparedImport(
            sourceURL: url,
            rawContents: contents,
            fileName: document.filename,
            detectedInstitution: metadata.institution,
            detectedDocumentType: metadata.documentType,
            parserName: parser.name,
            financialDocument: financialDocument,
            validation: validation,
            importSession: importSession
        )
    }

    func commitPreparedImport(_ preparedImport: PreparedImport) async -> ImportEngineResult {
        guard preparedImport.validation.passed else {
            return ImportEngineResult(
                fileName: preparedImport.fileName,
                transactionCount: preparedImport.transactionCount,
                validationPassed: false,
                persisted: false,
                errorMessage: ImportEngineCommitError.validationFailed.localizedDescription
            )
        }

        guard markPreparedImportCommitted(preparedImport.id) else {
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
                DeveloperConsole.shared.log("Repository Persistence: COMPLETED")
            }
        } catch {
            DeveloperConsole.shared.log("Repository Persistence: FAILED")
            DeveloperConsole.shared.log(error.localizedDescription)
            persistenceErrorMessage = error.localizedDescription
        }

        await MainActor.run {
            DocumentStore.shared.update(with: preparedImport.rawContents)
            TransactionStore.shared.replaceTransactions(
                preparedImport.financialDocument.transactions,
                validation: preparedImport.validation
            )
            AccountStore.shared.integrateImport(
                importSession: preparedImport.importSession,
                transactions: preparedImport.financialDocument.transactions
            )
        }

        DeveloperConsole.shared.log("Runtime Stores: UPDATED")
        DeveloperConsole.shared.log("Import Session Created")

        return ImportEngineResult(
            fileName: preparedImport.fileName,
            transactionCount: preparedImport.transactionCount,
            validationPassed: true,
            persisted: persistenceResult.persisted,
            errorMessage: persistenceErrorMessage
        )
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
        let normalizedRows = normalizer.normalize(
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
            normalizedRows: normalizedRows,
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
