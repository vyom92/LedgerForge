import CryptoKit
import Foundation
import PDFKit
import CLegacyXLS
import Testing
@testable import LedgerForge

/// Complete external authentic corpus plus an independently extracted source
/// oracle. No generated or sanitized financial source is accepted here.
@MainActor
struct HDFCBankAccountAuthenticAcceptanceTests {
    private struct Oracle: Decodable {
        let schema: String
        let carriers: Carriers
        let comparisons: [Comparison]
        let narrationAdjudications: [NarrationAdjudication]
        let totals: Totals
    }

    private struct Carriers: Decodable {
        let pdf: [Carrier]
        let xls: [Carrier]
    }

    private struct Carrier: Decodable {
        let carrier: String
        let sha256: String
        let pageCount: Int?
        let sheetRows: Int?
        let sheetColumns: Int?
        let account: String
        let periodStart: String
        let periodEnd: String
        let currency: String
        let rows: [Row]
        let summary: Summary

        var sourceFormat: FileFormat {
            carrier.lowercased().hasSuffix(".pdf") ? .pdf : .xls
        }

        var logicalStatementKey: String {
            [account, periodStart, periodEnd, currency].joined(separator: "|")
        }
    }

    private struct Row: Decodable {
        let physicalPage: Int?
        let physicalLine: Int?
        let physicalRow: Int?
        let date: String
        let narration: String
        let reference: String
        let valueDate: String
        let withdrawal: String
        let deposit: String
        let closing: String
    }

    private struct Summary: Decodable, Equatable {
        let openingBalance: String
        let debitCount: Int
        let creditCount: Int
        let debits: String
        let credits: String
        let closingBalance: String
    }

    private struct Comparison: Decodable {
        let logicalStatement: String
        let financialOrReferenceMismatches: [Mismatch]
        let compactNarrationMismatchOrdinals: [Int]
        let literalNarrationDifferenceOrdinals: [Int]
    }

    private struct Mismatch: Decodable {
        let ordinal: Int?
        let field: String
    }

    private struct NarrationAdjudication: Decodable {
        let id: String
        let logicalStatement: String
        let pdfFinancialOrdinal: Int
        let xlsPhysicalRow: Int
        let classification: String
        let pdfPageTransition: [Int]?
    }

    private struct Totals: Decodable {
        let pdfCarriers: Int
        let xlsCarriers: Int
        let logicalStatements: Int
        let canonicalRows: Int
        let representationRows: Int
        let allFinancialAndReferencesAgree: Bool
        let compactNarrationMismatchCount: Int
        let adjudicatedNarrationCases: Int
    }

    private enum CampaignOrder: String, CaseIterable {
        case chronological
        case reverse
        case deterministicMixed = "deterministic-mixed"
    }

    private enum ProviderKind: String, CaseIterable {
        case inMemory = "in-memory"
        case sqlite
    }

