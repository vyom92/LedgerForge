// LedgerForge
// CSVAnalyzer.swift
// Version: 0.0.4

import Foundation

final class CSVAnalyzer {

    func analyze(text: String, fileURL: URL) -> Document {

        let rows = text.components(separatedBy: .newlines)

        var document = Document(
            filename: fileURL.lastPathComponent,
            url: fileURL,
            fileType: "CSV",
            importedAt: Date()
        )

        document.rowCount = rows.count
        document.encoding = "UTF-8"

        let delimiters: [Character] = [",", ";", "\t"]

        var detectedDelimiter: Character = ","

        var highestScore = 0

        for delimiter in delimiters {

            let score = rows.prefix(20).reduce(0) { partial, row in
                partial + row.filter { $0 == delimiter }.count
            }

            if score > highestScore {
                highestScore = score
                detectedDelimiter = delimiter
            }
        }

        document.delimiter = detectedDelimiter

        let keywords = [
            "date",
            "txn",
            "description",
            "narration",
            "withdrawal",
            "deposit",
            "debit",
            "credit",
            "balance",
            "amount"
        ]

        for (index, row) in rows.enumerated() {

            let lower = row.lowercased()

            let matches = keywords.filter {
                lower.contains($0)
            }

            if matches.count >= 3 {

                document.headerRow = index + 1

                let columns = row.split(separator: detectedDelimiter)

                document.columnCount = columns.count

                document.firstTransactionRow = index + 2

                break
            }
        }

        return document
    }
}
