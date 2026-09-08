import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Complete external authentic corpus compared only with independently
/// extracted source facts. No source statement or FinancialDocument is made by
/// this test.
@MainActor
struct AxisBankAuthenticAcceptanceTests {
    private struct Oracle: Decodable {
        let schema: String
        let sourceInventorySha256: String
        let corpus: Corpus
        let carriers: [Carrier]
    }

    private struct Corpus: Decodable {
        let carrierCount: Int
        let logicalStatementCount: Int
        let canonicalEventCount: Int
        let representationRowCount: Int
        let formatCounts: [String: Int]
        let pageCounts: [Int]
    }

    private struct Carrier: Decodable {
        let sourceSha256: String
        let sourceSize: Int
        let format: String
        let logicalStatementId: String
        let accountIdentifierSha256: String
        let periodStart: String
        let periodEnd: String
        let rowCount: Int
        let pageCount: Int?
        let headerSourceOrdinal: Int?
        let controls: Controls
        let rows: [Row]
    }

    private struct Controls: Decodable {
        let openingBalance: String
        let closingBalance: String
        let debitTotal: String
        let creditTotal: String
    }

    private struct Row: Decodable {
        let sourceOrder: Int
        let sourceOrdinal: Int
        let sourcePage: Int?
        let date: String
        let direction: String
        let signedAmount: String
        let balance: String
        let descriptionSha256: String
        let chequeReferenceSha256: String?
        let upiOperation: String?
        let upiReference: String?
        let upiReferenceSha256: String?
        let upiSubtype: String?
    }

    private struct PreparedCarrier {
        let oracle: Carrier
        let financialDocument: FinancialDocument
        let semanticProjection: [String]
    }

    private struct Runtime {
        let provider: DatabaseProvider
        let engine: ImportEngine
        let hydrator: RepositoryStoreHydrator
        let accountStore: AccountStore
        let transactionStore: TransactionStore
        let importSessionStore: ImportSessionStore
        let importAttemptStore: ImportAttemptStore
    }

    private struct CampaignEvidence {
        let carrierByImportSessionID: [String: Carrier]
        let accountIDBySourceDigest: [String: String]
        let authoritativeImportSessionIDs: Set<String>
        let eventKeysByImportSessionID: [String: Set<TransactionEventIdentityKeyDTO>]
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusMatchesIndependentOracleAndCrossFormatProjection() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_AXIS_BANK_ROOT"]))
        let oracle = try loadOracle(
            URL(fileURLWithPath: try #require(environment["LEDGERFORGE_AXIS_BANK_ORACLE"]))
        )
        let sources = try sourceURLsByDigest(root: root)

        #expect(oracle.schema == "ledgerforge.axis-bank.source-oracle.v1")
        #expect(oracle.sourceInventorySha256 == "8eee75c51a522791fa387ddb5d7691647f90b4894f60b940c8e1f0d89eb189e3")
        #expect(oracle.corpus.carrierCount == 9)
        #expect(oracle.corpus.logicalStatementCount == 3)
        #expect(oracle.corpus.canonicalEventCount == 182)
        #expect(oracle.corpus.representationRowCount == 546)
        #expect(oracle.corpus.formatCounts == ["csv": 3, "pdf": 3, "xls": 3])
        #expect(oracle.corpus.pageCounts.sorted() == [2, 3, 4])
        #expect(oracle.carriers.count == 9)
        #expect(sources.count == 9)
        #expect(Set(oracle.carriers.map(\.sourceSha256)) == Set(sources.keys))

        let provider = DatabaseProvider(inMemory: true)
        let workspaceID = "axis-bank-authentic-parse-\(UUID().uuidString.lowercased())"
        let engine = makeEngine(provider: provider, workspaceID: workspaceID)
        var preparedCarriers: [PreparedCarrier] = []

        for carrier in oracle.carriers {
            let label = privacySafeLabel(carrier)
            let sourceURL = try #require(sources[carrier.sourceSha256])
            let prepared = try await engine.prepareImport(from: sourceURL)
            defer { engine.cancelPreparedImport(prepared) }

            let snapshotDigest = try prepared.sourceSnapshot.withBytes(sha256)
            #expect(snapshotDigest == carrier.sourceSha256, "\(label): source bytes")
            #expect(prepared.sourceSnapshot.byteCount == carrier.sourceSize, "\(label): source size")
            #expect(prepared.detectedInstitution == .axis, "\(label): institution")
            #expect(prepared.detectedDocumentType == .bankAccount, "\(label): family")
            #expect(prepared.financialDocument.metadata.fileFormat.rawValue.lowercased() == carrier.format, "\(label): format")
            #expect(prepared.validation.passed, "\(label): validation")
            try verify(prepared: prepared, against: carrier)
            preparedCarriers.append(
                PreparedCarrier(
                    oracle: carrier,
                    financialDocument: prepared.financialDocument,
                    semanticProjection: semanticProjection(prepared.financialDocument)
                )
            )
        }

        for group in Dictionary(grouping: preparedCarriers, by: { $0.oracle.logicalStatementId }).values {
            #expect(group.count == 3)
            #expect(Set(group.map { $0.oracle.format }) == Set(["csv", "pdf", "xls"]))
            #expect(Set(group.map(\.semanticProjection)).count == 1,
                    "\(group.first.map { privacySafeLabel($0.oracle) } ?? "statement"): cross-format financial projection")
        }

        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusPersistsWithProviderParityReplayReopenAndHydration() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_AXIS_BANK_ROOT"]))
        let oracle = try loadOracle(
            URL(fileURLWithPath: try #require(environment["LEDGERFORGE_AXIS_BANK_ORACLE"]))
        )
        let sources = try sourceURLsByDigest(root: root)
        #expect(oracle.carriers.count == 9)
        #expect(sources.count == 9)

        for inMemory in [true, false] {
            try await runAuthenticPersistenceCampaign(
                oracle: oracle,
                sources: sources,
                inMemory: inMemory
            )
        }
    }

