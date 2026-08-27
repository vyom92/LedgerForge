import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Opt-in production-path acceptance for the established private Axis corpus.
/// Set LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY to run it; credentials come
/// only from the production Keychain scope. The suite never writes a private
/// answer key and reports aggregate outcomes only.
@Suite(
    .enabled(
        if: ProcessInfo.processInfo.environment[
            "LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY"
        ]?.isEmpty == false,
        "Requires the private Axis credit-card corpus"
    )
)
@MainActor
struct AxisCreditCardAuthenticAcceptanceTests {
    private static let rootKey = "LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY"
    private static let privateResultFileKey = "LEDGERFORGE_PRIVATE_RESULT_FILE"

    @MainActor
    private static var completedPrivateResultPhases: Set<String> = []
    @MainActor
    private static var completedCorpus: LogicalCorpus?

    private enum SourceFormat: String, CaseIterable, Hashable {
        case appPDF = "app-pdf"
        case xlsx
        case traditionalPDF = "traditional-pdf"
    }

    private struct FinancialKey: Hashable {
        let date: String
        let effect: String
        let currency: String
        let minor: Int64
    }

    private typealias FinancialMultiset = [FinancialKey: Int]

    private struct PhysicalSource {
        let document: FinancialDocument
        let bytes: Data
        let format: SourceFormat
        let isLocked: Bool
        let cycle: String
        let selectedStatementMonth: String?
        let rawDigest: String
        let inventoryOrdinal: Int
    }

    private struct LogicalCorpus {
        let byCycle: [String: [SourceFormat: PhysicalSource]]
        let physicalSources: [PhysicalSource]
    }

    private struct AuthenticRepresentation {
        let document: FinancialDocument
        let bytes: Data
        let format: SourceFormat
        let cycle: String
    }

    private actor ChallengeInvocationProbe {
        private var invocationCount = 0

        func recordInvocation() {
            invocationCount += 1
        }

        func count() -> Int {
            invocationCount
        }
    }

    private enum AuthenticAcceptanceError: Error {
        case appCredentialUnavailable
        case traditionalCredentialUnavailable
        case sourceDirectoryUnreadable
        case sourceUnreadable
        case unexpectedPasswordChallenge
        case missingAppChronology
        case missingXLSXChronology
        case missingTraditionalChronology
        case unexpectedCycle
        case unexpectedCorpusShape
        case inconsistentDuplicateCopies
        case financialOutputMismatch
        case campaignInvariant
    }

    private static let expectedMonthlyCounts: [String: Int] = [
        "2026-01": 89,
        "2026-02": 95,
        "2026-03": 56,
        "2026-04": 178,
        "2026-05": 143,
        "2026-06": 154,
        "2026-07": 81
    ]

    private static let expectedPhysicalCounts: [SourceFormat: Int] = [
        .appPDF: 14,
        .xlsx: 7,
        .traditionalPDF: 14
    ]

    @Test
    func authenticJanJulProductionSourcesMatchEstablishedAggregateControls() async throws {
        guard let rootPath = ProcessInfo.processInfo.environment[Self.rootKey],
              !rootPath.isEmpty else {
            throw AuthenticAcceptanceError.sourceDirectoryUnreadable
        }

        let corpus = try await Self.authenticCorpus(
            root: URL(fileURLWithPath: rootPath, isDirectory: true)
        )
        try Self.assertLogicalSourceTruth(corpus)
        try Self.recordPrivateResultPhase("corpus", corpus: corpus)
    }

    @Test
    func authenticRepresentativeImportOrdersPersistWithProviderParityAndReopen() async throws {
        guard let rootPath = ProcessInfo.processInfo.environment[Self.rootKey],
              !rootPath.isEmpty else {
            throw AuthenticAcceptanceError.sourceDirectoryUnreadable
        }

        let representations = try await Self.activeRepresentations(
            root: URL(fileURLWithPath: rootPath, isDirectory: true),
            cycle: "2026-05"
        )
        let hasThreeRepresentations = representations.count == 3
        #expect(hasThreeRepresentations, "representative month has three logical formats")
        guard hasThreeRepresentations else { throw AuthenticAcceptanceError.unexpectedCorpusShape }

        let formats = representations.map(\.format)
        let expectedFormats: [SourceFormat] = [.appPDF, .xlsx, .traditionalPDF]
        let formatOrderIsStable = formats == expectedFormats
        #expect(formatOrderIsStable, "representative format order is deterministic")
        guard formatOrderIsStable else { throw AuthenticAcceptanceError.unexpectedCorpusShape }

        try await Self.runAuthenticCampaign(
            representations: representations,
            order: [0, 1, 2],
            inMemory: true
        )
        try await Self.runAuthenticCampaign(
            representations: representations,
            order: [1, 0, 2],
            inMemory: true
        )
        try await Self.runAuthenticCampaign(
            representations: representations,
            order: [0, 1, 2],
            inMemory: false
        )
        try await Self.runAuthenticCampaign(
            representations: representations,
            order: [1, 0, 2],
            inMemory: false
        )
        try Self.recordPrivateResultPhase("persistence")
    }

