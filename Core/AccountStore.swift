//
//  AccountStore.swift
//  LedgerForge
//
//  Created by Copilot on 06/07/26.
//

import Foundation
import Combine

/// AccountStore owns all Account objects and exposes a simple API
/// for creating, finding, updating balances and archiving accounts.
final class AccountStore: ObservableObject {

    static let shared = AccountStore()

    @Published private(set) var accounts: [Account] = []

    init() {}

    func replaceAccounts(_ accounts: [Account]) {
        let update = {
            self.accounts = accounts
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    // MARK: - Querying

    /// Find an account by institution and name.
    func findAccount(institution: String, name: String) -> Account? {
        return accounts.first { $0.institution == institution && $0.name == name }
    }

    /// Find an account by id
    func account(id: UUID) -> Account? {
        return accounts.first { $0.id == id }
    }

    /// Finds a hydrated account by its immutable repository identity.
    func account(repositoryAccountId: String) -> Account? {
        accounts.first { $0.repositoryAccountId == repositoryAccountId }
    }

    // MARK: - Creation

    /// Create and publish a new account. If an account with the same
    /// institution + name exists, it will be returned instead of creating a duplicate.
    @discardableResult
    func createAccount(
        institution: String,
        name: String,
        type: AccountType,
        currencyCode: String,
        currentBalance: Decimal = .zero,
        includeInNetWorth: Bool = true,
        lastImport: Date? = nil
    ) -> Account {

        if let existing = findAccount(institution: institution, name: name) {
            return existing
        }

        let account = Account(
            institution: institution,
            name: name,
            type: type,
            currencyCode: currencyCode,
            currentBalance: currentBalance,
            includeInNetWorth: includeInNetWorth,
            lastImport: lastImport
        )

        DispatchQueue.main.async {
            self.accounts.append(account)
        }

        return account
    }

    // MARK: - Import integration

    /// Integrate an import session and its transactions into the AccountStore.
    /// This will create or update a single account derived from the import metadata.
    /// Rules:
    /// - Display name: best available import metadata, with filename only as a cleaned fallback.
    /// - Balance: use the latest statement date and, within one source document only, its source ordinal.
    func integrateImport(importSession: ImportSession, transactions: [Transaction]) {

        let institutionName = importSession.institution?.rawValue ?? "Unknown"
        let accountName = ImportPersistenceMapper.displayAccountName(
            institutionName: institutionName,
            documentType: importSession.documentType,
            currency: transactions.first?.currency,
            fallbackFileName: importSession.fileName
        )

        // Determine account type from document type
        let type: AccountType
        switch importSession.documentType {
        case .bankAccount:
            type = .bank
        case .creditCard:
            type = .creditCard
        default:
            type = .bank
        }

        // Determine currency from first transaction if available
        let currency = transactions.first?.currency ?? "INR"

        // This path receives one parsed statement. It still fails closed rather than use array
        // insertion order if same-date balance authority is unsupported or ambiguous.
        let latestBalance = Self.latestKnownBalance(from: transactions)

        // Create or update account
        if let existing = findAccount(institution: institutionName, name: accountName) {
            // Update balance and lastImport
            var updated = existing
            updated.nativeCurrency = try! CurrencyCode(currency)
            if let latestBalance = latestBalance {
                updated.currentBalanceMoney = try! Money(amount: latestBalance, currency: updated.nativeCurrency)
            }
            updated.lastImport = importSession.importedAt

            DispatchQueue.main.async {
                if let idx = self.accounts.firstIndex(where: { $0.id == updated.id }) {
                    self.accounts[idx] = updated
                }
            }
        } else {
            let _ = createAccount(
                institution: institutionName,
                name: accountName,
                type: type,
                currencyCode: currency,
                currentBalance: latestBalance ?? .zero,
                includeInNetWorth: true,
                lastImport: importSession.importedAt
            )
        }
    }

    // MARK: - Balance updates

    private static func latestKnownBalance(from transactions: [Transaction]) -> Decimal? {
        let dated = transactions.compactMap { transaction -> (transaction: Transaction, date: StatementDate, balance: Decimal)? in
                guard let balance = transaction.balance else { return nil }
                guard let date = transaction.statementDate else { return nil }
                return (transaction: transaction, date: date, balance: balance)
            }
        guard let latestDate = dated.map(\.date).max() else { return nil }
        let candidates = dated.filter { $0.date == latestDate }
        guard let documentID = candidates.first?.transaction.documentScopedSourceOrder?.documentID,
              candidates.allSatisfy({ $0.transaction.documentScopedSourceOrder?.documentID == documentID }) else {
            return candidates.count == 1 ? candidates.first?.balance : nil
        }
        return candidates.max(by: {
            ($0.transaction.documentScopedSourceOrder?.ordinal ?? 0) <
            ($1.transaction.documentScopedSourceOrder?.ordinal ?? 0)
        })?.balance
    }

    func updateBalance(for id: UUID, newBalance: Decimal, lastImport: Date? = nil) {
        DispatchQueue.main.async {
            guard let idx = self.accounts.firstIndex(where: { $0.id == id }) else { return }
            var updated = self.accounts[idx]
            updated.currentBalanceMoney = try! Money(amount: newBalance, currency: updated.nativeCurrency)
            if let lastImport = lastImport {
                updated.lastImport = lastImport
            }
            self.accounts[idx] = updated
        }
    }

    // MARK: - Archiving

    func archiveAccount(id: UUID) {
        DispatchQueue.main.async {
            guard let idx = self.accounts.firstIndex(where: { $0.id == id }) else { return }
            var updated = self.accounts[idx]
            updated.status = .archived
            self.accounts[idx] = updated
        }
    }

}
