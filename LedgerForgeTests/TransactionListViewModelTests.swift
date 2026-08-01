//
//  TransactionListViewModelTests.swift
//  LedgerForgeTests
//

import Foundation
import Testing
@testable import LedgerForge

@Suite("TransactionListViewModel", .serialized)
struct TransactionListViewModelTests {

    @Test func closingBalanceWithholdsAuthorityForEqualDateDifferentDocuments() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let date = try! StatementDate(canonical: "2026-06-06")
        transactionStore.replaceTransactions([
            transactionForClosingBalance(document: "document-a", ordinal: 99, balance: 100, date: date),
            transactionForClosingBalance(document: "document-b", ordinal: 1, balance: 200, date: date)
        ])

        let viewModel = TransactionListViewModel(transactionStore: transactionStore, importSessionStore: importSessionStore)

        #expect(viewModel.closingBalance == nil)
    }

    @MainActor
    @Test(.globalRuntimeStateIsolation)
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
    @Test(.globalRuntimeStateIsolation)
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
    @Test(.globalRuntimeStateIsolation)
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
            statementDate: try! StatementDate(canonical: "2023-11-14"),
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
            statementDate: try! StatementDate(canonical: "2023-11-14"),
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
    @Test
    func completeDurableRelationshipsProduceAuthoritativeTransactionDetail() throws {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = detailTransaction()
        transactionStore.replaceTransactions([transaction], validation: .empty)
        importSessionStore.replaceImportSessions([detailSession()])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.signedAmount == MoneyFormatting.signedDisplay(transaction.money, isCredit: true))
        #expect(presentation.nativeCurrency == "INR")
        #expect(presentation.direction == "Credit")
        #expect(presentation.statementDate == "14 Nov 23")
        #expect(presentation.statementDateRole == "Value date")
        #expect(presentation.accountDisplayName == "Everyday account")
        #expect(presentation.institution == "Axis Bank")
        #expect(presentation.sourceDocumentName == "July statement.pdf")
        #expect(presentation.importedAt != nil)
        #expect(presentation.importedAtText != "Unavailable")
        #expect(presentation.validation?.title == "Passed")
        #expect(presentation.validation?.detail == "This imported transaction passed validation.")
        #expect(presentation.runningBalance == MoneyFormatting.display(try Money(amount: Decimal(string: "1234.56")!, currency: "INR")))
        #expect(presentation.provenanceAvailability == .complete)
    }

    @MainActor
    @Test
    func documentPresentationRequiresDurableDocumentRelationship() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = detailTransaction(repositoryDocumentId: nil)
        transactionStore.replaceTransactions([transaction], validation: .empty)
        importSessionStore.replaceImportSessions([detailSession()])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.sourceDocumentName == "Unavailable")
        #expect(presentation.importedAt != nil)
        #expect(presentation.validation?.title == "Passed")
        #expect(presentation.provenanceAvailability == .partial)
    }

    @MainActor
    @Test
    func missingReferencedSessionNeverSubstitutesAnUnrelatedSession() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = detailTransaction(repositoryImportSessionId: "missing-session")
        transactionStore.replaceTransactions([transaction], validation: .empty)
        importSessionStore.replaceImportSessions([
            detailSession(id: "unrelated-session", sourceDocumentName: "Unrelated statement.csv")
        ])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.sourceDocumentName == "Unavailable")
        #expect(presentation.importedAt == nil)
        #expect(presentation.importedAtText == "Unavailable")
        #expect(presentation.validation == nil)
        #expect(!presentation.accessibilityText.contains("Unrelated statement.csv"))
    }

    @MainActor
    @Test
    func malformedImportTimestampAndUnknownValidationFailClosed() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = detailTransaction()
        transactionStore.replaceTransactions([transaction], validation: .empty)
        importSessionStore.replaceImportSessions([
            detailSession(completedAtISO: "not-a-timestamp", validationStatus: "unexpected")
        ])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.sourceDocumentName == "July statement.pdf")
        #expect(presentation.importedAt == nil)
        #expect(presentation.importedAtText == "Unavailable")
        #expect(presentation.validation == nil)
        #expect(presentation.provenanceAvailability == .partial)
    }

    @MainActor
    @Test
    func conflictingMatchingSessionsFailClosedWithoutChoosingOne() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = detailTransaction()
        transactionStore.replaceTransactions([transaction], validation: .empty)
        importSessionStore.replaceImportSessions([
            detailSession(sourceDocumentName: "First statement.pdf"),
            detailSession(sourceDocumentName: "Second statement.pdf")
        ])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.sourceDocumentName == "Unavailable")
        #expect(presentation.importedAt == nil)
        #expect(presentation.validation == nil)
        #expect(!presentation.accessibilityText.contains("First statement.pdf"))
        #expect(!presentation.accessibilityText.contains("Second statement.pdf"))
    }

    @MainActor
    @Test
    func internalIdentifiersAndParserEvidenceNeverEnterDetailText() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = detailTransaction()
        transactionStore.replaceTransactions([transaction], validation: .empty)
        importSessionStore.replaceImportSessions([detailSession()])
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )
        let presentation = viewModel.detailPresentation(for: transaction)
        let presentedText = [
            presentation.description,
            presentation.signedAmount,
            presentation.nativeCurrency,
            presentation.direction,
            presentation.statementDate,
            presentation.statementDateRole,
            presentation.accountDisplayName,
            presentation.institution,
            presentation.sourceDocumentName,
            presentation.importedAtText,
            presentation.validation?.title ?? "",
            presentation.validation?.detail ?? "",
            presentation.runningBalance,
            presentation.provenanceAvailability.title,
            presentation.accessibilityText
        ].joined(separator: " ")

        for prohibited in [
            "repository-transaction-internal",
            "repository-account-internal",
            "repository-document-internal",
            "repository-session-internal",
            "normalized-document-internal",
            "normalized-row-internal",
            "record-digest-internal",
            "raw-parser-profile-internal",
            "internal-source-path-sentinel"
        ] {
            #expect(!presentedText.contains(prohibited), "Unexpected internal presentation: \(prohibited)")
        }
    }

    @MainActor
    @Test
    func historicalTransactionWithoutDurableProvenanceRemainsUsableAndNeutral() {
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let transaction = Transaction(
            statementDate: try! StatementDate(canonical: "2023-11-14"),
            description: "Historical adjustment",
            debit: 25,
            credit: nil,
            amount: -25,
            balance: nil,
            currency: "INR",
            account: "Legacy account label",
            sourceBank: "Legacy institution label",
            sourceFile: "legacy.csv"
        )
        transactionStore.replaceTransactions([transaction], validation: .empty)
        let viewModel = TransactionListViewModel(
            transactionStore: transactionStore,
            importSessionStore: importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.signedAmount == MoneyFormatting.signedDisplay(transaction.money, isCredit: false))
        #expect(presentation.direction == "Debit")
        #expect(presentation.statementDate == "14 Nov 23")
        #expect(presentation.accountDisplayName == "Unavailable")
        #expect(presentation.institution == "Unavailable")
        #expect(presentation.sourceDocumentName == "Unavailable")
        #expect(presentation.importedAt == nil)
        #expect(presentation.validation == nil)
        #expect(presentation.runningBalance == "Unavailable")
        #expect(presentation.provenanceAvailability == .unavailable)
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
            statementDate: try! StatementDate(canonical: "2023-11-14"),
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
            statementDate: try! StatementDate(canonical: "2023-11-16"),
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
        statementDate: try! StatementDate(canonical: "2023-11-14"),
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

private func transactionForClosingBalance(document: String, ordinal: Int, balance: Decimal, date: StatementDate) -> Transaction {
    Transaction(
        statementDate: date,
        description: "Closing balance evidence",
        debit: nil,
        credit: 1,
        amount: 1,
        balance: balance,
        currency: "INR",
        account: "Axis NRE",
        sourceBank: "Axis",
        sourceFile: "fixture",
        sourceProvenance: [TransactionSourceProvenance(
            normalizedDocumentID: document,
            normalizedRowID: "row-\(document)-\(ordinal)",
            sourceOrdinal: ordinal,
            normalizedRecordDigest: String.normalizedRecordDigest(values: [document, "\(ordinal)"]),
            parserProfileID: "test",
            parserProfileVersion: "1"
        )]
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

private func detailTransaction(
    repositoryImportSessionId: String? = "repository-session-internal",
    repositoryDocumentId: String? = "repository-document-internal"
) -> Transaction {
    Transaction(
        statementDate: try! StatementDate(canonical: "2023-11-14"),
        description: "Salary credit",
        debit: nil,
        credit: Decimal(string: "234.56")!,
        amount: Decimal(string: "234.56")!,
        balance: Decimal(string: "1234.56")!,
        currency: "INR",
        account: "Everyday account",
        sourceBank: "Axis Bank",
        sourceFile: "internal-source-path-sentinel",
        repositoryTransactionId: "repository-transaction-internal",
        financialDateRole: .valueDate,
        statementTimezoneEvidence: .iana("Asia/Kolkata"),
        sourceProvenance: [TransactionSourceProvenance(
            normalizedDocumentID: "normalized-document-internal",
            normalizedRowID: "normalized-row-internal",
            sourceOrdinal: 9,
            normalizedRecordDigest: "record-digest-internal",
            parserProfileID: "raw-parser-profile-internal",
            parserProfileVersion: "99"
        )],
        repositoryAccountId: "repository-account-internal",
        repositoryImportSessionId: repositoryImportSessionId,
        repositoryDocumentId: repositoryDocumentId
    )
}

private func detailSession(
    id: String = "repository-session-internal",
    sourceDocumentName: String? = "July statement.pdf",
    completedAtISO: String? = "2026-07-20T00:01:00Z",
    validationStatus: String = "passed"
) -> RepositoryImportSession {
    RepositoryImportSession(
        id: id,
        workspaceId: "workspace",
        sourceDocumentName: sourceDocumentName,
        startedAtISO: "2026-07-20T00:00:00Z",
        completedAtISO: completedAtISO,
        validationStatus: validationStatus,
        parserVersion: "raw-parser-profile-internal"
    )
}
