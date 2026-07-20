//
//  TransactionListViewModelTests.swift
//  LedgerForgeTests
//

import Foundation
import Testing
@testable import LedgerForge

@Suite("TransactionListViewModel", .serialized)
struct TransactionListViewModelTests {

    @MainActor
    @Test
    func searchTrimsWhitespaceAndMatchesDescriptionAccountAndBank() async throws {
        TransactionStore.shared.replaceTransactions([])
        TransactionStore.shared.replaceTransactions(Self.sampleTransactions)

        let viewModel = TransactionListViewModel()

        viewModel.searchText = "  axis  "
        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Salary credit"]
        )

        viewModel.searchText = "savings"
        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Salary credit"]
        )

        viewModel.searchText = "CBQ"
        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Rent debit"]
        )

        TransactionStore.shared.replaceTransactions([])
        await waitForViewModelUpdate()
    }

    @MainActor
    @Test
    func creditAndDebitFiltersAreMutuallySafe() async throws {
        TransactionStore.shared.replaceTransactions([])
        TransactionStore.shared.replaceTransactions(Self.sampleTransactions)

        let viewModel = TransactionListViewModel()

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = false

        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Salary credit"]
        )

        viewModel.showOnlyCredits = false
        viewModel.showOnlyDebits = true

        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Rent debit"]
        )

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = true

        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == Self.sampleTransactions.map { $0.description }
        )

        TransactionStore.shared.replaceTransactions([])
        await waitForViewModelUpdate()
    }

    @MainActor
    @Test
    func totalsUseAllRuntimeTransactions() async throws {
        TransactionStore.shared.replaceTransactions([])
        TransactionStore.shared.replaceTransactions(Self.sampleTransactions)

        let viewModel = TransactionListViewModel()

        viewModel.searchText = "salary"

        #expect(viewModel.filteredTransactions.count == 1)
        #expect(viewModel.totalCredits == Decimal(100_000))
        #expect(viewModel.totalDebits == Decimal(25_000))
        #expect(viewModel.closingBalance == Decimal(75_000))

        TransactionStore.shared.replaceTransactions([])
        await waitForViewModelUpdate()
    }

    @MainActor
    @Test
    func transactionValidationPresentationUsesItsReferencedImportSessionOnly() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let passed = Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            description: "Persisted passed transaction",
            debit: nil,
            credit: 10,
            amount: 10,
            balance: 10,
            currency: "QAR",
            account: "CBQ",
            sourceBank: "CBQ",
            sourceFile: "passed.csv",
            repositoryImportSessionId: "session-passed"
        )
        let withoutSession = Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_001),
            description: "No provenance",
            debit: 10,
            credit: nil,
            amount: -10,
            balance: 0,
            currency: "QAR",
            account: "CBQ",
            sourceBank: "CBQ",
            sourceFile: "unknown.csv"
        )
        transactionStore.replaceTransactions([passed, withoutSession])
        importSessionStore.replaceImportSessions([
            RepositoryImportSession(
                id: "session-passed",
                workspaceId: "workspace",
                sourceDocumentName: "passed.csv",
                startedAtISO: "2026-07-20T00:00:00Z",
                completedAtISO: "2026-07-20T00:01:00Z",
                validationStatus: "passed",
                parserVersion: "Parser"
            )
        ])

        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        #expect(viewModel.validationPresentation(for: passed)?.title == "Passed")
        #expect(viewModel.validationPresentation(for: withoutSession) == nil)
    }

    @MainActor
    @Test
    func transactionValidationPresentationFailsClosedForUnknownOrMissingSessionStatus() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let known = transactionForValidationPresentation(sessionID: "session-passed", description: "Known")
        let unknown = transactionForValidationPresentation(sessionID: "session-unknown", description: "Unknown")
        let missing = transactionForValidationPresentation(sessionID: "session-missing", description: "Missing")
        transactionStore.replaceTransactions([known, unknown, missing], validation: .empty)
        importSessionStore.replaceImportSessions([
            validationSession(id: "session-passed", status: "passed"),
            validationSession(id: "session-unknown", status: "unrecognized")
        ])

        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        #expect(viewModel.validationPresentation(for: known)?.title == "Passed")
        #expect(viewModel.validationPresentation(for: unknown) == nil)
        #expect(viewModel.validationPresentation(for: missing) == nil)
    }

    @MainActor
    @Test
    func transactionValidationPresentationRetainsEachSessionAcrossLaterImportsAndGlobalValidationChanges() async {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transactionA = transactionForValidationPresentation(sessionID: "session-a", description: "A")
        let transactionB = transactionForValidationPresentation(sessionID: "session-b", description: "B")
        let transactionC = transactionForValidationPresentation(sessionID: "session-c", description: "C")

        transactionStore.replaceTransactions([transactionA, transactionB], validation: ImportValidationResult.empty)
        importSessionStore.replaceImportSessions([
            validationSession(id: "session-a", status: "passed"),
            validationSession(id: "session-b", status: "failed")
        ])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        #expect(viewModel.validationPresentation(for: transactionA)?.title == "Passed")
        #expect(viewModel.validationPresentation(for: transactionB)?.title == "Failed")

        transactionStore.replaceTransactions([transactionA, transactionB, transactionC], validation: ImportValidationResult.empty)
        importSessionStore.replaceImportSessions([
            validationSession(id: "session-a", status: "passed"),
            validationSession(id: "session-b", status: "failed"),
            validationSession(id: "session-c", status: "warning")
        ])
        await waitForViewModelUpdate()

        #expect(viewModel.validationPresentation(for: transactionA)?.title == "Passed")
        #expect(viewModel.validationPresentation(for: transactionB)?.title == "Failed")
        #expect(viewModel.validationPresentation(for: transactionC)?.title == "Warning")
    }

    @MainActor
    private func waitForViewModelUpdate() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    private static let sampleTransactions: [Transaction] = [
        Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            description: "Salary credit",
            debit: nil,
            credit: Decimal(100_000),
            amount: Decimal(100_000),
            balance: Decimal(100_000),
            currency: "INR",
            account: "Axis Savings",
            sourceBank: "Axis",
            sourceFile: "salary.csv"
        ),
        Transaction(
            date: Date(timeIntervalSince1970: 1_700_100_000),
            description: "Rent debit",
            debit: Decimal(25_000),
            credit: nil,
            amount: Decimal(-25_000),
            balance: Decimal(75_000),
            currency: "INR",
            account: "Home Account",
            sourceBank: "CBQ",
            sourceFile: "rent.csv"
        )
    ]
}

private func transactionForValidationPresentation(sessionID: String, description: String) -> Transaction {
    Transaction(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        description: description,
        debit: nil,
        credit: 10,
        amount: 10,
        balance: 10,
        currency: "QAR",
        account: "CBQ",
        sourceBank: "CBQ",
        sourceFile: "presentation.csv",
        repositoryImportSessionId: sessionID
    )
}

private func validationSession(id: String, status: String) -> RepositoryImportSession {
    RepositoryImportSession(
        id: id,
        workspaceId: "workspace",
        sourceDocumentName: "presentation.csv",
        startedAtISO: "2026-07-20T00:00:00Z",
        completedAtISO: "2026-07-20T00:01:00Z",
        validationStatus: status,
        parserVersion: "Parser"
    )
}
