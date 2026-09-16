import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Required production-path acceptance for the complete registered authentic
/// Axis credit-card corpus. Private paths, credentials, filenames, source
/// narrations, and reference values never cross the test-report boundary.
@Suite(.serialized)
@MainActor
struct AxisCreditCardAuthenticAcceptanceTests {
    private static let rootKey = "LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY"

    @MainActor private static var completedPhases = Set<String>()
    @MainActor private static var completedCorpus: LogicalCorpus?

    private enum SourceFormat: String, CaseIterable, Codable, Hashable {
        case appPDF = "app_pdf"
        case xlsx
        case traditionalPDF = "traditional_pdf"

        @MainActor var parserProfileID: String {
            switch self {
            case .xlsx: AxisCreditCardXLSXParser.profileID
            case .appPDF, .traditionalPDF: AxisCreditCardPDFParser.profileID
            }
        }

        var parserProfileVersion: String { "1" }
    }

    private struct SourceOracle: Decodable {
        let schema: String
        let authority: String
        let sourceInventorySHA256: String
        let corpus: OracleCorpus
        let records: [OracleRecord]

        enum CodingKeys: String, CodingKey {
            case schema, authority, corpus, records
            case sourceInventorySHA256 = "source_inventory_sha256"
        }
    }

    private struct OracleCorpus: Decodable {
        let carrierCount: Int
        let logicalStatementCount: Int
        let transactionRowCount: Int
        let formatCounts: [String: Int]
        let cycles: [String]

        enum CodingKeys: String, CodingKey {
            case cycles
            case carrierCount = "carrier_count"
            case logicalStatementCount = "logical_statement_count"
            case transactionRowCount = "transaction_row_count"
            case formatCounts = "format_counts"
        }
    }

    private struct OracleRecord: Decodable {
        let sourceSHA256: String
        let format: SourceFormat
        let cycle: String
        let rowCount: Int
        let rows: [OracleRow]
        let controls: [String: String]

        enum CodingKeys: String, CodingKey {
            case format, cycle, rows, controls
            case sourceSHA256 = "source_sha256"
            case rowCount = "row_count"
        }
    }

    private struct OracleRow: Decodable {
        let date: String
        let amount: String
        let effect: String
        let reference: String?
        let narration: String
        let originalMerchantMoney: OracleMoney?

        enum CodingKeys: String, CodingKey {
            case date, amount, effect, reference, narration
            case originalMerchantMoney = "original_merchant_money"
        }
    }

    private struct OracleMoney: Decodable {
        let currency: String
        let amount: String
    }

    private struct FinancialKey: Hashable {
        let date: String
        let effect: String
        let currency: String
        let amountMagnitude: String
    }

    private struct PhysicalSource {
        let url: URL
        let document: FinancialDocument
        let format: SourceFormat
        let isLocked: Bool
        let cycle: String
        let rawDigest: String
        let oracle: OracleRecord
    }

    private struct LogicalCorpus {
        let oracle: SourceOracle
        let inMemoryOracleDigest: String
        let sources: [PhysicalSource]
        let byCycle: [String: [SourceFormat: PhysicalSource]]
    }

    private struct PrivateRuntime {
        let provider: DatabaseProvider
        let engine: ImportEngine
        let challengeProbe: ChallengeInvocationProbe
        let sqlite: SQLiteRepositoryProvider?
        let databaseURL: URL?
        let cleanup: () -> Void
    }

    private actor ChallengeInvocationProbe {
        private var invocationCount = 0
        func recordInvocation() { invocationCount += 1 }
        func count() -> Int { invocationCount }
    }

    private enum AuthenticAcceptanceError: Error {
        case sourceDirectoryUnreadable
        case sourceUnreadable
        case oracleUnavailable
        case oracleMismatch
        case appCredentialUnavailable
        case traditionalCredentialUnavailable
        case unexpectedPasswordChallenge
        case unexpectedCorpusShape
        case financialOutputMismatch
        case missingProductionCycle(format: String, oracleCycle: String)
        case validationMismatch(format: String, cycle: String, issueKinds: [String])
        case sourceProjectionMismatch(format: String, cycle: String, row: Int, field: String)
        case campaignInvariant
    }

    private static let expectedMonthlyCounts: [String: Int] = [
        "2025-02": 44,
        "2025-03": 33,
        "2025-04": 29,
        "2025-05": 47,
        "2025-06": 37,
        "2025-07": 36,
        "2025-08": 35,
        "2025-09": 81,
        "2025-10": 47,
        "2025-11": 71,
        "2025-12": 121,
        "2026-01": 89,
        "2026-02": 95,
        "2026-03": 56,
        "2026-04": 178,
        "2026-05": 143,
        "2026-06": 154,
        "2026-07": 81
    ]

    private static let expectedFormatCounts: [SourceFormat: Int] = [
        .appPDF: 18,
        .xlsx: 7,
        .traditionalPDF: 7
    ]

    private static var expectedCycles: [String] { expectedMonthlyCounts.keys.sorted() }
    private static var expectedCanonicalTransactionCount: Int {
        expectedMonthlyCounts.values.reduce(0, +)
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusMatchesIndependentSourceOracle() async throws {
        let corpus = try await Self.requireCorpus()
        try Self.assertCompleteSourceTruth(corpus)
        try Self.recordCompletedPhase("corpus", corpus: corpus)
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusPersistsThroughOrdinaryConfirmationWithParityReplayAndReopen() async throws {
        let corpus = try await Self.requireCorpus()
        let appFirst = Self.orderedSources(
            corpus,
            formatPriority: [.appPDF, .xlsx, .traditionalPDF]
        )
        let xlsxFirstReverse = Self.orderedSources(
            corpus,
            cycles: Self.expectedCycles.reversed(),
            formatPriority: [.xlsx, .traditionalPDF, .appPDF]
        )

        let mixedCycles = Self.expectedCycles.enumerated()
            .sorted { ($0.offset % 3, $0.offset) < ($1.offset % 3, $1.offset) }
            .map(\.element)
        let traditionalFirstMixed = Self.orderedSources(
            corpus, cycles: mixedCycles,
            formatPriority: [.traditionalPDF, .appPDF, .xlsx]
        )
        for inMemory in [true, false] {
            for sources in [appFirst, xlsxFirstReverse, traditionalFirstMixed] {
                try await Self.runAuthenticCampaign(
                    corpus: corpus, orderedSources: sources, inMemory: inMemory
                )
            }
        }
        try Self.recordCompletedPhase("corpus", corpus: corpus)
        try Self.recordCompletedPhase("persistence", corpus: corpus)
    }

    private static func requireCorpus() async throws -> LogicalCorpus {
        if let completedCorpus { return completedCorpus }
        guard let rootPath = ProcessInfo.processInfo.environment[rootKey], !rootPath.isEmpty else {
            throw AuthenticAcceptanceError.oracleUnavailable
        }
        let corpus = try await authenticCorpus(root: URL(fileURLWithPath: rootPath, isDirectory: true))
        completedCorpus = corpus
        return corpus
    }

    private static func authenticCorpus(root: URL) async throws -> LogicalCorpus {
        let oracle = try await loadInMemorySourceOracle(root: root)
        try validateOracleContract(oracle)

        let recordDigests = oracle.records.map(\.sourceSHA256)
        try require(Set(recordDigests).count == recordDigests.count, error: .oracleMismatch)
        let recordsByDigest = Dictionary(uniqueKeysWithValues: oracle.records.map {
            ($0.sourceSHA256, $0)
        })

        let challengeProbe = ChallengeInvocationProbe()
        let passwordProvider = try await makePasswordProvider(challengeProbe: challengeProbe)
        let preparationProvider = DatabaseProvider(inMemory: true)
        let preparationCoordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: preparationProvider,
            mapper: ImportPersistenceMapper(
                workspaceId: "axis-authentic-preparation-\(UUID().uuidString)",
                workspaceName: "Axis authentic preparation"
            )
        )
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: passwordProvider
            ),
            importPersistenceCoordinator: preparationCoordinator,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { preparationProvider.persistenceState },
            providerGenerationProvider: { preparationProvider.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
            },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(
                stateProvider: { nil }
            )
        )

