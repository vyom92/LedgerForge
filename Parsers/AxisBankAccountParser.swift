//
// LedgerForge
// AxisBankAccountParser.swift
// Version: 0.2.0
//

import Foundation

final class AxisBankAccountParser: StatementParser {

    var name: String {
        "Axis Bank Account"
    }

    func canParse(
        document: Document,
        metadata: DocumentMetadata
    ) -> Bool {

        return metadata.institution == .axis &&
               metadata.documentType == .bankAccount
    }

    func parse(
        document: NormalizedDocument
    ) throws -> [Transaction] {

        guard !document.rows.isEmpty else {
            return []
        }

        var transactions: [Transaction] = []

        for firstRow in document.rows {

            guard firstRow.values.count >= 6 else {
                print("Axis parser: skipping row \(firstRow.rowNumber) (insufficient columns)")
                continue
            }

            let dateString = firstRow.values[0].trimmingCharacters(in: .whitespacesAndNewlines)

            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            guard let parsedDate = formatter.date(from: dateString) else {
                print("Axis parser: skipping non-transaction row \(firstRow.rowNumber)")
                continue
            }

            let description = firstRow.values[2].trimmingCharacters(in: .whitespacesAndNewlines)
            // Axis Bank account CSV exports use column 3 for credits and column 4 for debits.
            // Normalize them into LedgerForge's canonical model.
            let creditString = firstRow.values[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let debitString = firstRow.values[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let balanceString = firstRow.values[5].trimmingCharacters(in: .whitespacesAndNewlines)

            var debit = Decimal(string: debitString)
            var credit = Decimal(string: creditString)
            let balance = Decimal(string: balanceString)

            let direction = DirectionResolver.resolve(
                strategy: .debitCreditColumns,
                debit: debit,
                credit: credit,
                amount: nil,
                direction: nil
            )

            debit = direction.debit
            credit = direction.credit

            let amount: Decimal

            if let debit {
                amount = -debit
            } else {
                amount = credit ?? 0
            }

            let transaction = Transaction(
                date: parsedDate,
                description: description,
                debit: debit,
                credit: credit,
                amount: amount,
                balance: balance,
                currency: "INR",
                account: document.metadata.institution.rawValue,
                sourceBank: "Axis Bank",
                sourceFile: document.document.filename
            )

            transactions.append(transaction)
        }

        print("Normalized rows: \(document.rows.count)")
        print("✓ Parsed \(transactions.count) transactions")

        return transactions
    }
}