    @Test(.globalRuntimeStateIsolation)
    func completeOriginalsMatchSourcePersistReplayAndReopen() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(Self.originalsRoot(environment)))
        let password = try await sourceOraclePassword(environment)
        let oracle = try makeInMemorySourceOracle(root: root, password: password)
        let carriers = oracle.carriers.pdf + oracle.carriers.xls

        verifyOracleContract(oracle, carriers: carriers)
        let originalDigests = try Dictionary(uniqueKeysWithValues: carriers.map { carrier in
            let url = root.appendingPathComponent(carrier.carrier)
            return (carrier.carrier, try sourceDigest(url))
        })
        expectSourceFact(originalDigests == Dictionary(uniqueKeysWithValues: carriers.map { ($0.carrier, $0.sha256) }))

        for providerKind in ProviderKind.allCases {
            for order in CampaignOrder.allCases {
                try await runCampaign(
                    providerKind: providerKind,
                    order: order,
                    carriers: carriers,
                    oracle: oracle,
                    root: root,
                    password: password
                )
            }
        }

        let endingDigests = try Dictionary(uniqueKeysWithValues: carriers.map { carrier in
            (carrier.carrier, try sourceDigest(root.appendingPathComponent(carrier.carrier)))
        })
        expectSourceFact(endingDigests == originalDigests, "Authentic source bytes must remain unchanged")
    }

    private func runCampaign(
        providerKind: ProviderKind,
        order: CampaignOrder,
        carriers: [Carrier],
        oracle: Oracle,
        root: URL,
        password: String
    ) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-HDFC-Authentic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let databaseURL = folder.appendingPathComponent("acceptance.sqlite")
        let sqlite = providerKind == .sqlite
            ? try SQLiteRepositoryProvider(path: databaseURL.path)
            : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map {
            DatabaseProvider.verifiedSQLite($0, protectsGeneration: false)
        } ?? DatabaseProvider(inMemory: true)
        let workspace = "hdfc-authentic-\(providerKind.rawValue)-\(order.rawValue)-\(UUID().uuidString)"
        let stores = RuntimeStores()
        let hydrator = makeHydrator(
            provider: provider,
            workspace: workspace,
            stores: stores
        )
        let credentials = InMemoryStatementPasswordCredentialStore(
            passwords: [Institution.hdfc.statementPasswordCredentialScope: password]
        )
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: DefaultPasswordProvider(
                    credentialStore: credentials,
                    supportedInstitutionCodes: [Institution.hdfc.statementPasswordCredentialScope],
                    challenge: { _ in nil }
                )
            ),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspace,
                    workspaceName: "HDFC authentic \(providerKind.rawValue) \(order.rawValue)"
                )
            ),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: {
                try hydrator.hydrateIfNeeded(forceRefresh: true)
            },
            rejectedAttemptHydration: {
                try hydrator.hydrateImportAttempts()
            },
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )

        let ordered = orderedCarriers(carriers, order: order)
        let cancelled = try await engine.prepareImport(
            from: root.appendingPathComponent(try #require(ordered.first).carrier)
        )
        engine.cancelPreparedImport(cancelled)
        try verifyNoAcceptedResidue(provider: provider, workspace: workspace)

        var representedStatements = Set<String>()
        var createdAccounts = Set<String>()
        var authoritativeCarriers = Set<String>()
        for carrier in ordered {
            let createsAccount = createdAccounts.insert(carrier.account).inserted
            let result = try await prepareVerifyAndCommit(
                carrier,
                engine: engine,
                root: root,
                accountChoice: createsAccount ? .createNewAccount(displayName: "Imported review account") : nil
            )
            let isSupporting = !representedStatements.insert(carrier.logicalStatementKey).inserted
            if !isSupporting {
                authoritativeCarriers.insert(carrier.carrier)
            }
            try #require(result.persisted)
            expectSourceFact(result.errorMessage == nil)
            expectSourceFact(result.hydrationOutcome == .committedAndHydrated)
            expectSourceFact(result.previousImport == nil)
            expectSourceFact(result.isEquivalentSupportingSource == isSupporting)
            expectSourceFact(result.transactionCount == (isSupporting ? 0 : carrier.rows.count))
        }

        try verifyDurableAndHydratedState(
            provider: provider,
            workspace: workspace,
            snapshot: hydrator.stageHydration(),
            stores: stores,
            oracle: oracle,
            expectedAttemptCount: 8
        )

        let stableCounts = try graphCounts(provider: provider, workspace: workspace)
        for carrier in ordered.reversed() {
            let prepared = try await engine.prepareImport(from: root.appendingPathComponent(carrier.carrier))
            defer { engine.cancelPreparedImport(prepared) }
            try verifyPrepared(prepared, against: carrier)
            let replay = await engine.commitPreparedImport(prepared)
            expectSourceFact(!replay.persisted)
            expectSourceFact(replay.previousImport != nil, "Every exact source byte replay must be recognized")
            let priorImportedCount = authoritativeCarriers.contains(carrier.carrier)
                ? carrier.rows.count
                : 0
            expectSourceFact(replay.transactionCount == priorImportedCount)
            expectSourceFact(replay.previousImport?.transactionCount == priorImportedCount)
            expectSourceFact(try graphCounts(provider: provider, workspace: workspace).withoutAttempts == stableCounts.withoutAttempts)
        }
        let afterReplay = try graphCounts(provider: provider, workspace: workspace)
        expectSourceFact(afterReplay.withoutAttempts == stableCounts.withoutAttempts)
        expectSourceFact(afterReplay.attempts == 16)
        try verifyDurableAndHydratedState(
            provider: provider,
            workspace: workspace,
            snapshot: hydrator.stageHydration(),
            stores: stores,
            oracle: oracle,
            expectedAttemptCount: 16
        )

        guard let sqlite else { return }
        try sqlite.database.checkpointAndClose()
        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        let reopenedStores = RuntimeStores()
        let reopenedHydrator = makeHydrator(
            provider: reopenedProvider,
            workspace: workspace,
            stores: reopenedStores
        )
        let reopenedSnapshot = try reopenedHydrator.stageHydration()
        try verifyDurableAndHydratedState(
            provider: reopenedProvider,
            workspace: workspace,
            snapshot: reopenedSnapshot,
            stores: reopenedStores,
            oracle: oracle,
            expectedAttemptCount: 16,
            requirePublishedStores: false
        )
        let published = try reopenedHydrator.hydrateIfNeeded(forceRefresh: true)
        expectSourceFact(published.didHydrate)
        expectSourceFact(published.accountCount == 2)
        expectSourceFact(published.transactionCount == 165)
        expectSourceFact(reopenedStores.transactions.transactions.count == 165)
        try reopenedSQLite.database.checkpointAndClose()
    }

    private func prepareVerifyAndCommit(
        _ carrier: Carrier,
        engine: ImportEngine,
        root: URL,
        accountChoice: ImportAccountChoice?
    ) async throws -> ImportEngineResult {
        let prepared = try await engine.prepareImport(from: root.appendingPathComponent(carrier.carrier))
        defer { engine.cancelPreparedImport(prepared) }
        try verifyPrepared(prepared, against: carrier)
        return await engine.commitPreparedImport(
            prepared,
            accountChoice: accountChoice
        )
    }

    private func verifyPrepared(_ prepared: PreparedImport, against carrier: Carrier) throws {
        let digest = try prepared.sourceSnapshot.withBytes {
            SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
        }
        expectSourceFact(digest == carrier.sha256)
        expectSourceFact(prepared.detectedInstitution == .hdfc)
        expectSourceFact(prepared.detectedDocumentType == .bankAccount)
        expectSourceFact(prepared.financialDocument.metadata.fileFormat == carrier.sourceFormat)
        expectSourceFact(prepared.parserName == (carrier.sourceFormat == .pdf ? "HDFC Bank Account PDF" : "HDFC Bank Account XLS"))
        expectSourceFact(prepared.validation.passed, "\(carrier.carrier): \(prepared.validation)")

        let document = prepared.financialDocument
        expectSourceFact(document.transactions.count == carrier.rows.count)
        expectSourceFact(document.bookedCurrency?.code == carrier.currency)
        expectSourceFact(document.financialIdentifiers.count == 1)
        expectSourceFact(document.financialIdentifiers.first?.kind == .institutionAccountId)
        expectSourceFact(document.financialIdentifiers.first?.normalizedValue == carrier.account)
        let expectedPeriodStart = try statementDate(carrier.periodStart)
        let expectedPeriodEnd = try statementDate(carrier.periodEnd)
        expectSourceFact(document.declaredStatementPeriod?.start == expectedPeriodStart)
        expectSourceFact(document.declaredStatementPeriod?.end == expectedPeriodEnd)
        expectSourceFact(document.sourceStatementEvidence?.openingBalance?.amount == decimal(carrier.summary.openingBalance))
        expectSourceFact(document.sourceStatementEvidence?.closingBalance?.amount == decimal(carrier.summary.closingBalance))

        let projection = try StatementFinancialProjection.make(from: document)
        expectSourceFact(projection.hasValidDigest())
        expectSourceFact(projection.eventCount == carrier.rows.count)
        expectSourceFact(projection.openingBalance.amount == decimal(carrier.summary.openingBalance))
        expectSourceFact(projection.closingBalance.amount == decimal(carrier.summary.closingBalance))
        expectSourceFact(projection.debitCount == carrier.summary.debitCount)
        expectSourceFact(projection.creditCount == carrier.summary.creditCount)
        expectSourceFact(projection.debitTotal.amount == decimal(carrier.summary.debits))
        expectSourceFact(projection.creditTotal.amount == decimal(carrier.summary.credits))

        var priorOrdinal = 0
        for (transaction, row) in zip(document.transactions, carrier.rows) {
            let expectedStatementDate = try statementDate(row.date)
            let expectedValueDate = try statementDate(row.valueDate)
            expectSourceFact(transaction.statementDate == expectedStatementDate, "\(carrier.carrier): posting date")
            expectSourceFact(transaction.valueDate == expectedValueDate, "\(carrier.carrier): value date")
            expectSourceFact(transaction.money.amount == signedAmount(row), "\(carrier.carrier): amount")
            expectSourceFact(transaction.runningBalanceMoney?.amount == decimal(row.closing), "\(carrier.carrier): balance")
            expectSourceFact(transaction.reference == (row.reference.isEmpty ? nil : row.reference), "\(carrier.carrier): reference")
            expectSourceFact(compact(transaction.description) == compact(row.narration), "\(carrier.carrier): narration representation")
            expectSourceFact(transaction.money.currency.code == "INR")
            let provenance = try #require(transaction.sourceProvenance.first)
            expectSourceFact(provenance.parserProfileID == (carrier.sourceFormat == .pdf
                ? HDFCBankAccountPDFParser.profileID
                : HDFCBankAccountXLSParser.profileID))
            expectSourceFact(provenance.parserProfileVersion == "1")
            expectSourceFact(provenance.sourceOrdinal > priorOrdinal)
            priorOrdinal = provenance.sourceOrdinal
            if carrier.sourceFormat == .pdf {
                expectSourceFact(provenance.sourcePage == row.physicalPage)
            } else {
                expectSourceFact(provenance.sourceOrdinal == row.physicalRow)
                expectSourceFact(provenance.sourcePage == nil)
            }
        }
    }

    private func verifyDurableAndHydratedState(
        provider: DatabaseProvider,
        workspace: String,
        snapshot: RepositoryRuntimeSnapshot,
        stores: RuntimeStores,
        oracle: Oracle,
        expectedAttemptCount: Int,
        requirePublishedStores: Bool = true
    ) throws {
        let counts = try graphCounts(provider: provider, workspace: workspace)
        expectSourceFact(counts.accounts == 2)
        expectSourceFact(counts.transactions == 165)
        expectSourceFact(counts.projections == 8)
        expectSourceFact(counts.groups == 4)
        expectSourceFact(counts.members == 8)
        expectSourceFact(counts.attempts == expectedAttemptCount)

        let members = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspace)
        expectSourceFact(members.filter { $0.role == .authoritative }.count == 4)
        expectSourceFact(members.filter { $0.role == .supporting }.count == 4)
        expectSourceFact(Set(members.map(\.sourceFormatCode)) == ["pdf", "xls"])
        let projections = try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspace)
        expectSourceFact(Set(projections.map(\.projection.sourceFormatCode)) == ["pdf", "xls"])
        expectSourceFact(projections.allSatisfy {
            $0.projection.institutionCode == StatementFinancialProjection.hdfcInstitutionCode &&
                $0.projection.statementFamilyCode == StatementFinancialProjection.hdfcBankAccountFamilyCode &&
                $0.projection.isValid()
        })
        expectSourceFact(projections.reduce(0) { $0 + $1.projection.eventCount } == 330)
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspace)
        expectSourceFact(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue }.count == 4)
        expectSourceFact(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue }.count == 4)
        if expectedAttemptCount == 16 {
            expectSourceFact(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue }.count == 8)
        }

        expectSourceFact(snapshot.accounts.count == 2)
        expectSourceFact(snapshot.transactions.count == 165)
        expectSourceFact(snapshot.importSessions.count == 8)
        expectSourceFact(snapshot.importAttempts.count == expectedAttemptCount)
        let identifiers = try accountIdentifiers(provider: provider, workspace: workspace)
        let actual = try multiset(snapshot.transactions.map { transaction in
            try transactionKey(transaction, identifiersByAccountID: identifiers)
        })
        let expected = try expectedFinancialMultiset(oracle)
        expectSourceFact(actual == expected)
        expectSourceFact(snapshot.transactions.allSatisfy { transaction in
            transaction.sourceProvenance.count == 1 &&
                [HDFCBankAccountPDFParser.profileID, HDFCBankAccountXLSParser.profileID]
                    .contains(transaction.sourceProvenance[0].parserProfileID) &&
                transaction.sourceProvenance[0].parserProfileVersion == "1" &&
                transaction.sourceProvenance[0].sourceOrdinal > 0
        })
        if requirePublishedStores {
            expectSourceFact(stores.accounts.accounts.count == 2)
            expectSourceFact(stores.transactions.transactions.count == 165)
            expectSourceFact(stores.sessions.importSessions.count == 8)
            expectSourceFact(stores.attempts.attempts.count == expectedAttemptCount)
        }
    }

    private func verifyOracleContract(_ oracle: Oracle, carriers: [Carrier]) {
        expectSourceFact(oracle.schema == "ledgerforge.hdfc.authentic-source-oracle.v2")
        expectSourceFact(oracle.totals.pdfCarriers == 4)
        expectSourceFact(oracle.totals.xlsCarriers == 4)
        expectSourceFact(oracle.totals.logicalStatements == 4)
        expectSourceFact(oracle.totals.canonicalRows == 165)
        expectSourceFact(oracle.totals.representationRows == 330)
        expectSourceFact(oracle.totals.allFinancialAndReferencesAgree)
        expectSourceFact(oracle.totals.compactNarrationMismatchCount == 0)
        expectSourceFact(oracle.totals.adjudicatedNarrationCases == 2)
        expectSourceFact(carriers.count == 8)
        expectSourceFact(oracle.carriers.pdf.map { $0.rows.count }.sorted() == [8, 19, 62, 76])
        expectSourceFact(oracle.carriers.xls.map { $0.rows.count }.sorted() == [8, 19, 62, 76])
        expectSourceFact(oracle.carriers.pdf.compactMap(\.pageCount).sorted() == [1, 2, 5, 7])
        expectSourceFact(oracle.comparisons.count == 4)
        expectSourceFact(oracle.comparisons.allSatisfy { $0.financialOrReferenceMismatches.isEmpty })
        expectSourceFact(oracle.comparisons.allSatisfy { $0.compactNarrationMismatchOrdinals.isEmpty })

        expectSourceFact(Set(oracle.narrationAdjudications.map(\.id)) == ["HDFC-NRE-ADJ-001", "HDFC-NRE-ADJ-002"])
        let first = oracle.narrationAdjudications.first { $0.id == "HDFC-NRE-ADJ-001" }
        expectSourceFact(first?.logicalStatement == "HDFC NRE FY 25-26")
        expectSourceFact(first?.pdfFinancialOrdinal == 5)
        expectSourceFact(first?.xlsPhysicalRow == 28)
        let second = oracle.narrationAdjudications.first { $0.id == "HDFC-NRE-ADJ-002" }
        expectSourceFact(second?.logicalStatement == "HDFC NRE FY 26-27")
        expectSourceFact(second?.pdfFinancialOrdinal == 15)
        expectSourceFact(second?.xlsPhysicalRow == 38)
        expectSourceFact(second?.pdfPageTransition == [1, 2])
        expectSourceFact(oracle.narrationAdjudications.allSatisfy {
            $0.classification == "GENUINE_SOURCE_NARRATION_DIFFERENCE"
        })
    }

    private struct GraphCounts: Equatable {
        let accounts: Int
        let transactions: Int
        let projections: Int
        let groups: Int
        let members: Int
        let attempts: Int

        var withoutAttempts: GraphCounts {
            GraphCounts(
                accounts: accounts,
                transactions: transactions,
                projections: projections,
                groups: groups,
                members: members,
                attempts: 0
            )
        }
    }

    private func graphCounts(provider: DatabaseProvider, workspace: String) throws -> GraphCounts {
        GraphCounts(
            accounts: try provider.accountRepo.accounts(workspaceId: workspace).count,
            transactions: try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count,
            projections: try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspace).count,
            groups: try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspace).count,
            members: try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspace).count,
            attempts: try provider.importSessionRepo.importAttempts(workspaceId: workspace).count
        )
    }

    private func verifyNoAcceptedResidue(provider: DatabaseProvider, workspace: String) throws {
        expectSourceFact(try graphCounts(provider: provider, workspace: workspace) == GraphCounts(
            accounts: 0,
            transactions: 0,
            projections: 0,
            groups: 0,
            members: 0,
            attempts: 0
        ))
    }

    private func orderedCarriers(_ carriers: [Carrier], order: CampaignOrder) -> [Carrier] {
        let chronological = carriers.sorted {
            let left = (dateSortKey($0.periodStart), $0.sourceFormat == .pdf ? 0 : 1, $0.carrier)
            let right = (dateSortKey($1.periodStart), $1.sourceFormat == .pdf ? 0 : 1, $1.carrier)
            return left < right
        }
        switch order {
        case .chronological:
            return chronological
        case .reverse:
            return chronological.reversed()
        case .deterministicMixed:
            let indices = [3, 0, 6, 1, 4, 7, 2, 5]
            return indices.map { chronological[$0] }
        }
    }

    private func accountIdentifiers(
        provider: DatabaseProvider,
        workspace: String
    ) throws -> [String: String] {
        try Dictionary(uniqueKeysWithValues: provider.accountRepo.accounts(workspaceId: workspace).map { account in
            let identifiers = try provider.accountRepo.identifiers(accountId: account.id, workspaceId: workspace)
            let value = try #require(identifiers.first {
                $0.scheme == FinancialIdentifierKind.institutionAccountId.rawValue
            }?.identifier)
            return (account.id, value)
        })
    }

    private func expectedFinancialMultiset(_ oracle: Oracle) throws -> [String: Int] {
        try multiset(oracle.carriers.pdf.flatMap { carrier in
            try carrier.rows.map { row in
                try financialKey(
                    account: carrier.account,
                    date: statementDate(row.date),
                    valueDate: statementDate(row.valueDate),
                    signedAmount: signedAmount(row),
                    closing: decimal(row.closing),
                    reference: row.reference
                )
            }
        })
    }

    private func transactionKey(
        _ transaction: Transaction,
        identifiersByAccountID: [String: String]
    ) throws -> String {
        let accountID = try #require(transaction.repositoryAccountId)
        return try financialKey(
            account: #require(identifiersByAccountID[accountID]),
            date: #require(transaction.statementDate),
            valueDate: #require(transaction.valueDate),
            signedAmount: transaction.money.amount,
            closing: #require(transaction.runningBalanceMoney?.amount),
            reference: transaction.reference ?? ""
        )
    }

    private func financialKey(
        account: String,
        date: StatementDate,
        valueDate: StatementDate,
        signedAmount: Decimal,
        closing: Decimal,
        reference: String
    ) throws -> String {
        let currency = try CurrencyCode("INR")
        let amountMinor = try Money(amount: signedAmount, currency: currency).minorUnits()
        let closingMinor = try Money(amount: closing, currency: currency).minorUnits()
        return [
            account,
            date.canonical,
            valueDate.canonical,
            String(amountMinor),
            String(closingMinor),
            reference
        ].joined(separator: "|")
    }

    private func multiset(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    private func sourceDigest(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func signedAmount(_ row: Row) -> Decimal {
        row.withdrawal.isEmpty ? decimal(row.deposit) : -decimal(row.withdrawal)
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value.replacingOccurrences(of: ",", with: ""),
                locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func statementDate(_ value: String) throws -> StatementDate {
        let pieces = value.split(separator: "/")
        guard pieces.count == 3,
              let day = Int(pieces[0]),
              let month = Int(pieces[1]),
              let rawYear = Int(pieces[2]) else {
            throw HDFCBankAccountXLSParserError.malformedStatementPeriod(sourceOrdinal: 0)
        }
        return try StatementDate(
            year: rawYear < 100 ? 2000 + rawYear : rawYear,
            month: month,
            day: day
        )
    }

    private func dateSortKey(_ value: String) -> Int {
        let pieces = value.split(separator: "/").compactMap { Int($0) }
        guard pieces.count == 3 else { return .max }
        return pieces[2] * 10_000 + pieces[1] * 100 + pieces[0]
    }

    private func compact(_ value: String) -> String {
        value.filter { !$0.isWhitespace }
    }

    private func makeHydrator(
        provider: DatabaseProvider,
        workspace: String,
        stores: RuntimeStores
    ) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: stores.accounts,
            transactionStore: stores.transactions,
            categoryStore: stores.categories,
            cardStore: stores.cards,
            salaryStore: stores.salaries,
            fundingPlanStore: stores.fundingPlans,
            importSessionStore: stores.sessions,
            importAttemptStore: stores.attempts,
            workspaceId: workspace,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        )
    }

    func sourceOraclePassword(_ environment: [String: String]) async throws -> String {
        if let password = environment["LEDGERFORGE_PRIVATE_HDFC_PASSWORD"], !password.isEmpty { return password }
        return try #require(try await KeychainStatementPasswordCredentialStore().password(
            institutionCode: Institution.hdfc.statementPasswordCredentialScope
        ))
    }

    private struct HDFCSourceGlyph {
        let text: String
        let x: Double
        let y: Double
        let width: Double
    }
    private struct HDFCSourceLine {
        let y: Double
        let glyphs: [HDFCSourceGlyph]
    }
    private struct HDFCSourceMetadata: Equatable {
        let account: String
        let start: String
        let end: String
        let currency: String
    }
    private struct HDFCSourceRow {
        let page: Int
        let line: Int
        let date: String
        var narration: [String]
        var reference: String
        let valueDate: String
        let withdrawal: String
        let deposit: String
        let closing: String
    }
    private struct HDFCSourcePDF {
        let carrier: Carrier
        let transitions: [Int: [Int]]
    }
    private func sourceRequire(_ condition: @autoclosure () throws -> Bool, _ stage: String) throws {
        guard try condition() else {
            throw NSError(
                domain: "LedgerForge.HDFCIndependentSourceOracle", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Independent HDFC source check failed: " + stage]
            )
        }
    }
    private func sourceMatches(_ pattern: String, _ text: String) throws -> [[String]] {
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }
    private func sourceCapture(_ pattern: String, _ text: String) throws -> String {
        let matches = try sourceMatches(pattern, text)
        try sourceRequire(matches.count == 1 && matches[0].count > 1, "source metadata")
        return matches[0][1]
    }
    private func sourceMetadata(_ text: String) throws -> HDFCSourceMetadata {
        try HDFCSourceMetadata(
            account: sourceCapture(#"Account No\s*:\s*(\d+)"#, text),
            start: sourceCapture(#"From\s*:\s*(\d+/\d+/\d+)"#, text),
            end: sourceCapture(#"To\s*:\s*(\d+/\d+/\d+)"#, text),
            currency: sourceCapture(#"Currency\s*:\s*([A-Z]+)"#, text)
        )
    }
    private func sourceDecimal(_ text: String) throws -> Decimal {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 2)
        }
        return value
    }
    private func sourceMoney(_ text: String) throws -> String {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
        let value = try sourceDecimal(text)
        var original = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &original, 2, .plain)
        try sourceRequire(rounded == value, "native currency scale")
        return NSDecimalNumber(decimal: value).stringValue
    }
    private func sourceIsDate(_ text: String) throws -> Bool {
        !(try sourceMatches(#"^\d{2}/\d{2}/\d{2}$"#, text)).isEmpty
    }
    private func sourceValidateDate(_ text: String, fourDigitYear: Bool) throws {
        let pieces = text.split(separator: "/")
        try sourceRequire(pieces.count == 3, "date structure")
        guard let day = Int(pieces[0]), let month = Int(pieces[1]), let rawYear = Int(pieces[2]) else {
            throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 3)
        }
        try sourceRequire(pieces[2].count == (fourDigitYear ? 4 : 2), "date year width")
        let year = fourDigitYear ? rawYear : 2000 + rawYear
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 4)
        }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        try sourceRequire(actual.year == year && actual.month == month && actual.day == day, "source date")
    }
    private func sourceCompact(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }
    private func sourceLines(_ page: PDFPage) throws -> [HDFCSourceLine] {
        var seen = Set<String>()
        var groups: [Double: [HDFCSourceGlyph]] = [:]
        for index in 0..<page.numberOfCharacters {
            guard let selection = page.selection(for: NSRange(location: index, length: 1)) else {
                throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 5)
            }
            let text = selection.string ?? ""
            if text == "\n" || text == "\r" { continue }
            let rect = selection.bounds(for: page)
            let x = Double(rect.origin.x), y = Double(rect.origin.y), width = Double(rect.width)
            // PDFKit inserted line separators can repeat the preceding glyph.
            // Only identical source character/rectangle selections are deduplicated.
            let key = "\((x * 10000).rounded())|\((y * 10000).rounded())|\((width * 10000).rounded())|\(text)"
            guard seen.insert(key).inserted else { continue }
            groups[(y * 100).rounded() / 100, default: []].append(
                HDFCSourceGlyph(text: text, x: x, y: y, width: width)
            )
        }
        return groups.keys.sorted(by: >).map { y in
            HDFCSourceLine(y: y, glyphs: groups[y]!.sorted { $0.x < $1.x })
        }
    }
    private func sourceText(_ glyphs: [HDFCSourceGlyph]) -> String {
        glyphs.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func sourceColumns(_ glyphs: [HDFCSourceGlyph]) -> [String] {
        // Independently inspected boundaries of these authentic source tables.
        // This is source evidence interpretation, not a production layout contract.
        let edges: [Double] = [0, 68, 270, 350, 400, 475, 550, 1000]
        return (0..<7).map { column in
            sourceText(glyphs.filter { $0.x >= edges[column] && $0.x < edges[column + 1] })
        }
    }
    private func sourceMakeCarrier(
        url: URL, data: Data, metadata: HDFCSourceMetadata, rows: [Row], summary: Summary,
        pageCount: Int? = nil, sheetRows: Int? = nil, sheetColumns: Int? = nil
    ) -> Carrier {
        Carrier(
            carrier: url.lastPathComponent,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            pageCount: pageCount, sheetRows: sheetRows, sheetColumns: sheetColumns,
            account: metadata.account, periodStart: metadata.start, periodEnd: metadata.end,
            currency: metadata.currency, rows: rows, summary: summary
        )
    }
    private func sourceReadPDF(_ url: URL, password: String) throws -> HDFCSourcePDF {
        let data = try Data(contentsOf: url)
        guard let document = PDFDocument(data: data) else {
            throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 6)
        }
        if document.isLocked {
            try sourceRequire(document.unlock(withPassword: password), "PDF unlock")
        }
        var rows: [HDFCSourceRow] = []
        var summaries: [Summary] = []
        var metadata: [HDFCSourceMetadata] = []
        var transitions: [Int: [Int]] = [:]
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 7)
            }
            let lines = try sourceLines(page)
            metadata.append(try sourceMetadata(lines.map { sourceText($0.glyphs) }.joined(separator: " ")))
            var inSummary = false
            for (lineIndex, line) in lines.enumerated() {
                let text = sourceText(line.glyphs)
                let cells = sourceColumns(line.glyphs)
                if text.hasPrefix("STATEMENT SUMMARY") {
                    inSummary = true
                    continue
                }
                if inSummary {
                    if text.hasPrefix("Opening Balance") { continue }
                    let values = try sourceMatches(#"[\d,]+\.\d{2}|\b\d+\b"#, text).map { $0[0] }
                    try sourceRequire(values.count == 6, "PDF summary columns")
                    guard let dr = Int(values[1]), let cr = Int(values[2]) else {
                        throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 8)
                    }
                    summaries.append(try Summary(
                        openingBalance: sourceMoney(values[0]), debitCount: dr, creditCount: cr,
                        debits: sourceMoney(values[3]), credits: sourceMoney(values[4]),
                        closingBalance: sourceMoney(values[5])
                    ))
                    inSummary = false
                }
                if try sourceIsDate(cells[0]) {
                    try sourceRequire(try sourceIsDate(cells[3]), "PDF value date")
                    rows.append(try HDFCSourceRow(
                        page: pageIndex + 1, line: lineIndex + 1, date: cells[0],
                        narration: [cells[1]], reference: cells[2], valueDate: cells[3],
                        withdrawal: sourceMoney(cells[4]), deposit: sourceMoney(cells[5]),
                        closing: sourceMoney(cells[6])
                    ))
                } else if line.y > 50 && line.y < 610
                    && (!cells[1].isEmpty || !cells[2].isEmpty)
                    && [0, 3, 4, 5, 6].allSatisfy({ cells[$0].isEmpty }) {
                    try sourceRequire(!rows.isEmpty, "PDF continuation owner")
                    let last = rows.count - 1
                    rows[last].narration.append(cells[1])
                    rows[last].reference += cells[2]
                    if rows[last].page != pageIndex + 1 {
                        transitions[rows.count] = [rows[last].page, pageIndex + 1]
                    }
                }
            }
            try sourceRequire(!inSummary, "PDF complete summary")
        }
        try sourceRequire(summaries.count == 1 && !metadata.isEmpty, "PDF controls")
        try sourceRequire(metadata.allSatisfy { $0 == metadata[0] }, "PDF page identity")
        let sourceRows = rows.map {
            Row(
                physicalPage: $0.page, physicalLine: $0.line, physicalRow: nil,
                date: $0.date, narration: $0.narration.joined(separator: "\n"),
                reference: $0.reference, valueDate: $0.valueDate,
                withdrawal: $0.withdrawal, deposit: $0.deposit, closing: $0.closing
            )
        }
        return HDFCSourcePDF(
            carrier: sourceMakeCarrier(
                url: url, data: data, metadata: metadata[0], rows: sourceRows,
                summary: summaries[0], pageCount: document.pageCount
            ),
            transitions: transitions
        )
    }
    private func sourceReadXLS(_ url: URL) throws -> Carrier {
        let data = try Data(contentsOf: url)
        var error = LF_XLS_ERROR_OK
        let document = data.withUnsafeBytes { bytes in
            lf_xls_open_buffer(
                bytes.bindMemory(to: UInt8.self).baseAddress, bytes.count, &error
            )
        }
        guard let document, error == LF_XLS_ERROR_OK else {
            throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 9)
        }
        defer { lf_xls_close(document) }
        let rowCount = Int(lf_xls_row_count(document))
        let columnCount = Int(lf_xls_column_count(document))
        try sourceRequire(columnCount == 7, "XLS source columns")
        var grid: [[String]] = []
        for row in 0..<rowCount {
            var cells: [String] = []
            for column in 0..<columnCount {
                let r = UInt32(row), c = UInt32(column)
                let kind = lf_xls_cell_kind(document, r, c)
                if kind == LF_XLS_CELL_STRING {
                    cells.append(lf_xls_cell_string(document, r, c).map { String(cString: $0) } ?? "")
                } else if kind == LF_XLS_CELL_NUMBER {
                    cells.append(String(
                        format: "%.15g", locale: Locale(identifier: "en_US_POSIX"),
                        lf_xls_cell_number(document, r, c)
                    ))
                } else {
                    try sourceRequire(kind == LF_XLS_CELL_BLANK, "XLS source cell kind")
                    cells.append("")
                }
            }
            grid.append(cells)
        }
        var rows: [Row] = []
        for (index, cells) in grid.enumerated() {
            if try sourceIsDate(cells[0].trimmingCharacters(in: .whitespacesAndNewlines)) {
                rows.append(try Row(
                    physicalPage: nil, physicalLine: nil, physicalRow: index + 1,
                    date: cells[0].trimmingCharacters(in: .whitespacesAndNewlines),
                    narration: cells[1].trimmingCharacters(in: .whitespacesAndNewlines),
                    reference: cells[2].trimmingCharacters(in: .whitespacesAndNewlines),
                    valueDate: cells[3].trimmingCharacters(in: .whitespacesAndNewlines),
                    withdrawal: sourceMoney(cells[4]), deposit: sourceMoney(cells[5]),
                    closing: sourceMoney(cells[6])
                ))
            }
        }
        let indices = grid.indices.filter { grid[$0][0].hasPrefix("STATEMENT SUMMARY") }
        try sourceRequire(indices.count == 1, "XLS summary")
        let index = indices[0]
        try sourceRequire(index + 5 < grid.count, "XLS summary extent")
        let amounts = grid[index + 2], counts = grid[index + 5]
        guard let dr = Int(counts[4]), let cr = Int(counts[5]) else {
            throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 10)
        }
        let summary = try Summary(
            openingBalance: sourceMoney(amounts[0]), debitCount: dr, creditCount: cr,
            debits: sourceMoney(amounts[4]), credits: sourceMoney(amounts[5]),
            closingBalance: sourceMoney(amounts[6])
        )
        return try sourceMakeCarrier(
            url: url, data: data,
            metadata: sourceMetadata(grid.map { $0.joined(separator: " ") }.joined(separator: " ")),
            rows: rows, summary: summary, sheetRows: rowCount, sheetColumns: columnCount
        )
    }
    private func sourceCheckCarrier(_ carrier: Carrier, root: URL) throws {
        var previous = try sourceDecimal(carrier.summary.openingBalance)
        var debit = Decimal.zero, credit = Decimal.zero
        var dr = 0, cr = 0
        for row in carrier.rows {
            try sourceValidateDate(row.date, fourDigitYear: false)
            try sourceValidateDate(row.valueDate, fourDigitYear: false)
            try sourceRequire(row.withdrawal.isEmpty != row.deposit.isEmpty, "single financial direction")
            let withdrawal = try sourceDecimal(row.withdrawal.isEmpty ? "0" : row.withdrawal)
            let deposit = try sourceDecimal(row.deposit.isEmpty ? "0" : row.deposit)
            let closing = try sourceDecimal(row.closing)
            try sourceRequire(withdrawal >= 0 && deposit >= 0, "unsigned source columns")
            try sourceRequire(previous - withdrawal + deposit == closing, "running balance")
            previous = closing
            debit += withdrawal
            credit += deposit
            dr += row.withdrawal.isEmpty ? 0 : 1
            cr += row.deposit.isEmpty ? 0 : 1
        }
        let closing = try sourceDecimal(carrier.summary.closingBalance)
        let debits = try sourceDecimal(carrier.summary.debits)
        let credits = try sourceDecimal(carrier.summary.credits)
        try sourceRequire(previous == closing && debit == debits && credit == credits, "summary totals")
        try sourceRequire(dr == carrier.summary.debitCount && cr == carrier.summary.creditCount, "summary counts")
        try sourceValidateDate(carrier.periodStart, fourDigitYear: true)
        try sourceValidateDate(carrier.periodEnd, fourDigitYear: true)
        try sourceRequire(carrier.currency == "INR", "source native currency")
        let digest = SHA256.hash(data: try Data(contentsOf: root.appendingPathComponent(carrier.carrier)))
            .map { String(format: "%02x", $0) }.joined()
        try sourceRequire(digest == carrier.sha256, "original bytes unchanged")
    }
    /// Preserve the mixed queue's existing lowest-digest XLS selection while
    /// reusing the complete eight-original comparison, entirely in memory.
    func sourceMetadataForMixedBatch(root: URL, environment: [String: String]) async throws -> (
        url: URL, sha256: String, byteCount: Int, logicalStatementID: String, rowCount: Int
    ) {
        let password = try await sourceOraclePassword(environment)
        let oracle = try makeInMemorySourceOracle(root: root, password: password)
        let carrier = try #require(oracle.carriers.xls.sorted { $0.sha256 < $1.sha256 }.first)
        let url = root.appendingPathComponent(carrier.carrier)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try sourceRequire(digest == carrier.sha256, "mixed queue original digest")
        return (url, digest, data.count, "hdfc|\(carrier.logicalStatementKey)", carrier.rows.count)
    }

    private func makeInMemorySourceOracle(root: URL, password: String) throws -> Oracle {
        let resolved = root.resolvingSymlinksInPath().standardizedFileURL
        try sourceRequire(
            resolved.path == "/Users/vyom/Documents/Ledger Forge/Originals/HDFC",
            "authentic source root"
        )
        let urls = try FileManager.default.contentsOfDirectory(
            at: resolved, includingPropertiesForKeys: nil
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        let pdfs = try urls.filter { $0.pathExtension.lowercased() == "pdf" }
            .map { try sourceReadPDF($0, password: password) }
        let pdf = pdfs.map(\.carrier)
        let xls = try urls.filter { $0.pathExtension.lowercased() == "xls" }
            .map { try sourceReadXLS($0) }
        try sourceRequire(pdf.count == 4 && xls.count == 4, "complete eight original carriers")
        try sourceRequire(pdf.map { $0.rows.count }.sorted() == [8, 19, 62, 76], "complete PDF rows")
        try sourceRequire(xls.map { $0.rows.count }.sorted() == [8, 19, 62, 76], "complete XLS rows")
        try sourceRequire(pdf.compactMap(\.pageCount).sorted() == [1, 2, 5, 7], "original PDF pages")
        for carrier in pdf + xls { try sourceCheckCarrier(carrier, root: resolved) }

        var pdfByIdentity: [String: Carrier] = [:], xlsByIdentity: [String: Carrier] = [:]
        for carrier in pdf {
            try sourceRequire(pdfByIdentity[carrier.logicalStatementKey] == nil, "unique PDF statement")
            pdfByIdentity[carrier.logicalStatementKey] = carrier
        }
        for carrier in xls {
            try sourceRequire(xlsByIdentity[carrier.logicalStatementKey] == nil, "unique XLS statement")
            xlsByIdentity[carrier.logicalStatementKey] = carrier
        }
        try sourceRequire(Set(pdfByIdentity.keys) == Set(xlsByIdentity.keys), "paired source identities")
        var comparisons: [Comparison] = []
        for key in pdfByIdentity.keys.sorted() {
            let p = pdfByIdentity[key]!, x = xlsByIdentity[key]!
            try sourceRequire(p.summary == x.summary, "paired financial controls")
            try sourceRequire(p.rows.count == x.rows.count, "paired source multiplicity")
            var financial: [Mismatch] = [], compactMismatch: [Int] = [], literal: [Int] = []
            for (index, pair) in zip(p.rows, x.rows).enumerated() {
                let a = pair.0, b = pair.1, ordinal = index + 1
                let fields: [(String, String, String)] = [
                    ("date", a.date, b.date), ("valueDate", a.valueDate, b.valueDate),
                    ("withdrawal", a.withdrawal, b.withdrawal), ("deposit", a.deposit, b.deposit),
                    ("closing", a.closing, b.closing), ("reference", a.reference, b.reference)
                ]
                for (field, left, right) in fields where left != right {
                    financial.append(Mismatch(ordinal: ordinal, field: field))
                }
                if sourceCompact(a.narration) != sourceCompact(b.narration) { compactMismatch.append(ordinal) }
                if a.narration != b.narration { literal.append(ordinal) }
            }
            try sourceRequire(financial.isEmpty && compactMismatch.isEmpty, "paired ordered financial/reference/narration")
            comparisons.append(Comparison(
                logicalStatement: URL(fileURLWithPath: p.carrier).deletingPathExtension().lastPathComponent,
                financialOrReferenceMismatches: financial,
                compactNarrationMismatchOrdinals: compactMismatch,
                literalNarrationDifferenceOrdinals: literal
            ))
        }
        var adjudications: [NarrationAdjudication] = []
        for (number, label, ordinal, physicalRow) in [
            (1, "HDFC NRE FY 25-26", 5, 28), (2, "HDFC NRE FY 26-27", 15, 38)
        ] {
            // Historical adjudication label identifies the PDF only; its paired XLS
            // is always selected using the actual unique financial source identity.
            let candidates = pdfs.filter {
                URL(fileURLWithPath: $0.carrier.carrier).deletingPathExtension().lastPathComponent == label
            }
            try sourceRequire(candidates.count == 1, "adjudication source")
            let source = candidates[0], p = source.carrier
            guard let x = xlsByIdentity[p.logicalStatementKey] else {
                throw NSError(domain: "LedgerForge.HDFCIndependentSourceOracle", code: 11)
            }
            try sourceRequire(ordinal <= p.rows.count && ordinal <= x.rows.count, "adjudication extent")
            let a = p.rows[ordinal - 1], b = x.rows[ordinal - 1]
            try sourceRequire(b.physicalRow == physicalRow, "adjudication physical source row")
            try sourceRequire(a.narration != b.narration, "literal source narration difference")
            try sourceRequire(sourceCompact(a.narration) == sourceCompact(b.narration), "adjudication compact equality")
            if number == 1 {
                try sourceRequire(a.narration.split(separator: "\n").count > 1, "adjudication source lines")
            } else {
                try sourceRequire(source.transitions[ordinal] == [1, 2], "adjudication source page continuation")
            }
            adjudications.append(NarrationAdjudication(
                id: String(format: "HDFC-NRE-ADJ-%03d", number),
                logicalStatement: label, pdfFinancialOrdinal: ordinal,
                xlsPhysicalRow: physicalRow, classification: "GENUINE_SOURCE_NARRATION_DIFFERENCE",
                pdfPageTransition: source.transitions[ordinal]
            ))
        }
        let canonical = pdf.reduce(0) { $0 + $1.rows.count }
        let representations = (pdf + xls).reduce(0) { $0 + $1.rows.count }
        try sourceRequire(canonical == 165 && representations == 330, "complete representation multiplicity")
        return Oracle(
            schema: "ledgerforge.hdfc.authentic-source-oracle.v2",
            carriers: Carriers(pdf: pdf, xls: xls), comparisons: comparisons,
            narrationAdjudications: adjudications,
            totals: Totals(
                pdfCarriers: pdf.count, xlsCarriers: xls.count, logicalStatements: comparisons.count,
                canonicalRows: canonical, representationRows: representations,
                allFinancialAndReferencesAgree: comparisons.allSatisfy { $0.financialOrReferenceMismatches.isEmpty },
                compactNarrationMismatchCount: comparisons.reduce(0) { $0 + $1.compactNarrationMismatchOrdinals.count },
                adjudicatedNarrationCases: adjudications.count
            )
        )
    }


    private static func originalsRoot(_ environment: [String: String]) -> String? {
        if let root = environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT"], !root.isEmpty {
            return root
        }
        guard let pointer = environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_FILE"],
              let value = try? String(contentsOfFile: pointer, encoding: .utf8) else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Keep source values in memory when an assertion fails. The test result
    /// records the field, source location and Boolean outcome only.
    private func expectSourceFact(
        _ condition: Bool, _ comment: Comment? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(condition, comment, sourceLocation: sourceLocation)
    }

}


@MainActor
private final class RuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let categories = CategoryStore()
    let cards = CardStore()
    let salaries = SalaryStore()
    let fundingPlans = FundingPlanStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
}