        let files = try regularFinancialFiles(under: root)
        try require(files.count == 32, error: .unexpectedCorpusShape)
        var sources = [PhysicalSource]()
        sources.reserveCapacity(files.count)
        for url in files {
            let bytes: Data
            do { bytes = try Data(contentsOf: url, options: [.mappedIfSafe]) }
            catch { throw AuthenticAcceptanceError.sourceUnreadable }
            let digest = sha256Hex(bytes)
            guard let oracleRecord = recordsByDigest[digest] else {
                throw AuthenticAcceptanceError.oracleMismatch
            }

            let isLocked: Bool
            if url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
                guard let pdf = PDFDocument(data: bytes) else {
                    throw AuthenticAcceptanceError.sourceUnreadable
                }
                isLocked = pdf.isLocked
            } else {
                isLocked = false
            }

            let prepared: PreparedImport
            do { prepared = try await engine.prepareImport(from: url) }
            catch let error as AuthenticAcceptanceError { throw error }
            catch { throw AuthenticAcceptanceError.sourceUnreadable }
            defer { engine.cancelPreparedImport(prepared) }

            let format: SourceFormat
            if url.pathExtension.caseInsensitiveCompare("xlsx") == .orderedSame {
                format = .xlsx
            } else {
                guard let presentation = prepared.axisCreditCardPDFPresentation else {
                    throw AuthenticAcceptanceError.unexpectedCorpusShape
                }
                format = presentation == .appPDF ? .appPDF : .traditionalPDF
            }
            let cycle = try sourceCycle(
                prepared.financialDocument,
                format: format,
                oracleCycleForDiagnostics: oracleRecord.cycle
            )
            guard prepared.validation.passed else {
                throw AuthenticAcceptanceError.validationMismatch(
                    format: format.rawValue,
                    cycle: cycle,
                    issueKinds: prepared.validation.issues.map(\.message)
                )
            }
            try require(format == oracleRecord.format, error: .oracleMismatch)
            try require(cycle == oracleRecord.cycle, error: .oracleMismatch)
            try assertProduction(prepared.financialDocument, matches: oracleRecord)
            sources.append(PhysicalSource(
                url: url,
                document: prepared.financialDocument,
                format: format,
                isLocked: isLocked,
                cycle: cycle,
                rawDigest: digest,
                oracle: oracleRecord
            ))
        }

        try require(Set(sources.map(\.rawDigest)) == Set(recordDigests), error: .oracleMismatch)
        try assertPhysicalCorpus(sources)
        guard await challengeProbe.count() == 0 else {
            throw AuthenticAcceptanceError.unexpectedPasswordChallenge
        }

        var byCycle = [String: [SourceFormat: PhysicalSource]]()
        for source in sources {
            try require(byCycle[source.cycle]?[source.format] == nil, error: .unexpectedCorpusShape)
            byCycle[source.cycle, default: [:]][source.format] = source
        }
        let corpus = LogicalCorpus(
            oracle: oracle,
            inMemoryOracleDigest: sourceOracleProjectionDigest(oracle),
            sources: sources,
            byCycle: byCycle
        )
        try assertCompleteSourceTruth(corpus)
        return corpus
    }

    private static func validateOracleContract(_ oracle: SourceOracle) throws {
        try require(oracle.schema == "ledgerforge.axis.source-oracle.v5", error: .oracleMismatch)
        try require(
            oracle.authority == "authentic-originals-independent-in-memory-projection",
            error: .oracleMismatch
        )
        try require(oracle.sourceInventorySHA256 == "db2414293ca3cb04a661f56638bde6e592ab39d66468aa18534b8ff8d383f92e", error: .oracleMismatch)
        try require(oracle.corpus.carrierCount == 32, error: .oracleMismatch)
        try require(oracle.corpus.logicalStatementCount == 18, error: .oracleMismatch)
        try require(
            oracle.corpus.transactionRowCount == expectedCanonicalTransactionCount,
            error: .oracleMismatch
        )
        try require(oracle.corpus.cycles == expectedCycles, error: .oracleMismatch)
        for format in SourceFormat.allCases {
            try require(
                oracle.corpus.formatCounts[format.rawValue] == expectedFormatCounts[format],
                error: .oracleMismatch
            )
        }
        try require(oracle.records.count == 32, error: .oracleMismatch)
        try require(
            oracle.records.allSatisfy { $0.rowCount == $0.rows.count },
            error: .oracleMismatch
        )
        try require(
            oracle.records.filter { $0.format == .appPDF }.reduce(0) { $0 + $1.rowCount }
                == expectedCanonicalTransactionCount,
            error: .oracleMismatch
        )
        try require(
            oracle.records.flatMap(\.rows).compactMap(\.reference).count == 164,
            error: .oracleMismatch
        )
        try require(
            oracle.records.filter { $0.format == .appPDF }
                .flatMap(\.rows).compactMap(\.reference).count == 66,
            error: .oracleMismatch
        )
    }

    private static func assertProduction(
        _ document: FinancialDocument,
        matches oracle: OracleRecord
    ) throws {
        func requireRow(_ condition: Bool, row: Int, field: String) throws {
            #expect(condition, "authentic source projection invariant")
            guard condition else {
                throw AuthenticAcceptanceError.sourceProjectionMismatch(
                    format: oracle.format.rawValue,
                    cycle: oracle.cycle,
                    row: row,
                    field: field
                )
            }
        }
        try requireRow(
            document.transactions.count == oracle.rowCount,
            row: 0,
            field: "row-count"
        )
        let evidence = try #require(document.cardStatementEvidence)
        try assertControls(
            controls(
                period: evidence.declaredStatementPeriod,
                month: evidence.selectedStatementMonth,
                summary: evidence.summaryComponents
            ),
            matches: oracle
        )
        let expectedProfileID = oracle.format.parserProfileID
        var normalizedDocumentID: String?
        var sourceOrdinals = Set<Int>()
        for (offset, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let (transaction, row) = pair
            let rowNumber = offset + 1
            guard let date = transaction.statementDate,
                  let effect = transaction.cardLiabilityEffect,
                  let provenance = transaction.sourceProvenance.only else {
                throw AuthenticAcceptanceError.sourceProjectionMismatch(
                    format: oracle.format.rawValue,
                    cycle: oracle.cycle,
                    row: rowNumber,
                    field: "required-semantics"
                )
            }
            let money = try transaction.money.canonicalDecimalString()
            let magnitude = money.hasPrefix("-") ? String(money.dropFirst()) : money
            try requireRow(date.canonical == row.date, row: rowNumber, field: "date")
            try requireRow(effect.rawValue == row.effect, row: rowNumber, field: "effect")
            try requireRow(transaction.money.currency.code == "INR", row: rowNumber, field: "currency")
            try requireRow(magnitude == row.amount, row: rowNumber, field: "amount")
            try requireRow(transaction.reference == row.reference, row: rowNumber, field: "reference")
            try requireRow(sourceNarrationGlyphs(transaction.description) == sourceNarrationGlyphs(row.narration),
                           row: rowNumber, field: "complete-narration")
            let annotation = try #require(evidence.transactionAnnotations.only {
                $0.parserTransactionID == transaction.id
            })
            let original = annotation.originalMerchantMoney
            let signedOriginal = try original?.canonicalDecimalString()
            let expectedOriginal = row.originalMerchantMoney.map {
                row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                    ? "-" + $0.amount : $0.amount
            }
            try requireRow(original?.currency.code == row.originalMerchantMoney?.currency,
                           row: rowNumber, field: "original-merchant-currency")
            try requireRow(signedOriginal == expectedOriginal,
                           row: rowNumber, field: "original-merchant-money")
            try requireRow(provenance.parserProfileID == expectedProfileID,
                           row: rowNumber, field: "profile-id")
            try requireRow(
                provenance.parserProfileVersion == oracle.format.parserProfileVersion,
                row: rowNumber,
                field: "profile-version"
            )
            try requireRow(provenance.sourceOrdinal > 0, row: rowNumber, field: "source-ordinal")
            try requireRow(sourceOrdinals.insert(provenance.sourceOrdinal).inserted,
                           row: rowNumber, field: "source-ordinal-unique")
            if let normalizedDocumentID {
                try requireRow(
                    provenance.normalizedDocumentID == normalizedDocumentID,
                    row: rowNumber,
                    field: "normalized-document-id"
                )
            } else {
                normalizedDocumentID = provenance.normalizedDocumentID
            }
            let expectedReferenceDigest = row.reference.map { sha256Hex(Data($0.utf8)) }
            try requireRow(
                provenance.structuredReferenceDigest == expectedReferenceDigest,
                row: rowNumber,
                field: "reference-digest"
            )
            let descriptionReferences = AxisCreditCardPDFNormalizer.sourceReferences(
                in: transaction.description
            )
            try requireRow(
                descriptionReferences == row.reference.map { [$0] } ?? [],
                row: rowNumber,
                field: "narration-reference"
            )
        }
    }

    private static func assertPhysicalCorpus(_ sources: [PhysicalSource]) throws {
        try require(sources.count == 32, error: .unexpectedCorpusShape)
        try require(Set(sources.map(\.rawDigest)).count == 32, error: .unexpectedCorpusShape)
        for format in SourceFormat.allCases {
            try require(
                sources.filter { $0.format == format }.count == expectedFormatCounts[format],
                error: .unexpectedCorpusShape
            )
        }
        try require(
            sources.filter { $0.format != .xlsx }.allSatisfy(\.isLocked),
            error: .unexpectedCorpusShape
        )
        try require(
            sources.filter { $0.format == .xlsx }.allSatisfy { !$0.isLocked },
            error: .unexpectedCorpusShape
        )
    }

    private static func assertCompleteSourceTruth(_ corpus: LogicalCorpus) throws {
        try validateOracleContract(corpus.oracle)
        try assertPhysicalCorpus(corpus.sources)
        try require(Set(corpus.byCycle.keys) == Set(expectedCycles), error: .unexpectedCorpusShape)

        for cycle in expectedCycles {
            guard let representations = corpus.byCycle[cycle],
                  let app = representations[.appPDF],
                  let expectedCount = expectedMonthlyCounts[cycle] else {
                throw AuthenticAcceptanceError.unexpectedCorpusShape
            }
            let expectedFormats: Set<SourceFormat> = cycle.hasPrefix("2025-")
                ? [.appPDF]
                : Set(SourceFormat.allCases)
            try require(Set(representations.keys) == expectedFormats, error: .unexpectedCorpusShape)
            try require(app.document.transactions.count == expectedCount,
                        error: .financialOutputMismatch)
            try require(
                app.document.cardStatementEvidence?.selectedStatementMonth?.canonical == cycle,
                error: .financialOutputMismatch
            )

            guard cycle.hasPrefix("2026-") else { continue }
            guard let xlsx = representations[.xlsx],
                  let traditional = representations[.traditionalPDF] else {
                throw AuthenticAcceptanceError.unexpectedCorpusShape
            }
            let appKeys = try financialKeys(app.document.transactions)
            let xlsxKeys = try financialKeys(xlsx.document.transactions)
            let traditionalKeys = try financialKeys(traditional.document.transactions)
            try require(appKeys == xlsxKeys, error: .financialOutputMismatch)
            try require(multiset(appKeys) == multiset(traditionalKeys),
                        error: .financialOutputMismatch)
            try require(
                normalizedDescriptions(app.document.transactions)
                    == normalizedDescriptions(xlsx.document.transactions),
                error: .financialOutputMismatch
            )
            try require(
                xlsx.document.cardStatementEvidence?.selectedStatementMonth?.canonical == cycle,
                error: .financialOutputMismatch
            )
            try require(
                try sourceCycle(traditional.document, format: .traditionalPDF) == cycle,
                error: .financialOutputMismatch
            )
        }

        try require(
            corpus.sources.filter { $0.format == .appPDF }
                .reduce(0) { $0 + $1.document.transactions.count }
                == expectedCanonicalTransactionCount,
            error: .financialOutputMismatch
        )
        for format in [SourceFormat.xlsx, .traditionalPDF] {
            try require(
                corpus.sources.filter { $0.format == format }
                    .reduce(0) { $0 + $1.document.transactions.count } == 796,
                error: .financialOutputMismatch
            )
        }
    }

    /// The frozen oracle retains all printed controls. Statement Generation
    /// Date is source provenance, not a substitute for a financial statement
    /// day/period in the accepted Axis domain; do not invent that mapping.
    private static func assertControls(
        _ actual: [String: String], matches oracle: OracleRecord
    ) throws {
        let knownKeys: Set<String> = [
            "selected_statement_month", "statement_period_start",
            "statement_period_end", "opening_balance", "total_payment_due",
            "payment_due_date", "statement_generation_date"
        ]
        try require(Set(oracle.controls.keys).isSubset(of: knownKeys), error: .oracleMismatch)
        let expected = oracle.controls.filter { $0.key != "statement_generation_date" }
        #expect(actual == expected, "Complete authentic Axis summary-control projection")
        guard actual == expected else {
            throw AuthenticAcceptanceError.sourceProjectionMismatch(
                format: oracle.format.rawValue, cycle: oracle.cycle,
                row: 0, field: "summary-controls"
            )
        }
    }

    private static func controls(
        period: DeclaredStatementPeriod?,
        month: SelectedStatementMonth?,
        summary: [CardStatementSummaryComponent]
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        result["statement_period_start"] = period?.start.canonical
        result["statement_period_end"] = period?.end.canonical
        result["selected_statement_month"] = month?.canonical
        for (code, key) in [
            ("previous_balance", "opening_balance"),
            ("axis_total_payment_due", "total_payment_due")
        ] {
            if let money = summary.first(where: { $0.persistenceCode == code })?.money {
                try require(money.currency.code == "INR", error: .financialOutputMismatch)
                result[key] = try money.canonicalDecimalString()
            }
        }
        result["payment_due_date"] = summary.first { $0.persistenceCode == "due_date" }?.date?.canonical
        return result
    }

    private static func orderedSources(
        _ corpus: LogicalCorpus,
        formatPriority: [SourceFormat]
    ) -> [PhysicalSource] {
        orderedSources(
            corpus,
            cycles: expectedCycles,
            formatPriority: formatPriority
        )
    }

    private static func orderedSources<S: Sequence>(
        _ corpus: LogicalCorpus,
        cycles: S,
        formatPriority: [SourceFormat]
    ) -> [PhysicalSource] where S.Element == String {
        cycles.flatMap { cycle in
            formatPriority.compactMap { corpus.byCycle[cycle]?[$0] }
        }
    }

    private static func runAuthenticCampaign(
        corpus: LogicalCorpus,
        orderedSources: [PhysicalSource],
        inMemory: Bool
    ) async throws {
        try require(orderedSources.count == 32, error: .campaignInvariant)
        try require(Set(orderedSources.map(\.rawDigest)).count == 32, error: .campaignInvariant)
        let workspaceID = "axis-authentic-\(UUID().uuidString)"
        let runtime = try await makeRuntime(workspaceID: workspaceID, inMemory: inMemory)
        defer { runtime.cleanup() }

        var accountID: String?
        var seenCycles = Set<String>()
        var insertedTransactionCount = 0
        for source in orderedSources {
            let prepared = try await runtime.engine.prepareImport(from: source.url)
            try require(prepared.validation.passed, error: .campaignInvariant)
            try assertProduction(prepared.financialDocument, matches: source.oracle)

            let isSupporting = seenCycles.contains(source.cycle)
            let choice: ImportAccountChoice = accountID.map {
                .useExistingAccount(accountId: $0)
            } ?? .createNewAccount(displayName: "Imported review account")
            let result = await runtime.engine.commitPreparedImport(
                prepared,
                accountChoice: choice
            )
            let expectedDelta = isSupporting ? 0 : source.oracle.rowCount
            try require(result.succeeded, error: .campaignInvariant)
            try require(result.isEquivalentSupportingSource == isSupporting,
                        error: .campaignInvariant)
            try require(result.transactionCount == expectedDelta, error: .campaignInvariant)
            try require(result.hydrationOutcome == .committedAndHydrated,
                        error: .campaignInvariant)
            guard let persistedAccountID = result.accountId else {
                throw AuthenticAcceptanceError.campaignInvariant
            }
            if let accountID {
                try require(persistedAccountID == accountID, error: .campaignInvariant)
            } else {
                accountID = persistedAccountID
            }
            if seenCycles.insert(source.cycle).inserted {
                insertedTransactionCount += source.oracle.rowCount
            }
            try require(
                try runtime.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count
                    == insertedTransactionCount,
                error: .campaignInvariant
            )
        }
        try require(seenCycles == Set(expectedCycles), error: .campaignInvariant)
        try require(insertedTransactionCount == expectedCanonicalTransactionCount,
                    error: .campaignInvariant)

        let canonicalTransactions = try runtime.provider.transactionRepo.trustedTransactions(
            workspaceId: workspaceID
        )
        let canonicalIDs = Set(canonicalTransactions.map(\.id))
        let finalOwnership = transactionOwnership(canonicalTransactions)
        try verify(
            runtime.provider,
            workspaceID: workspaceID,
            canonicalIDs: canonicalIDs,
            expectedOwnership: finalOwnership,
            corpus: corpus
        )

        // Every accepted carrier is prepared and confirmed again through the
        // ordinary engine. Exact-byte replay must reject without accepted
        // financial residue or identity drift.
        for source in orderedSources {
            let replay = try await runtime.engine.prepareImport(from: source.url)
            try require(replay.advisoryPreviousImport != nil, error: .campaignInvariant)
            let result = await runtime.engine.commitPreparedImport(replay, accountChoice: nil)
            try require(!result.persisted, error: .campaignInvariant)
            try require(result.previousImport != nil, error: .campaignInvariant)
            try require(
                result.recoveryRoute == .reviewRequired(.exactStatementDuplicate),
                error: .campaignInvariant
            )
        }
        try verify(
            runtime.provider,
            workspaceID: workspaceID,
            canonicalIDs: canonicalIDs,
            expectedOwnership: finalOwnership,
            corpus: corpus
        )
        guard await runtime.challengeProbe.count() == 0 else {
            throw AuthenticAcceptanceError.unexpectedPasswordChallenge
        }

        if let sqlite = runtime.sqlite, let databaseURL = runtime.databaseURL {
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: databaseURL.path)
            let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            try verify(
                reopenedProvider,
                workspaceID: workspaceID,
                canonicalIDs: canonicalIDs,
                expectedOwnership: finalOwnership,
                corpus: corpus
            )
            reopened.database.close()
        }
    }

    private static func makeRuntime(
        workspaceID: String,
        inMemory: Bool
    ) async throws -> PrivateRuntime {
        let provider: DatabaseProvider
        let sqlite: SQLiteRepositoryProvider?
        let databaseURL: URL?
        let folder: URL?
        if inMemory {
            provider = DatabaseProvider(inMemory: true)
            sqlite = nil
            databaseURL = nil
            folder = nil
        } else {
            let createdFolder = FileManager.default.temporaryDirectory.appendingPathComponent(
                "LedgerForge-AxisAuthentic-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: createdFolder, withIntermediateDirectories: true)
            let createdDatabaseURL = createdFolder.appendingPathComponent("authentic.sqlite")
            let opened = try SQLiteRepositoryProvider(path: createdDatabaseURL.path)
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
            sqlite = opened
            databaseURL = createdDatabaseURL
            folder = createdFolder
        }

        let challengeProbe = ChallengeInvocationProbe()
        let passwordProvider = try await makePasswordProvider(challengeProbe: challengeProbe)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Axis authentic acceptance"
            )
        )
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            salaryStore: SalaryStore(),
            fundingPlanStore: FundingPlanStore(),
            importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: passwordProvider
            ),
            importPersistenceCoordinator: coordinator,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: { _ = try hydrator.stageHydration() },
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(
                stateProvider: { nil }
            )
        )
        return PrivateRuntime(
            provider: provider,
            engine: engine,
            challengeProbe: challengeProbe,
            sqlite: sqlite,
            databaseURL: databaseURL,
            cleanup: {
                sqlite?.database.close()
                if let folder { try? FileManager.default.removeItem(at: folder) }
            }
        )
    }

    private static func verify(
        _ provider: DatabaseProvider,
        workspaceID: String,
        canonicalIDs: Set<String>,
        expectedOwnership: [String],
        corpus: LogicalCorpus
    ) throws {
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        try require(transactions.count == expectedCanonicalTransactionCount,
                    error: .campaignInvariant)
        try require(Set(transactions.map(\.id)) == canonicalIDs, error: .campaignInvariant)
        try require(transactionOwnership(transactions) == expectedOwnership,
                    error: .campaignInvariant)
        try require(transactions.allSatisfy { $0.rawRows.count == 1 }, error: .campaignInvariant)
        try require(transactions.compactMap(\.reference).count == 66, error: .campaignInvariant)
        try require(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1,
                    error: .campaignInvariant)

        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        try require(card.instruments.isEmpty, error: .campaignInvariant)
        try require(card.sections.isEmpty, error: .campaignInvariant)
        try require(card.sectionObservations.isEmpty, error: .campaignInvariant)
        try require(card.statements.count == 32, error: .campaignInvariant)
        try require(card.transactionEvidence.count == expectedCanonicalTransactionCount,
                    error: .campaignInvariant)
        try require(Set(card.transactionEvidence.map(\.transactionId)) == canonicalIDs,
                    error: .campaignInvariant)
        try require(card.semanticProjections.count == 32, error: .campaignInvariant)
        try require(card.semanticGroups.count == 18, error: .campaignInvariant)
        try require(card.semanticMembers.count == 32, error: .campaignInvariant)
        try require(card.semanticMembers.filter { $0.role == .supporting }.count == 14,
                    error: .campaignInvariant)
        try require(card.semanticProjections.reduce(0) { $0 + $1.eventCount } == 2_969,
                    error: .campaignInvariant)
        try require(
            card.semanticProjections.flatMap(\.events).compactMap(\.sourceReference).count == 164,
            error: .campaignInvariant
        )

        let transactionsByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        let projectionsByID = Dictionary(uniqueKeysWithValues: card.semanticProjections.map { ($0.id, $0) })
        let membersByGroup = Dictionary(grouping: card.semanticMembers, by: \.groupId)
        var authoritativeCanonicalIDs = Set<String>()
        var authoritativeReferenceCount = 0
        for group in card.semanticGroups {
            guard let members = membersByGroup[group.id],
                  let authoritativeMember = members.only(where: { $0.role == .authoritative }),
                  authoritativeMember.projectionId == group.authoritativeProjectionId,
                  let projection = projectionsByID[authoritativeMember.projectionId] else {
                throw AuthenticAcceptanceError.campaignInvariant
            }
            try require(projection.parserProfileVersion == "1", error: .campaignInvariant)
            try require(
                [AxisCreditCardPDFParser.profileID, AxisCreditCardXLSXParser.profileID]
                    .contains(projection.parserProfileId),
                error: .campaignInvariant
            )
            try require(projection.events.count == projection.eventCount,
                        error: .campaignInvariant)
            for event in projection.events {
                guard let canonicalID = event.canonicalTransactionId,
                      let transaction = transactionsByID[canonicalID],
                      let raw = transaction.rawRows.only else {
                    throw AuthenticAcceptanceError.campaignInvariant
                }
                try require(authoritativeCanonicalIDs.insert(canonicalID).inserted,
                            error: .campaignInvariant)
                try require(transaction.reference == event.sourceReference,
                            error: .campaignInvariant)
                try require(raw.normalizedRowId == event.normalizedRowId,
                            error: .campaignInvariant)
                try require(raw.sourceOrdinal == event.sourceOrdinal, error: .campaignInvariant)
                try require(raw.parserProfileId == projection.parserProfileId,
                            error: .campaignInvariant)
                try require(raw.parserProfileVersion == projection.parserProfileVersion,
                            error: .campaignInvariant)
                if event.sourceReference != nil { authoritativeReferenceCount += 1 }
            }
        }
        try require(authoritativeCanonicalIDs == canonicalIDs, error: .campaignInvariant)
        try require(authoritativeReferenceCount == 66, error: .campaignInvariant)

        let hydrated = try RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            salaryStore: SalaryStore(),
            fundingPlanStore: FundingPlanStore(),
            importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        ).stageHydration()
        try require(hydrated.transactions.count == expectedCanonicalTransactionCount,
                    error: .campaignInvariant)
        try require(hydrated.cardSnapshot.statements.count == 32, error: .campaignInvariant)
        try require(hydrated.cardSnapshot.transactionEvidence.count == expectedCanonicalTransactionCount,
                    error: .campaignInvariant)
        let hydratedByID = Dictionary(uniqueKeysWithValues: hydrated.transactions.compactMap { transaction in
            transaction.repositoryTransactionId.map { ($0, transaction) }
        })
        for source in corpus.sources {
            let priorResult = try provider.importSessionRepo.priorImportedStatement(
                algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                fingerprint: source.oracle.sourceSHA256
            )
            let prior = try #require(priorResult)
            let persisted = try #require(card.statements.only {
                $0.importSessionId == prior.importSessionId
            })
            let projection = try #require(card.semanticProjections.only {
                $0.cardStatementId == persisted.id
            })
            let sourceMember = try #require(card.semanticMembers.only {
                $0.projectionId == projection.id
            })
            let events = projection.events.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            try require(events.count == source.oracle.rows.count, error: .campaignInvariant)
            for (event, row) in zip(events, source.oracle.rows) {
                let expectedOriginal = row.originalMerchantMoney.map {
                    row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                        ? "-" + $0.amount : $0.amount
                }
                try require(event.originalCurrency == row.originalMerchantMoney?.currency,
                            error: .campaignInvariant)
                try require(event.originalAmountDecimal == expectedOriginal,
                            error: .campaignInvariant)
                try require(event.financialDateISO == row.date && event.sourceReference == row.reference,
                            error: .campaignInvariant)
                let signedPosted = row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                    ? "-" + row.amount : row.amount
                try require(event.postedCurrency == "INR" && event.postedAmountDecimal == signedPosted
                            && event.liabilityEffectCode == row.effect, error: .campaignInvariant)
                // Supporting carriers retain their own source projection, but
                // do not replace the authoritative carrier's narration or FX.
                if sourceMember.role == .authoritative,
                   let canonicalID = event.canonicalTransactionId {
                    let transaction = try #require(transactionsByID[canonicalID])
                    let visibleTransaction = try #require(hydratedByID[canonicalID])
                    try require(sourceNarrationGlyphs(transaction.description ?? "") == sourceNarrationGlyphs(row.narration),
                                error: .campaignInvariant)
                    try require(sourceNarrationGlyphs(visibleTransaction.description) == sourceNarrationGlyphs(row.narration),
                                error: .campaignInvariant)
                    let durableEvidence = try #require(card.transactionEvidence.only {
                        $0.transactionId == canonicalID
                    })
                    let visibleEvidence = try #require(hydrated.cardSnapshot.transactionEvidence.only {
                        $0.transactionID == canonicalID
                    })
                    try require(durableEvidence.originalCurrency == row.originalMerchantMoney?.currency
                                && durableEvidence.originalAmountDecimal == expectedOriginal,
                                error: .campaignInvariant)
                    let visibleOriginal = try visibleEvidence.originalMerchantMoney?.canonicalDecimalString()
                    try require(visibleEvidence.originalMerchantMoney?.currency.code == row.originalMerchantMoney?.currency
                                && visibleOriginal == expectedOriginal, error: .campaignInvariant)
                }
            }
            let summary = card.summaryComponents.filter { $0.cardStatementId == persisted.id }
            var persistedControls: [String: String] = [:]
            persistedControls["statement_period_start"] = persisted.statementStartDateISO
            persistedControls["statement_period_end"] = persisted.statementEndDateISO
            persistedControls["selected_statement_month"] = persisted.selectedStatementMonthISO
            for (code, key) in [
                ("previous_balance", "opening_balance"),
                ("axis_total_payment_due", "total_payment_due")
            ] {
                if let component = summary.first(where: { $0.componentCode == code }) {
                    try require(component.moneyCurrency == "INR", error: .campaignInvariant)
                    persistedControls[key] = component.moneyDecimal
                }
            }
            persistedControls["payment_due_date"] = summary.first { $0.componentCode == "due_date" }?.dateISO
            try assertControls(persistedControls, matches: source.oracle)
            let visible = try #require(hydrated.cardSnapshot.statements.only {
                $0.importSessionID == prior.importSessionId
            })
            try assertControls(
                controls(period: visible.period, month: visible.selectedStatementMonth,
                         summary: visible.summaryComponents),
                matches: source.oracle
            )
        }
        for transaction in hydrated.transactions {
            guard let repositoryID = transaction.repositoryTransactionId,
                  let persisted = transactionsByID[repositoryID],
                  let persistedRaw = persisted.rawRows.only,
                  let provenance = transaction.sourceProvenance.only else {
                throw AuthenticAcceptanceError.campaignInvariant
            }
            try require(transaction.reference == persisted.reference, error: .campaignInvariant)
            try require(transaction.repositoryPreferredStructuredReferenceDigest == nil,
                        error: .campaignInvariant)
            try require(provenance.normalizedRowID == persistedRaw.normalizedRowId,
                        error: .campaignInvariant)
            try require(provenance.sourceOrdinal == persistedRaw.sourceOrdinal,
                        error: .campaignInvariant)
            try require(provenance.parserProfileID == persistedRaw.parserProfileId,
                        error: .campaignInvariant)
            try require(provenance.parserProfileVersion == persistedRaw.parserProfileVersion,
                        error: .campaignInvariant)
        }

        // Bind the durable aggregate counts back to the independent corpus
        // authority without treating repository output as its own oracle.
        try require(
            corpus.oracle.records.reduce(0) { $0 + $1.rowCount } == 2_969,
            error: .campaignInvariant
        )
    }

    private static func makePasswordProvider(
        challengeProbe: ChallengeInvocationProbe
    ) async throws -> DefaultPasswordProvider {
        let appPassword = try await sourceOraclePassword("axis-bank.credit-card.app-pdf")
        let traditionalPassword = try await sourceOraclePassword("axis-bank.credit-card.traditional-pdf")
        let store = InMemoryStatementPasswordCredentialStore(passwords: [
            KeychainStatementPasswordCredentialStore.axisAppPDFScope: appPassword,
            KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope: traditionalPassword
        ])
        return DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [Institution.axis.statementPasswordCredentialScope],
            challenge: { _ in
                await challengeProbe.recordInvocation()
                throw AuthenticAcceptanceError.unexpectedPasswordChallenge
            }
        )
    }

    private static func sourceCycle(
        _ document: FinancialDocument,
        format: SourceFormat,
        oracleCycleForDiagnostics: String = "unavailable"
    ) throws -> String {
        if let month = document.cardStatementEvidence?.selectedStatementMonth {
            return month.canonical
        }
        if format == .traditionalPDF,
           let end = document.cardStatementEvidence?.declaredStatementPeriod?.end
            ?? document.declaredStatementPeriod?.end {
            return String(format: "%04d-%02d", end.year, end.month)
        }
        throw AuthenticAcceptanceError.missingProductionCycle(
            format: format.rawValue,
            oracleCycle: oracleCycleForDiagnostics
        )
    }

    private static func financialKeys(_ transactions: [Transaction]) throws -> [FinancialKey] {
        try transactions.map { transaction in
            guard let date = transaction.statementDate,
                  let effect = transaction.cardLiabilityEffect else {
                throw AuthenticAcceptanceError.financialOutputMismatch
            }
            let money = try transaction.money.canonicalDecimalString()
            return FinancialKey(
                date: date.canonical,
                effect: effect.rawValue,
                currency: transaction.money.currency.code,
                amountMagnitude: money.hasPrefix("-") ? String(money.dropFirst()) : money
            )
        }
    }

    private static func multiset(_ keys: [FinancialKey]) -> [FinancialKey: Int] {
        keys.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    private static func normalizedDescriptions(_ transactions: [Transaction]) -> [String] {
        transactions.map {
            $0.description.precomposedStringWithCanonicalMapping
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// PDF extractors introduce spaces within words and around punctuation.
    /// Compare every visible narration glyph, in order; never accept a prefix
    /// or a narration derived from the production parser as its own oracle.
    private static func sourceNarrationGlyphs(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .filter { !$0.isWhitespace }
    }

    private static func regularFinancialFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { throw AuthenticAcceptanceError.sourceDirectoryUnreadable }
        var files = [URL]()
        for case let url as URL in enumerator {
            let values: URLResourceValues
            do { values = try url.resourceValues(forKeys: [.isRegularFileKey]) }
            catch { throw AuthenticAcceptanceError.sourceDirectoryUnreadable }
            guard values.isRegularFile == true else { continue }
            let ext = url.pathExtension.lowercased()
            guard ext == "pdf" || ext == "xlsx" else { continue }
            let directories = url.deletingLastPathComponent().pathComponents
            guard !directories.contains(where: isExcludedArchiveComponent) else { continue }
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func isExcludedArchiveComponent(_ component: String) -> Bool {
        let compact = component.precomposedStringWithCanonicalMapping.lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return compact.contains("archive") || compact.contains("ignore")
    }

    private static func transactionOwnership(_ transactions: [TransactionDTO]) -> [String] {
        transactions.map {
            [$0.id, $0.documentId ?? "", $0.importSessionId ?? ""].joined(separator: "|")
        }.sorted()
    }

    @MainActor
    private static func recordCompletedPhase(
        _ phase: String,
        corpus: LogicalCorpus
    ) throws {
        completedCorpus = corpus
        completedPhases.insert(phase)
        // Acceptance progress remains in memory; never emit a derived result file.
    }

    /// Builds expected truth only from original source bytes and generic readers.
    /// No Axis parser/normalizer or retained financial output participates.
    private static func loadInMemorySourceOracle(root: URL) async throws -> SourceOracle {
        try await constructSourceOracle(
            root: root,
            tagged: { url, bytes, password in
                let snapshot = SourceContentSnapshot(bytes: bytes)
                defer { snapshot.invalidate() }
                let raw = try await PDFDocumentReader().read(
                    request: ImportRequest(fileURL: url), snapshot: snapshot, password: password
                )
                return raw.pdfTaggedTables ?? []
            },
            workbook: { url, bytes in
                let snapshot = SourceContentSnapshot(bytes: bytes)
                defer { snapshot.invalidate() }
                let raw = try await OOXMLDocumentReader().read(
                    request: ImportRequest(fileURL: url), snapshot: snapshot, password: nil
                )
                guard case .tabular(let sheet) = raw.content else { throw AuthenticAcceptanceError.oracleMismatch }
                return sheet.rows.map { row in row.cells.map { $0.value.canonicalText } }
            }
        )
    }

    private static func sourceOraclePassword(_ scope: String) async throws -> String {
        guard let password = try await KeychainStatementPasswordCredentialStore().password(institutionCode: scope),
              !password.isEmpty else { throw AuthenticAcceptanceError.oracleUnavailable }
        return password
    }

    private static func constructSourceOracle(
        root: URL,
        tagged: (URL, Data, String) async throws -> [RawPDFTaggedTableEvidence],
        workbook: (URL, Data) async throws -> [[String]]
    ) async throws -> SourceOracle {
        let approved = URL(fileURLWithPath: "/Users/vyom/Documents/Ledger Forge/Originals/Axis/CreditCard")
        guard root.resolvingSymlinksInPath().standardizedFileURL == approved.resolvingSymlinksInPath().standardizedFileURL else {
            throw AuthenticAcceptanceError.sourceDirectoryUnreadable
        }
        let files = try regularFinancialFiles(under: root)
        guard files.count == 32 else { throw AuthenticAcceptanceError.unexpectedCorpusShape }
        let passwords = [try await sourceOraclePassword("axis-bank.credit-card.app-pdf"),
                         try await sourceOraclePassword("axis-bank.credit-card.traditional-pdf")]
        var records: [OracleRecord] = [], inventory: [String: String] = [:]
        for url in files {
            let bytes = try Data(contentsOf: url), digest = sha256Hex(bytes)
            let rows: [OracleRow], controls: [String: String], format: SourceFormat
            if url.pathExtension.lowercased() == "xlsx" {
                let grid = try await workbook(url, bytes)
                let result = try sourceWorkbook(grid)
                rows = result.rows; controls = result.controls; format = .xlsx
            } else {
                guard let document = PDFDocument(data: bytes), document.isLocked else { throw AuthenticAcceptanceError.sourceUnreadable }
                guard let password = passwords.first(where: { document.unlock(withPassword: $0) }) else {
                    throw AuthenticAcceptanceError.oracleUnavailable
                }
                let tables = try await tagged(url, bytes, password)
                let candidates = tables.filter { table in
                    guard let first = table.rows.first else { return false }
                    return first.cells.map(sourceTaggedCell) == ["Date", "Transaction Details", "Amount (INR)", "Debit/Credit"]
                }
                let pageLines = try (0..<document.pageCount).map { index -> [Int: [SourceGlyph]] in
                    guard let page = document.page(at: index) else { throw AuthenticAcceptanceError.sourceUnreadable }
                    return try sourceGlyphLines(page)
                }
                guard let top = pageLines.first else { throw AuthenticAcceptanceError.sourceUnreadable }
                if !candidates.isEmpty {
                    guard candidates.count == 1, let table = candidates.first,
                          table.rows.first!.cells.allSatisfy({ $0.role == .header }) else { throw AuthenticAcceptanceError.oracleMismatch }
                    rows = try table.rows.dropFirst().map { row in
                        guard row.cells.count == 4, row.cells.allSatisfy({ $0.role == .data }) else { throw AuthenticAcceptanceError.oracleMismatch }
                        let cells = row.cells.map(sourceTaggedCell)
                        return try sourceOracleRow(date: cells[0], narration: cells[1], amount: cells[2], direction: cells[3], retainsOriginalMoney: false)
                    }
                    controls = try sourceAppControls(top)
                    format = .appPDF
                } else {
                    var output: [OracleRow] = []
                    for lines in pageLines {
                        for y in lines.keys.sorted(by: >) {
                            let glyphs = lines[y]!, date = sourceColumn(glyphs, 0, 85)
                            if date.range(of: #"^\d{2}/\d{2}/\d{4}$"#, options: .regularExpression) == nil { continue }
                            let parts = try sourceCapture(#"^([0-9,.]+)\s*(Dr|Cr)$"#, sourceColumn(glyphs, 505, 650))
                            output.append(try sourceOracleRow(date: date, narration: sourceColumn(glyphs, 85, 505), amount: parts[0], direction: parts[1], retainsOriginalMoney: true))
                        }
                    }
                    rows = output
                    controls = try sourceTraditionalControls(top)
                    format = .traditionalPDF
                }
            }
            guard let cycle = controls["selected_statement_month"] ?? controls["statement_period_end"].map({ String($0.prefix(7)) }),
                  rows.count == expectedMonthlyCounts[cycle],
                  inventory.updateValue("\(bytes.count)|\(format.rawValue)", forKey: digest) == nil else {
                throw AuthenticAcceptanceError.oracleMismatch
            }
            records.append(OracleRecord(sourceSHA256: digest, format: format, cycle: cycle, rowCount: rows.count, rows: rows, controls: controls))
        }
        try sourceVerifyInventory(inventory)
        let grouped = Dictionary(grouping: records, by: \.cycle)
        guard grouped.count == 18 else { throw AuthenticAcceptanceError.oracleMismatch }
        for group in grouped.values {
            guard let app = group.first(where: { $0.format == .appPDF }), group.filter({ $0.format == .appPDF }).count == 1 else {
                throw AuthenticAcceptanceError.oracleMismatch
            }
            let expected = sourceFinancialMultiset(app.rows)
            for record in group {
                guard sourceFinancialMultiset(record.rows) == expected else { throw AuthenticAcceptanceError.oracleMismatch }
                if record.format == .xlsx {
                    guard record.controls == app.controls, record.rows.count == app.rows.count else { throw AuthenticAcceptanceError.oracleMismatch }
                    for (left, right) in zip(record.rows, app.rows) {
                        guard left.date == right.date, left.amount == right.amount, left.effect == right.effect,
                              left.reference == right.reference,
                              sourceNarrationGlyphs(left.narration) == sourceNarrationGlyphs(right.narration) else { throw AuthenticAcceptanceError.oracleMismatch }
                    }
                }
            }
        }
        let oracle = SourceOracle(
            schema: "ledgerforge.axis.source-oracle.v5",
            authority: "authentic-originals-independent-in-memory-projection",
            sourceInventorySHA256: sourceInventoryDigest(inventory),
            corpus: OracleCorpus(carrierCount: records.count, logicalStatementCount: grouped.count,
                transactionRowCount: records.filter { $0.format == .appPDF }.reduce(0) { $0 + $1.rows.count },
                formatCounts: Dictionary(grouping: records, by: { $0.format.rawValue }).mapValues(\.count), cycles: grouped.keys.sorted()),
            records: records.sorted { ($0.cycle, $0.format.rawValue, $0.sourceSHA256) < ($1.cycle, $1.format.rawValue, $1.sourceSHA256) }
        )
        guard oracle.records.reduce(0, { $0 + $1.rowCount }) == 2969,
              oracle.records.flatMap(\.rows).compactMap(\.reference).count == 164,
              oracle.records.filter({ $0.format == .appPDF }).flatMap(\.rows).compactMap(\.reference).count == 66 else { throw AuthenticAcceptanceError.oracleMismatch }
        return oracle
    }

    private struct SourceGlyph { let x: CGFloat; let text: String }
    private static func sourceGlyphLines(_ page: PDFPage) throws -> [Int: [SourceGlyph]] {
        guard let text = page.string else { throw AuthenticAcceptanceError.sourceUnreadable }
        let ns = text as NSString
        var lines: [Int: [SourceGlyph]] = [:]
        for i in 0..<ns.length {
            let character = ns.substring(with: NSRange(location: i, length: 1))
            if character == "\n" || character == "\r" { continue }
            guard let selection = page.selection(for: NSRange(location: i, length: 1)) else { throw AuthenticAcceptanceError.sourceUnreadable }
            let bounds = selection.bounds(for: page)
            lines[Int((bounds.minY * 10).rounded()), default: []].append(SourceGlyph(x: bounds.minX, text: character))
        }
        return lines.mapValues { $0.sorted { $0.x < $1.x } }
    }
    private static func sourceColumn(_ glyphs: [SourceGlyph], _ start: CGFloat, _ end: CGFloat) -> String {
        glyphs.filter { $0.x >= start && $0.x < end }.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func sourceTaggedCell(_ cell: RawPDFTaggedCellEvidence) -> String {
        cell.children.flatMap { child -> [String] in
            switch child {
            case .markedContent(let value): value.textBlocks
            case .structure(let value): value.markedContent.flatMap(\.textBlocks)
            }
        }.joined()
    }
    private static func sourceCapture(_ pattern: String, _ text: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard matches.count == 1, let match = matches.first else { throw AuthenticAcceptanceError.oracleMismatch }
        return try (1..<match.numberOfRanges).map { i in
            guard let range = Range(match.range(at: i), in: text) else { throw AuthenticAcceptanceError.oracleMismatch }
            return String(text[range])
        }
    }
    private static func sourceClean(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    private static func sourceDate(_ text: String) throws -> String {
        let source = sourceClean(text)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        for format in ["dd MMM ''yy", "dd/MM/yyyy", "dd-MM-yyyy", "dd MMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: source) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }
        throw AuthenticAcceptanceError.oracleMismatch
    }
    private static func sourceMonth(_ text: String) throws -> String {
        let parts = try sourceCapture(#"^([A-Za-z]{3}) ([0-9]{4})$"#, sourceClean(text))
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard let month = months.firstIndex(of: parts[0]) else { throw AuthenticAcceptanceError.oracleMismatch }
        return String(format: "%@-%02d", parts[1], month + 1)
    }
    private static func sourceMoney(_ text: String) throws -> String {
        let source = sourceClean(text).replacingOccurrences(of: "₹", with: "").trimmingCharacters(in: .whitespaces)
        let regex = try NSRegularExpression(pattern: #"^([0-9][0-9,]*\.[0-9]{1,2})\s*(Dr|Cr)?$"#)
        guard let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let r = Range(match.range(at: 1), in: source) else { throw AuthenticAcceptanceError.oracleMismatch }
        let digits = source[r].replacingOccurrences(of: ",", with: "")
        guard let amount = Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX")), amount >= 0 else { throw AuthenticAcceptanceError.oracleMismatch }
        let canonical = NSDecimalNumber(decimal: amount).stringValue.split(separator: ".", omittingEmptySubsequences: false)
        let fraction = canonical.count == 2 ? String(canonical[1]) : ""
        guard fraction.count <= 2 else { throw AuthenticAcceptanceError.oracleMismatch }
        let credit = Range(match.range(at: 2), in: source).map { source[$0] == "Cr" } ?? false
        return (credit && amount != 0 ? "-" : "") + canonical[0] + "." + fraction + String(repeating: "0", count: 2 - fraction.count)
    }
    private static func sourceOracleRow(date: String, narration: String, amount: String, direction: String, retainsOriginalMoney: Bool) throws -> OracleRow {
        let details = sourceClean(narration), normalizedDirection = sourceClean(direction).lowercased()
        guard !details.isEmpty, ["debit", "credit", "dr", "cr"].contains(normalizedDirection) else { throw AuthenticAcceptanceError.oracleMismatch }
        var references: [String] = []
        for (pattern, prefix) in [(#"(?i)\bPAYMENT\s*#\s*([A-Z0-9]{14})\b"#, "PAYMENT #"), (#"(?i)\bRef\s*#\s*([0-9]{8})\b"#, "Ref# ")] {
            let regex = try NSRegularExpression(pattern: pattern)
            for m in regex.matches(in: details, range: NSRange(details.startIndex..., in: details)) {
                guard let r = Range(m.range(at: 1), in: details) else { throw AuthenticAcceptanceError.oracleMismatch }
                references.append(prefix + details[r])
            }
        }
        guard references.count <= 1 else { throw AuthenticAcceptanceError.oracleMismatch }
        var original: OracleMoney?
        let pattern = try NSRegularExpression(pattern: #"\(\s*([A-Z]{3})\s+([0-9][0-9,]*\.[0-9]{1,2})\s*\)"#)
        let matches = pattern.matches(in: details, range: NSRange(details.startIndex..., in: details))
        guard matches.count <= 1, retainsOriginalMoney || matches.isEmpty else { throw AuthenticAcceptanceError.oracleMismatch }
        if retainsOriginalMoney, let m = matches.first,
           let currency = Range(m.range(at: 1), in: details), let value = Range(m.range(at: 2), in: details) {
            original = OracleMoney(currency: String(details[currency]), amount: try sourceMoney(String(details[value])))
        }
        return OracleRow(date: try sourceDate(date), amount: try sourceMoney(amount),
            effect: ["credit", "cr"].contains(normalizedDirection) ? "card_decrease_owed" : "card_increase_owed",
            reference: references.first, narration: details, originalMerchantMoney: original)
    }
    private static func sourceAppControls(_ lines: [Int: [SourceGlyph]]) throws -> [String: String] {
        guard let paymentHeader = lines[6570], let accountHeader = lines[6105], let payment = lines[6405], let account = lines[5940],
              sourceColumn(paymentHeader, 0, 210) == "Total Payment Due",
              sourceColumn(paymentHeader, 210, 380) == "Minimum Payment Due",
              sourceColumn(paymentHeader, 380, 600) == "Payment Due Date",
              sourceColumn(accountHeader, 0, 210) == "Selected Statement Month",
              sourceColumn(accountHeader, 210, 380) == "Credit Limit",
              sourceColumn(accountHeader, 380, 600) == "Opening Balance" else { throw AuthenticAcceptanceError.oracleMismatch }
        _ = try sourceMoney(sourceColumn(payment, 210, 380))
        _ = try sourceMoney(sourceColumn(account, 210, 380))
        return try ["selected_statement_month": sourceMonth(sourceColumn(account, 0, 210)),
            "opening_balance": sourceMoney(sourceColumn(account, 380, 600)),
            "total_payment_due": sourceMoney(sourceColumn(payment, 0, 210)),
            "payment_due_date": sourceDate(sourceColumn(payment, 380, 600))]
    }
    private static func sourceTraditionalControls(_ lines: [Int: [SourceGlyph]]) throws -> [String: String] {
        guard let header = lines[8540], let balanceHeader = lines[7960], let dates = lines[8415], let payment = lines[8405], let balances = lines[7830],
              sourceColumn(header, 0, 140) == "Total Payment Due",
              sourceColumn(header, 255, 375) == "Statement Period",
              sourceColumn(balanceHeader, 60, 130).contains("Previous Balance") else { throw AuthenticAcceptanceError.oracleMismatch }
        let period = try sourceCapture(#"^(\d{2}/\d{2}/\d{4})\s*-\s*(\d{2}/\d{2}/\d{4})$"#, sourceColumn(dates, 255, 375))
        return try ["statement_period_start": sourceDate(period[0]), "statement_period_end": sourceDate(period[1]),
            "opening_balance": sourceMoney(sourceColumn(balances, 0, 110)),
            "total_payment_due": sourceMoney(sourceColumn(payment, 0, 140)),
            "payment_due_date": sourceDate(sourceColumn(dates, 375, 465)),
            "statement_generation_date": sourceDate(sourceColumn(dates, 465, 600))]
    }
    private static func sourceWorkbook(_ grid: [[String]]) throws -> (rows: [OracleRow], controls: [String: String]) {
        guard grid.count > 8, grid.allSatisfy({ $0.count >= 5 }),
              grid[6][0] == "Date", grid[6][1] == "Transaction Details", grid[6][3] == "Amount (INR)", grid[6][4] == "Debit/Credit" else { throw AuthenticAcceptanceError.oracleMismatch }
        var controls: [String: String] = [:]
        for row in grid.prefix(7) {
            for cell in row {
                let pieces = cell.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                guard pieces.count == 2 else { continue }
                let label = String(pieces[0]).trimmingCharacters(in: .whitespaces), value = String(pieces[1])
                let key: String, result: String
                switch label {
                case "Selected Statement Month": key = "selected_statement_month"; result = try sourceMonth(value)
                case "Opening Balance": key = "opening_balance"; result = try sourceMoney(value)
                case "Total Payment Due": key = "total_payment_due"; result = try sourceMoney(value)
                case "Payment Due Date": key = "payment_due_date"; result = try sourceDate(value)
                default: continue
                }
                guard controls.updateValue(result, forKey: key) == nil else { throw AuthenticAcceptanceError.oracleMismatch }
            }
        }
        guard controls.count == 4 else { throw AuthenticAcceptanceError.oracleMismatch }
        var rows: [OracleRow] = [], endSeen = false
        for cells in grid.dropFirst(7) {
            if cells.allSatisfy({ $0.isEmpty }) { continue }
            if sourceClean(cells[0]).lowercased() == "** end of statement **" {
                guard !endSeen, cells.dropFirst().allSatisfy({ $0.isEmpty }) else { throw AuthenticAcceptanceError.oracleMismatch }
                endSeen = true; continue
            }
            guard !endSeen else { throw AuthenticAcceptanceError.oracleMismatch }
            rows.append(try sourceOracleRow(date: cells[0], narration: cells[1], amount: cells[3], direction: cells[4], retainsOriginalMoney: false))
        }
        guard endSeen else { throw AuthenticAcceptanceError.oracleMismatch }
        return (rows, controls)
    }
    private static func sourceFinancialMultiset(_ rows: [OracleRow]) -> [String: Int] {
        rows.reduce(into: [:]) { result, row in result[[row.date, row.amount, row.effect].joined(separator: "|") , default: 0] += 1 }
    }
    private static func sourceInventoryDigest(_ inventory: [String: String]) -> String {
        // UTF-8 version header plus sorted digest|byte-count|format records, all LF-terminated.
        let text = "ledgerforge.axis-card.authentic-source-inventory.v1\n" + inventory.keys.sorted().map { "\($0)|\(inventory[$0]!)\n" }.joined()
        return sha256Hex(Data(text.utf8))
    }

    private static func sourceVerifyInventory(_ actual: [String: String]) throws {
        let expected: [String: String] = [
            "013a3ed9925670382b33b0d62a4ef8b11ad77d5b10b2ef714f7482a015ab1937": "140489|app_pdf",
            "098aad1b2370333c69c5f9f36a9059e0f0015a21bb388e35c95a833adf5802b5": "27460|xlsx",
            "0eef6ffd3e64e09c70ae02c4df70e1e36cb0b7129abf0f454f8d368ea3891bcd": "208382|traditional_pdf",
            "1928df08d7924eb61b0e730c3179e98536ed3fb5b48085f690c1172d60a502dc": "220802|traditional_pdf",
            "1eb676f218dd0b6301e1931423902f7d3c94c241fbc68c10639f4df1f008e8bd": "133989|app_pdf",
            "20d0891b20c2e370cb3716c47cb4faac3cd6add355863422cc004dc478770f1d": "158997|app_pdf",
            "25e1fd1310684261d7801c67e04622a2b3c71870ee1ac29386c7328275166813": "293925|app_pdf",
            "2e4b2534bf01dc3f855b4e6e4eaaf3af0d1ae17e1078cd86c6cef05ebf98510f": "22916|xlsx",
            "2e88ba806f0336ebc15a21dc62c0962f692322220b3919e2029f0d627e32363f": "312133|traditional_pdf",
            "305082faa93f28d32875044845f7666b0bcb620ce068c1715028c4088a5912d3": "24133|xlsx",
            "35e8b95fe4c590107313dcfd77f9e256129c8ae2e4d2705b45d18d96e433d3bc": "176015|app_pdf",
            "409c6a4d2ad57e54e787b336ae990ded0c102101b421bf60a38f0660eaf94be9": "353471|app_pdf",
            "51825aca2ace4feafe1a2def5b2ca04451efbd6df9225f58a7549024c9848785": "153550|app_pdf",
            "6ac9ae28b9fb3ef288b7370b5d91a0c72f7e96f6c55d769168f31a23f68c2ec2": "198084|traditional_pdf",
            "74f2e38ec1775cbd0b99b30f1e08e3ba415daf29678695c1e4e3a7f930762f08": "313171|traditional_pdf",
            "86dd24d2cc464beb63d715837178f4ca835603f92234eae05f3781dacc6c1def": "138022|app_pdf",
            "b18e7a63c5f2b460bc87d1530a19ae43624126663fdf6f243e2a1f3c086def9e": "334463|app_pdf",
            "b2713c803870c361cc3a8ddccea20123bb6644b25fb33b6fa4f54e4a63287e0c": "202412|app_pdf",
            "b27d1b0ebd9681ee75b6f163a75c2716341125fa11627ffc9501c09ab1dd55ca": "141110|app_pdf",
            "b9dd39b143cf88cd1dbbb122318d70ea8616b07cbfa3591a48f4121fa551a2de": "236550|app_pdf",
            "bc6ea94f21d7c608e95fc646b7ed040ebbcdb6b5d6a21b5f3c47637599f35b44": "320878|traditional_pdf",
            "cbf19468a119f0d0d42c46a386061a03d1bce35e020491c2574ef3d64efcc653": "247482|app_pdf",
            "ccfcc8ed86eee48fd30c69382849c7731618e4e78027733089b1b1e7360ac082": "27033|xlsx",
            "d777aec229a70a830e6830b3b0df6db65f6ea731e5a7d76f079fd6e223319221": "28676|xlsx",
            "de3bf6d3fdd7a90005ff783474e88319192f67c3230e2b94b38da8c369f60ab0": "24537|xlsx",
            "e876b186ca152e6655fea80dd2fd753969847b4e4f3c0686cd630a501c532063": "220593|app_pdf",
            "eadba710e691a48b7768015a5ea88ef52fe2ba80e0fbebdd46052fe806500cf1": "214083|traditional_pdf",
            "ec38e3a12476a2e1fc737b1fe05fc1e774821421479909884afe01ea708e761a": "24838|xlsx",
            "f3e59d78badd40cd09b7f6311becaa12cd9ae2b9ff128b221130e22a78550067": "158552|app_pdf",
            "f4b5070daf1bcffab33d6cb30a7c0fcd80adec4c19942af979873589199d24f5": "399335|app_pdf",
            "f5c487124dc76246ac3b4a2f825690a44efb94537f194769f24f158ffef30074": "127479|app_pdf",
            "fa0694dfb436ff52d011c4b5bbcd0b7d205a7d3497e039b42fb7db9509fc037b": "221792|app_pdf"
        ]
        guard actual == expected,
              sourceInventoryDigest(actual) == "db2414293ca3cb04a661f56638bde6e592ab39d66468aa18534b8ff8d383f92e" else { throw AuthenticAcceptanceError.oracleMismatch }
    }

    /// Deterministic digest of the independently constructed oracle in memory.
    /// This is not a file digest and is never written to a result artifact.
    private static func sourceOracleProjectionDigest(_ oracle: SourceOracle) -> String {
        func field(_ value: String) -> String { "\(value.utf8.count):\(value)" }
        var values = ["ledgerforge.axis-card.in-memory-oracle-digest.v1", oracle.schema, oracle.authority, oracle.sourceInventorySHA256]
        for record in oracle.records.sorted(by: { $0.sourceSHA256 < $1.sourceSHA256 }) {
            values += [record.sourceSHA256, record.format.rawValue, record.cycle, String(record.rowCount)]
            for key in record.controls.keys.sorted() { values += [key, record.controls[key]!] }
            values.append("rows")
            for row in record.rows {
                values += [row.date, row.amount, row.effect, row.narration,
                    row.reference == nil ? "absent-reference" : "present-reference", row.reference ?? "",
                    row.originalMerchantMoney == nil ? "absent-original-money" : "present-original-money",
                    row.originalMerchantMoney?.currency ?? "", row.originalMerchantMoney?.amount ?? ""]
            }
        }
        return sha256Hex(Data(values.map(field).joined().utf8))
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func require(
        _ condition: Bool,
        error: AuthenticAcceptanceError,
        function: String = #function,
        line: Int = #line
    ) throws {
        #expect(condition, "authentic acceptance invariant at \(function):\(line)")
        guard condition else { throw error }
    }
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }

    func only(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        var match: Element?
        for element in self where try predicate(element) {
            guard match == nil else { return nil }
            match = element
        }
        return match
    }
}
