// LedgerForgeTests/RepositoryStoreHydratorTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct RepositoryStoreHydratorTests {

    @Test func hydratorLoadsTrustedRepositoryDataIntoRuntimeStores() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        let result = try hydrator.hydrateIfNeeded()

        #expect(result.didHydrate)
        #expect(result.accountCount == 1)
        #expect(result.transactionCount == 1)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == 1)
        #expect(stores.accounts.accounts.first?.name == "Axis NRE")
        #expect(stores.accounts.accounts.first?.currentBalance == Decimal(1_050))
        #expect(stores.transactions.transactions.first?.description == "Trusted credit")
        #expect(stores.transactions.transactions.first?.credit == Decimal(100))
        #expect(stores.transactions.transactions.first?.account == "Axis NRE")
        #expect(stores.transactions.transactions.first?.sourceBank == "Axis")
        #expect(stores.accounts.accounts.first?.repositoryAccountId == "account-dashboard")
        #expect(stores.accounts.accounts.first?.workspaceId == "workspace-dashboard")
        #expect(stores.transactions.transactions.first?.repositoryAccountId == "account-dashboard")
        #expect(stores.transactions.transactions.first?.repositoryImportSessionId == "import-dashboard")
        #expect(stores.transactions.transactions.first?.repositoryTransactionId == "transaction-trusted")
        #expect(stores.importSessions.importSessions.map(\.id) == ["import-dashboard"])

        let viewModel = TransactionListViewModel(
            transactionStore: stores.transactions,
            importSessionStore: stores.importSessions
        )
        let transaction = try #require(stores.transactions.transactions.first)
        #expect(viewModel.validationPresentation(for: transaction)?.title == "Passed")
    }

    @Test func hydratorRedactsOnlyVerifiedStrongIdentifiersBeforeRuntimePresentation() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let verifiedIdentifier = "AXIS-ACCOUNT-12345678"
        _ = try provider.accountRepo.attachIdentifier(AccountIdentifierDTO(
            id: "identifier-verified",
            accountId: "account-dashboard",
            workspaceId: "workspace-dashboard",
            scheme: FinancialIdentifierKind.institutionAccountId.rawValue,
            identifier: verifiedIdentifier,
            strength: FinancialIdentifierStrength.strong.rawValue,
            verificationState: FinancialIdentifierVerificationState.verified.rawValue,
            provenance: FinancialIdentifierProvenance.institutionStructuredField.rawValue,
            createdAtISO: "2026-07-08T00:05:00Z"
        ))
        _ = try provider.accountRepo.attachIdentifier(AccountIdentifierDTO(
            id: "identifier-weak",
            accountId: "account-dashboard",
            workspaceId: "workspace-dashboard",
            scheme: FinancialIdentifierKind.accountSuffix.rawValue,
            identifier: "5678",
            strength: FinancialIdentifierStrength.weak.rawValue,
            verificationState: FinancialIdentifierVerificationState.verified.rawValue,
            provenance: FinancialIdentifierProvenance.parserDerivedText.rawValue,
            createdAtISO: "2026-07-08T00:05:00Z"
        ))
        let hydrator = makeHydrator(provider: provider, stores: stores)

        _ = try hydrator.hydrateIfNeeded()

        let summaries = try #require(stores.accounts.accounts.first?.identitySummaries)
        #expect(summaries.count == 1)
        #expect(summaries.first?.redactedValue == FinancialIdentifier.redacted(verifiedIdentifier))
        #expect(summaries.first?.redactedValue != verifiedIdentifier)
    }

    @Test func hydratorRunsOnlyOnceUnlessForced() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        let firstResult = try hydrator.hydrateIfNeeded()
        let secondResult = try hydrator.hydrateIfNeeded()

        #expect(firstResult.didHydrate)
        #expect(!secondResult.didHydrate)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == 1)
    }

    @Test func hydrationUsesStableRuntimeIdentityWithoutReplacingOpaqueRepositoryIdentity() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        _ = try hydrator.hydrateIfNeeded()
        let initial = try #require(stores.transactions.transactions.first)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let refreshed = try #require(stores.transactions.transactions.first)

        #expect(initial.repositoryTransactionId == "transaction-trusted")
        #expect(refreshed.repositoryTransactionId == "transaction-trusted")
        #expect(initial.id == refreshed.id)
    }

    @Test func forcedHydrationRefreshesRuntimeStoresWithoutDuplicatingState() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [trustedTransaction()])
        let hydrator = makeHydrator(provider: provider, stores: stores, transactionRepo: transactionRepo)

        _ = try hydrator.hydrateIfNeeded()
        transactionRepo.transactions = [trustedTransaction(amountMinor: 25_00, runningBalanceMinor: 1_075_00)]

        let refreshResult = try hydrator.hydrateIfNeeded(forceRefresh: true)

        #expect(refreshResult.didHydrate)
        #expect(refreshResult.transactionCount == 1)
        #expect(stores.transactions.transactions.count == 1)
        #expect(stores.transactions.transactions.first?.description == "Trusted credit")
        #expect(stores.transactions.transactions.first?.credit == Decimal(25))
        #expect(stores.transactions.transactions.first?.account == "Axis NRE")
    }
    @Test func hydratorUsesLatestDatedRunningBalanceForAccountBalance() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [
            trustedTransaction(id: "transaction-newer", amountMinor: 25_00, runningBalanceMinor: 1_075_00, postedDateISO: "2026-07-09"),
            trustedTransaction(id: "transaction-older", amountMinor: 100_00, runningBalanceMinor: 1_050_00, postedDateISO: "2026-07-08")
        ])
        let hydrator = makeHydrator(provider: provider, stores: stores, transactionRepo: transactionRepo)

        let result = try hydrator.hydrateIfNeeded(forceRefresh: true)

        #expect(result.didHydrate)
        #expect(stores.accounts.accounts.first?.currentBalance == Decimal(1_075))
        #expect(stores.transactions.transactions.first?.description == "Trusted credit")
        #expect(stores.transactions.transactions.last?.balance == Decimal(1_075))
    }

    @Test func hydratorRejectsNoncanonicalPersistedINRTextWithoutMutatingStores() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [trustedTransaction(amountDecimal: "100")])
        let hydrator = makeHydrator(provider: provider, stores: stores, transactionRepo: transactionRepo)

        #expect(throws: RepositoryStoreHydrationError.self) {
            try hydrator.hydrateIfNeeded()
        }
        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
    }

    @Test func hydratorRejectsDecimalMinorDisagreementWithoutMutatingStores() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [trustedTransaction(amountDecimal: "99.99")])
        let hydrator = makeHydrator(provider: provider, stores: stores, transactionRepo: transactionRepo)

        #expect(throws: RepositoryStoreHydrationError.self) {
            try hydrator.hydrateIfNeeded()
        }
        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
    }

    @Test func hydratorStrictlyRejectsMalformedTrustedEvidenceWithoutMutatingStores() throws {
        let validRaw = trustedRawRow()
        let cases: [(String, TransactionDTO)] = [
            ("no relationships", trustedTransaction(rawRows: [])),
            ("missing document", trustedTransaction(rawRows: [trustedRawRow(normalizedDocumentId: nil)])),
            ("missing row", trustedTransaction(rawRows: [trustedRawRow(normalizedRowId: "")])),
            ("zero ordinal", trustedTransaction(rawRows: [trustedRawRow(sourceOrdinal: 0)])),
            ("negative ordinal", trustedTransaction(rawRows: [trustedRawRow(sourceOrdinal: -1)])),
            ("missing digest", trustedTransaction(rawRows: [trustedRawRow(normalizedRecordDigest: nil)])),
            ("malformed date role", trustedTransaction(financialDateRole: "posted-at")),
            ("malformed timezone", trustedTransaction(statementTimezoneEvidence: "local")),
            ("invalid IANA timezone", trustedTransaction(statementTimezoneEvidence: "iana:Not/AZone")),
            ("missing profile ID", trustedTransaction(rawRows: [trustedRawRow(parserProfileId: nil)])),
            ("missing profile version", trustedTransaction(rawRows: [trustedRawRow(parserProfileVersion: nil)])),
            ("orphaned relationship", trustedTransaction(rawRows: [trustedRawRow(normalizedRowId: "orphaned-row", normalizedDocumentId: nil)])),
            ("duplicate relationship", trustedTransaction(rawRows: [validRaw, validRaw])),
            ("conflicting ordinal", trustedTransaction(rawRows: [validRaw, trustedRawRow(id: "raw-second", normalizedRowId: "normalized-row-second")])),
            ("profile disagreement", trustedTransaction(rawRows: [validRaw, trustedRawRow(id: "raw-second", normalizedRowId: "normalized-row-second", sourceOrdinal: 2, parserProfileVersion: "2")]))
        ]

        for (name, transaction) in cases {
            let provider = try seededProvider()
            let stores = RuntimeStores()
            let hydrator = makeHydrator(
                provider: provider,
                stores: stores,
                transactionRepo: HydrationFixtureTransactionRepo(transactions: [transaction])
            )

            #expect(throws: RepositoryStoreHydrationError.self, "\(name)") {
                try hydrator.hydrateIfNeeded()
            }
            #expect(stores.accounts.accounts.isEmpty, "\(name)")
            #expect(stores.transactions.transactions.isEmpty, "\(name)")
            #expect(stores.importSessions.importSessions.isEmpty, "\(name)")
        }
    }
}

