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

        guard let firstRow = document.rows.first else {
            return []
        }

        print("========== FIRST NORMALIZED ROW ==========")
        print(firstRow)
        print("=========================================")

        guard firstRow.values.count >= 6 else {
            print("Axis parser: insufficient columns in first row")
            return []
        }

        let dateString = firstRow.values[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let description = firstRow.values[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let debitString = firstRow.values[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let creditString = firstRow.values[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let balanceString = firstRow.values[5].trimmingCharacters(in: .whitespacesAndNewlines)

        print("Date: \(dateString)")
        print("Description: \(description)")
        print("Debit: \(debitString)")
        print("Credit: \(creditString)")
        print("Balance: \(balanceString)")

        let amountString = debitString.isEmpty ? creditString : debitString
        let transactionType = debitString.isEmpty ? "Credit" : "Debit"

        print("Amount: \(amountString)")
        print("Transaction Type: \(transactionType)")

        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let parsedDate = formatter.date(from: dateString)

        let debit = Decimal(string: debitString)
        let credit = Decimal(string: creditString)
        let balance = Decimal(string: balanceString)

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

        print("✓ First transaction created successfully")

        return [transaction]
    }
}
