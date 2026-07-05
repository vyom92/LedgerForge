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
            let debitString = firstRow.values[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let creditString = firstRow.values[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let balanceString = firstRow.values[5].trimmingCharacters(in: .whitespacesAndNewlines)

            let amountString = debitString.isEmpty ? creditString : debitString
            let transactionType = debitString.isEmpty ? "Credit" : "Debit"

            var debit = Decimal(string: debitString)
            var credit = Decimal(string: creditString)
            let balance = Decimal(string: balanceString)

            // Some Axis CSV exports place the transaction amount in the
            // opposite DR/CR column. Infer the correct side from which
            // column actually contains a value.
            if debit == nil, let value = credit {
                debit = value
                credit = nil
            }

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
                account: "",
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