private struct RuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let importSessions = ImportSessionStore()
}

private func makeHydrator(
    provider: InMemoryRepositoryProvider,
    stores: RuntimeStores,
    transactionRepo: TransactionRepository = HydrationFixtureTransactionRepo(transactions: [trustedTransaction()])
) -> RepositoryStoreHydrator {
    RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: transactionRepo,
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        importSessionStore: stores.importSessions,
        workspaceId: "workspace-dashboard"
    )
}

private func seededProvider() throws -> InMemoryRepositoryProvider {
    let provider = InMemoryRepositoryProvider()
    let workspace = WorkspaceDTO(
        id: "workspace-dashboard",
        name: "Dashboard Workspace",
        createdAtISO: "2026-07-08T00:00:00Z"
    )
    let account = AccountDTO(
        id: "account-dashboard",
        workspaceId: workspace.id,
        name: "Axis NRE",
        institutionId: "Axis",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Dashboard account",
        createdAtISO: "2026-07-08T00:01:00Z"
    )
    let session = ImportSessionDTO(
        id: "import-dashboard",
        workspaceId: workspace.id,
        userVisibleName: "Dashboard Import",
        startedAtISO: "2026-07-08T00:02:00Z",
        validationStatus: "passed",
        readerVersion: nil,
        parserVersion: "Axis Bank Account",
        layoutVersion: nil
    )
    let untrusted = TransactionDTO(
        id: "transaction-untrusted",
        workspaceId: workspace.id,
        accountId: account.id,
        importSessionId: session.id,
        postedDateISO: "2026-07-08",
        description: "Untrusted debit",
        nativeCurrency: "INR",
        amountMinor: -50_00,
        amountDecimal: "-50.00",
        direction: "debit",
        runningBalanceMinor: 1_000_00,
        isTrusted: false,
        trustedAtISO: nil,
        createdAtISO: "2026-07-08T00:03:00Z"
    )

    _ = try provider.workspaceRepo.upsertWorkspace(workspace)
    _ = try provider.accountRepo.upsertAccount(account)
    _ = try provider.importSessionRepo.createImportSession(session)
    try provider.transactionRepo.replaceTransactions(
        workspaceId: workspace.id,
        importSessionId: session.id,
        transactions: [untrusted]
    )

    return provider
}