    private func runAuthenticPersistenceCampaign(
        oracle: Oracle,
        sources: [String: URL],
        inMemory: Bool
    ) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Axis-Bank-Authentic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let sqlite = inMemory ? nil : try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("acceptance.sqlite").path
        )
        defer { sqlite?.database.close() }
        let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) }
            ?? DatabaseProvider(inMemory: true)
        let workspaceID = "axis-bank-authentic-persistence-\(UUID().uuidString.lowercased())"
        let runtime = makeRuntime(provider: provider, workspaceID: workspaceID)
        let ordered = try orderedCampaignCarriers(oracle.carriers)

        let cancelledCarrier = try #require(ordered.first)
        let cancelledURL = try #require(sources[cancelledCarrier.sourceSha256])
        let cancelled = try await runtime.engine.prepareImport(from: cancelledURL)
        runtime.engine.cancelPreparedImport(cancelled)
        let cancelledCommit = await runtime.engine.commitPreparedImport(cancelled)
        #expect(!cancelledCommit.persisted, "cancelled authentic confirmation is rejected")
        try verifyNoFinancialResidue(provider, workspaceID: workspaceID)

        var carrierByImportSessionID: [String: Carrier] = [:]
        var accountIDBySourceDigest: [String: String] = [:]
        var accountIDByIdentifierDigest: [String: String] = [:]
        var authoritativeImportSessionIDByLogicalStatement: [String: String] = [:]
        var authoritativeImportSessionIDs = Set<String>()
        var eventKeysByImportSessionID: [String: Set<TransactionEventIdentityKeyDTO>] = [:]
        var expectedCanonicalTransactionCount = 0

        for carrier in ordered {
            let label = privacySafeLabel(carrier)
            let sourceURL = try #require(sources[carrier.sourceSha256])
            let prepared = try await runtime.engine.prepareImport(from: sourceURL)
            try verify(prepared: prepared, against: carrier)

            let isAuthoritative = authoritativeImportSessionIDByLogicalStatement[carrier.logicalStatementId] == nil
            if isAuthoritative {
                #expect(prepared.statementEquivalenceReview == .firstAcceptedSource,
                        "\(label): first source review")
            } else if case .equivalent(let reviewedAuthority) = prepared.statementEquivalenceReview {
                #expect(reviewedAuthority == authoritativeImportSessionIDByLogicalStatement[carrier.logicalStatementId],
                        "\(label): supporting source authority")
            } else {
                Issue.record("\(label): expected equivalent supporting-source review")
            }

            let accountChoice: ImportAccountChoice
            switch try runtime.engine.reviewPreparedImport(prepared) {
            case .matchedExisting(let accountID):
                accountChoice = .useExistingAccount(accountId: accountID)
            case .choiceRequired:
                accountChoice = .createNewAccount
            default:
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            let committed = await runtime.engine.commitPreparedImport(
                prepared,
                accountChoice: accountChoice
            )
            #expect(committed.persisted, "\(label): \(committed.errorMessage ?? "confirmation failed")")
            #expect(committed.hydrationOutcome == .committedAndHydrated, "\(label): commit hydration")
            #expect(committed.isEquivalentSupportingSource == !isAuthoritative,
                    "\(label): source authority role")
            #expect(committed.transactionCount == (isAuthoritative ? carrier.rowCount : 0),
                    "\(label): canonical transaction delta")
            guard committed.persisted,
                  let accountID = committed.accountId,
                  let importSessionID = committed.importSessionId else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            if let established = accountIDByIdentifierDigest[carrier.accountIdentifierSha256] {
                #expect(accountID == established, "\(label): stable source-proven account ownership")
            } else {
                accountIDByIdentifierDigest[carrier.accountIdentifierSha256] = accountID
            }
            accountIDBySourceDigest[carrier.sourceSha256] = accountID
            carrierByImportSessionID[importSessionID] = carrier
            if isAuthoritative {
                authoritativeImportSessionIDByLogicalStatement[carrier.logicalStatementId] = importSessionID
                authoritativeImportSessionIDs.insert(importSessionID)
                expectedCanonicalTransactionCount += carrier.rowCount
                let expectedKeys = try carrier.rows.compactMap {
                    try adr031EventKey(row: $0, resolvedAccountID: accountID)
                }
                let keys = Set(expectedKeys)
                #expect(keys.count == expectedKeys.count,
                        "\(label): unique ADR-031 identities")
                #expect(expectedKeys.count == carrier.rows.filter { $0.upiReference != nil }.count,
                        "\(label): all eligible authentic UPI rows")
                eventKeysByImportSessionID[importSessionID] = keys
            }

            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == expectedCanonicalTransactionCount,
                    "\(label): canonical transaction cardinality")

            let countsBeforeReplay = try financialRepositoryCounts(provider, workspaceID: workspaceID)
            let replay = try await runtime.engine.prepareImport(from: sourceURL)
            #expect(replay.advisoryPreviousImport != nil, "\(label): exact replay advisory")
            let replayed = await runtime.engine.commitPreparedImport(replay)
            #expect(!replayed.persisted, "\(label): exact replay rejected")
            #expect(replayed.previousImport != nil, "\(label): exact replay authority")
            #expect(try financialRepositoryCounts(provider, workspaceID: workspaceID) == countsBeforeReplay,
                    "\(label): exact replay leaves no financial residue")
        }

        #expect(accountIDByIdentifierDigest.count == 2, "two source-proven Axis accounts")
        #expect(expectedCanonicalTransactionCount == oracle.corpus.canonicalEventCount)
        let evidence = CampaignEvidence(
            carrierByImportSessionID: carrierByImportSessionID,
            accountIDBySourceDigest: accountIDBySourceDigest,
            authoritativeImportSessionIDs: authoritativeImportSessionIDs,
            eventKeysByImportSessionID: eventKeysByImportSessionID
        )
        try verifyPersistedCampaign(
            provider,
            workspaceID: workspaceID,
            oracle: oracle,
            evidence: evidence
        )
        let staged = try runtime.hydrator.stageHydration()
        try verifyHydratedSnapshot(staged, oracle: oracle, evidence: evidence)
        #expect(runtime.accountStore.accounts.count == 2)
        #expect(runtime.transactionStore.transactions.count == oracle.corpus.canonicalEventCount)
        #expect(runtime.importSessionStore.importSessions.count == oracle.carriers.count)

        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: sqlite.databasePath)
            defer { reopenedSQLite.database.close() }
            let reopenedProvider = DatabaseProvider.verifiedSQLite(
                reopenedSQLite,
                protectsGeneration: false
            )
            try verifyPersistedCampaign(
                reopenedProvider,
                workspaceID: workspaceID,
                oracle: oracle,
                evidence: evidence
            )
            let reopenedRuntime = makeRuntime(
                provider: reopenedProvider,
                workspaceID: workspaceID
            )
            let hydration = try reopenedRuntime.hydrator.hydrateIfNeeded(forceRefresh: true)
            #expect(hydration.didHydrate)
            #expect(hydration.accountCount == 2)
            #expect(hydration.transactionCount == oracle.corpus.canonicalEventCount)
            #expect(hydration.importSessionCount == oracle.carriers.count)
            let reopenedSnapshot = try reopenedRuntime.hydrator.stageHydration()
            try verifyHydratedSnapshot(reopenedSnapshot, oracle: oracle, evidence: evidence)
        }
    }

    private func orderedCampaignCarriers(_ carriers: [Carrier]) throws -> [Carrier] {
        let groups = Dictionary(grouping: carriers, by: \.logicalStatementId)
        guard groups.count == 3,
              groups.values.allSatisfy({ group in
                  group.count == 3 && Set(group.map(\.format)) == Set(["csv", "pdf", "xls"])
              }) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let referenceGroups = groups.values.filter { group in
            group.contains { $0.rows.contains { $0.chequeReferenceSha256 != nil } }
        }
        guard referenceGroups.count == 1, let referenceGroup = referenceGroups.first else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let remaining = groups.values
            .filter { $0[0].logicalStatementId != referenceGroup[0].logicalStatementId }
            .sorted { $0[0].logicalStatementId < $1[0].logicalStatementId }
        let campaigns = [(referenceGroup, "pdf"), (remaining[0], "csv"), (remaining[1], "xls")]
        let formatOrder = ["csv": 0, "pdf": 1, "xls": 2]
        return try campaigns.flatMap { group, authoritativeFormat in
            guard let authoritative = group.first(where: { $0.format == authoritativeFormat }) else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            return [authoritative] + group
                .filter { $0.format != authoritativeFormat }
                .sorted { formatOrder[$0.format, default: 9] < formatOrder[$1.format, default: 9] }
        }
    }

    private func verify(prepared: PreparedImport, against carrier: Carrier) throws {
        let label = privacySafeLabel(carrier)
        let document = prepared.financialDocument
        #expect(document.bookedCurrency?.code == "INR", "\(label): currency")
        #expect(document.declaredStatementPeriod?.start.canonical == carrier.periodStart, "\(label): period start")
        #expect(document.declaredStatementPeriod?.end.canonical == carrier.periodEnd, "\(label): period end")
        #expect(document.transactions.count == carrier.rowCount, "\(label): row count")
        #expect(document.transactions.count == carrier.rows.count, "\(label): oracle row count")
        #expect(document.financialIdentifiers.count == 1, "\(label): identifier count")
        #expect(document.financialIdentifiers.first?.kind == .institutionAccountId, "\(label): identifier kind")
        #expect(document.financialIdentifiers.first?.verificationState == .verified, "\(label): identifier verification")
        #expect(document.financialIdentifiers.first.map { sha256(Data($0.normalizedValue.utf8)) } == carrier.accountIdentifierSha256,
                "\(label): identifier")

        let expectedProfile: (String, String)
        switch carrier.format {
        case "csv": expectedProfile = (AxisBankAccountParser.profileID, AxisBankAccountParser.profileVersion)
        case "pdf": expectedProfile = (AxisBankAccountPDFParser.profileID, AxisBankAccountPDFParser.profileVersion)
        case "xls": expectedProfile = (AxisBankAccountXLSParser.profileID, AxisBankAccountXLSParser.profileVersion)
        default: throw AxisBankAuthenticAcceptanceError.unsupportedFormat
        }

        for (index, pair) in zip(document.transactions, carrier.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let rowLabel = "\(label): event \(index + 1)"
            #expect(row.sourceOrder == index + 1, "\(rowLabel): oracle order")
            #expect(transaction.statementDate?.canonical == row.date, "\(rowLabel): date")
            #expect(transaction.valueDate == nil, "\(rowLabel): absent value date")
            #expect(transaction.money.amount == decimal(row.signedAmount), "\(rowLabel): signed Money")
            #expect(transaction.runningBalanceMoney?.amount == decimal(row.balance), "\(rowLabel): balance")
            #expect(direction(transaction) == row.direction, "\(rowLabel): direction")
            #expect(transaction.money.currency.code == "INR", "\(rowLabel): currency")
            #expect(transaction.runningBalanceMoney?.currency.code == "INR", "\(rowLabel): balance currency")
            #expect(transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256,
                    "\(rowLabel): reference")
            #expect(sha256(Data(collapse(transaction.description).utf8)) == row.descriptionSha256,
                    "\(rowLabel): complete source narration")
            #expect(transaction.verifiedAxisUPIEventEvidence?.operation.rawValue == row.upiOperation,
                    "\(rowLabel): UPI operation")
            #expect(transaction.verifiedAxisUPIEventEvidence?.reference == row.upiReference,
                    "\(rowLabel): UPI reference value")
            #expect(transaction.verifiedAxisUPIEventEvidence.map { sha256(Data($0.reference.utf8)) } == row.upiReferenceSha256,
                    "\(rowLabel): UPI reference")
            #expect(transaction.verifiedAxisUPIEventEvidence?.subtype.rawValue == row.upiSubtype,
                    "\(rowLabel): UPI subtype")
            #expect(transaction.sourceProvenance.count == 1, "\(rowLabel): provenance cardinality")
            let provenance = try #require(transaction.sourceProvenance.first)
            #expect(provenance.parserProfileID == expectedProfile.0, "\(rowLabel): profile")
            #expect(provenance.parserProfileVersion == expectedProfile.1, "\(rowLabel): profile version")
            #expect(provenance.structuredReferenceDigest == row.chequeReferenceSha256,
                    "\(rowLabel): reference digest")
            #expect(isLowercaseSHA256(provenance.normalizedRecordDigest), "\(rowLabel): row digest")
            if carrier.format == "pdf" {
                #expect(provenance.sourcePage == row.sourcePage, "\(rowLabel): page")
            } else {
                #expect(provenance.sourcePage == nil, "\(rowLabel): no tabular page")
                #expect(provenance.sourceOrdinal == row.sourceOrdinal, "\(rowLabel): physical source ordinal")
            }
        }

        let ordinals = document.transactions.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
        #expect(ordinals.count == carrier.rows.count, "\(label): complete ordinals")
        #expect(zip(ordinals, ordinals.dropFirst()).allSatisfy(<), "\(label): source order")
        if carrier.format == "pdf" {
            let pages = document.transactions.compactMap { $0.sourceProvenance.first?.sourcePage }
            #expect(pages.count == carrier.rows.count, "\(label): complete pages")
            #expect(pages.allSatisfy { (1...(carrier.pageCount ?? 0)).contains($0) }, "\(label): page range")
        } else {
            #expect(carrier.headerSourceOrdinal.map { $0 + 1 } == carrier.rows.first?.sourceOrdinal,
                    "\(label): first transaction source ordinal")
        }

        let controls = try financialControls(document)
        #expect(controls.opening == decimal(carrier.controls.openingBalance), "\(label): opening")
        #expect(controls.closing == decimal(carrier.controls.closingBalance), "\(label): closing")
        #expect(controls.debit == decimal(carrier.controls.debitTotal), "\(label): debit total")
        #expect(controls.credit == decimal(carrier.controls.creditTotal), "\(label): credit total")
    }

    private func verifyPersistedCampaign(
        _ provider: DatabaseProvider,
        workspaceID: String,
        oracle: Oracle,
        evidence: CampaignEvidence
    ) throws {
        let accounts = try provider.accountRepo.accounts(workspaceId: workspaceID)
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        let projections = try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID)
        let groups = try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID)
        let members = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID)

        #expect(accounts.count == 2)
        #expect(transactions.count == oracle.corpus.canonicalEventCount)
        #expect(projections.count == oracle.carriers.count)
        #expect(groups.count == oracle.corpus.logicalStatementCount)
        #expect(members.count == oracle.carriers.count)
        #expect(members.filter { $0.role == .authoritative }.count == oracle.corpus.logicalStatementCount)
        #expect(members.filter { $0.role == .supporting }.count == 6)
        #expect(Dictionary(grouping: members, by: \.sourceFormatCode).mapValues(\.count) == [
            "csv": 3, "pdf": 3, "xls": 3
        ])

        let accountIDs = Set(accounts.map(\.id))
        var identifierDigests = Set<String>()
        for account in accounts {
            let identifiers = try provider.accountRepo.identifiers(
                accountId: account.id,
                workspaceId: workspaceID
            ).filter { $0.scheme == FinancialIdentifierKind.institutionAccountId.rawValue }
            #expect(identifiers.count == 1, "one source-proven identifier per Axis account")
            if let identifier = identifiers.first {
                identifierDigests.insert(sha256(Data(identifier.identifier.utf8)))
            }
        }
        #expect(identifierDigests == Set(oracle.carriers.map(\.accountIdentifierSha256)))

        guard Set(projections.map { $0.projection.id }).count == projections.count else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let projectionByID = Dictionary(uniqueKeysWithValues: projections.map { ($0.projection.id, $0) })
        for record in projections {
            let carrier = try #require(evidence.carrierByImportSessionID[record.importSessionID])
            let label = privacySafeLabel(carrier)
            let projection = record.projection
            #expect(projection.isValid(), "\(label): durable projection validity")
            #expect(projection.algorithmIdentifier == StatementFinancialProjectionDTO.axisAlgorithm,
                    "\(label): distinct Axis projection algorithm")
            #expect(record.workspaceID == workspaceID, "\(label): projection workspace")
            #expect(record.accountID == evidence.accountIDBySourceDigest[carrier.sourceSha256],
                    "\(label): projection account")
            #expect(accountIDs.contains(record.accountID), "\(label): available projection account")
            #expect(projection.institutionCode == StatementFinancialProjection.axisInstitutionCode)
            #expect(projection.statementFamilyCode == StatementFinancialProjection.axisBankAccountFamilyCode)
            let expectedProfile = try profile(for: carrier)
            #expect(projection.parserProfileID == expectedProfile.0, "\(label): projection profile")
            #expect(projection.parserProfileVersion == expectedProfile.1, "\(label): projection version")
            #expect(projection.sourceFormatCode == carrier.format, "\(label): source format")
            #expect(projection.statementStartDateISO == carrier.periodStart, "\(label): period start")
            #expect(projection.statementEndDateISO == carrier.periodEnd, "\(label): period end")
            #expect(projection.nativeCurrency == "INR", "\(label): native currency")
            #expect(projection.eventCount == carrier.rowCount, "\(label): event multiplicity")
            #expect(projection.openingBalanceMinor == (try minorUnits(carrier.controls.openingBalance)))
            #expect(decimal(projection.openingBalanceDecimal) == decimal(carrier.controls.openingBalance))
            #expect(projection.debitTotalMinor == (try minorUnits(carrier.controls.debitTotal)))
            #expect(decimal(projection.debitTotalDecimal) == decimal(carrier.controls.debitTotal))
            #expect(projection.creditTotalMinor == (try minorUnits(carrier.controls.creditTotal)))
            #expect(decimal(projection.creditTotalDecimal) == decimal(carrier.controls.creditTotal))
            #expect(projection.closingBalanceMinor == (try minorUnits(carrier.controls.closingBalance)))
            #expect(decimal(projection.closingBalanceDecimal) == decimal(carrier.controls.closingBalance))
            for (event, row) in zip(projection.events, carrier.rows) {
                #expect(event.ordinal == row.sourceOrder, "\(label): projection order")
                #expect(event.statementDateISO == row.date, "\(label): projection date")
                #expect(event.valueDateISO == nil, "\(label): authentic absent value date")
                #expect(event.direction == row.direction, "\(label): projection direction")
                #expect(event.signedAmountMinor == (try minorUnits(row.signedAmount)), "\(label): projection Money")
                #expect(decimal(event.signedAmountDecimal) == decimal(row.signedAmount),
                        "\(label): projection Money decimal")
                #expect(event.runningBalanceMinor == (try minorUnits(row.balance)), "\(label): projection balance")
                #expect(decimal(event.runningBalanceDecimal) == decimal(row.balance),
                        "\(label): projection balance decimal")
                #expect(event.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256,
                        "\(label): source-owned cheque/reference")
            }
        }

        for carrierGroup in Dictionary(grouping: oracle.carriers, by: \.logicalStatementId).values {
            let records = projections.filter { record in
                evidence.carrierByImportSessionID[record.importSessionID]?.logicalStatementId == carrierGroup[0].logicalStatementId
            }
            #expect(records.count == 3)
            #expect(Set(records.map { $0.projection.digest }).count == 1,
                    "\(privacySafeLabel(carrierGroup[0])): durable cross-format digest")
        }

        for group in groups {
            let groupMembers = members.filter { $0.groupID == group.id }
            #expect(groupMembers.count == 3)
            #expect(Set(groupMembers.map(\.sourceFormatCode)) == Set(["csv", "pdf", "xls"]))
            #expect(group.projectionAlgorithm == StatementFinancialProjectionDTO.axisAlgorithm)
            #expect(accountIDs.contains(group.accountID))
            let authorityMembers = groupMembers.filter { $0.role == .authoritative }
            #expect(authorityMembers.count == 1)
            #expect(authorityMembers.first?.projectionID == group.authoritativeProjectionID)
            for member in groupMembers {
                let record = try #require(projectionByID[member.projectionID])
                let carrier = try #require(evidence.carrierByImportSessionID[record.importSessionID])
                #expect(record.accountID == group.accountID)
                #expect(record.projection.digest == group.projectionDigest)
                #expect(member.sourceFormatCode == carrier.format)
                #expect(member.role == (evidence.authoritativeImportSessionIDs.contains(record.importSessionID)
                    ? .authoritative : .supporting))
            }
        }

        let transactionIDs = Set(transactions.map(\.id))
        for importSessionID in evidence.authoritativeImportSessionIDs {
            let carrier = try #require(evidence.carrierByImportSessionID[importSessionID])
            let label = privacySafeLabel(carrier)
            let expectedProfile = try profile(for: carrier)
            let sourceTransactions = transactions
                .filter { $0.importSessionId == importSessionID }
                .sorted {
                    ($0.rawRows.first?.sourceOrdinal ?? Int.max) <
                        ($1.rawRows.first?.sourceOrdinal ?? Int.max)
                }
            #expect(sourceTransactions.count == carrier.rowCount, "\(label): canonical source ownership")
            for (transaction, row) in zip(sourceTransactions, carrier.rows) {
                #expect(transaction.accountId == evidence.accountIDBySourceDigest[carrier.sourceSha256])
                #expect(transaction.valueDateISO == nil, "\(label): persisted absent value date")
                #expect(transaction.postedDateISO == row.date, "\(label): persisted date")
                #expect(transaction.direction == row.direction, "\(label): persisted direction")
                #expect(transaction.nativeCurrency == "INR", "\(label): persisted currency")
                #expect(transaction.amountMinor == (try minorUnits(row.signedAmount)), "\(label): persisted Money")
                #expect(decimal(transaction.amountDecimal) == decimal(row.signedAmount),
                        "\(label): persisted Money decimal")
                #expect(transaction.runningBalanceMinor == (try minorUnits(row.balance)),
                        "\(label): persisted balance")
                #expect(transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256,
                        "\(label): persisted reference")
                #expect(transaction.description.map { sha256(Data(collapse($0).utf8)) } == row.descriptionSha256,
                        "\(label): complete persisted source narration")
                #expect(transaction.rawRows.count == 1, "\(label): normalized row provenance")
                let raw = try #require(transaction.rawRows.first)
                if carrier.format == "pdf" {
                    #expect((raw.sourceOrdinal ?? 0) > 0, "\(label): PDF physical source order")
                } else {
                    #expect(raw.sourceOrdinal == row.sourceOrdinal, "\(label): physical source ordinal")
                }
                #expect(raw.parserProfileId == expectedProfile.0, "\(label): persisted profile")
                #expect(raw.parserProfileVersion == expectedProfile.1, "\(label): persisted profile version")
                #expect(raw.normalizedRecordDigest.map(isLowercaseSHA256) == true,
                        "\(label): persisted row digest")
            }
            let sourceOrdinals = sourceTransactions.compactMap { $0.rawRows.first?.sourceOrdinal }
            #expect(sourceOrdinals.count == carrier.rowCount, "\(label): complete persisted source order")
            #expect(zip(sourceOrdinals, sourceOrdinals.dropFirst()).allSatisfy(<),
                    "\(label): strictly increasing persisted source order")
        }

        var ownerSessionByEventKey: [TransactionEventIdentityKeyDTO: String] = [:]
        for (importSessionID, keys) in evidence.eventKeysByImportSessionID {
            for key in keys {
                guard ownerSessionByEventKey.updateValue(importSessionID, forKey: key) == nil else {
                    throw AxisBankAuthenticAcceptanceError.campaignInvariant
                }
            }
        }
        #expect(ownerSessionByEventKey.count == 120, "complete eligible ADR-031 authentic set")
        let owners = try provider.importSessionRepo.transactionEventOwners(
            keys: Set(ownerSessionByEventKey.keys)
        )
        #expect(owners.count == ownerSessionByEventKey.count, "all ADR-031 digests remain durable")
        for (key, expectedImportSessionID) in ownerSessionByEventKey {
            let owner = try #require(owners[key])
            let carrier = try #require(evidence.carrierByImportSessionID[expectedImportSessionID])
            #expect(owner.importSessionId == expectedImportSessionID)
            #expect(owner.accountId == evidence.accountIDBySourceDigest[carrier.sourceSha256])
            #expect(transactionIDs.contains(owner.transactionId))
        }

        let canonicalCarriers = oracle.carriers.reduce(into: [String: Carrier]()) { result, carrier in
            if result[carrier.logicalStatementId] == nil { result[carrier.logicalStatementId] = carrier }
        }.values
        var subtypeSetsByPrivateReference: [String: Set<String>] = [:]
        for carrier in canonicalCarriers {
            for row in carrier.rows where row.upiReference != nil {
                let privateKey = "\(carrier.accountIdentifierSha256)|\(row.upiReference!)"
                subtypeSetsByPrivateReference[privateKey, default: []].insert(try #require(row.upiSubtype))
            }
        }
        #expect(subtypeSetsByPrivateReference.values.filter { $0.count > 1 }.count == 2,
                "authentic reused references remain distinct through subtype")
    }

    private func verifyHydratedSnapshot(
        _ snapshot: RepositoryRuntimeSnapshot,
        oracle: Oracle,
        evidence: CampaignEvidence
    ) throws {
        #expect(snapshot.accounts.count == 2)
        #expect(snapshot.transactions.count == oracle.corpus.canonicalEventCount)
        #expect(snapshot.importSessions.count == oracle.carriers.count)
        #expect(snapshot.hydrationResult.didHydrate)
        #expect(snapshot.hydrationResult.accountCount == 2)
        #expect(snapshot.hydrationResult.transactionCount == oracle.corpus.canonicalEventCount)
        #expect(snapshot.hydrationResult.importSessionCount == oracle.carriers.count)
        #expect(snapshot.transactions.allSatisfy { $0.valueDate == nil })
        // ADR-031 persists only the privacy-safe owner digest. Hydration must
        // not reconstruct typed UPI evidence from retained narration.
        #expect(snapshot.transactions.allSatisfy { $0.verifiedAxisUPIEventEvidence == nil })

        for importSessionID in evidence.authoritativeImportSessionIDs {
            let carrier = try #require(evidence.carrierByImportSessionID[importSessionID])
            let expectedProfile = try profile(for: carrier)
            let transactions = snapshot.transactions
                .filter { $0.repositoryImportSessionId == importSessionID }
                .sorted {
                    ($0.sourceProvenance.first?.sourceOrdinal ?? Int.max) <
                        ($1.sourceProvenance.first?.sourceOrdinal ?? Int.max)
                }
            #expect(transactions.count == carrier.rowCount)
            for (transaction, row) in zip(transactions, carrier.rows) {
                #expect(transaction.statementDate?.canonical == row.date)
                #expect(sha256(Data(collapse(transaction.description).utf8)) == row.descriptionSha256,
                        "Complete authoritative source narration survives hydration")
                #expect(transaction.money.amount == decimal(row.signedAmount))
                #expect(transaction.runningBalanceMoney?.amount == decimal(row.balance))
                #expect(direction(transaction) == row.direction)
                #expect(transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256)
                #expect(transaction.sourceProvenance.count == 1)
                let provenance = try #require(transaction.sourceProvenance.first)
                if carrier.format == "pdf" {
                    #expect(provenance.sourceOrdinal > 0)
                } else {
                    #expect(provenance.sourceOrdinal == row.sourceOrdinal)
                }
                #expect(provenance.parserProfileID == expectedProfile.0)
                #expect(provenance.parserProfileVersion == expectedProfile.1)
                #expect(provenance.normalizedRecordDigest.isEmpty == false)
            }
            let sourceOrdinals = transactions.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
            #expect(sourceOrdinals.count == carrier.rowCount)
            #expect(zip(sourceOrdinals, sourceOrdinals.dropFirst()).allSatisfy(<))
        }
    }

    private func verifyNoFinancialResidue(
        _ provider: DatabaseProvider,
        workspaceID: String
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).isEmpty)
    }

    private func financialRepositoryCounts(
        _ provider: DatabaseProvider,
        workspaceID: String
    ) throws -> [Int] {
        [
            try provider.accountRepo.accounts(workspaceId: workspaceID).count,
            try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count,
            try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).count,
            try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).count,
            try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).count
        ]
    }

    private func profile(for carrier: Carrier) throws -> (String, String) {
        switch carrier.format {
        case "csv": return (AxisBankAccountParser.profileID, AxisBankAccountParser.profileVersion)
        case "pdf": return (AxisBankAccountPDFParser.profileID, AxisBankAccountPDFParser.profileVersion)
        case "xls": return (AxisBankAccountXLSParser.profileID, AxisBankAccountXLSParser.profileVersion)
        default: throw AxisBankAuthenticAcceptanceError.unsupportedFormat
        }
    }

    private func adr031EventKey(
        row: Row,
        resolvedAccountID: String
    ) throws -> TransactionEventIdentityKeyDTO? {
        let components = (row.upiOperation, row.upiReference, row.upiReferenceSha256, row.upiSubtype)
        if components == (nil, nil, nil, nil) { return nil }
        guard !resolvedAccountID.isEmpty,
              let operation = row.upiOperation,
              let reference = row.upiReference,
              let referenceDigest = row.upiReferenceSha256,
              let subtype = row.upiSubtype,
              ["p2a", "p2m"].contains(operation),
              reference.utf8.count == 12,
              reference.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }),
              sha256(Data(reference.utf8)) == referenceDigest,
              ["posting", "credit-adjustment"].contains(subtype) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let algorithm = "ledgerforge.transaction-event.axis-upi-reference.v1"
        let fields = [algorithm, resolvedAccountID, "axis-upi", operation, reference, subtype]
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return TransactionEventIdentityKeyDTO(
            algorithm: algorithm,
            digest: sha256(Data(payload.utf8))
        )
    }

    private func minorUnits(_ value: String) throws -> Int64 {
        try Money(
            amount: decimal(value),
            currency: CurrencyCode("INR")
        ).minorUnits()
    }

    private func financialControls(
        _ document: FinancialDocument
    ) throws -> (opening: Decimal, closing: Decimal, debit: Decimal, credit: Decimal) {
        let first = try #require(document.transactions.first)
        let last = try #require(document.transactions.last)
        let firstBalance = try #require(first.runningBalanceMoney)
        let opening = try firstBalance - first.money
        let currency = try #require(document.bookedCurrency)
        let zero = try Money(amount: 0, currency: currency)
        let debit = try document.transactions.compactMap(\.debitMoney).reduce(zero, +)
        let credit = try document.transactions.compactMap(\.creditMoney).reduce(zero, +)
        return (
            opening.amount,
            try #require(last.runningBalanceMoney).amount,
            debit.amount,
            credit.amount
        )
    }

    private func semanticProjection(_ document: FinancialDocument) -> [String] {
        document.transactions.enumerated().map { index, transaction in
            [
                String(index + 1),
                transaction.statementDate?.canonical ?? "",
                direction(transaction),
                (try? transaction.money.canonicalDecimalString()) ?? "",
                (try? transaction.runningBalanceMoney?.canonicalDecimalString()) ?? "",
                transaction.reference.map { sha256(Data($0.utf8)) } ?? ""
            ].joined(separator: "|")
        }
    }

    private func direction(_ transaction: Transaction) -> String {
        switch (transaction.debitMoney, transaction.creditMoney) {
        case (.some, nil): "debit"
        case (nil, .some): "credit"
        default: "invalid"
        }
    }

    private func makeRuntime(provider: DatabaseProvider, workspaceID: String) -> Runtime {
        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let importAttemptStore = ImportAttemptStore()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry()),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspaceID,
                    workspaceName: "Axis Bank authentic acceptance"
                )
            ),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(
                stateProvider: { nil }
            )
        )
        return Runtime(
            provider: provider,
            engine: engine,
            hydrator: hydrator,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore
        )
    }

    private func makeEngine(provider: DatabaseProvider, workspaceID: String) -> ImportEngine {
        makeRuntime(provider: provider, workspaceID: workspaceID).engine
    }

    private func loadOracle(_ url: URL) throws -> Oracle {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Oracle.self, from: Data(contentsOf: url))
    }

    private func sourceURLsByDigest(root: URL) throws -> [String: URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AxisBankAuthenticAcceptanceError.corpusUnavailable
        }
        var result: [String: URL] = [:]
        for case let url as URL in enumerator {
            guard ["csv", "pdf", "xls"].contains(url.pathExtension.lowercased()),
                  (try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            let digest = sha256(try Data(contentsOf: url, options: [.mappedIfSafe]))
            guard result[digest] == nil else {
                throw AxisBankAuthenticAcceptanceError.duplicateSourceDigest
            }
            result[digest] = url
        }
        return result
    }

    private func privacySafeLabel(_ carrier: Carrier) -> String {
        "\(carrier.format):\(carrier.logicalStatementId.prefix(12))"
    }

    private func collapse(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func isLowercaseSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66)
        }
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private enum AxisBankAuthenticAcceptanceError: Error {
        case corpusUnavailable
        case duplicateSourceDigest
        case unsupportedFormat
        case campaignInvariant
    }
}
