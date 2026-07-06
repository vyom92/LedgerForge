//
//  DirectionResolver.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

/// Supported strategies for determining transaction direction.
enum TransactionDirectionStrategy {
    case debitCreditColumns
    case amountAndDrCr
    case signedAmount
    case withdrawalDepositColumns
}

/// Describes the financial direction of a transaction.
enum TransactionType {
    case debit
    case credit
}

/// The result returned after resolving transaction direction.
struct DirectionResult {
    let debit: Decimal?
    let credit: Decimal?
    let transactionType: TransactionType
}

/// Resolves transaction direction independently of any financial institution.
final class DirectionResolver {

    static func resolve(
        strategy: TransactionDirectionStrategy,
        debit: Decimal?,
        credit: Decimal?,
        amount: Decimal?,
        direction: String?
    ) -> DirectionResult {

        switch strategy {

        case .debitCreditColumns:

            if let debit {
                return DirectionResult(
                    debit: debit,
                    credit: nil,
                    transactionType: .debit
                )
            }

            if let credit {
                return DirectionResult(
                    debit: nil,
                    credit: credit,
                    transactionType: .credit
                )
            }

            return DirectionResult(
                debit: nil,
                credit: nil,
                transactionType: .debit
            )

        case .amountAndDrCr,
             .signedAmount,
             .withdrawalDepositColumns:
            fatalError("TransactionDirectionStrategy not implemented yet.")
        }
    }
}
