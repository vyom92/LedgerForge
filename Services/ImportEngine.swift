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

final class ImportEngine {

    static let shared = ImportEngine()

    private let importCoordinator: any ImportFramework.ImportCoordinator
    private let importPersistenceCoordinator: ImportPersistenceCoordinating

    init(
        importCoordinator: any ImportFramework.ImportCoordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(),
            passwordProvider: DefaultPasswordProvider()
        ),
        importPersistenceCoordinator: ImportPersistenceCoordinating = DefaultImportPersistenceCoordinator()
    ) {
        self.importCoordinator = importCoordinator
        self.importPersistenceCoordinator = importPersistenceCoordinator
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

            let contents = try await readTextDocument(from: url)

            guard !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                DeveloperConsole.shared.log("ERROR: Imported document is empty.")
                return ImportEngineResult(
                    fileName: url.lastPathComponent,
                    transactionCount: 0,
                    validationPassed: false,
                    persisted: false,
                    errorMessage: "Imported document is empty."
                )
            }

            DocumentStore.shared.update(with: contents)

            let metadata = InstitutionDetector().detect(from: contents)

            DeveloperConsole.shared.log("Detected Institution: \(metadata.institution.rawValue)")
            DeveloperConsole.shared.log("Document Type: \(metadata.documentType.rawValue)")
            DeveloperConsole.shared.log("Confidence: \(Int(metadata.confidence * 100))%")
            DeveloperConsole.shared.log("")

            let analyzer = CSVAnalyzer()

            let document = analyzer.analyze(
                text: contents,
                fileURL: url
            )

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

            let normalizer = CSVNormalizer()

            let normalizedRows = normalizer.normalize(
                text: contents,
                document: document
            )

            DeveloperConsole.shared.log("Normalized Rows: \(normalizedRows.count)")
            DeveloperConsole.shared.log("")

            if let parser = StatementParserRegistry.shared.parser(
                for: document,
                metadata: metadata
            ) {

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

                // Replace transactions only for validated imports. TransactionStore is the single owner of imported transactions.
                // ADR-010 requires validation before trusted state is updated.
                var persistenceResult = ImportPersistenceResult.skipped
                var persistenceErrorMessage: String?
                if validation.passed {
                    do {
                        persistenceResult = try importPersistenceCoordinator.persistValidatedImport(
                            financialDocument: financialDocument,
                            importSession: importSession,
                            validation: validation
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
                        TransactionStore.shared.replaceTransactions(financialDocument.transactions, validation: validation)
                        AccountStore.shared.integrateImport(importSession: importSession, transactions: financialDocument.transactions)
                    }

                    DeveloperConsole.shared.log("Runtime Stores: UPDATED")
                }

                DeveloperConsole.shared.log("Transactions Parsed: \(financialDocument.transactions.count)")
                DeveloperConsole.shared.log("Import Session Created")
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
                return ImportEngineResult(
                    fileName: importSession.fileName,
                    transactionCount: financialDocument.transactions.count,
                    validationPassed: validation.passed,
                    persisted: persistenceResult.persisted,
                    errorMessage: validation.passed ? persistenceErrorMessage : "Import validation failed."
                )

            } else {

                DeveloperConsole.shared.log("No suitable parser found.")
                return ImportEngineResult(
                    fileName: document.filename,
                    transactionCount: 0,
                    validationPassed: false,
                    persisted: false,
                    errorMessage: "No suitable parser found."
                )

            }

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