private func trustedTransaction(
    id: String = "transaction-trusted",
    amountMinor: Int64 = 100_00,
    runningBalanceMinor: Int64 = 1_050_00,
    postedDateISO: String = "2026-07-08",
    amountDecimal: String? = nil,
    financialDateRole: String = FinancialDateRole.transactionDate.rawValue,
    statementTimezoneEvidence: String = "iana:Asia/Kolkata",
    rawRows: [TransactionRawRowDTO] = [trustedRawRow()]
) -> TransactionDTO {
    TransactionDTO(
        id: id,
        workspaceId: "workspace-dashboard",
        accountId: "account-dashboard",
        importSessionId: "import-dashboard",
        postedDateISO: postedDateISO,
        financialDateRole: financialDateRole,
        statementTimezoneEvidence: statementTimezoneEvidence,
        description: "Trusted credit",
        nativeCurrency: "INR",
        amountMinor: amountMinor,
        amountDecimal: amountDecimal ?? (try! Money.fromMinorUnits(amountMinor, currency: "INR").canonicalDecimalString()),
        direction: "credit",
        runningBalanceMinor: runningBalanceMinor,
        isTrusted: true,
        trustedAtISO: "2026-07-08T00:04:00Z",
        createdAtISO: "2026-07-08T00:03:00Z",
        rawRows: rawRows
    )
}

private func trustedRawRow(
    id: String = "transaction-raw-row",
    normalizedRowId: String = "normalized-row",
    sourceOrdinal: Int? = 1,
    normalizedRecordDigest: String? = String(repeating: "a", count: 64),
    normalizedDocumentId: String? = "normalized-document",
    parserProfileId: String? = "fixture.profile",
    parserProfileVersion: String? = "1"
) -> TransactionRawRowDTO {
    TransactionRawRowDTO(
        id: id,
        normalizedRowId: normalizedRowId,
        contributionType: "transaction",
        sourceOrdinal: sourceOrdinal,
        normalizedRecordDigest: normalizedRecordDigest,
        normalizedDocumentId: normalizedDocumentId,
        parserProfileId: parserProfileId,
        parserProfileVersion: parserProfileVersion
    )
}

/// Test-target-only read fixture. Production code cannot instantiate this type.
private final class HydrationFixtureTransactionRepo: TransactionRepository {
    var transactions: [TransactionDTO]

    init(transactions: [TransactionDTO]) {
        self.transactions = transactions
    }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        throw RepositoryError.trustedTransactionWriteForbidden
    }

    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] {
        transactions.filter { $0.workspaceId == workspaceId && (importSessionId == nil || $0.importSessionId == importSessionId) }
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        transactions
            .filter { $0.workspaceId == workspaceId && $0.isTrusted }
            .sorted { lhs, rhs in
                if lhs.postedDateISO != rhs.postedDateISO { return lhs.postedDateISO < rhs.postedDateISO }
                let lhsSource = lhs.rawRows.first
                let rhsSource = rhs.rawRows.first
                if lhsSource?.normalizedDocumentId == rhsSource?.normalizedDocumentId,
                   let lhsOrdinal = lhsSource?.sourceOrdinal,
                   let rhsOrdinal = rhsSource?.sourceOrdinal,
                   lhsOrdinal != rhsOrdinal { return lhsOrdinal < rhsOrdinal }
                if lhsSource?.normalizedDocumentId != rhsSource?.normalizedDocumentId {
                    return (lhsSource?.normalizedDocumentId ?? "~") < (rhsSource?.normalizedDocumentId ?? "~")
                }
                return lhs.id < rhs.id
            }
    }
}
