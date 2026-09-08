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
    private static let oracleKey = "LEDGERFORGE_AXIS_CARD_SOURCE_ORACLE"
    private static let appPasswordKey = "LEDGERFORGE_AXIS_CARD_APP_PASSWORD"
    private static let traditionalPasswordKey = "LEDGERFORGE_AXIS_CARD_TRADITIONAL_PASSWORD"
    private static let privateResultFileKey = "LEDGERFORGE_PRIVATE_RESULT_FILE"

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
        let oracleFileDigest: String
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
        guard let rootPath = ProcessInfo.processInfo.environment[rootKey], !rootPath.isEmpty,
              let oraclePath = ProcessInfo.processInfo.environment[oracleKey], !oraclePath.isEmpty else {
            throw AuthenticAcceptanceError.oracleUnavailable
        }
        let corpus = try await authenticCorpus(
            root: URL(fileURLWithPath: rootPath, isDirectory: true),
            oracleURL: URL(fileURLWithPath: oraclePath)
        )
        completedCorpus = corpus
        return corpus
    }

    private static func authenticCorpus(root: URL, oracleURL: URL) async throws -> LogicalCorpus {
        let oracleBytes: Data
        let oracle: SourceOracle
        do {
            oracleBytes = try Data(contentsOf: oracleURL, options: [.mappedIfSafe])
            oracle = try JSONDecoder().decode(SourceOracle.self, from: oracleBytes)
        } catch {
            throw AuthenticAcceptanceError.oracleUnavailable
        }
        try validateOracleContract(oracle)

        let recordDigests = oracle.records.map(\.sourceSHA256)
        try require(Set(recordDigests).count == recordDigests.count, error: .oracleMismatch)
        let recordsByDigest = Dictionary(uniqueKeysWithValues: oracle.records.map {
            ($0.sourceSHA256, $0)
        })

        let challengeProbe = ChallengeInvocationProbe()
        let passwordProvider = try makePasswordProvider(challengeProbe: challengeProbe)
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
            oracleFileDigest: sha256Hex(oracleBytes),
            sources: sources,
            byCycle: byCycle
        )
        try assertCompleteSourceTruth(corpus)
        return corpus
    }

    private static func validateOracleContract(_ oracle: SourceOracle) throws {
        try require(oracle.schema == "ledgerforge.axis.source-oracle.v4", error: .oracleMismatch)
        try require(
            oracle.authority == "raw-authentic-source-text-independent-projection",
            error: .oracleMismatch
        )
        try require(oracle.sourceInventorySHA256.count == 64, error: .oracleMismatch)
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
        let runtime = try makeRuntime(workspaceID: workspaceID, inMemory: inMemory)
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
            } ?? .createNewAccount
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
    ) throws -> PrivateRuntime {
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
        let passwordProvider = try makePasswordProvider(challengeProbe: challengeProbe)
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
    ) throws -> DefaultPasswordProvider {
        guard let appPassword = ProcessInfo.processInfo.environment[appPasswordKey],
              !appPassword.isEmpty else {
            throw AuthenticAcceptanceError.appCredentialUnavailable
        }
        guard let traditionalPassword = ProcessInfo.processInfo.environment[traditionalPasswordKey],
              !traditionalPassword.isEmpty else {
            throw AuthenticAcceptanceError.traditionalCredentialUnavailable
        }
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
        guard completedPhases == Set(["corpus", "persistence"]),
              let resultPath = ProcessInfo.processInfo.environment[privateResultFileKey],
              !resultPath.isEmpty else { return }

        let physicalRows = corpus.oracle.records.reduce(0) { $0 + $1.rowCount }
        let payload: [String: Any] = [
            "contract": "ledgerforge-axis-credit-card-authentic-acceptance-v4",
            "tests": ["corpus": true, "persistence": true],
            "non_vacuity": [
                "selected_physical_source_count": corpus.sources.count,
                "logical_statement_count": expectedCycles.count,
                "cycles_exercised": expectedCycles,
                "production_tests_executed": 2,
                "selected_private_tests_skipped": 0,
                "rows_processed": physicalRows,
                "ordinary_prepare_validate_confirm": true,
                "exact_byte_replay_all_sources": true,
                "sqlite_campaign_execution": true,
                "in_memory_campaign_execution": true,
                "checkpoint_close_reopen_execution": true,
                "hydration_execution": true
            ],
            "source_oracle": [
                "schema": corpus.oracle.schema,
                "authority": corpus.oracle.authority,
                "oracle_file_sha256": corpus.oracleFileDigest,
                "source_inventory_sha256": corpus.oracle.sourceInventorySHA256,
                "carrier_count": 32,
                "format_counts": ["app_pdf": 18, "xlsx": 7, "traditional_pdf": 7],
                "canonical_transaction_rows": expectedCanonicalTransactionCount,
                "physical_financial_rows": physicalRows,
                "physical_structured_references": 164,
                "canonical_structured_references": 66
            ],
            "persistence": [
                "campaigns": 6,
                "in_memory_campaigns": 3,
                "sqlite_campaigns": 3,
                "canonical_transactions": expectedCanonicalTransactionCount,
                "liability_accounts": 1,
                "accepted_statements": 32,
                "transaction_evidence": expectedCanonicalTransactionCount,
                "semantic_projections": 32,
                "semantic_groups": 18,
                "semantic_members": 32,
                "supporting_members": 14,
                "hydrated_reference_and_parser_provenance_verified": true,
                "axis_repository_preferred_cbq_digest_is_nil": true,
                "sqlite_inmemory_parity_verified": true,
                "sqlite_checkpoint_reopen_verified": true
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: resultPath), options: [.atomic])
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
