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

enum DirectionResolutionError: Error, Equatable {
    case missingDebitAndCredit
    case populatedDebitAndCredit
}

/// Resolves transaction direction independently of any financial institution.
final class DirectionResolver {

    static func resolve(
        strategy: TransactionDirectionStrategy,
        debit: Decimal?,
        credit: Decimal?,
        amount: Decimal?,
        direction: String?
    ) throws -> DirectionResult {

        switch strategy {

        case .debitCreditColumns:

            if let debit, credit == nil {
                return DirectionResult(
                    debit: debit,
                    credit: nil,
                    transactionType: .debit
                )
            }

            if let credit, debit == nil {
                return DirectionResult(
                    debit: nil,
                    credit: credit,
                    transactionType: .credit
                )
            }

            if debit != nil, credit != nil {
                throw DirectionResolutionError.populatedDebitAndCredit
            }

            throw DirectionResolutionError.missingDebitAndCredit

        case .amountAndDrCr,
             .signedAmount,
             .withdrawalDepositColumns:
            fatalError("TransactionDirectionStrategy not implemented yet.")
        }
    }
}