    @MainActor
    private static func recordPrivateResultPhase(
        _ phase: String,
        corpus: LogicalCorpus? = nil
    ) throws {
        if let corpus {
            completedCorpus = corpus
        }
        completedPrivateResultPhases.insert(phase)
        guard completedPrivateResultPhases == Set(["corpus", "persistence"]) else {
            return
        }
        guard let resultPath = ProcessInfo.processInfo.environment[privateResultFileKey],
              !resultPath.isEmpty else {
            return
        }
        guard let corpus = completedCorpus else {
            throw AuthenticAcceptanceError.campaignInvariant
        }

        let productionSourceResult = try Self.canonicalProductionSourceResult(corpus)
        let rowsProcessed = Self.expectedCycles.reduce(0) { partial, cycle in
            partial + (corpus.byCycle[cycle] ?? [:]).values.reduce(0) {
                $0 + $1.document.transactions.count
            }
        }

        // This payload summarizes assertions that have already completed. It is
        // evidence export only, never an independent oracle or a source of test
        // expectations. No credential values, private paths, filenames, raw rows,
        // descriptions, or account identifiers cross this boundary.
        let payload: [String: Any] = [
            "contract": "ledgerforge-axis-credit-card-authentic-acceptance-v1",
            "tests": [
                "corpus": true,
                "persistence": true
            ],
            "non_vacuity": [
                "requested_private_context": "axis-card",
                "selected_physical_source_count": corpus.physicalSources.count,
                "logical_representation_count": corpus.byCycle.values.reduce(0) { $0 + $1.count },
                "cycles_exercised": Self.expectedCycles,
                "production_tests_executed": 2,
                "selected_private_tests_skipped": 0,
                "rows_processed": rowsProcessed,
                "sqlite_campaign_execution": true,
                "in_memory_campaign_execution": true,
                "checkpoint_close_reopen_execution": true,
                "hydration_execution": true
            ],
            "corpus": [
                "physical_sources": 35,
                "logical_representations": 21,
                "cycles": expectedCycles.count,
                "rows_per_representation_family": expectedMonthlyCounts.values.reduce(0, +),
                "monthly_rows": expectedMonthlyCounts,
                "app_xlsx_order_and_narration_verified": true,
                "locked_unlocked_pairs_verified": true,
                "march_duplicate_neutral_key_multiplicity": 2,
                "june_duplicate_neutral_key_multiplicity": 2,
                "selected_statement_month_verified_for_app_and_xlsx": true
            ],
            "persistence": [
                "representative_cycle": "2026-05",
                "campaigns": 4,
                "in_memory_campaigns": 2,
                "sqlite_campaigns": 2,
                "canonical_transactions": 143,
                "liability_accounts": 1,
                "axis_card_instruments": 0,
                "statement_sections": 0,
                "section_observations": 0,
                "accepted_statements": 3,
                "transaction_evidence": 143,
                "semantic_projections": 3,
                "semantic_groups": 1,
                "semantic_members": 3,
                "supporting_members": 2,
                "sqlite_inmemory_parity_verified": true,
                "sqlite_checkpoint_reopen_verified": true,
                "canonical_hydration_verified": true
            ],
            "production_source_result": productionSourceResult
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: resultPath), options: [.atomic])
    }

    private static func canonicalProductionSourceResult(
        _ corpus: LogicalCorpus
    ) throws -> [String: Any] {
        let physicalDigests = corpus.physicalSources.map(\.rawDigest)
        let formatCounts = SourceFormat.allCases.reduce(into: [String: Int]()) { counts, format in
            counts[Self.canonicalFormatCode(format)] = corpus.physicalSources.filter {
                $0.format == format
            }.count
        }

        var logicalRecords: [[String: Any]] = []
        logicalRecords.reserveCapacity(corpus.byCycle.values.reduce(0) { $0 + $1.count })
        for cycle in Self.expectedCycles {
            guard let logical = corpus.byCycle[cycle] else {
                throw AuthenticAcceptanceError.unexpectedCorpusShape
            }
            for format in SourceFormat.allCases {
                guard let source = logical[format] else {
                    throw AuthenticAcceptanceError.unexpectedCorpusShape
                }
                let tuples = try Self.canonicalFinancialTuples(source.document.transactions)
                let record: [String: Any] = [
                    "representation": Self.canonicalFormatCode(format),
                    "source_sha256": source.rawDigest,
                    "cycle_or_period": Self.sourceCycleOrPeriod(source),
                    "financial_row_count": tuples.count,
                    "neutral_financial_multiset_sha256": Self.digest(
                        prefix: "ledgerforge.axis.financial-multiset.v1",
                        values: tuples,
                        sortByRawUTF8: true
                    ),
                    "ordered_financial_sequence_sha256": Self.digest(
                        prefix: "ledgerforge.axis.financial-order.v1",
                        values: tuples
                    ),
                    "narration_sequence_sha256": Self.digest(
                        prefix: "ledgerforge.axis.narration-order.v1",
                        values: Self.descriptions(source.document.transactions)
                    ),
                    "duplicate_multiplicity_summary": Self.duplicateSummary(tuples)
                ]
                logicalRecords.append(record)
            }
        }

        let march = corpus.byCycle["2026-03"]?[.appPDF]?.document.transactions ?? []
        let june = corpus.byCycle["2026-06"]?[.appPDF]?.document.transactions ?? []
        return [
            "schema": "ledgerforge.axis.blind-source.v1",
            "serialization": [
                "version": "lf-length-prefixed-v1",
                "text": "UTF-8",
                "field": "name=<decimal UTF-8 byte length>:<UTF-8 value>",
                "tuple_field_order": ["date", "effect", "currency", "money"],
                "tuple_separator": "|",
                "card_effect_values": ["card_increase_owed", "card_decrease_owed"],
                "money": "canonical fixed-scale native decimal"
            ],
            "corpus": [
                "selected_physical_count": corpus.physicalSources.count,
                "physical_representation_counts": formatCounts,
                "locked_physical_count": corpus.physicalSources.filter(\.isLocked).count,
                "unlocked_physical_count": corpus.physicalSources.filter { !$0.isLocked }.count,
                "source_set_sha256": Self.digest(
                    prefix: "ledgerforge.axis.source-set.v1",
                    values: physicalDigests,
                    sortByRawUTF8: true
                )
            ],
            "logical_sources": logicalRecords,
            "source_controls": [
                "march_duplicate_multiplicity_summary": Self.duplicateSummary(
                    try Self.canonicalFinancialTuples(march)
                ),
                "june_duplicate_multiplicity_summary": Self.duplicateSummary(
                    try Self.canonicalFinancialTuples(june)
                ),
                "active_loans_excluded_from_transactions": true,
                "active_loans_exclusion_evidence": [
                    "app_pdf_explicit_boundary",
                    "traditional_pdf_emi_boundary",
                    "xlsx_no_loans_section"
                ]
            ]
        ]
    }

    private static func sourceCycleOrPeriod(_ source: PhysicalSource) -> String {
        guard source.format == .traditionalPDF,
              let period = source.document.cardStatementEvidence?.declaredStatementPeriod
                ?? source.document.declaredStatementPeriod else {
            return source.cycle
        }
        return String(
            format: "%02d/%02d/%04d - %02d/%02d/%04d",
            period.start.day,
            period.start.month,
            period.start.year,
            period.end.day,
            period.end.month,
            period.end.year
        )
    }

    private static func canonicalFormatCode(_ format: SourceFormat) -> String {
        switch format {
        case .appPDF: return "app_pdf"
        case .xlsx: return "xlsx"
        case .traditionalPDF: return "traditional_pdf"
        }
    }

    private static func canonicalField(_ name: String, _ value: String) -> String {
        "\(name)=\(value.utf8.count):\(value)"
    }

    private static func canonicalFinancialTuples(
        _ transactions: [Transaction]
    ) throws -> [String] {
        try transactions.map { transaction in
            guard let effect = transaction.cardLiabilityEffect,
                  let date = transaction.statementDate else {
                throw AuthenticAcceptanceError.financialOutputMismatch
            }
            // The independent source authority records the printed card amount
            // as a non-negative native-money magnitude and carries direction in
            // CardLiabilityEffect.  Production Transaction deliberately keeps
            // its signed Money presentation for downstream semantics, so this
            // acceptance-only projection removes that presentation sign while
            // retaining the independent effect field above.
            let productionMoney = try transaction.money.canonicalDecimalString()
            let sourceMoneyMagnitude = productionMoney.hasPrefix("-")
                ? String(productionMoney.dropFirst())
                : productionMoney
            return [
                Self.canonicalField("date", date.canonical),
                Self.canonicalField("effect", effect.rawValue),
                Self.canonicalField("currency", transaction.money.currency.code),
                Self.canonicalField("money", sourceMoneyMagnitude)
            ].joined(separator: "|")
        }
    }

    private static func duplicateSummary(_ values: [String]) -> [String: Any] {
        let counts = values.reduce(into: [String: Int]()) { counts, value in
            counts[value, default: 0] += 1
        }
        let duplicateMultiplicities = counts.values.filter { $0 > 1 }.sorted()
        return [
            "multiplicities_gt1": duplicateMultiplicities,
            "duplicate_bucket_count": duplicateMultiplicities.count,
            "maximum_multiplicity": counts.values.max() ?? 0
        ]
    }

    private static func digest(
        prefix: String,
        values: [String],
        sortByRawUTF8: Bool = false
    ) -> String {
        let ordered = sortByRawUTF8
            ? values.sorted {
                Data($0.utf8).lexicographicallyPrecedes(Data($1.utf8))
            }
            : values
        var payload = Data((prefix + "\n").utf8)
        for value in ordered {
            payload.append(contentsOf: value.utf8)
            payload.append(0x0A)
        }
        return Self.sha256Hex(payload)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func authenticCorpus(root: URL) async throws -> LogicalCorpus {
        let challengeProbe = ChallengeInvocationProbe()
        let passwordProvider = DefaultPasswordProvider(
            supportedInstitutionCodes: [Institution.axis.statementPasswordCredentialScope],
            challenge: { _ in
                await challengeProbe.recordInvocation()
                throw AuthenticAcceptanceError.unexpectedPasswordChallenge
            }
        )
        try await Self.requireCanonicalCredentialScopes(passwordProvider)

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
            persistenceStateProvider: { preparationProvider.persistenceState },
            providerGenerationProvider: { preparationProvider.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(
                    didHydrate: true,
                    accountCount: 0,
                    transactionCount: 0
                )
            },
            rejectedAttemptHydration: {}
        )

        let files = try regularFiles(under: root)
        var sources: [PhysicalSource] = []
        var inventoryOrdinal = 0
        for url in files {
            let extensionName = url.pathExtension.lowercased()
            guard extensionName == "pdf" || extensionName == "xlsx" else { continue }

            let bytes: Data
            do {
                bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
            } catch {
                throw AuthenticAcceptanceError.sourceUnreadable
            }

            let isLocked: Bool
            if extensionName == "pdf" {
                guard let pdf = PDFDocument(data: bytes) else {
                    throw AuthenticAcceptanceError.sourceUnreadable
                }
                // This is generic PDF encryption evidence captured before the
                // production reader receives a candidate; it is never inferred
                // from a filename or path.
                isLocked = pdf.isLocked
            } else {
                isLocked = false
            }

            let prepared: PreparedImport
            do {
                prepared = try await engine.prepareImport(from: url)
            } catch let error as AuthenticAcceptanceError {
                throw error
            } catch {
                throw AuthenticAcceptanceError.sourceUnreadable
            }
            let document = prepared.financialDocument
            let format: SourceFormat
            switch extensionName {
            case "pdf":
                // Consume the exact transient structural presentation selected
                // by the production Axis normalizer. The private gate must not
                // maintain a second text parser for App vs traditional PDF.
                guard let presentation = prepared.axisCreditCardPDFPresentation else {
                    engine.cancelPreparedImport(prepared)
                    throw AuthenticAcceptanceError.unexpectedCorpusShape
                }
                format = presentation == .appPDF ? .appPDF : .traditionalPDF
            case "xlsx":
                format = .xlsx
            default:
                engine.cancelPreparedImport(prepared)
                throw AuthenticAcceptanceError.sourceUnreadable
            }
            engine.cancelPreparedImport(prepared)

            guard prepared.validation.passed else {
                throw AuthenticAcceptanceError.sourceUnreadable
            }
            let cycle = try Self.cycle(document, format: format)
            guard Self.isActiveCycle(cycle) else {
                throw AuthenticAcceptanceError.unexpectedCycle
            }
            _ = try Self.financialKeys(document.transactions)
            let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            sources.append(PhysicalSource(
                document: document,
                bytes: bytes,
                format: format,
                isLocked: isLocked,
                cycle: cycle,
                selectedStatementMonth: document.cardStatementEvidence?.selectedStatementMonth?.canonical,
                rawDigest: digest,
                inventoryOrdinal: inventoryOrdinal
            ))
            inventoryOrdinal += 1
        }

        guard await challengeProbe.count() == 0 else {
            throw AuthenticAcceptanceError.unexpectedPasswordChallenge
        }

        try Self.assertPhysicalCorpus(sources)

        var byCycle: [String: [SourceFormat: PhysicalSource]] = [:]
        for cycle in Self.expectedCycles {
            let cycleSources = sources.filter { $0.cycle == cycle }
            var logical: [SourceFormat: PhysicalSource] = [:]
            for format in SourceFormat.allCases {
                let copies = cycleSources.filter { $0.format == format }
                let expectedCopies = format == .xlsx ? 1 : 2
                try Self.require(
                    copies.count == expectedCopies,
                    error: .unexpectedCorpusShape
                )

                if format != .xlsx {
                    let lockEvidence = copies.filter(\.isLocked)
                    let unlockEvidence = copies.filter { !$0.isLocked }
                    try Self.require(
                        lockEvidence.count == 1 && unlockEvidence.count == 1,
                        error: .unexpectedCorpusShape
                    )
                    try Self.require(
                        Set(copies.map(\.rawDigest)).count == 2,
                        error: .unexpectedCorpusShape
                    )
                    let equivalent = try Self.productionOutputEquivalent(copies[0], copies[1])
                    #expect(equivalent, "physical duplicate copies have equivalent production output")
                    guard equivalent else {
                        throw AuthenticAcceptanceError.inconsistentDuplicateCopies
                    }
                }

                guard let representative = copies.sorted(by: Self.representativeOrdering).first else {
                    throw AuthenticAcceptanceError.unexpectedCorpusShape
                }
                logical[format] = representative
            }
            byCycle[cycle] = logical
        }

        let corpus = LogicalCorpus(byCycle: byCycle, physicalSources: sources)
        try Self.assertLogicalSourceTruth(corpus)
        return corpus
    }

    private static var expectedCycles: [String] {
        expectedMonthlyCounts.keys.sorted()
    }

    private static func assertPhysicalCorpus(_ sources: [PhysicalSource]) throws {
        let totalIsCorrect = sources.count == 35
        #expect(totalIsCorrect, "active physical source count is 35")
        try Self.require(totalIsCorrect, error: .unexpectedCorpusShape)

        for format in SourceFormat.allCases {
            let actual = sources.filter { $0.format == format }.count
            let expected = expectedPhysicalCounts[format] ?? -1
            try Self.require(actual == expected, error: .unexpectedCorpusShape)
        }

        for cycle in Self.expectedCycles {
            let cycleSources = sources.filter { $0.cycle == cycle }
            for format in SourceFormat.allCases {
                let expectedCopies = format == .xlsx ? 1 : 2
                let count = cycleSources.filter { $0.format == format }.count
                try Self.require(count == expectedCopies, error: .unexpectedCorpusShape)
                if format != .xlsx {
                    let copies = cycleSources.filter { $0.format == format }
                    try Self.require(
                        copies.filter(\.isLocked).count == 1 &&
                            copies.filter { !$0.isLocked }.count == 1,
                        error: .unexpectedCorpusShape
                    )
                }
            }
        }
    }

    private static func assertLogicalSourceTruth(_ corpus: LogicalCorpus) throws {
        for cycle in Self.expectedCycles {
            guard let logical = corpus.byCycle[cycle],
                  let app = logical[.appPDF],
                  let xlsx = logical[.xlsx],
                  let traditional = logical[.traditionalPDF] else {
                throw AuthenticAcceptanceError.unexpectedCorpusShape
            }

            let appKeys = try Self.financialKeys(app.document.transactions)
            let xlsxKeys = try Self.financialKeys(xlsx.document.transactions)
            let traditionalKeys = try Self.financialKeys(traditional.document.transactions)
            let expectedCount = Self.expectedMonthlyCounts[cycle] ?? -1

            try Self.require(appKeys.count == expectedCount, error: .financialOutputMismatch)
            try Self.require(xlsxKeys.count == expectedCount, error: .financialOutputMismatch)
            try Self.require(traditionalKeys.count == expectedCount, error: .financialOutputMismatch)
            try Self.require(Self.multiset(appKeys) == Self.multiset(xlsxKeys), error: .financialOutputMismatch)
            try Self.require(Self.multiset(appKeys) == Self.multiset(traditionalKeys), error: .financialOutputMismatch)
            try Self.require(Self.multiset(xlsxKeys) == Self.multiset(traditionalKeys), error: .financialOutputMismatch)

            let appXLSXOrderMatches = appKeys == xlsxKeys
            #expect(appXLSXOrderMatches, "App PDF and XLSX financial source order matches")
            try Self.require(appXLSXOrderMatches, error: .financialOutputMismatch)

            let narrationMatches = Self.descriptions(app.document.transactions) ==
                Self.descriptions(xlsx.document.transactions)
            #expect(narrationMatches, "App PDF and XLSX normalized narration order matches")
            try Self.require(narrationMatches, error: .financialOutputMismatch)

            try Self.assertDuplicateShape(appKeys, cycle: cycle)
            try Self.assertDuplicateShape(xlsxKeys, cycle: cycle)
            try Self.assertDuplicateShape(traditionalKeys, cycle: cycle)

            let appMonthMatches = app.selectedStatementMonth == cycle && app.cycle == cycle
            let xlsxMonthMatches = xlsx.selectedStatementMonth == cycle && xlsx.cycle == cycle
            #expect(appMonthMatches, "App PDF cycle comes from selected statement month")
            #expect(xlsxMonthMatches, "XLSX cycle comes from selected statement month")
            try Self.require(appMonthMatches, error: .financialOutputMismatch)
            try Self.require(xlsxMonthMatches, error: .financialOutputMismatch)
            if let traditionalMonth = traditional.selectedStatementMonth {
                try Self.require(traditionalMonth == cycle, error: .financialOutputMismatch)
            }
        }

        for format in SourceFormat.allCases {
            let total = Self.expectedCycles.reduce(0) { partial, cycle in
                partial + (corpus.byCycle[cycle]?[format]?.document.transactions.count ?? 0)
            }
            try Self.require(total == 796, error: .financialOutputMismatch)
        }
    }

    private static func assertDuplicateShape(
        _ keys: [FinancialKey],
        cycle: String
    ) throws {
        let counts = Self.multiset(keys)
        let duplicateMultiplicities = counts.values.filter { $0 > 1 }.sorted()
        switch cycle {
        case "2026-03":
            let shapeMatches = keys.count == 56 && counts.count == 55 &&
                duplicateMultiplicities == [2] && counts.values.allSatisfy { $0 <= 2 }
            #expect(shapeMatches, "March has exactly one duplicated neutral key")
            try Self.require(shapeMatches, error: .financialOutputMismatch)
        case "2026-06":
            let shapeMatches = keys.count == 154 && counts.count == 153 &&
                duplicateMultiplicities == [2] && counts.values.allSatisfy { $0 <= 2 }
            #expect(shapeMatches, "June has exactly one duplicated neutral key")
            try Self.require(shapeMatches, error: .financialOutputMismatch)
        default:
            let shapeMatches = counts.count == keys.count && duplicateMultiplicities.isEmpty
            #expect(shapeMatches, "non-duplicate months have unique neutral keys")
            try Self.require(shapeMatches, error: .financialOutputMismatch)
        }
    }

    private static func representativeOrdering(
        _ lhs: PhysicalSource,
        _ rhs: PhysicalSource
    ) -> Bool {
        if lhs.isLocked != rhs.isLocked {
            // Logical representations are always sourced from the unlocked
            // copy; locked counterparts remain physical/equivalence evidence.
            return !lhs.isLocked
        }
        if lhs.rawDigest != rhs.rawDigest {
            return lhs.rawDigest < rhs.rawDigest
        }
        return lhs.inventoryOrdinal < rhs.inventoryOrdinal
    }

    private static func productionOutputEquivalent(
        _ lhs: PhysicalSource,
        _ rhs: PhysicalSource
    ) throws -> Bool {
        guard lhs.format == rhs.format,
              lhs.cycle == rhs.cycle,
              lhs.selectedStatementMonth == rhs.selectedStatementMonth else {
            return false
        }
        return try Self.financialKeys(lhs.document.transactions) ==
            Self.financialKeys(rhs.document.transactions) &&
            Self.descriptions(lhs.document.transactions) == Self.descriptions(rhs.document.transactions)
    }

    private static func regularFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AuthenticAcceptanceError.sourceDirectoryUnreadable
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: [.isRegularFileKey])
            } catch {
                throw AuthenticAcceptanceError.sourceDirectoryUnreadable
            }
            guard values.isRegularFile == true else { continue }
            let directoryComponents = url.deletingLastPathComponent().pathComponents
            guard !directoryComponents.contains(where: Self.isExcludedArchiveComponent) else {
                continue
            }
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func isExcludedArchiveComponent(_ component: String) -> Bool {
        let normalized = component
            .precomposedStringWithCanonicalMapping
            .lowercased()
        let compact = normalized.filter { $0.isLetter || $0.isNumber }
        return compact.contains("archive") || compact.contains("ignore")
    }

    private static func requireCanonicalCredentialScopes(
        _ provider: DefaultPasswordProvider
    ) async throws {
        let probeRequest = ImportRequest(
            fileURL: URL(fileURLWithPath: "/axis-authentic-credential-probe.pdf")
        )
        // The provider is the only credential boundary used here. Inspect
        // candidate origins, never candidate values, so no secret can enter
        // test output or an independent credential path.
        let candidates = try await provider.rememberedPasswordCandidates(for: probeRequest)
        func containsCanonicalScope(_ scope: String) -> Bool {
            candidates.contains { candidate in
                candidate.origins.contains { origin in
                    guard case .canonical(let candidateScope) = origin else { return false }
                    return candidateScope == scope
                }
            }
        }

        guard containsCanonicalScope(KeychainStatementPasswordCredentialStore.axisAppPDFScope) else {
            throw AuthenticAcceptanceError.appCredentialUnavailable
        }
        guard containsCanonicalScope(KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope) else {
            throw AuthenticAcceptanceError.traditionalCredentialUnavailable
        }
    }

    private static func cycle(
        _ document: FinancialDocument,
        format: SourceFormat
    ) throws -> String {
        switch format {
        case .appPDF:
            guard let month = document.cardStatementEvidence?.selectedStatementMonth else {
                throw AuthenticAcceptanceError.missingAppChronology
            }
            return month.canonical
        case .xlsx:
            guard let month = document.cardStatementEvidence?.selectedStatementMonth else {
                throw AuthenticAcceptanceError.missingXLSXChronology
            }
            return month.canonical
        case .traditionalPDF:
            if let month = document.cardStatementEvidence?.selectedStatementMonth {
                return month.canonical
            }
            if let end = document.cardStatementEvidence?.declaredStatementPeriod?.end {
                return String(format: "%04d-%02d", end.year, end.month)
            }
            if let date = document.cardStatementEvidence?.statementDate {
                return String(format: "%04d-%02d", date.year, date.month)
            }
            throw AuthenticAcceptanceError.missingTraditionalChronology
        }
    }

    private static func isActiveCycle(_ cycle: String) -> Bool {
        expectedMonthlyCounts[cycle] != nil
    }

    private static func financialKeys(
        _ transactions: [Transaction]
    ) throws -> [FinancialKey] {
        var keys: [FinancialKey] = []
        keys.reserveCapacity(transactions.count)
        for transaction in transactions {
            guard let effect = transaction.cardLiabilityEffect,
                  let date = transaction.statementDate,
                  let minor = try? transaction.money.minorUnits() else {
                throw AuthenticAcceptanceError.financialOutputMismatch
            }
            keys.append(FinancialKey(
                date: date.canonical,
                effect: effect.rawValue,
                currency: transaction.money.currency.code,
                minor: minor
            ))
        }
        guard keys.count == transactions.count else {
            throw AuthenticAcceptanceError.financialOutputMismatch
        }
        return keys
    }

    private static func multiset(_ keys: [FinancialKey]) -> FinancialMultiset {
        keys.reduce(into: FinancialMultiset()) { counts, key in
            counts[key, default: 0] += 1
        }
    }

    private static func descriptions(_ transactions: [Transaction]) -> [String] {
        transactions.map { transaction in
            transaction.description
                .precomposedStringWithCanonicalMapping
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func activeRepresentations(
        root: URL,
        cycle wantedCycle: String
    ) async throws -> [AuthenticRepresentation] {
        let corpus = try await Self.authenticCorpus(root: root)
        guard let logical = corpus.byCycle[wantedCycle] else {
            throw AuthenticAcceptanceError.unexpectedCorpusShape
        }
        return try SourceFormat.allCases.map { format in
            guard let source = logical[format] else {
                throw AuthenticAcceptanceError.unexpectedCorpusShape
            }
            return AuthenticRepresentation(
                document: source.document,
                bytes: source.bytes,
                format: source.format,
                cycle: source.cycle
            )
        }
    }

    private static func runAuthenticCampaign(
        representations: [AuthenticRepresentation],
        order: [Int],
        inMemory: Bool
    ) async throws {
        let workspaceID = "axis-authentic-\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LedgerForge-AxisAuthentic-\(UUID().uuidString)",
            isDirectory: true
        )
        let databaseURL = folder.appendingPathComponent("authentic.sqlite")
        let sqlite: SQLiteRepositoryProvider?
        let provider: DatabaseProvider
        if inMemory {
            sqlite = nil
            provider = DatabaseProvider(inMemory: true)
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let opened = try SQLiteRepositoryProvider(path: databaseURL.path)
            sqlite = opened
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
        }
        defer {
            sqlite?.database.close()
            if inMemory { try? FileManager.default.removeItem(at: folder) }
        }

        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID)
        )
        var accountID: String?
        var canonicalIDs: Set<String>?
        var firstOwnership: [String]?
        for index in order {
            guard representations.indices.contains(index) else {
                throw AuthenticAcceptanceError.campaignInvariant
            }
            let representation = representations[index]
            let validation = ImportValidator.validate(financialDocument: representation.document)
            #expect(validation.passed, "authentic representation passes import validation")
            guard validation.passed else { throw AuthenticAcceptanceError.campaignInvariant }

            let session = ImportSession(
                fileName: representation.document.sourceDocument.filename,
                institution: .axis,
                documentType: .creditCard,
                parserName: representation.document.parserName,
                transactionCount: representation.document.transactions.count,
                validation: validation
            )
            let choice: ImportAccountChoice = accountID == nil
                ? .createNewAccount
                : .useExistingAccount(accountId: accountID!)
            let result = try coordinator.persistValidatedImport(
                financialDocument: representation.document,
                importSession: session,
                validation: validation,
                fingerprintSet: fingerprintSet(representation),
                accountChoice: choice,
                providerGeneration: provider.generationToken
            )

            let isSupporting = canonicalIDs != nil
            #expect(result.persisted, "authentic campaign persistence committed")
            #expect(result.isEquivalentSupportingSource == isSupporting, "supporting-source classification is exact")
            #expect(result.transactionCount == (isSupporting ? 0 : 143), "authentic campaign transaction delta is exact")
            guard result.persisted,
                  result.accountId != nil,
                  result.isEquivalentSupportingSource == isSupporting,
                  result.transactionCount == (isSupporting ? 0 : 143) else {
                throw AuthenticAcceptanceError.campaignInvariant
            }
            accountID = accountID ?? result.accountId

            let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
            let ids = Set(transactions.map(\.id))
            if let canonicalIDs {
                try Self.require(ids == canonicalIDs, error: .campaignInvariant)
            } else {
                try Self.require(transactions.count == 143, error: .campaignInvariant)
                canonicalIDs = ids
                firstOwnership = Self.transactionOwnership(transactions)
            }
        }

        guard let canonicalIDs, let firstOwnership else {
            throw AuthenticAcceptanceError.campaignInvariant
        }
        try Self.verify(
            provider,
            workspaceID: workspaceID,
            canonicalIDs: canonicalIDs,
            firstOwnership: firstOwnership
        )

        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: databaseURL.path)
            let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            try Self.verify(
                reopenedProvider,
                workspaceID: workspaceID,
                canonicalIDs: canonicalIDs,
                firstOwnership: firstOwnership
            )
            reopened.database.close()
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private static func verify(
        _ target: DatabaseProvider,
        workspaceID: String,
        canonicalIDs: Set<String>,
        firstOwnership: [String]
    ) throws {
        let transactions = try target.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        try Self.require(transactions.count == 143, error: .campaignInvariant)
        try Self.require(Set(transactions.map(\.id)) == canonicalIDs, error: .campaignInvariant)
        try Self.require(Self.transactionOwnership(transactions) == firstOwnership, error: .campaignInvariant)

        let card = try target.cardRepo.snapshot(workspaceId: workspaceID)
        try Self.require(try target.accountRepo.accounts(workspaceId: workspaceID).count == 1, error: .campaignInvariant)
        try Self.require(card.instruments.isEmpty, error: .campaignInvariant)
        try Self.require(card.sections.isEmpty, error: .campaignInvariant)
        try Self.require(card.sectionObservations.isEmpty, error: .campaignInvariant)
        try Self.require(card.statements.count == 3, error: .campaignInvariant)
        try Self.require(card.transactionEvidence.count == 143, error: .campaignInvariant)
        try Self.require(Set(card.transactionEvidence.map(\.transactionId)) == canonicalIDs, error: .campaignInvariant)
        try Self.require(card.semanticProjections.count == 3, error: .campaignInvariant)
        try Self.require(card.semanticGroups.count == 1, error: .campaignInvariant)
        try Self.require(card.semanticMembers.count == 3, error: .campaignInvariant)
        try Self.require(card.semanticMembers.filter { $0.role == .supporting }.count == 2, error: .campaignInvariant)

        let authoritativeMember = card.semanticMembers.first { $0.role == .authoritative }
        let supportingMembers = card.semanticMembers.filter { $0.role == .supporting }
        guard let authoritativeMember,
              let authoritativeProjection = card.semanticProjections.first(where: {
                  $0.id == authoritativeMember.projectionId
              }) else {
            throw AuthenticAcceptanceError.campaignInvariant
        }
        try Self.require(
            card.semanticGroups.first?.authoritativeProjectionId == authoritativeProjection.id,
            error: .campaignInvariant
        )
        try Self.require(
            authoritativeProjection.events.allSatisfy { $0.canonicalTransactionId != nil },
            error: .campaignInvariant
        )
        try Self.require(
            Set(authoritativeProjection.events.compactMap(\.canonicalTransactionId)) == canonicalIDs,
            error: .campaignInvariant
        )

        for member in supportingMembers {
            guard let projection = card.semanticProjections.first(where: { $0.id == member.projectionId }) else {
                throw AuthenticAcceptanceError.campaignInvariant
            }
            let buckets = Dictionary(grouping: projection.events, by: Self.axisProjectionKey)
            for bucket in buckets.values {
                if bucket.count > 1 {
                    try Self.require(
                        bucket.allSatisfy { $0.canonicalTransactionId == nil },
                        error: .campaignInvariant
                    )
                } else if let event = bucket.first {
                    try Self.require(
                        event.canonicalTransactionId.map(canonicalIDs.contains) == true,
                        error: .campaignInvariant
                    )
                }
            }
        }

        let hydrated = try RepositoryStoreHydrator(
            accountRepo: target.accountRepo,
            importSessionRepo: target.importSessionRepo,
            transactionRepo: target.transactionRepo,
            categoryRepo: target.categoryRepo,
            cardRepo: target.cardRepo,
            workspaceId: workspaceID,
            persistenceState: target.persistenceState,
            providerGeneration: target.generationToken,
            participatesInLifecycleGate: false
        ).stageHydration()
        try Self.require(hydrated.transactions.count == 143, error: .campaignInvariant)
        try Self.require(hydrated.cardSnapshot.statements.count == 3, error: .campaignInvariant)
        try Self.require(hydrated.cardSnapshot.transactionEvidence.count == 143, error: .campaignInvariant)
    }

    private static func axisProjectionKey(
        _ event: CardStatementSemanticProjectionEventDTO
    ) -> FinancialKey {
        FinancialKey(
            date: event.financialDateISO,
            effect: event.liabilityEffectCode,
            currency: event.postedCurrency,
            minor: event.postedAmountMinor
        )
    }

    private static func transactionOwnership(_ transactions: [TransactionDTO]) -> [String] {
        transactions.map {
            [$0.id, $0.documentId ?? "", $0.importSessionId ?? ""].joined(separator: "|")
        }.sorted()
    }

    private static func require(
        _ condition: Bool,
        error: AuthenticAcceptanceError
    ) throws {
        #expect(condition, "authentic acceptance invariant")
        guard condition else { throw error }
    }

    private static func fingerprintSet(
        _ representation: AuthenticRepresentation
    ) -> PreparedDocumentFingerprintSet {
        let digest = SHA256.hash(data: representation.bytes).map { String(format: "%02x", $0) }.joined()
        return PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
                digest: digest,
                byteCount: Int64(representation.bytes.count),
                isDuplicateAuthority: false
            ),
            VersionedDocumentFingerprint(
                algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                digest: digest,
                byteCount: Int64(representation.bytes.count),
                isDuplicateAuthority: true
            )
        ])
    }
}
