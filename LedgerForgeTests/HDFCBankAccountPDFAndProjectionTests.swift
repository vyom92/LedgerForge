import CryptoKit
import Foundation
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
        let password = try #require(environment["LEDGERFORGE_PRIVATE_HDFC_PASSWORD"])
        let oracleURL = URL(fileURLWithPath: try #require(
            environment["LEDGERFORGE_PRIVATE_HDFC_ORACLE_FILE"]
        ))
        let oracle = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf: oracleURL))
        let carriers = oracle.carriers.pdf + oracle.carriers.xls

        verifyOracleContract(oracle, carriers: carriers)
        let originalDigests = try Dictionary(uniqueKeysWithValues: carriers.map { carrier in
            let url = root.appendingPathComponent(carrier.carrier)
            return (carrier.carrier, try sourceDigest(url))
        })
        #expect(originalDigests == Dictionary(uniqueKeysWithValues: carriers.map { ($0.carrier, $0.sha256) }))

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
        #expect(endingDigests == originalDigests, "Authentic source bytes must remain unchanged")
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
                accountChoice: createsAccount ? .createNewAccount : nil
            )
            let isSupporting = !representedStatements.insert(carrier.logicalStatementKey).inserted
            if !isSupporting {
                authoritativeCarriers.insert(carrier.carrier)
            }
            try #require(result.persisted)
            #expect(result.errorMessage == nil)
            #expect(result.hydrationOutcome == .committedAndHydrated)
            #expect(result.previousImport == nil)
            #expect(result.isEquivalentSupportingSource == isSupporting)
            #expect(result.transactionCount == (isSupporting ? 0 : carrier.rows.count))
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
            #expect(!replay.persisted)
            #expect(replay.previousImport != nil, "Every exact source byte replay must be recognized")
            let priorImportedCount = authoritativeCarriers.contains(carrier.carrier)
                ? carrier.rows.count
                : 0
            #expect(replay.transactionCount == priorImportedCount)
            #expect(replay.previousImport?.transactionCount == priorImportedCount)
            #expect(try graphCounts(provider: provider, workspace: workspace).withoutAttempts == stableCounts.withoutAttempts)
        }
        let afterReplay = try graphCounts(provider: provider, workspace: workspace)
        #expect(afterReplay.withoutAttempts == stableCounts.withoutAttempts)
        #expect(afterReplay.attempts == 16)
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
        #expect(published.didHydrate)
        #expect(published.accountCount == 2)
        #expect(published.transactionCount == 165)
        #expect(reopenedStores.transactions.transactions.count == 165)
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
        #expect(digest == carrier.sha256)
        #expect(prepared.detectedInstitution == .hdfc)
        #expect(prepared.detectedDocumentType == .bankAccount)
        #expect(prepared.financialDocument.metadata.fileFormat == carrier.sourceFormat)
        #expect(prepared.parserName == (carrier.sourceFormat == .pdf ? "HDFC Bank Account PDF" : "HDFC Bank Account XLS"))
        #expect(prepared.validation.passed, "\(carrier.carrier): \(prepared.validation)")

        let document = prepared.financialDocument
        #expect(document.transactions.count == carrier.rows.count)
        #expect(document.bookedCurrency?.code == carrier.currency)
        #expect(document.financialIdentifiers.count == 1)
        #expect(document.financialIdentifiers.first?.kind == .institutionAccountId)
        #expect(document.financialIdentifiers.first?.normalizedValue == carrier.account)
        let expectedPeriodStart = try statementDate(carrier.periodStart)
        let expectedPeriodEnd = try statementDate(carrier.periodEnd)
        #expect(document.declaredStatementPeriod?.start == expectedPeriodStart)
        #expect(document.declaredStatementPeriod?.end == expectedPeriodEnd)
        #expect(document.sourceStatementEvidence?.openingBalance?.amount == decimal(carrier.summary.openingBalance))
        #expect(document.sourceStatementEvidence?.closingBalance?.amount == decimal(carrier.summary.closingBalance))

        let projection = try StatementFinancialProjection.make(from: document)
        #expect(projection.hasValidDigest())
        #expect(projection.eventCount == carrier.rows.count)
        #expect(projection.openingBalance.amount == decimal(carrier.summary.openingBalance))
        #expect(projection.closingBalance.amount == decimal(carrier.summary.closingBalance))
        #expect(projection.debitCount == carrier.summary.debitCount)
        #expect(projection.creditCount == carrier.summary.creditCount)
        #expect(projection.debitTotal.amount == decimal(carrier.summary.debits))
        #expect(projection.creditTotal.amount == decimal(carrier.summary.credits))

        var priorOrdinal = 0
        for (transaction, row) in zip(document.transactions, carrier.rows) {
            let expectedStatementDate = try statementDate(row.date)
            let expectedValueDate = try statementDate(row.valueDate)
            #expect(transaction.statementDate == expectedStatementDate, "\(carrier.carrier): posting date")
            #expect(transaction.valueDate == expectedValueDate, "\(carrier.carrier): value date")
            #expect(transaction.money.amount == signedAmount(row), "\(carrier.carrier): amount")
            #expect(transaction.runningBalanceMoney?.amount == decimal(row.closing), "\(carrier.carrier): balance")
            #expect(transaction.reference == (row.reference.isEmpty ? nil : row.reference), "\(carrier.carrier): reference")
            #expect(compact(transaction.description) == compact(row.narration), "\(carrier.carrier): narration representation")
            #expect(transaction.money.currency.code == "INR")
            let provenance = try #require(transaction.sourceProvenance.first)
            #expect(provenance.parserProfileID == (carrier.sourceFormat == .pdf
                ? HDFCBankAccountPDFParser.profileID
                : HDFCBankAccountXLSParser.profileID))
            #expect(provenance.parserProfileVersion == "1")
            #expect(provenance.sourceOrdinal > priorOrdinal)
            priorOrdinal = provenance.sourceOrdinal
            if carrier.sourceFormat == .pdf {
                #expect(provenance.sourcePage == row.physicalPage)
            } else {
                #expect(provenance.sourceOrdinal == row.physicalRow)
                #expect(provenance.sourcePage == nil)
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
        #expect(counts.accounts == 2)
        #expect(counts.transactions == 165)
        #expect(counts.projections == 8)
        #expect(counts.groups == 4)
        #expect(counts.members == 8)
        #expect(counts.attempts == expectedAttemptCount)

        let members = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspace)
        #expect(members.filter { $0.role == .authoritative }.count == 4)
        #expect(members.filter { $0.role == .supporting }.count == 4)
        #expect(Set(members.map(\.sourceFormatCode)) == ["pdf", "xls"])
        let projections = try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspace)
        #expect(Set(projections.map(\.projection.sourceFormatCode)) == ["pdf", "xls"])
        #expect(projections.allSatisfy {
            $0.projection.institutionCode == StatementFinancialProjection.hdfcInstitutionCode &&
                $0.projection.statementFamilyCode == StatementFinancialProjection.hdfcBankAccountFamilyCode &&
                $0.projection.isValid()
        })
        #expect(projections.reduce(0) { $0 + $1.projection.eventCount } == 330)
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspace)
        #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue }.count == 4)
        #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue }.count == 4)
        if expectedAttemptCount == 16 {
            #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue }.count == 8)
        }

        #expect(snapshot.accounts.count == 2)
        #expect(snapshot.transactions.count == 165)
        #expect(snapshot.importSessions.count == 8)
        #expect(snapshot.importAttempts.count == expectedAttemptCount)
        let identifiers = try accountIdentifiers(provider: provider, workspace: workspace)
        let actual = try multiset(snapshot.transactions.map { transaction in
            try transactionKey(transaction, identifiersByAccountID: identifiers)
        })
        let expected = try expectedFinancialMultiset(oracle)
        #expect(actual == expected)
        #expect(snapshot.transactions.allSatisfy { transaction in
            transaction.sourceProvenance.count == 1 &&
                [HDFCBankAccountPDFParser.profileID, HDFCBankAccountXLSParser.profileID]
                    .contains(transaction.sourceProvenance[0].parserProfileID) &&
                transaction.sourceProvenance[0].parserProfileVersion == "1" &&
                transaction.sourceProvenance[0].sourceOrdinal > 0
        })
        if requirePublishedStores {
            #expect(stores.accounts.accounts.count == 2)
            #expect(stores.transactions.transactions.count == 165)
            #expect(stores.sessions.importSessions.count == 8)
            #expect(stores.attempts.attempts.count == expectedAttemptCount)
        }
    }

    private func verifyOracleContract(_ oracle: Oracle, carriers: [Carrier]) {
        #expect(oracle.schema == "ledgerforge.hdfc.authentic-source-oracle.v2")
        #expect(oracle.totals.pdfCarriers == 4)
        #expect(oracle.totals.xlsCarriers == 4)
        #expect(oracle.totals.logicalStatements == 4)
        #expect(oracle.totals.canonicalRows == 165)
        #expect(oracle.totals.representationRows == 330)
        #expect(oracle.totals.allFinancialAndReferencesAgree)
        #expect(oracle.totals.compactNarrationMismatchCount == 0)
        #expect(oracle.totals.adjudicatedNarrationCases == 2)
        #expect(carriers.count == 8)
        #expect(oracle.carriers.pdf.map { $0.rows.count }.sorted() == [8, 19, 62, 76])
        #expect(oracle.carriers.xls.map { $0.rows.count }.sorted() == [8, 19, 62, 76])
        #expect(oracle.carriers.pdf.compactMap(\.pageCount).sorted() == [1, 2, 5, 7])
        #expect(oracle.comparisons.count == 4)
        #expect(oracle.comparisons.allSatisfy { $0.financialOrReferenceMismatches.isEmpty })
        #expect(oracle.comparisons.allSatisfy { $0.compactNarrationMismatchOrdinals.isEmpty })

        #expect(Set(oracle.narrationAdjudications.map(\.id)) == ["HDFC-NRE-ADJ-001", "HDFC-NRE-ADJ-002"])
        let first = oracle.narrationAdjudications.first { $0.id == "HDFC-NRE-ADJ-001" }
        #expect(first?.logicalStatement == "HDFC NRE FY 25-26")
        #expect(first?.pdfFinancialOrdinal == 5)
        #expect(first?.xlsPhysicalRow == 28)
        let second = oracle.narrationAdjudications.first { $0.id == "HDFC-NRE-ADJ-002" }
        #expect(second?.logicalStatement == "HDFC NRE FY 26-27")
        #expect(second?.pdfFinancialOrdinal == 15)
        #expect(second?.xlsPhysicalRow == 38)
        #expect(second?.pdfPageTransition == [1, 2])
        #expect(oracle.narrationAdjudications.allSatisfy {
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
        #expect(try graphCounts(provider: provider, workspace: workspace) == GraphCounts(
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
