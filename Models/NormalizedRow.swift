//
// LedgerForge
// NormalizedRow.swift
// Version: 0.2.0
//

import Foundation

struct NormalizedRow: Identifiable {

    let id = UUID()

    let rowNumber: Int

    let values: [String]

    /// Optional source-faithful cell text retained before trimming or other
    /// presentation normalization. Financial parsers may use this transient
    /// channel only when the source family proves that exact cell form carries
    /// meaning (for example, a fixed-width printed reference).
    let rawValues: [String]?

    /// Optional physical source-page provenance. Tabular normalizers do not
    /// provide a page boundary; PDF profiles may attach one transiently so a
    /// prepared document can prove where a source row was observed without
    /// widening durable schema or persistence contracts.
    let sourcePage: Int?

    init(
        rowNumber: Int,
        values: [String],
        rawValues: [String]? = nil,
        sourcePage: Int? = nil
    ) {
        self.rowNumber = rowNumber
        self.values = values
        self.rawValues = rawValues
        self.sourcePage = sourcePage
    }

    var hasConsistentRawValues: Bool {
        rawValues.map { $0.count == values.count } ?? true
    }

    func value(
        for column: ColumnType,
        mapping: ColumnMapping
    ) -> String? {

        let index: Int?

        switch column {

        case .date:
            index = mapping.date

        case .description:
            index = mapping.description

        case .debit:
            index = mapping.debit

        case .credit:
            index = mapping.credit

        case .balance:
            index = mapping.balance

        default:
            index = nil

        }

        guard
            let index,
            values.indices.contains(index)
        else {
            return nil
        }

        return values[index]

    }

}
