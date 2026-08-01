// LedgerForgeTests/RepositoryStoreHydratorTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct RepositoryStoreHydratorTests {

    @Test func stagedHydrationIsPureUntilOneCompleteSnapshotIsPublished() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [trustedTransaction()])
        let hydrator = makeHydrator(
            provider: provider,
            stores: stores,
            transactionRepo: transactionRepo
        )

        let snapshot = try hydrator.stageHydration()

        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
        #expect(stores.importSessions.importSessions.isEmpty)
        #expect(stores.importAttempts.attempts.isEmpty)
        #expect(stores.categories.snapshot == .empty)
        #expect(snapshot.accounts.map { $0.repositoryAccountId } == ["account-dashboard"])
        #expect(snapshot.transactions.map { $0.repositoryTransactionId } == ["transaction-trusted"])
        #expect(snapshot.importSessions.map(\.id) == ["import-dashboard"])

        transactionRepo.transactions = []
        hydrator.publish(snapshot)

        #expect(stores.accounts.accounts.map { $0.id } == snapshot.accounts.map { $0.id })
        #expect(stores.accounts.accounts.map { $0.repositoryAccountId } == ["account-dashboard"])
        #expect(stores.transactions.transactions.map { $0.id } == snapshot.transactions.map { $0.id })
        #expect(stores.transactions.transactions.map { $0.repositoryTransactionId } == ["transaction-trusted"])
        #expect(stores.importSessions.importSessions == snapshot.importSessions)
        #expect(stores.importAttempts.attempts == snapshot.importAttempts)
        #expect(stores.categories.snapshot == snapshot.categorySnapshot)
        #expect(snapshot.hydrationResult.accountCount == 1)
        #expect(snapshot.hydrationResult.transactionCount == 1)
    }

    @Test func stagedMappingFailurePreservesEveryRuntimeStore() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [trustedTransaction()])
        let hydrator = makeHydrator(
            provider: provider,
            stores: stores,
            transactionRepo: transactionRepo
        )
        _ = try hydrator.hydrateIfNeeded()
        let accountsBefore = stores.accounts.accounts.map(HydratedAccountObservation.init)
        let transactionsBefore = stores.transactions.transactions.map(HydratedTransactionObservation.init)
        let sessionsBefore = stores.importSessions.importSessions
        let attemptsBefore = stores.importAttempts.attempts
        let categoriesBefore = stores.categories.snapshot

        transactionRepo.transactions = [trustedTransaction(amountDecimal: "99.99")]
        #expect(throws: RepositoryStoreHydrationError.self) {
            _ = try hydrator.stageHydration()
        }

        #expect(stores.accounts.accounts.map(HydratedAccountObservation.init) == accountsBefore)
        #expect(stores.transactions.transactions.map(HydratedTransactionObservation.init) == transactionsBefore)
        #expect(stores.importSessions.importSessions == sessionsBefore)
        #expect(stores.importAttempts.attempts == attemptsBefore)
        #expect(stores.categories.snapshot == categoriesBefore)
    }

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
        #expect(stores.transactions.transactions.first?.repositoryDocumentId == "document-dashboard")
        #expect(stores.transactions.transactions.first?.repositorySourceDocumentName == "authoritative-dashboard.csv")
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
        #expect(initial.repositoryDocumentId == "document-dashboard")
        #expect(refreshed.repositoryDocumentId == "document-dashboard")
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
        #expect(stores.transactions.transactions.first?.repositoryDocumentId == "document-dashboard")
    }

    @Test func legacyTransactionWithoutDocumentRelationshipRemainsReadable() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(
            provider: provider,
            stores: stores,
            transactionRepo: HydrationFixtureTransactionRepo(
                transactions: [trustedTransaction(documentId: nil)]
            )
        )

        let result = try hydrator.hydrateIfNeeded()

        #expect(result.didHydrate)
        #expect(stores.transactions.transactions.count == 1)
        #expect(stores.transactions.transactions.first?.repositoryDocumentId == nil)
        #expect(stores.transactions.transactions.first?.repositorySourceDocumentName == nil)
    }

    @Test func missingReferencedDocumentRemainsReadableAndNeutral() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let repository = HydrationFixtureImportSessionRepo(base: provider.importSessionRepo, documents: [:])
        let hydrator = makeHydrator(provider: provider, stores: stores, importSessionRepo: repository)

        _ = try hydrator.hydrateIfNeeded()

        #expect(stores.transactions.transactions.first?.repositoryDocumentId == "document-dashboard")
        #expect(stores.transactions.transactions.first?.repositorySourceDocumentName == nil)
        #expect(repository.documentReadIDs == ["document-dashboard"])
    }

    @Test func inconsistentOrBlankReferencedDocumentRemainsReadableAndNeutral() throws {
        let cases = [
            importedDocument(importSessionId: "other-session"),
            importedDocument(workspaceId: "other-workspace"),
            importedDocument(filename: "  \n  ")
        ]

        for document in cases {
            let provider = try seededProvider()
            let stores = RuntimeStores()
            let repository = HydrationFixtureImportSessionRepo(
                base: provider.importSessionRepo,
                documents: [document.id: document]
            )
            let hydrator = makeHydrator(provider: provider, stores: stores, importSessionRepo: repository)

            _ = try hydrator.hydrateIfNeeded()

            #expect(stores.transactions.transactions.first?.repositoryDocumentId == "document-dashboard")
            #expect(stores.transactions.transactions.first?.repositorySourceDocumentName == nil)
        }
    }

    @Test func stagedHydrationReadsEachReferencedDocumentOnceAndTrimsItsFilename() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let repository = HydrationFixtureImportSessionRepo(
            base: provider.importSessionRepo,
            documents: ["document-dashboard": importedDocument(filename: "  durable-statement.csv  ")]
        )
        let transactions = [
            trustedTransaction(id: "transaction-a"),
            trustedTransaction(id: "transaction-b", rawRows: [trustedRawRow(id: "raw-b", normalizedRowId: "row-b", sourceOrdinal: 2)])
        ]
        let hydrator = makeHydrator(
            provider: provider,
            stores: stores,
            importSessionRepo: repository,
            transactionRepo: HydrationFixtureTransactionRepo(transactions: transactions)
        )

        _ = try hydrator.hydrateIfNeeded()

        #expect(repository.documentReadIDs == ["document-dashboard"])
        #expect(stores.transactions.transactions.map(\.repositorySourceDocumentName) == ["durable-statement.csv", "durable-statement.csv"])
    }

    @Test func documentReadFailurePreservesPreviouslyPublishedCompleteSnapshot() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let repository = HydrationFixtureImportSessionRepo(
            base: provider.importSessionRepo,
            documents: ["document-dashboard": importedDocument()]
        )
        let hydrator = makeHydrator(provider: provider, stores: stores, importSessionRepo: repository)
        _ = try hydrator.hydrateIfNeeded()
        let before = stores.transactions.transactions.map(HydratedTransactionObservation.init)
        repository.documentReadError = RepositoryError.persistenceUnavailable

        #expect(throws: RepositoryError.self) {
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        }

        #expect(stores.transactions.transactions.map(HydratedTransactionObservation.init) == before)
        #expect(stores.transactions.transactions.first?.repositorySourceDocumentName == "authoritative-dashboard.csv")
    }

    @Test func forcedHydrationValidationFailurePreservesPublishedDocumentRelationship() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let transactionRepo = HydrationFixtureTransactionRepo(transactions: [trustedTransaction()])
        let hydrator = makeHydrator(provider: provider, stores: stores, transactionRepo: transactionRepo)
        _ = try hydrator.hydrateIfNeeded()
        let before = stores.transactions.transactions.map(HydratedTransactionObservation.init)
        transactionRepo.transactions = [trustedTransaction(documentId: "replacement-document", amountDecimal: "99.99")]

        #expect(throws: RepositoryStoreHydrationError.self) {
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        }

        #expect(stores.transactions.transactions.map(HydratedTransactionObservation.init) == before)
        #expect(stores.transactions.transactions.first?.repositoryDocumentId == "document-dashboard")
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
    let importAttempts = ImportAttemptStore()
    let categories = CategoryStore()
}

