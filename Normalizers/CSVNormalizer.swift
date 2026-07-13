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

struct CSVNormalizationResult {

    let rows: [NormalizedRow]

    let sourceContext: NormalizedDocument.SourceContext

}

final class CSVNormalizer {

    func normalize(
        text: String,
        document: Document
    ) -> [NormalizedRow] {

        normalizeWithSourceContext(
            text: text,
            document: document
        ).rows

    }

    func normalizeWithSourceContext(
        text: String,
        document: Document
    ) -> CSVNormalizationResult {

        let lines = text.components(separatedBy: .newlines)

        guard
            let delimiter = document.delimiter,
            let firstRow = document.firstTransactionRow,
            firstRow > 0,
            firstRow <= lines.count
        else {
            return CSVNormalizationResult(
                rows: [],
                sourceContext: .empty
            )
        }

        let preTransactionFragments = lines
            .prefix(firstRow - 1)
            .enumerated()
            .map { index, line in
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: index + 1,
                    text: line
                )
            }

        let sourceContext = NormalizedDocument.SourceContext(
            preTransactionFragments: preTransactionFragments
        )

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

        return CSVNormalizationResult(
            rows: rows,
            sourceContext: sourceContext
        )
    }

}
