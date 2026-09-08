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

    let header: NormalizedRow?

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
            firstRow <= lines.count + 1
        else {
            return CSVNormalizationResult(
                rows: [],
                header: nil,
                sourceContext: .empty
            )
        }

        let header: NormalizedRow? = {
            guard
                let headerRow = document.headerRow,
                headerRow > 0,
                headerRow < firstRow,
                lines.indices.contains(headerRow - 1)
            else {
                return nil
            }

            let rawValues = rawValues(in: lines[headerRow - 1], delimiter: delimiter)
            return NormalizedRow(
                rowNumber: headerRow,
                values: normalizedValues(from: rawValues),
                rawValues: rawValues
            )
        }()

        let preTransactionFragments = lines
            .prefix(firstRow - 1)
            .enumerated()
            .map { index, line in
                NormalizedDocument.SourceFragment(
                    sourceOrdinal: index + 1,
                    text: line
                )
            }

        var rows: [NormalizedRow] = []

        for index in (firstRow - 1)..<lines.count {

            let line = lines[index]

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let rawValues = rawValues(in: line, delimiter: delimiter)
            rows.append(
                NormalizedRow(
                    rowNumber: index + 1,
                    values: normalizedValues(from: rawValues),
                    rawValues: rawValues
                )
            )
        }

        let financialRegion: NormalizedDocument.ExhaustedFinancialRegionEvidence?
        if let headerRow = document.headerRow,
           headerRow > 0, headerRow <= lines.count {
            financialRegion = try? .init(
                descriptor: "Delimited table from resolved header through end of source",
                sourceUnit: .line,
                startOrdinal: headerRow,
                endOrdinal: max(headerRow, lines.count),
                recognizedFinancialRowCount: rows.count,
                sourceRecords: Array(lines[(headerRow - 1)..<lines.count])
            )
        } else {
            financialRegion = nil
        }
        let sourceContext = NormalizedDocument.SourceContext(
            preTransactionFragments: preTransactionFragments,
            exhaustedFinancialRegion: financialRegion
        )

        return CSVNormalizationResult(
            rows: rows,
            header: header,
            sourceContext: sourceContext
        )
    }

    private func rawValues(
        in line: String,
        delimiter: Character
    ) -> [String] {
        line
            .split(separator: delimiter, omittingEmptySubsequences: false)
            .map(String.init)
    }

    private func normalizedValues(
        from rawValues: [String]
    ) -> [String] {
        rawValues.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

}