private func makeHydrator(
    provider: InMemoryRepositoryProvider,
    stores: RuntimeStores,
    importSessionRepo: ImportSessionRepository? = nil,
    transactionRepo: TransactionRepository = HydrationFixtureTransactionRepo(transactions: [trustedTransaction()])
) -> RepositoryStoreHydrator {
    let resolvedImportSessionRepo = importSessionRepo ?? HydrationFixtureImportSessionRepo(
        base: provider.importSessionRepo,
        documents: ["document-dashboard": importedDocument()]
    )
    return RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: resolvedImportSessionRepo,
        transactionRepo: transactionRepo,
        categoryRepo: provider.categoryRepo,
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        categoryStore: stores.categories,
        importSessionStore: stores.importSessions,
        importAttemptStore: stores.importAttempts,
        workspaceId: "workspace-dashboard"
    )
}

private func importedDocument(
    id: String = "document-dashboard",
    workspaceId: String = "workspace-dashboard",
    importSessionId: String = "import-dashboard",
    filename: String = "authoritative-dashboard.csv"
) -> ImportedDocumentDTO {
    ImportedDocumentDTO(
        id: id,
        workspaceId: workspaceId,
        importSessionId: importSessionId,
        filename: filename,
        mimeType: "text/csv",
        sizeBytes: 128,
        legacyRawTextSHA256: String(repeating: "d", count: 64),
        createdAtISO: "2026-07-08T00:02:30Z"
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
    documentId: String? = "document-dashboard",
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
        documentId: documentId,
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

private struct HydratedTransactionObservation: Equatable {
    let id: UUID
    let repositoryTransactionId: String?
    let statementDate: String?
    let description: String
    let debit: Decimal?
    let credit: Decimal?
    let amount: Decimal
    let balance: Decimal?
    let currency: String
    let account: String
    let sourceBank: String
    let sourceFile: String
    let repositoryAccountId: String?
    let repositoryImportSessionId: String?
    let repositoryDocumentId: String?
    let repositorySourceDocumentName: String?

    init(_ transaction: Transaction) {
        id = transaction.id
        repositoryTransactionId = transaction.repositoryTransactionId
        statementDate = transaction.statementDate?.canonical
        description = transaction.description
        debit = transaction.debit
        credit = transaction.credit
        amount = transaction.amount
        balance = transaction.balance
        currency = transaction.currency
        account = transaction.account
        sourceBank = transaction.sourceBank
        sourceFile = transaction.sourceFile
        repositoryAccountId = transaction.repositoryAccountId
        repositoryImportSessionId = transaction.repositoryImportSessionId
        repositoryDocumentId = transaction.repositoryDocumentId
        repositorySourceDocumentName = transaction.repositorySourceDocumentName
    }
}

private final class HydrationFixtureImportSessionRepo: ImportSessionRepository {
    private let base: ImportSessionRepository
    private let documents: [String: ImportedDocumentDTO]
    var documentReadError: Error?
    private(set) var documentReadIDs: [String] = []

    init(base: ImportSessionRepository, documents: [String: ImportedDocumentDTO]) {
        self.base = base
        self.documents = documents
    }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String { try base.createImportSession(payload) }
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws { try base.updateImportSession(id, updates: updates) }
    func importSession(id: String) throws -> ImportSessionRecordDTO? { try base.importSession(id: id) }
    func importedDocument(id: String) throws -> ImportedDocumentDTO? {
        documentReadIDs.append(id)
        if let documentReadError { throw documentReadError }
        return documents[id]
    }
    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? { try base.priorImportedStatement(algorithm: algorithm, fingerprint: fingerprint) }
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] { try base.transactionEventOwners(keys: keys) }
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String { try base.recordImportAttempt(payload) }
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] { try base.importAttempts(workspaceId: workspaceId) }
    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? { try base.partialImportSummary(importSessionId: importSessionId) }
    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] { try base.incomingRowDispositions(importSessionId: importSessionId) }
    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult { try base.commitImportHistory(payload) }
}

