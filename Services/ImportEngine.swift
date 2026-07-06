//
// LedgerForge
// ImportEngine.swift
// Version: 0.1.1
//

import Foundation

final class ImportEngine {

    static let shared = ImportEngine()

    private init() { }

    func importFile(from url: URL) {

        DeveloperConsole.shared.clear()

        DeveloperConsole.shared.log("Import requested")
        DeveloperConsole.shared.log(url.path)
        DeveloperConsole.shared.log("")

        do {

            let reader = CSVReader()
            let contents = try reader.read(from: url)

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

                let transactions = try parser.parse(
                    document: normalizedDocument
                )

                let validation = ImportValidator.validate(
                    transactions: transactions
                )

                let importSession = ImportSession(
                    fileName: document.filename,
                    institution: metadata.institution,
                    documentType: metadata.documentType,
                    parserName: parser.name,
                    transactionCount: transactions.count,
                    validation: validation
                )

                // Replace transactions only for validated imports. TransactionStore is the single owner of imported transactions.
                // ADR-010 requires validation before trusted state is updated.
                if validation.passed {
                    TransactionStore.shared.replaceTransactions(transactions, validation: validation)
                    AccountStore.shared.integrateImport(importSession: importSession, transactions: transactions)
                }

                DeveloperConsole.shared.log("Transactions Parsed: \(transactions.count)")
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

            } else {

                DeveloperConsole.shared.log("No suitable parser found.")

            }

        } catch {

            DeveloperConsole.shared.log("ERROR: \(error.localizedDescription)")

        }

    }

}
