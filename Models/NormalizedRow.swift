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
