//
//  ColumnMapping.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


//
// LedgerForge
// ColumnDetector.swift
// Version: 0.0.8
//

import Foundation

struct ColumnMapping {

    var date: Int?
    var description: Int?
    var debit: Int?
    var credit: Int?
    var balance: Int?

    var isValid: Bool {
        date != nil &&
        description != nil &&
        balance != nil &&
        (debit != nil || credit != nil)
    }

    var missingColumns: [String] {
        var missing: [String] = []

        if date == nil {
            missing.append("Date")
        }

        if description == nil {
            missing.append("Description")
        }

        if debit == nil && credit == nil {
            missing.append("Debit/Credit")
        }

        if balance == nil {
            missing.append("Balance")
        }

        return missing
    }

}

final class ColumnDetector {

    func detect(from headerRow: String,
                delimiter: Character) -> ColumnMapping {

        let columns = headerRow
            .split(separator: delimiter)
            .map {
                $0
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }

        var mapping = ColumnMapping()

        for (index, column) in columns.enumerated() {

            if column.contains("date") || column.contains("txn") {

                mapping.date = index

            }

            if column.contains("description")
                || column.contains("narration")
                || column.contains("particular") {

                mapping.description = index

            }

            if column.contains("debit")
                || column.contains("withdraw") {

                mapping.debit = index

            }

            if column.contains("credit")
                || column.contains("deposit") {

                mapping.credit = index

            }

            if column.contains("balance") {

                mapping.balance = index

            }

        }

        return mapping

    }

}