private struct HydratedAccountObservation: Equatable {
    let id: UUID
    let repositoryAccountId: String?
    let workspaceId: String?
    let institution: String
    let name: String
    let nickname: String?
    let type: String
    let nativeCurrency: String
    let timeZoneIdentifier: String
    let currentBalance: Decimal
    let includeInNetWorth: Bool
    let baseCurrencyBalance: Decimal?
    let exchangeRateToBaseCurrency: Decimal?
    let status: String
    let lastImport: TimeInterval?
    let identitySummaries: [HydratedIdentityObservation]

    init(_ account: Account) {
        id = account.id
        repositoryAccountId = account.repositoryAccountId
        workspaceId = account.workspaceId
        institution = account.institution
        name = account.name
        nickname = account.nickname
        type = account.type.rawValue
        nativeCurrency = account.nativeCurrency.code
        timeZoneIdentifier = account.timeZoneIdentifier
        currentBalance = account.currentBalance
        includeInNetWorth = account.includeInNetWorth
        baseCurrencyBalance = account.baseCurrencyBalance
        exchangeRateToBaseCurrency = account.exchangeRateToBaseCurrency
        status = account.status.rawValue
        lastImport = account.lastImport?.timeIntervalSince1970
        identitySummaries = account.identitySummaries.map(HydratedIdentityObservation.init)
    }
}

private struct HydratedIdentityObservation: Equatable {
    let id: String
    let kind: String
    let redactedValue: String
    let strength: String
    let verificationState: String
    let provenance: String

    init(_ summary: AccountIdentitySummary) {
        id = summary.id
        kind = summary.kind
        redactedValue = summary.redactedValue
        strength = summary.strength
        verificationState = summary.verificationState
        provenance = summary.provenance
    }
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
