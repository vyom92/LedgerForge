//
//  CSVNormalizer.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


//
// LedgerForge
// CSVNormalizer.swift
// Version: 0.1.1
//

import Foundation

final class CSVNormalizer {

    func normalize(
        text: String,
        document: Document
    ) -> [NormalizedRow] {

        guard
            let delimiter = document.delimiter,
            let firstRow = document.firstTransactionRow
        else {
            return []
        }

        let lines = text.components(separatedBy: .newlines)

        var rows: [NormalizedRow] = []

        for index in (firstRow - 1)..<lines.count {

            let line = lines[index]

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let values = line
                .split(separator: delimiter, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            rows.append(
                NormalizedRow(
                    rowNumber: index + 1,
                    values: values
                )
            )
        }

        return rows
    }

}
