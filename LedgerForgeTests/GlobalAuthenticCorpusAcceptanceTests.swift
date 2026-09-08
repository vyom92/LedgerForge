import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Complete mixed-family acceptance over immutable authentic source carriers.
///
/// There is intentionally no test-owned financial statement, document, row, or
/// repository graph in this suite. Source facts come from frozen independent
/// oracles (or, for encrypted CBQ card PDFs, the same source-only text/geometry
/// oracle used by the family gate) before an ordinary production preparation is
/// attempted. Each campaign then queues the real carriers through the public
/// one-source-at-a-time prepare/validate/confirm workflow.
@Suite(.serialized)
@MainActor
struct GlobalAuthenticCorpusAcceptanceTests {
    private static let expectedCarrierCount = 127
    private static let expectedLogicalStatementCount = 103
    private static let expectedCanonicalTransactionCount = 3_165
    private static let expectedRepresentationTransactionCount = 5_286

    private static let frozenOracleDigests: [Family: String] = [
        .axisBank: "5fd6a8ae466f9aa40e8c03e87c240fbb985ef59308665778cb7b8c6f7e46e0e8",
        .hdfcBank: "5e0332c96f17bc2eb3dcb8b256b8fe59938271b4ddb13c47354046c92c2a9dd2",
        .cbqBank: "d4cee9469f4fa811ad30317312e6b671d1d955325d4682000f16aef3a75564ca",
        .axisCard: "04aacb0af0decaa61ea85aa5664d08d8872eb0ac29ec085b815a836104b37e93",
        .amexCard: "92d14deedec5ba2f6c57be780b06c9e8deeb2703e689c2c1145507a3ca138e81",
        .salary: "9b4223c2c7c21391b4250c853dc22590616688b33c6431ce458d2f0429445377"
    ]

    private enum Family: String, CaseIterable, Comparable {
        case axisBank = "axis-bank"
        case hdfcBank = "hdfc-bank"
        case cbqBank = "cbq-bank"
        case axisCard = "axis-card"
        case cbqCard = "cbq-card"
        case amexCard = "amex-card"
        case salary

        static func < (lhs: Family, rhs: Family) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
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

    private enum SourceFormat: String, Decodable {
        case csv
        case pdf
        case xls
        case xlsx
        case axisAppPDF = "app_pdf"
        case axisTraditionalPDF = "traditional_pdf"
    }

    private struct Context {
        let axisBankRoot: URL
        let axisBankOracle: URL
        let hdfcRoot: URL
        let hdfcOracle: URL
        let cbqBankRoot: URL
        let cbqBankAttachment: URL
        let cbqBankOracle: URL
        let axisCardRoot: URL
        let axisCardOracle: URL
        let cbqCardRoot: URL
        let amexRoot: URL
        let amexOracle: URL
        let salaryRoot: URL
        let salaryOracle: URL
        let hdfcPassword: String
        let cbqPassword: String
        let axisAppPassword: String
        let axisTraditionalPassword: String
        let amexPassword: String
        let resultFile: URL

        @MainActor
        static func load(_ environment: [String: String]) throws -> Context {
            let amexOracleSHA = try required(
                "LEDGERFORGE_PRIVATE_AMEX_ORACLE_SHA256", environment
            )
            guard amexOracleSHA == frozenOracleDigests[.amexCard] else {
                throw AcceptanceError.context("amex oracle digest")
            }
            return Context(
                axisBankRoot: try directory(try required("LEDGERFORGE_AXIS_BANK_ROOT", environment)),
                axisBankOracle: try file(try required("LEDGERFORGE_AXIS_BANK_ORACLE_V2", environment)),
                hdfcRoot: try directory(try required("LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT", environment)),
                hdfcOracle: try file(try required("LEDGERFORGE_PRIVATE_HDFC_ORACLE_FILE", environment)),
                cbqBankRoot: try directory(try required("LEDGERFORGE_CBQ_BANK_ROOT", environment)),
                cbqBankAttachment: try file(try required("LEDGERFORGE_CBQ_BANK_ATTACHMENT", environment)),
                cbqBankOracle: try file(try required("LEDGERFORGE_CBQ_BANK_ORACLE", environment)),
                axisCardRoot: try directory(try required("LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY", environment)),
                axisCardOracle: try file(try required("LEDGERFORGE_AXIS_CARD_SOURCE_ORACLE", environment)),
                cbqCardRoot: try directory(try required("LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY", environment)),
                amexRoot: try directory(try required("LEDGERFORGE_PRIVATE_AMEX_ROOT", environment)),
                amexOracle: try file(try required("LEDGERFORGE_PRIVATE_AMEX_ORACLE_PATH", environment)),
                salaryRoot: try directory(try required("LEDGERFORGE_PRIVATE_SALARY_ORIGINALS_ROOT", environment)),
                salaryOracle: try file(try required("LEDGERFORGE_PRIVATE_SALARY_ORACLE_FILE", environment)),
                hdfcPassword: try required("LEDGERFORGE_PRIVATE_HDFC_PASSWORD", environment),
                cbqPassword: try required("LEDGERFORGE_PRIVATE_CBQ_PASSWORD", environment),
                axisAppPassword: try required("LEDGERFORGE_AXIS_CARD_APP_PASSWORD", environment),
                axisTraditionalPassword: try required("LEDGERFORGE_AXIS_CARD_TRADITIONAL_PASSWORD", environment),
                amexPassword: try required("LEDGERFORGE_PRIVATE_AMEX_PASSWORD", environment),
                resultFile: try evidenceDestination(environment)
            )
        }

        static func evidenceDestination(_ environment: [String: String]) throws -> URL {
            URL(fileURLWithPath: try required("LEDGERFORGE_GLOBAL_AUTHENTIC_RESULT_FILE", environment))
        }

        private static func required(
            _ key: String,
            _ environment: [String: String]
        ) throws -> String {
            guard let value = environment[key],
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AcceptanceError.context("missing runtime key \(key)")
            }
            return value
        }

        private static func file(_ path: String) throws -> URL {
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                throw AcceptanceError.context("required file unavailable")
            }
            return url
        }

        private static func directory(_ path: String) throws -> URL {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw AcceptanceError.context("required directory unavailable")
            }
            return url
        }
    }

    private struct Corpus {
        let carriers: [Carrier]
        let oracleFileDigests: [Family: String]
        let cbqCardSourceOracleDigest: String
        let startingSourceDigests: [String: String]
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

    private struct Runtime {
        let provider: DatabaseProvider
        let engine: ImportEngine
        let hydrator: RepositoryStoreHydrator
        let stores: RuntimeStores
        let sqlite: SQLiteRepositoryProvider?
        let databaseURL: URL?
        let folder: URL
    }

    private struct RoutingState {
        var accountIDs: [String: String] = [:]
        var representedStatements: Set<String> = []
        var authoritativeByLogicalStatement: [String: Carrier] = [:]
        var importSessionBySourceDigest: [String: String] = [:]
        var duplicateAuthorityBySourceDigest: [String: VersionedDocumentFingerprint] = [:]
    }

    private struct AcceptedGraph: Equatable {
        let accounts: Int
        let transactions: Int
        let transactionIDs: Set<String>
        let importSessions: Int
        let salaryStatements: Int
        let salaryComponents: Int
        let cardStatements: Int
        let cardInstruments: Int
        let cardSections: Int
        let cardTransactionEvidence: Int
        let cardSemanticProjections: Int
        let cardSemanticGroups: Int
        let cardSemanticMembers: Int
        let bankProjections: Int
        let bankGroups: Int
        let bankMembers: Int
        let cbqBankObservations: Int
    }

    private struct Carrier {
        let family: Family
        let url: URL
        let sourceSHA256: String
        let sourceSize: Int
        let logicalStatementKey: String
        let chronologicalKey: String
        let expectedTransactionCount: Int
        let evidence: Evidence

        var token: String { "\(family.rawValue):\(sourceSHA256.prefix(12))" }
    }

    private enum Evidence {
        case axisBank(AxisBankCarrier)
        case hdfcBank(HDFCCarrier)
        case cbqBank(CBQBankCarrier)
        case axisCard(AxisCardRecord)
        case cbqCard(PrivateCBQOracle)
        case amexCard(AmexSource)
        case salary(SalarySource)
    }

    // MARK: Frozen oracle schemas

    private struct AxisBankOracle: Decodable {
        let schema: String
        let sourceInventorySha256: String
        let corpus: AxisBankCorpus
        let carriers: [AxisBankCarrier]
    }

    private struct AxisBankCorpus: Decodable {
        let carrierCount: Int
        let logicalStatementCount: Int
        let canonicalEventCount: Int
        let representationRowCount: Int
        let formatCounts: [String: Int]
        let pageCounts: [Int]
    }

    private struct AxisBankCarrier: Decodable {
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
        let controls: AxisBankControls
        let rows: [AxisBankRow]
    }

    private struct AxisBankControls: Decodable {
        let openingBalance: String
        let closingBalance: String
        let debitTotal: String
        let creditTotal: String
    }

    private struct AxisBankRow: Decodable {
        let sourceOrder: Int
        let sourceOrdinal: Int
        let sourcePage: Int?
        let date: String
        let direction: String
        let signedAmount: String
        let balance: String
        let descriptionSha256: String?
        let chequeReferenceSha256: String?
        let upiOperation: String?
        let upiReference: String?
        let upiReferenceSha256: String?
        let upiSubtype: String?
    }

    private struct HDFCOracle: Decodable {
        let schema: String
        let carriers: HDFCCarriers
        let totals: HDFCTotals
    }

    private struct HDFCCarriers: Decodable {
        let pdf: [HDFCCarrier]
        let xls: [HDFCCarrier]
    }

    private struct HDFCCarrier: Decodable {
        let carrier: String
        let sha256: String
        let account: String
        let periodStart: String
        let periodEnd: String
        let currency: String
        let rows: [HDFCRow]
        let summary: HDFCSummary
    }

    private struct HDFCRow: Decodable {
        let physicalPage: Int?
        let physicalRow: Int?
        let date: String
        let narration: String
        let reference: String
        let valueDate: String
        let withdrawal: String
        let deposit: String
        let closing: String
    }

    private struct HDFCSummary: Decodable {
        let openingBalance: String
        let debitCount: Int
        let creditCount: Int
        let debits: String
        let credits: String
        let closingBalance: String
    }

    private struct HDFCTotals: Decodable {
        let pdfCarriers: Int
        let xlsCarriers: Int
        let logicalStatements: Int
        let canonicalRows: Int
        let representationRows: Int
        let allFinancialAndReferencesAgree: Bool
    }

    private struct CBQBankOracle: Decodable {
        let schema: String
        let extraction: String
        let directionAuthority: String
        let carriers: [CBQBankCarrier]
    }

    private struct CBQBankCarrier: Decodable {
        let carrier: String
        let sha256: String
        let statementDate: String
        let periodStart: String
        let maskedAccount: String
        let maskedIBAN: String
        let openingBalance: String
        let closingBalance: String
        let rows: [CBQBankRow]
    }

    private struct CBQBankRow: Decodable {
        let postingDate: String
        let description: String
        let sourceTransactionDate: String
        let signedAmount: String
        let balance: String
        let sourcePage: Int
    }

    private struct AxisCardOracle: Decodable {
        let schema: String
        let authority: String
        let sourceInventorySha256: String
        let corpus: AxisCardCorpus
        let records: [AxisCardRecord]
    }

    private struct AxisCardCorpus: Decodable {
        let carrierCount: Int
        let logicalStatementCount: Int
        let transactionRowCount: Int
        let formatCounts: [String: Int]
        let cycles: [String]
    }

    private struct AxisCardRecord: Decodable {
        let sourceSha256: String
        let format: String
        let cycle: String
        let rowCount: Int
        let rows: [AxisCardRow]
        let controls: [String: String]
    }

    private struct AxisCardRow: Decodable {
        let date: String
        let amount: String
        let effect: String
        let reference: String?
        let narration: String
        let originalMerchantMoney: SourceMoney?
    }

    private struct AmexOracle: Decodable {
        let sources: [AmexSource]
        let aggregate: AmexAggregate
    }

    private struct AmexAggregate: Decodable {
        let statementCount: Int
        let financialRowCount: Int
        let sectionCount: Int
        let foreignMoneyRowCount: Int
        let reconciliationFailureCount: Int
        let sectionFailureCount: Int
    }

    private struct AmexSource: Decodable {
        let basename: String
        let sourceByteSize: Int
        let sourceSHA256: String
        let statementDate: String
        let statementPeriod: SourcePeriod
        let dueDate: String
        let nativeCurrency: String
        let membershipLiabilityIdentityEvidence: AmexIdentity
        let summary: AmexSummary
        let sections: [AmexSection]
        let rows: [AmexRow]
    }

    private struct AmexIdentity: Decodable {
        let membershipNumberMasked: String
    }

    private struct AmexSummary: Decodable {
        let previousBalance: SourceMoney
        let newCredits: SourceMoney
        let newDebits: SourceMoney
        let newBalance: SourceMoney
        let reconciliationResidual: Int
        let oracleCalculated: AmexSummaryCalculation
    }

    private struct AmexSummaryCalculation: Decodable {
        let statementEquationResidualMinorUnits: Int64
    }

    private struct AmexSection: Decodable {
        let accountMasked: String
        let accountKeyHash: String
        let rowOrdinals: [Int]
        let oracleCalculated: AmexSectionCalculation
    }

    private struct AmexSectionCalculation: Decodable {
        let allPrintedTotalsMatch: Bool
        let netActivity: SourceMoney
        let rowCount: Int
    }

    private struct AmexRow: Decodable {
        let globalSourceOrdinal: Int
        let page: Int
        let transactionDate: String
        let postingDate: String
        let sourceReference: String?
        let descriptionSourceExact: String
        let descriptionSourceRawSegmentsSHA256: String
        let postedNativeMoney: SourceMoney
        let creditDebitLiabilityDirection: String
        let financialScope: String
        let sectionAccountMasked: String?
        let sectionAccountKeyHash: String?
        let originalForeignMoney: SourceMoney?
    }

    private struct SourcePeriod: Decodable {
        let start: String
        let end: String
    }

    private struct SourceMoney: Decodable {
        let currency: String
        let minorUnits: Int64?
        let amount: String?

        private enum CodingKeys: String, CodingKey {
            case currency, minorUnits, amount, unscaledIntegerAtSourceDisplayedScale
        }

        init(currency: String, minorUnits: Int64?, amount: String?) {
            self.currency = currency
            self.minorUnits = minorUnits
            self.amount = amount
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            currency = try values.decode(String.self, forKey: .currency)
            amount = try values.decodeIfPresent(String.self, forKey: .amount)
            minorUnits = try values.decodeIfPresent(Int64.self, forKey: .minorUnits)
                ?? values.decodeIfPresent(Int64.self, forKey: .unscaledIntegerAtSourceDisplayedScale)
        }
    }

    private struct SalaryOracle: Decodable {
        let oracleSchema: String
        let oracleMethod: String
        let statements: [SalarySource]
    }

    private struct SalarySource: Decodable {
        let sourceBasename: String
        let sourceSha256: String
        let sourceSize: Int
        let pageCount: Int
        let encrypted: Bool
        let sourceIdentity: SalaryIdentity
        let documentTitle: String
        let period: String
        let printDate: String
        let kind: String
        let currency: String
        let earnings: [SalaryComponentSource]
        let deductions: [SalaryComponentSource]
        let printedControls: SalaryControls
        let reconciliation: SalaryReconciliation
    }

    private struct SalaryIdentity: Decodable, Hashable {
        let employer: String
        let employeeName: String
        let employeeNumber: String
        let position: String
        let paymentIban: String
    }

    private struct SalaryComponentSource: Decodable {
        let ordinal: Int
        let label: String
        let amount: String
    }

    private struct SalaryControls: Decodable {
        let totalEarnings: String
        let totalDeductions: String?
        let netPay: String
        let paymentTotal: String
    }

    private struct SalaryReconciliation: Decodable {
        let earningsSumMatches: Bool
        let deductionsSumMatchesOrAbsent: Bool
        let netMatchesEarningsLessDeductions: Bool
        let paymentTotalMatchesNet: Bool

        var allPass: Bool {
            earningsSumMatches && deductionsSumMatchesOrAbsent
                && netMatchesEarningsLessDeductions && paymentTotalMatchesNet
        }
    }

    // MARK: Source-only corpus freeze

    /// Nonfinancial output mechanics, exercised in the same sandbox as the corpus gate.
    @Test(.globalRuntimeStateIsolation)
    func configuredEvidenceDestinationSupportsAtomicWrites() throws {
        try preflightEvidenceDestination(Context.evidenceDestination(ProcessInfo.processInfo.environment))
    }

    @Test(.globalRuntimeStateIsolation, .timeLimit(.minutes(20)))
    func completeAuthenticCorpusUsesMixedOrdinaryImportReplayAndReopen() async throws {
        let context = try Context.load(ProcessInfo.processInfo.environment)
        try preflightEvidenceDestination(context.resultFile)
        let corpus = try await loadCorpus(context)
        try verifyCorpusContract(corpus)
        var campaignDigests: [String: String] = [:]
        for providerKind in ProviderKind.allCases {
            for order in CampaignOrder.allCases {
                let digest = try await runCampaign(
                    context: context,
                    corpus: corpus,
                    providerKind: providerKind,
                    order: order
                )
                campaignDigests["\(providerKind.rawValue)|\(order.rawValue)"] = digest
                print("Global authentic campaign passed: \(providerKind.rawValue)|\(order.rawValue)")
            }
        }
        try require(
            Set(campaignDigests.values).count == 1,
            .campaign("provider/order hydrated semantic parity")
        )
        let ending = try Dictionary(uniqueKeysWithValues: corpus.carriers.map { carrier in
            (carrier.sourceSHA256, try sourceDigest(carrier.url))
        })
        try require(ending == corpus.startingSourceDigests,
                    .source("authentic source bytes changed"))
        try writeEvidence(
            context: context,
            corpus: corpus,
            campaignDigests: campaignDigests
        )
    }

    private func runCampaign(
        context: Context,
        corpus: Corpus,
        providerKind: ProviderKind,
        order: CampaignOrder
    ) async throws -> String {
        let workspace = "global-authentic-\(providerKind.rawValue)-\(order.rawValue)-\(UUID().uuidString)"
        let runtime = try makeRuntime(
            context: context,
            workspace: workspace,
            providerKind: providerKind
        )
        defer {
            runtime.sqlite?.database.close()
            try? FileManager.default.removeItem(at: runtime.folder)
        }
        let ordered = orderedCarriers(corpus.carriers, order: order)
        try require(ordered.count == Self.expectedCarrierCount,
                    .campaign("\(providerKind.rawValue)/\(order.rawValue) queue count"))

        let cancelled = try await runtime.engine.prepareImport(
            from: try requireValue(ordered.first?.url, .campaign("cancel source"))
        )
        try verifyPrepared(cancelled, carrier: try requireValue(ordered.first, .campaign("cancel carrier")))
        runtime.engine.cancelPreparedImport(cancelled)
        try verifyNoAcceptedResidue(runtime.provider, workspace: workspace, hydrator: runtime.hydrator)

        let lockedCBQ = try requireValue(
            ordered.first { $0.family == .cbqCard },
            .campaign("password rejection source")
        )
        let passwordless = makeEngine(
            context: context,
            provider: runtime.provider,
            workspace: workspace,
            hydrator: runtime.hydrator,
            includeCredentials: false
        )
        var passwordRejected = false
        do {
            let unexpectedlyPrepared = try await passwordless.prepareImport(from: lockedCBQ.url)
            passwordless.cancelPreparedImport(unexpectedlyPrepared)
        } catch let error as ImportError {
            passwordRejected = error == .passwordRequired || error == .incorrectPassword
        } catch {
            throw error
        }
        try require(passwordRejected,
                    .campaign("\(providerKind.rawValue)/\(order.rawValue) missing-password rejection"))
        try verifyNoAcceptedResidue(runtime.provider, workspace: workspace, hydrator: runtime.hydrator)

        var state = RoutingState()
        for carrier in ordered {
            let prepared = try await runtime.engine.prepareImport(from: carrier.url)
            defer { runtime.engine.cancelPreparedImport(prepared) }
            try verifyPrepared(prepared, carrier: carrier)
            let supporting = state.representedStatements.contains(carrier.logicalStatementKey)
            let choice = try accountChoice(
                prepared: prepared,
                carrier: carrier,
                supporting: supporting,
                state: state,
                provider: runtime.provider,
                workspace: workspace
            )
            let result = await runtime.engine.commitPreparedImport(
                prepared,
                accountChoice: choice
            )
            let expectedDelta = supporting ? 0 : carrier.expectedTransactionCount
            try require(
                result.persisted && result.validationPassed
                    && result.errorMessage == nil
                    && result.previousImport == nil
                    && result.hydrationOutcome == .committedAndHydrated
                    && result.transactionCount == expectedDelta
                    && result.isEquivalentSupportingSource == supporting
                    && result.isSalaryImport == (carrier.family == .salary),
                .campaign("\(providerKind.rawValue)/\(order.rawValue)/\(carrier.token) confirmation")
            )
            if let routingKey = accountRoutingKey(carrier) {
                let accountID = try requireValue(result.accountId,
                                                 .campaign("\(carrier.token) account result"))
                if let existing = state.accountIDs[routingKey] {
                    try require(existing == accountID, .campaign("\(carrier.token) account stability"))
                } else {
                    state.accountIDs[routingKey] = accountID
                }
            } else {
                try require(result.accountId == nil, .campaign("\(carrier.token) salary account absence"))
            }
            let importSessionID = try requireValue(
                result.importSessionId,
                .campaign("\(carrier.token) import session")
            )
            state.importSessionBySourceDigest[carrier.sourceSHA256] = importSessionID
            state.duplicateAuthorityBySourceDigest[carrier.sourceSHA256] = try requireValue(
                prepared.fingerprintSet.duplicateAuthority,
                .campaign("\(carrier.token) duplicate authority")
            )
            if state.representedStatements.insert(carrier.logicalStatementKey).inserted {
                state.authoritativeByLogicalStatement[carrier.logicalStatementKey] = carrier
            }
        }
        try require(state.representedStatements.count == Self.expectedLogicalStatementCount,
                    .campaign("semantic statement coverage"))
        try require(state.importSessionBySourceDigest.count == Self.expectedCarrierCount,
                    .campaign("accepted source session coverage"))
        try require(state.duplicateAuthorityBySourceDigest.count == Self.expectedCarrierCount,
                    .campaign("accepted duplicate authority coverage"))

        let beforeReplay = try verifyFinalState(
            provider: runtime.provider,
            hydrator: runtime.hydrator,
            sqlite: runtime.sqlite,
            workspace: workspace,
            corpus: corpus,
            state: state,
            expectedAttemptCount: 127
        )
        let replayFolder = runtime.folder.appendingPathComponent("renamed-exact-replay", isDirectory: true)
        try FileManager.default.createDirectory(at: replayFolder, withIntermediateDirectories: true)
        for (index, carrier) in ordered.reversed().enumerated() {
            let replayURL = replayFolder.appendingPathComponent(
                "replay-\(index + 1)-\(carrier.sourceSHA256.prefix(12)).\(carrier.url.pathExtension.lowercased())"
            )
            try FileManager.default.copyItem(at: carrier.url, to: replayURL)
            try require(try sourceDigest(replayURL) == carrier.sourceSHA256,
                        .source("\(carrier.token) renamed replay bytes"))
            let replay = try await runtime.engine.prepareImport(from: replayURL)
            defer { runtime.engine.cancelPreparedImport(replay) }
            try verifyPrepared(replay, carrier: carrier)
            try require(replay.advisoryPreviousImport != nil,
                        .campaign("\(carrier.token) replay advisory"))
            let result = await runtime.engine.commitPreparedImport(replay)
            let authoritative = state.authoritativeByLogicalStatement[carrier.logicalStatementKey]?.sourceSHA256
                == carrier.sourceSHA256
            let expectedPriorRows = authoritative ? carrier.expectedTransactionCount : 0
            try require(
                !result.persisted && result.previousImport != nil
                    && result.transactionCount == expectedPriorRows
                    && result.previousImport?.transactionCount == expectedPriorRows
                    && result.hydrationOutcome == .notRequired
                    && result.recoveryRoute == .reviewRequired(.exactStatementDuplicate),
                .campaign("\(providerKind.rawValue)/\(order.rawValue)/\(carrier.token) exact replay")
            )
        }
        let afterReplay = try verifyFinalState(
            provider: runtime.provider,
            hydrator: runtime.hydrator,
            sqlite: runtime.sqlite,
            workspace: workspace,
            corpus: corpus,
            state: state,
            expectedAttemptCount: 254
        )
        try require(afterReplay == beforeReplay,
                    .campaign("\(providerKind.rawValue)/\(order.rawValue) replay residue"))

        guard let sqlite = runtime.sqlite, let databaseURL = runtime.databaseURL else {
            return beforeReplay
        }
        try sqlite.database.checkpointAndClose()
        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
        let reopenedStores = RuntimeStores()
        let reopenedHydrator = makeHydrator(
            provider: reopenedProvider,
            workspace: workspace,
            stores: reopenedStores
        )
        let stagedDigest = try verifyFinalState(
            provider: reopenedProvider,
            hydrator: reopenedHydrator,
            sqlite: reopenedSQLite,
            workspace: workspace,
            corpus: corpus,
            state: state,
            expectedAttemptCount: 254
        )
        try require(stagedDigest == beforeReplay,
                    .campaign("sqlite close/reopen semantic digest"))
        try require(
            reopenedStores.accounts.accounts.isEmpty
                && reopenedStores.transactions.transactions.isEmpty
                && reopenedStores.cards.snapshot.statements.isEmpty
                && reopenedStores.salaries.statements.isEmpty,
            .campaign("stage hydration published early")
        )
        let hydration = try reopenedHydrator.hydrateIfNeeded(forceRefresh: true)
        let expectedAccountCount = Set(corpus.carriers.compactMap(accountRoutingKey)).count
        try require(
            expectedAccountCount == 8
                && hydration.didHydrate && hydration.accountCount == expectedAccountCount
                && hydration.transactionCount == Self.expectedCanonicalTransactionCount
                && hydration.importSessionCount == Self.expectedCarrierCount
                && hydration.salaryStatementCount == 20
                && reopenedStores.accounts.accounts.count == expectedAccountCount
                && reopenedStores.transactions.transactions.count == Self.expectedCanonicalTransactionCount
                && reopenedStores.cards.snapshot.statements.count == 71
                && reopenedStores.salaries.statements.count == 20,
            .campaign("sqlite reopened published hydration")
        )
        try reopenedSQLite.database.checkpointAndClose()
        return stagedDigest
    }

    // MARK: Ordinary import runtime and deterministic routing

    private func makeRuntime(
        context: Context,
        workspace: String,
        providerKind: ProviderKind
    ) throws -> Runtime {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LedgerForge-GlobalAuthentic-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let databaseURL = folder.appendingPathComponent("acceptance.sqlite")
        let sqlite: SQLiteRepositoryProvider?
        let provider: DatabaseProvider
        switch providerKind {
        case .inMemory:
            sqlite = nil
            provider = DatabaseProvider(inMemory: true)
        case .sqlite:
            let opened = try SQLiteRepositoryProvider(path: databaseURL.path)
            sqlite = opened
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
        }
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, workspace: workspace, stores: stores)
        let engine = makeEngine(
            context: context,
            provider: provider,
            workspace: workspace,
            hydrator: hydrator,
            includeCredentials: true
        )
        return Runtime(
            provider: provider,
            engine: engine,
            hydrator: hydrator,
            stores: stores,
            sqlite: sqlite,
            databaseURL: providerKind == .sqlite ? databaseURL : nil,
            folder: folder
        )
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

    private func makeEngine(
        context: Context,
        provider: DatabaseProvider,
        workspace: String,
        hydrator: RepositoryStoreHydrator,
        includeCredentials: Bool
    ) -> ImportEngine {
        let passwords: [String: String] = includeCredentials ? [
            KeychainStatementPasswordCredentialStore.axisAppPDFScope: context.axisAppPassword,
            KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope: context.axisTraditionalPassword,
            Institution.hdfc.statementPasswordCredentialScope: context.hdfcPassword,
            Institution.cbq.statementPasswordCredentialScope: context.cbqPassword,
            Institution.amex.statementPasswordCredentialScope: context.amexPassword
        ] : [:]
        let credentials = InMemoryStatementPasswordCredentialStore(passwords: passwords)
        let passwordProvider = DefaultPasswordProvider(
            credentialStore: credentials,
            supportedInstitutionCodes: [
                Institution.axis.statementPasswordCredentialScope,
                Institution.hdfc.statementPasswordCredentialScope,
                Institution.cbq.statementPasswordCredentialScope,
                Institution.amex.statementPasswordCredentialScope
            ],
            challenge: { _ in nil }
        )
        return ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: passwordProvider
            ),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspace,
                    workspaceName: "Global authentic acceptance"
                )
            ),
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: { _ = try hydrator.stageHydration() },
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(
                stateProvider: { nil }
            )
        )
    }

    private func orderedCarriers(
        _ carriers: [Carrier],
        order: CampaignOrder
    ) -> [Carrier] {
        let chronological = carriers.sorted {
            ($0.chronologicalKey, $0.family.rawValue, $0.sourceSHA256)
                < ($1.chronologicalKey, $1.family.rawValue, $1.sourceSHA256)
        }
        switch order {
        case .chronological:
            return chronological
        case .reverse:
            return Array(chronological.reversed())
        case .deterministicMixed:
            var queues = Dictionary(grouping: chronological, by: \.family)
            var result: [Carrier] = []
            let familyOrder: [Family] = [
                .salary, .axisCard, .cbqBank, .hdfcBank, .amexCard, .axisBank, .cbqCard
            ]
            while result.count < chronological.count {
                for family in familyOrder {
                    guard var queue = queues[family], !queue.isEmpty else { continue }
                    let source = family == .cbqBank || family == .axisCard
                        ? queue.removeLast() : queue.removeFirst()
                    queues[family] = queue
                    result.append(source)
                }
            }
            return result
        }
    }

    private func accountRoutingKey(_ carrier: Carrier) -> String? {
        switch carrier.evidence {
        case .axisBank(let oracle):
            return "axis-bank|\(oracle.accountIdentifierSha256)"
        case .hdfcBank(let oracle):
            return "hdfc-bank|\(oracle.account)"
        case .cbqBank(let oracle):
            return "cbq-bank|\(oracle.maskedAccount)"
        case .axisCard:
            return "axis-card"
        case .cbqCard:
            return "cbq-card"
        case .amexCard:
            return "amex-card"
        case .salary:
            return nil
        }
    }

    private func accountChoice(
        prepared: PreparedImport,
        carrier: Carrier,
        supporting: Bool,
        state: RoutingState,
        provider: DatabaseProvider,
        workspace: String
    ) throws -> ImportAccountChoice? {
        guard let key = accountRoutingKey(carrier) else { return nil }
        guard let accountID = state.accountIDs[key] else {
            switch carrier.family {
            case .cbqCard, .amexCard:
                return .createNewCardLiabilityAccountAndInstrument
            default:
                return .createNewAccount
            }
        }
        switch carrier.family {
        case .cbqCard, .amexCard:
            return try explicitCardSectionChoice(
                document: prepared.financialDocument,
                accountID: accountID,
                provider: provider,
                workspace: workspace
            )
        case .hdfcBank:
            // HDFC's equivalent second physical representation can be confirmed
            // without an identity choice when the durable identifier is unique.
            return supporting ? nil : .useExistingAccount(accountId: accountID)
        default:
            return .useExistingAccount(accountId: accountID)
        }
    }

    private func explicitCardSectionChoice(
        document: FinancialDocument,
        accountID: String,
        provider: DatabaseProvider,
        workspace: String
    ) throws -> ImportAccountChoice {
        let evidence = try requireValue(
            document.cardStatementEvidence,
            .campaign("card instrument evidence")
        )
        let snapshot = try provider.cardRepo.snapshot(workspaceId: workspace)
        let choices = try Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map { section in
            let sourceValue = try requireValue(
                section.sourceIdentityObservations.first?.value,
                .campaign("card instrument identity")
            )
            let instrumentIDs = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                guard observation.sourceValue == sourceValue,
                      let durableSection = snapshot.sections.first(where: {
                          $0.id == observation.cardStatementSectionId
                      }),
                      snapshot.instruments.contains(where: {
                          $0.id == durableSection.instrumentId && $0.liabilityAccountId == accountID
                      }) else { return nil }
                return durableSection.instrumentId
            })
            try require(instrumentIDs.count <= 1, .campaign("ambiguous card instrument identity"))
            let choice: ImportCardInstrumentChoice = instrumentIDs.first.map {
                .reuseExistingInstrument(instrumentId: $0)
            } ?? .createNewInstrument()
            return (section.documentScopedSectionID, choice)
        })
        return .useExistingCardLiabilityAccountSections(
            accountId: accountID,
            sectionChoices: choices
        )
    }

    private func verifyNoAcceptedResidue(
        _ provider: DatabaseProvider,
        workspace: String,
        hydrator: RepositoryStoreHydrator
    ) throws {
        let staged = try hydrator.stageHydration()
        let card = try provider.cardRepo.snapshot(workspaceId: workspace)
        let salary = try provider.salaryRepo.snapshot(workspaceId: workspace)
        try require(
            try provider.accountRepo.accounts(workspaceId: workspace).isEmpty
                && provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty
                && provider.importSessionRepo.importAttempts(workspaceId: workspace).isEmpty
                && provider.importSessionRepo.statementFinancialProjections(workspaceId: workspace).isEmpty
                && provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspace).isEmpty
                && provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace).isEmpty
                && card.statements.isEmpty && card.transactionEvidence.isEmpty
                && salary.statements.isEmpty
                && staged.accounts.isEmpty && staged.transactions.isEmpty
                && staged.importSessions.isEmpty && staged.importAttempts.isEmpty
                && staged.cardSnapshot.statements.isEmpty
                && staged.salaryStatements.isEmpty,
            .campaign("cancel/password failure accepted residue")
        )
    }

    // MARK: Accepted repository and hydration graph

    private func verifyFinalState(
        provider: DatabaseProvider,
        hydrator: RepositoryStoreHydrator,
        sqlite: SQLiteRepositoryProvider?,
        workspace: String,
        corpus: Corpus,
        state: RoutingState,
        expectedAttemptCount: Int
    ) throws -> String {
        let accounts = try provider.accountRepo.accounts(workspaceId: workspace)
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspace)
        let bankProjections = try provider.importSessionRepo.statementFinancialProjections(
            workspaceId: workspace
        )
        let bankGroups = try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspace)
        let bankMembers = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspace)
        let cbqObservations = try provider.importSessionRepo.cbqSourceObservationSummaries(
            workspaceId: workspace
        )
        let card = try provider.cardRepo.snapshot(workspaceId: workspace)
        let salary = try provider.salaryRepo.snapshot(workspaceId: workspace)
        let hydrated = try hydrator.stageHydration()

        let graph = AcceptedGraph(
            accounts: accounts.count,
            transactions: transactions.count,
            transactionIDs: Set(transactions.map(\.id)),
            importSessions: hydrated.importSessions.count,
            salaryStatements: salary.statements.count,
            salaryComponents: salary.statements.reduce(0) { $0 + $1.components.count },
            cardStatements: card.statements.count,
            cardInstruments: card.instruments.count,
            cardSections: card.sections.count,
            cardTransactionEvidence: card.transactionEvidence.count,
            cardSemanticProjections: card.semanticProjections.count,
            cardSemanticGroups: card.semanticGroups.count,
            cardSemanticMembers: card.semanticMembers.count,
            bankProjections: bankProjections.count,
            bankGroups: bankGroups.count,
            bankMembers: bankMembers.count,
            cbqBankObservations: cbqObservations.count
        )
        let expectedAccountCount = Set(corpus.carriers.compactMap(accountRoutingKey)).count
        try require(
            expectedAccountCount == 8
                && graph.accounts == expectedAccountCount
                && graph.transactions == Self.expectedCanonicalTransactionCount
                && graph.importSessions == Self.expectedCarrierCount
                && graph.salaryStatements == 20
                && graph.salaryComponents == 258
                && graph.cardStatements == 71
                && graph.cardInstruments == 5
                && graph.cardSections == 69
                && graph.cardTransactionEvidence == 2_631
                && graph.cardSemanticProjections == 52
                && graph.cardSemanticGroups == 38
                && graph.cardSemanticMembers == 52
                && graph.bankProjections == 17
                && graph.bankGroups == 7
                && graph.bankMembers == 17
                && graph.cbqBankObservations == 19,
            .campaign("complete accepted graph cardinality")
        )
        try require(
            attempts.count == expectedAttemptCount
                && attempts.filter {
                    $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue
                }.count == 84
                && attempts.filter {
                    $0.outcomeCode == ImportAttemptOutcome.cbqSourceOverlapCommitted.rawValue
                }.count == 19
                && attempts.filter {
                    $0.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue
                }.count == 24
                && attempts.filter {
                    $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue
                }.count == expectedAttemptCount - Self.expectedCarrierCount,
            .campaign("accepted/replayed attempt outcomes")
        )
        try require(
            bankProjections.reduce(0) { $0 + $1.projection.eventCount } == 876
                && bankProjections.allSatisfy { $0.projection.isValid() }
                && bankMembers.filter { $0.role == .authoritative }.count == 7
                && bankMembers.filter { $0.role == .supporting }.count == 10
                && cbqObservations.reduce(0) { $0 + $1.sourceRowCount } == 187
                && cbqObservations.reduce(0) { $0 + $1.importedTransactionCount } == 187
                && cbqObservations.reduce(0) { $0 + $1.representedTransactionCount } == 0
                && cbqObservations.reduce(0) { $0 + $1.transactionObservationCount } == 187
                && card.semanticProjections.reduce(0) { $0 + $1.eventCount } == 3_871
                && card.semanticMembers.filter { $0.role == .authoritative }.count == 38
                && card.semanticMembers.filter { $0.role == .supporting }.count == 14,
            .campaign("source representation graph cardinality")
        )
        try require(
            hydrated.accounts.count == accounts.count
                && hydrated.transactions.count == transactions.count
                && Set(hydrated.transactions.compactMap(\.repositoryTransactionId)) == graph.transactionIDs
                && hydrated.importSessions.count == Self.expectedCarrierCount
                && hydrated.importAttempts.count == expectedAttemptCount
                && hydrated.cardSnapshot.statements.count == card.statements.count
                && hydrated.cardSnapshot.instruments.count == card.instruments.count
                && hydrated.cardSnapshot.transactionEvidence.count == card.transactionEvidence.count
                && hydrated.salaryStatements.count == salary.statements.count
                && hydrated.categorySnapshot.categories.isEmpty
                && hydrated.categorySnapshot.assignments.isEmpty
                && hydrated.fundingPlans.isEmpty,
            .campaign("repository hydrator reconstruction cardinality")
        )

        let documentBySession = try sourceDocumentIDs(
            bankProjections: bankProjections,
            cbqObservations: cbqObservations,
            card: card,
            salary: salary
        )
        try require(documentBySession.count == Self.expectedCarrierCount,
                    .campaign("source document relationship coverage"))
        try verifySQLiteSourceFingerprints(
            sqlite: sqlite,
            corpus: corpus,
            state: state,
            documentBySession: documentBySession
        )
        try verifySourceDocumentBindings(
            provider: provider,
            corpus: corpus,
            state: state,
            documentBySession: documentBySession
        )
        try verifyAccountOwnership(
            durableTransactions: transactions,
            hydrated: hydrated,
            bankProjections: bankProjections,
            card: card,
            corpus: corpus,
            state: state
        )
        try verifyAxisUPIDurableOwners(provider: provider, workspace: workspace, state: state)
        try verifyBankProjectionSources(
            bankProjections,
            corpus: corpus,
            state: state
        )
        try verifyCardSourcePersistence(
            card,
            hydrated: hydrated,
            corpus: corpus,
            state: state
        )
        try verifySalaryPersistence(
            salary,
            hydrated: hydrated,
            corpus: corpus,
            state: state
        )
        try verifyHydratedCanonicalSources(
            hydrated,
            corpus: corpus,
            state: state
        )
        return try acceptedSemanticDigest(
            hydrated: hydrated,
            bankProjections: bankProjections,
            cbqObservations: cbqObservations,
            card: card,
            salary: salary,
            corpus: corpus,
            state: state
        )
    }

    private func sourceDocumentIDs(
        bankProjections: [StatementFinancialProjectionRecordDTO],
        cbqObservations: [CBQSourceObservationSummaryDTO],
        card: CardRepositorySnapshotDTO,
        salary: SalaryRepositorySnapshotDTO
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        let pairs = bankProjections.map { ($0.importSessionID, $0.documentID) }
            + cbqObservations.map { ($0.importSessionId, $0.documentId) }
            + card.statements.map { ($0.importSessionId, $0.documentId) }
            + salary.statements.map { ($0.importSessionId, $0.documentId) }
        for (session, document) in pairs {
            try require(result[session] == nil, .campaign("duplicate source document relationship"))
            result[session] = document
        }
        return result
    }

    private func verifySQLiteSourceFingerprints(
        sqlite: SQLiteRepositoryProvider?,
        corpus: Corpus,
        state: RoutingState,
        documentBySession: [String: String]
    ) throws {
        guard let sqlite else { return }
        let rows = try sqlite.database.query(
            sql: """
            SELECT f.fingerprint, f.is_duplicate_authority, f.document_id,
                   f.import_session_id, d.size_bytes
            FROM document_fingerprints f
            JOIN documents d ON d.id = f.document_id
            WHERE f.algorithm = ?
            ORDER BY f.fingerprint;
            """,
            params: [DocumentFingerprintDTO.sourceBytesSHA256Algorithm]
        ) {
            (
                fingerprint: $0.string(at: 0) ?? "",
                isAuthority: $0.bool(at: 1),
                documentID: $0.string(at: 2) ?? "",
                importSessionID: $0.string(at: 3) ?? "",
                sizeBytes: $0.int64(at: 4) ?? -1
            )
        }
        try require(rows.count == Self.expectedCarrierCount,
                    .campaign("SQLite complete source-byte fingerprint count"))
        var byFingerprint: [String: (
            isAuthority: Bool,
            documentID: String,
            importSessionID: String,
            sizeBytes: Int64
        )] = [:]
        for row in rows {
            try require(byFingerprint.updateValue(
                (row.isAuthority, row.documentID, row.importSessionID, row.sizeBytes),
                forKey: row.fingerprint
            ) == nil, .campaign("SQLite unique source-byte fingerprint"))
        }
        for carrier in corpus.carriers {
            let stored = try requireValue(
                byFingerprint[carrier.sourceSHA256],
                .campaign("\(carrier.token) SQLite source-byte fingerprint")
            )
            let expectedSession = try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("\(carrier.token) SQLite source session")
            )
            let expectedDocument = try requireValue(
                documentBySession[expectedSession],
                .campaign("\(carrier.token) SQLite source document")
            )
            try require(
                stored.importSessionID == expectedSession
                    && stored.documentID == expectedDocument
                    && stored.sizeBytes == Int64(carrier.sourceSize)
                    && stored.isAuthority == (carrier.url.pathExtension.lowercased() != "csv"),
                .campaign("\(carrier.token) SQLite source-byte binding")
            )
        }
    }

    private func verifyAccountOwnership(
        durableTransactions: [TransactionDTO],
        hydrated: RepositoryRuntimeSnapshot,
        bankProjections: [StatementFinancialProjectionRecordDTO],
        card: CardRepositorySnapshotDTO,
        corpus: Corpus,
        state: RoutingState
    ) throws {
        let expectedAccountIDs = Set(state.accountIDs.values)
        try require(
            expectedAccountIDs.count == 8
                && Set(hydrated.accounts.compactMap(\.repositoryAccountId)) == expectedAccountIDs,
            .campaign("complete hydrated account identity set")
        )
        let sourceBySession = try carriersByImportSession(corpus: corpus, state: state)
        for projection in bankProjections {
            let carrier = try requireValue(
                sourceBySession[projection.importSessionID],
                .campaign("bank projection account source")
            )
            let route = try requireValue(accountRoutingKey(carrier),
                                         .campaign("bank projection account route"))
            let expectedAccountID = try requireValue(
                state.accountIDs[route],
                .campaign("bank projection resolved account")
            )
            try require(
                projection.accountID == expectedAccountID,
                .campaign("\(carrier.token) bank projection account binding")
            )
        }
        for statement in card.statements {
            let carrier = try requireValue(
                sourceBySession[statement.importSessionId],
                .campaign("card statement account source")
            )
            let route = try requireValue(accountRoutingKey(carrier),
                                         .campaign("card statement account route"))
            let expectedAccountID = try requireValue(
                state.accountIDs[route],
                .campaign("card statement resolved account")
            )
            try require(
                statement.liabilityAccountId == expectedAccountID,
                .campaign("\(carrier.token) card statement account binding")
            )
        }

        var coveredDurableIDs = Set<String>()
        var coveredHydratedIDs = Set<String>()
        for carrier in state.authoritativeByLogicalStatement.values {
            guard let route = accountRoutingKey(carrier) else { continue }
            let expectedAccountID = try requireValue(
                state.accountIDs[route],
                .campaign("\(carrier.token) canonical account route")
            )
            let session = try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("\(carrier.token) canonical account session")
            )
            let durable = durableTransactions.filter { $0.importSessionId == session }
            let visible = hydrated.transactions.filter { $0.repositoryImportSessionId == session }
            try require(
                durable.count == carrier.expectedTransactionCount
                    && durable.allSatisfy { $0.accountId == expectedAccountID }
                    && visible.count == carrier.expectedTransactionCount
                    && visible.allSatisfy { $0.repositoryAccountId == expectedAccountID },
                .campaign("\(carrier.token) canonical transaction account binding")
            )
            for transaction in durable {
                try require(coveredDurableIDs.insert(transaction.id).inserted,
                            .campaign("canonical durable ownership overlap"))
            }
            for transaction in visible {
                let identifier = try requireValue(
                    transaction.repositoryTransactionId,
                    .campaign("canonical hydrated transaction identity")
                )
                try require(coveredHydratedIDs.insert(identifier).inserted,
                            .campaign("canonical hydrated ownership overlap"))
            }
        }
        let allDurableIDs = Set(durableTransactions.map(\.id))
        let allHydratedIDs = Set(hydrated.transactions.compactMap(\.repositoryTransactionId))
        try require(
            coveredDurableIDs == allDurableIDs
                && coveredHydratedIDs == allDurableIDs
                && allHydratedIDs == allDurableIDs
                && allDurableIDs.count == Self.expectedCanonicalTransactionCount,
            .campaign("complete canonical transaction account ownership")
        )
    }

    private func verifySourceDocumentBindings(
        provider: DatabaseProvider,
        corpus: Corpus,
        state: RoutingState,
        documentBySession: [String: String]
    ) throws {
        for carrier in corpus.carriers {
            let sessionID = try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("\(carrier.token) expected source session")
            )
            let prior = try requireValue(
                provider.importSessionRepo.priorImportedStatement(
                    algorithm: try requireValue(
                        state.duplicateAuthorityBySourceDigest[carrier.sourceSHA256],
                        .campaign("\(carrier.token) duplicate authority lookup")
                    ).algorithm,
                    fingerprint: try requireValue(
                        state.duplicateAuthorityBySourceDigest[carrier.sourceSHA256],
                        .campaign("\(carrier.token) duplicate authority lookup")
                    ).digest
                ),
                .campaign("\(carrier.token) durable duplicate authority")
            )
            let documentID = try requireValue(
                documentBySession[sessionID],
                .campaign("\(carrier.token) document relationship")
            )
            let document = try requireValue(
                provider.importSessionRepo.importedDocument(id: documentID),
                .campaign("\(carrier.token) imported document")
            )
            let session = try requireValue(
                provider.importSessionRepo.importSession(id: sessionID),
                .campaign("\(carrier.token) import session")
            )
            let authoritative = state.authoritativeByLogicalStatement[
                carrier.logicalStatementKey
            ]?.sourceSHA256 == carrier.sourceSHA256
            try require(
                prior.importSessionId == sessionID
                    && prior.transactionCount == (authoritative ? carrier.expectedTransactionCount : 0)
                    && document.workspaceId == session.workspaceId
                    && document.importSessionId == sessionID
                    && document.filename == carrier.url.lastPathComponent
                    && document.sizeBytes == Int64(carrier.sourceSize)
                    && session.completedAtISO != nil
                    && session.validationStatus == "passed",
                .campaign("\(carrier.token) durable source binding")
            )
        }
    }

    private func verifyAxisUPIDurableOwners(
        provider: DatabaseProvider,
        workspace: String,
        state: RoutingState
    ) throws {
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        var expectedOwners: [TransactionEventIdentityKeyDTO: (
            importSessionID: String,
            accountID: String,
            transactionID: String,
            documentID: String
        )] = [:]
        for carrier in state.authoritativeByLogicalStatement.values {
            guard case .axisBank(let oracle) = carrier.evidence else { continue }
            let routingKey = try requireValue(accountRoutingKey(carrier),
                                              .campaign("Axis UPI account route"))
            let accountID = try requireValue(state.accountIDs[routingKey],
                                             .campaign("Axis UPI durable account"))
            let sessionID = try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("Axis UPI authoritative session")
            )
            let sourceTransactions = transactions.filter {
                $0.importSessionId == sessionID
            }.sorted {
                ($0.rawRows.first?.sourceOrdinal ?? Int.max)
                    < ($1.rawRows.first?.sourceOrdinal ?? Int.max)
            }
            try require(sourceTransactions.count == oracle.rows.count,
                        .campaign("Axis UPI authoritative transaction count"))
            for (index, row) in oracle.rows.enumerated() {
                let components = (row.upiOperation, row.upiReference,
                                  row.upiReferenceSha256, row.upiSubtype)
                if components == (nil, nil, nil, nil) { continue }
                let transaction = sourceTransactions[index]
                let operation = try requireValue(row.upiOperation, .oracle("Axis UPI operation"))
                let reference = try requireValue(row.upiReference, .oracle("Axis UPI reference"))
                let referenceSHA = try requireValue(row.upiReferenceSha256,
                                                    .oracle("Axis UPI reference digest"))
                let subtype = try requireValue(row.upiSubtype, .oracle("Axis UPI subtype"))
                try require(
                    ["p2a", "p2m"].contains(operation)
                        && reference.utf8.count == 12
                        && reference.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
                        && sha256(Data(reference.utf8)) == referenceSHA
                        && ["posting", "credit-adjustment"].contains(subtype)
                        && row.sourceOrder == index + 1
                        && transaction.accountId == accountID
                        && transaction.importSessionId == sessionID,
                    .oracle("Axis UPI typed source evidence")
                )
                let algorithm = TransactionEventIdentity.algorithm
                let payload = [algorithm, accountID, TransactionEventIdentity.family,
                               operation, reference, subtype]
                    .map { "\($0.utf8.count):\($0)" }.joined()
                let key = TransactionEventIdentityKeyDTO(
                    algorithm: algorithm,
                    digest: sha256(Data(payload.utf8))
                )
                let documentID = try requireValue(
                    transaction.documentId,
                    .campaign("Axis UPI authoritative document")
                )
                try require(expectedOwners.updateValue(
                    (sessionID, accountID, transaction.id, documentID),
                    forKey: key
                ) == nil,
                            .campaign("duplicate Axis UPI identity"))
            }
        }
        try require(expectedOwners.count == 120,
                    .campaign("complete authentic Axis UPI identity count"))
        let actual = try provider.importSessionRepo.transactionEventOwners(keys: Set(expectedOwners.keys))
        try require(actual.count == expectedOwners.count,
                    .campaign("durable Axis UPI owner count"))
        for (key, expected) in expectedOwners {
            let owner = try requireValue(actual[key], .campaign("durable Axis UPI owner"))
            try require(
                owner.importSessionId == expected.importSessionID
                    && owner.accountId == expected.accountID
                    && owner.transactionId == expected.transactionID
                    && owner.documentId == expected.documentID,
                .campaign("durable Axis UPI owner relationship")
            )
        }
    }

    private func carriersByImportSession(
        corpus: Corpus,
        state: RoutingState
    ) throws -> [String: Carrier] {
        var result: [String: Carrier] = [:]
        for carrier in corpus.carriers {
            let session = try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("\(carrier.token) session lookup")
            )
            try require(result[session] == nil, .campaign("duplicate source import session"))
            result[session] = carrier
        }
        return result
    }

    private func verifyBankProjectionSources(
        _ records: [StatementFinancialProjectionRecordDTO],
        corpus: Corpus,
        state: RoutingState
    ) throws {
        let sourceBySession = try carriersByImportSession(corpus: corpus, state: state)
        for record in records {
            let carrier = try requireValue(
                sourceBySession[record.importSessionID],
                .campaign("bank projection source session")
            )
            let projection = record.projection
            try require(projection.eventCount == carrier.expectedTransactionCount,
                        .campaign("\(carrier.token) bank projection row count"))
            switch carrier.evidence {
            case .axisBank(let oracle):
                try require(
                    projection.institutionCode == "axis"
                        && projection.statementFamilyCode == "axis.bank-account"
                        && projection.sourceFormatCode == oracle.format
                        && projection.statementStartDateISO == oracle.periodStart
                        && projection.statementEndDateISO == oracle.periodEnd
                        && projection.nativeCurrency == "INR"
                        && decimal(projection.openingBalanceDecimal) == decimal(oracle.controls.openingBalance)
                        && decimal(projection.closingBalanceDecimal) == decimal(oracle.controls.closingBalance)
                        && decimal(projection.debitTotalDecimal) == decimal(oracle.controls.debitTotal)
                        && decimal(projection.creditTotalDecimal) == decimal(oracle.controls.creditTotal),
                    .campaign("\(carrier.token) Axis-bank durable controls")
                )
                for (index, pair) in zip(projection.events, oracle.rows).enumerated() {
                    let event = pair.0
                    let row = pair.1
                    try require(
                        event.ordinal == index + 1
                            && event.statementDateISO == row.date
                            && event.valueDateISO == nil
                            && event.direction == row.direction
                            && decimal(event.signedAmountDecimal) == decimal(row.signedAmount)
                            && decimal(event.runningBalanceDecimal) == decimal(row.balance)
                            && event.reference.map { sha256(Data($0.utf8)) }
                                == row.chequeReferenceSha256,
                        .campaign("\(carrier.token) Axis-bank projection row \(index + 1)")
                    )
                }
            case .hdfcBank(let oracle):
                try require(
                    projection.institutionCode == "hdfc"
                        && projection.statementFamilyCode == "hdfc.bank-account"
                        && projection.sourceFormatCode
                            == (oracle.carrier.lowercased().hasSuffix(".pdf") ? "pdf" : "xls")
                        && projection.statementStartDateISO == hdfcDate(oracle.periodStart).canonical
                        && projection.statementEndDateISO == hdfcDate(oracle.periodEnd).canonical
                        && projection.nativeCurrency == oracle.currency
                        && decimal(projection.openingBalanceDecimal) == decimal(oracle.summary.openingBalance)
                        && decimal(projection.closingBalanceDecimal) == decimal(oracle.summary.closingBalance)
                        && decimal(projection.debitTotalDecimal) == decimal(oracle.summary.debits)
                        && decimal(projection.creditTotalDecimal) == decimal(oracle.summary.credits),
                    .campaign("\(carrier.token) HDFC durable controls")
                )
                for (index, pair) in zip(projection.events, oracle.rows).enumerated() {
                    let event = pair.0
                    let row = pair.1
                    try require(
                        event.ordinal == index + 1
                            && event.statementDateISO == hdfcDate(row.date).canonical
                            && event.valueDateISO == hdfcDate(row.valueDate).canonical
                            && event.direction == (row.withdrawal.isEmpty ? "credit" : "debit")
                            && decimal(event.signedAmountDecimal)
                                == (row.withdrawal.isEmpty ? decimal(row.deposit) : -decimal(row.withdrawal))
                            && decimal(event.runningBalanceDecimal) == decimal(row.closing)
                            && event.reference == (row.reference.isEmpty ? nil : row.reference),
                        .campaign("\(carrier.token) HDFC projection row \(index + 1)")
                    )
                }
            default:
                throw AcceptanceError.campaign("non-bank source owns bank projection")
            }
        }
        let projectedSessions = Set(records.map(\.importSessionID))
        let expectedSessions = Set(try corpus.carriers.compactMap { carrier -> String? in
            guard carrier.family == .axisBank || carrier.family == .hdfcBank else { return nil }
            return try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("bank source session")
            )
        })
        try require(projectedSessions == expectedSessions,
                    .campaign("all bank source projections persisted"))
    }

    private func verifyCardSourcePersistence(
        _ card: CardRepositorySnapshotDTO,
        hydrated: RepositoryRuntimeSnapshot,
        corpus: Corpus,
        state: RoutingState
    ) throws {
        let sourceBySession = try carriersByImportSession(corpus: corpus, state: state)
        for statement in card.statements {
            let carrier = try requireValue(
                sourceBySession[statement.importSessionId],
                .campaign("card statement source session")
            )
            let summaries = card.summaryComponents.filter { $0.cardStatementId == statement.id }
            let sections = card.sections.filter { $0.cardStatementId == statement.id }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            let annotations = card.transactionEvidence.filter { $0.cardStatementId == statement.id }
            try require(statement.sourceRowCount == carrier.expectedTransactionCount,
                        .campaign("\(carrier.token) durable card source row count"))
            switch carrier.evidence {
            case .axisCard(let oracle):
                try require(
                    statement.parserProfileId == (oracle.format == "xlsx"
                        ? AxisCreditCardXLSXParser.profileID : AxisCreditCardPDFParser.profileID)
                        && statement.parserProfileVersion == "1"
                        && statement.statementCurrency == "INR"
                        && statement.statementStartDateISO == oracle.controls["statement_period_start"]
                        && statement.statementEndDateISO == oracle.controls["statement_period_end"]
                        && statement.selectedStatementMonthISO == oracle.controls["selected_statement_month"]
                        && sections.isEmpty,
                    .campaign("\(carrier.token) Axis-card durable statement controls")
                )
                try verifySummaryMoney(
                    summaries,
                    code: "previous_balance",
                    currency: "INR",
                    amount: try requireValue(
                        oracle.controls["opening_balance"],
                        .oracle("\(carrier.token) Axis opening balance")
                    ),
                    token: carrier.token
                )
                try verifySummaryMoney(
                    summaries,
                    code: "axis_total_payment_due",
                    currency: "INR",
                    amount: try requireValue(
                        oracle.controls["total_payment_due"],
                        .oracle("\(carrier.token) Axis payment due")
                    ),
                    token: carrier.token
                )
                try require(
                    summaries.first { $0.componentCode == "due_date" }?.dateISO
                        == oracle.controls["payment_due_date"],
                    .campaign("\(carrier.token) Axis-card due date")
                )
                let projection = try requireValue(
                    card.semanticProjections.first { $0.cardStatementId == statement.id },
                    .campaign("\(carrier.token) Axis-card semantic projection")
                )
                let projectionMember = try requireValue(
                    card.semanticMembers.first { $0.projectionId == projection.id },
                    .campaign("\(carrier.token) Axis-card semantic member")
                )
                try verifyAxisCardProjection(
                    projection,
                    annotations: annotations,
                    isAuthoritative: projectionMember.role == .authoritative,
                    oracle: oracle,
                    token: carrier.token
                )
            case .cbqCard(let oracle):
                try require(
                    statement.parserProfileId == CBQCreditCardPDFParser.profileID
                        && statement.parserProfileVersion == CBQCreditCardPDFParser.profileVersion
                        && statement.statementDateISO == oracle.statementDate.canonical
                        && statement.statementStartDateISO == oracle.period.start.canonical
                        && statement.statementEndDateISO == oracle.period.end.canonical
                        && statement.statementCurrency == "QAR"
                        && card.semanticProjections.allSatisfy { $0.cardStatementId != statement.id }
                        && annotations.count == oracle.rows.count,
                    .campaign("\(carrier.token) CBQ-card durable statement controls")
                )
                try require(
                    summaries.first { $0.componentCode == "due_date" }?.dateISO
                        == oracle.dueDate.canonical,
                    .campaign("\(carrier.token) CBQ-card due date")
                )
                for (code, money) in oracle.summary {
                    try verifySummaryMoney(
                        summaries,
                        code: code,
                        money: money,
                        token: carrier.token
                    )
                }
                try require(sections.count == oracle.sections.count,
                            .campaign("\(carrier.token) CBQ-card durable section count"))
                for (actual, expected) in zip(sections, oracle.sections) {
                    let sourceCard = card.sectionObservations.first {
                        $0.cardStatementSectionId == actual.id
                            && $0.observationKind
                                == CardSourceIdentityObservationKind.cbqInstrumentMaskedCardNumber.rawValue
                    }?.sourceValue
                    try require(
                        actual.sourceOrdinal == expected.sourceOrdinal
                            && actual.holderLabel == expected.holderLabel
                            && sourceCard == expected.card
                            && moneyFieldsMatch(
                                currency: actual.signedTotalCurrency,
                                minor: actual.signedTotalMinor,
                                decimal: actual.signedTotalDecimal,
                                money: expected.total
                            ),
                        .campaign("\(carrier.token) CBQ-card durable section \(expected.sourceOrdinal)")
                    )
                }
            case .amexCard(let oracle):
                try require(
                    statement.parserProfileId == AmericanExpressCreditCardPDFParser.profileID
                        && statement.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion
                        && statement.statementDateISO == oracle.statementDate
                        && statement.statementStartDateISO == oracle.statementPeriod.start
                        && statement.statementEndDateISO == oracle.statementPeriod.end
                        && statement.statementCurrency == oracle.nativeCurrency,
                    .campaign("\(carrier.token) Amex durable statement controls")
                )
                try require(
                    summaries.first { $0.componentCode == "due_date" }?.dateISO == oracle.dueDate,
                    .campaign("\(carrier.token) Amex due date")
                )
                for pair in [
                    ("previous_balance", oracle.summary.previousBalance),
                    ("new_credits", oracle.summary.newCredits),
                    ("new_debits", oracle.summary.newDebits),
                    ("new_balance", oracle.summary.newBalance)
                ] {
                    try verifySummaryMoney(summaries, code: pair.0, source: pair.1, token: carrier.token)
                }
                try require(sections.count == oracle.sections.count,
                            .campaign("\(carrier.token) Amex durable section count"))
                for (actual, expected) in zip(sections, oracle.sections) {
                    let account = card.sectionObservations.first {
                        $0.cardStatementSectionId == actual.id
                            && $0.observationKind == "amex_card_account_number"
                    }?.sourceValue
                    try require(
                        account == expected.accountMasked
                            && expected.accountKeyHash == sha256(Data(expected.accountMasked.utf8))
                            && moneyFieldsMatch(
                                currency: actual.signedTotalCurrency,
                                minor: actual.signedTotalMinor,
                                decimal: actual.signedTotalDecimal,
                                source: expected.oracleCalculated.netActivity
                            ),
                        .campaign("\(carrier.token) Amex durable section")
                    )
                }
                let projection = try requireValue(
                    card.semanticProjections.first { $0.cardStatementId == statement.id },
                    .campaign("\(carrier.token) Amex semantic projection")
                )
                try verifyAmexProjection(
                    projection,
                    annotations: annotations,
                    oracle: oracle,
                    token: carrier.token
                )
            default:
                throw AcceptanceError.campaign("non-card source owns card statement")
            }
        }
        let statementSessions = Set(card.statements.map(\.importSessionId))
        let expectedSessions = Set(try corpus.carriers.compactMap { carrier -> String? in
            guard [.axisCard, .cbqCard, .amexCard].contains(carrier.family) else { return nil }
            return try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("card source session")
            )
        })
        try require(statementSessions == expectedSessions,
                    .campaign("all card source statements persisted"))
    }

    private func verifyAxisCardProjection(
        _ projection: CardStatementSemanticProjectionRecordDTO,
        annotations: [CardTransactionEvidenceDTO],
        isAuthoritative: Bool,
        oracle: AxisCardRecord,
        token: String
    ) throws {
        let events = projection.events.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        try require(
            projection.algorithm == CardStatementSemanticProjectionDTO.axisMultisetAlgorithm
                && projection.institutionCode == "Axis Bank"
                && projection.statementFamilyCode == "axis.credit-card@1"
                && projection.parserProfileId == (oracle.format == "xlsx"
                    ? AxisCreditCardXLSXParser.profileID : AxisCreditCardPDFParser.profileID)
                && projection.parserProfileVersion == "1"
                && projection.nativeCurrency == "INR"
                && projection.sectionCount == 0
                && events.count == oracle.rows.count
                && annotations.count == (isAuthoritative ? oracle.rows.count : 0),
            .campaign("\(token) Axis-card projection envelope")
        )
        let annotationByTransaction = Dictionary(uniqueKeysWithValues: annotations.map {
            ($0.transactionId, $0)
        })
        try require(
            zip(events, events.dropFirst()).allSatisfy {
                $0.0.sourceOrdinal > 0 && $0.0.sourceOrdinal < $0.1.sourceOrdinal
            } && events.last.map { $0.sourceOrdinal > 0 } != false,
            .campaign("\(token) Axis-card source ordering")
        )
        for (index, pair) in zip(events, oracle.rows).enumerated() {
            let event = pair.0
            let row = pair.1
            let expectedSigned = row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                ? -decimal(row.amount) : decimal(row.amount)
            let expectedOriginal = row.originalMerchantMoney.map {
                row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                    ? -decimal($0.amount ?? "") : decimal($0.amount ?? "")
            }
            try require(
                event.financialDateISO == row.date
                    && event.financialDateRoleCode == FinancialDateRole.transactionDate.rawValue
                    && event.liabilityEffectCode == row.effect
                    && event.postedCurrency == "INR"
                    && decimal(event.postedAmountDecimal) == expectedSigned
                    && event.originalCurrency == row.originalMerchantMoney?.currency
                    && event.originalAmountDecimal.map(decimal) == expectedOriginal
                    && event.sourceReference == row.reference
                    && event.rowScopeCode == CardTransactionScope.accountLevel.persistenceCode
                    && event.documentScopedSectionId == nil
                    && event.documentSectionOrdinal == nil
                    && (!isAuthoritative || event.canonicalTransactionId != nil),
                .campaign("\(token) Axis-card projection row \(index + 1)")
            )
            if isAuthoritative {
                let annotation = try requireValue(
                    event.canonicalTransactionId.flatMap { annotationByTransaction[$0] },
                    .campaign("\(token) Axis-card projection annotation \(index + 1)")
                )
                try require(
                    annotation.liabilityEffectCode == row.effect
                        && annotation.originalCurrency == event.originalCurrency
                        && annotation.originalAmountDecimal == event.originalAmountDecimal,
                    .campaign("\(token) Axis-card authoritative evidence \(index + 1)")
                )
            }
        }
    }

    private func verifyAmexProjection(
        _ projection: CardStatementSemanticProjectionRecordDTO,
        annotations: [CardTransactionEvidenceDTO],
        oracle: AmexSource,
        token: String
    ) throws {
        let events = projection.events.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        try require(
            projection.algorithm == CardStatementSemanticProjectionDTO.amexAlgorithm
                && projection.institutionCode == "American Express"
                && projection.statementFamilyCode == "amex.credit-card.pdf@1"
                && projection.parserProfileId == AmericanExpressCreditCardPDFParser.profileID
                && projection.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion
                && projection.statementDateISO == oracle.statementDate
                && projection.statementStartDateISO == oracle.statementPeriod.start
                && projection.statementEndDateISO == oracle.statementPeriod.end
                && projection.nativeCurrency == oracle.nativeCurrency
                && events.count == oracle.rows.count
                && annotations.count == oracle.rows.count,
            .campaign("\(token) Amex projection envelope")
        )
        let annotationByTransaction = Dictionary(uniqueKeysWithValues: annotations.map {
            ($0.transactionId, $0)
        })
        for (index, pair) in zip(events, oracle.rows).enumerated() {
            let event = pair.0
            let row = pair.1
            let effect: CardLiabilityEffect = row.creditDebitLiabilityDirection == "liability_decrease"
                ? .decreasesAmountOwed : .increasesAmountOwed
            let posted = signed(row.postedNativeMoney, effect: effect)
            let original = row.originalForeignMoney.map { signed($0, effect: effect) }
            let annotation = try requireValue(
                event.canonicalTransactionId.flatMap { annotationByTransaction[$0] },
                .campaign("\(token) Amex projection annotation \(index + 1)")
            )
            try require(
                event.sourceOrdinal == row.globalSourceOrdinal
                    && event.financialDateISO == row.postingDate
                    && event.financialDateRoleCode == FinancialDateRole.postingDate.rawValue
                    && event.sourceTransactionDateISO == row.transactionDate
                    && event.liabilityEffectCode == effect.rawValue
                    && sourceMoneyFieldsMatch(
                        currency: event.postedCurrency,
                        minor: event.postedAmountMinor,
                        decimal: event.postedAmountDecimal,
                        source: posted
                    )
                    && optionalSourceMoneyFieldsMatch(
                        currency: event.originalCurrency,
                        minor: event.originalAmountMinor,
                        decimal: event.originalAmountDecimal,
                        source: original
                    )
                    && event.sourceReference == row.sourceReference
                    && event.rowScopeCode == (row.financialScope == "account_level"
                        ? CardTransactionScope.accountLevel.persistenceCode
                        : CardTransactionScope.instrument.persistenceCode)
                    && event.documentSectionOrdinal
                        == (row.financialScope == "account_level" ? nil
                            : oracle.sections.firstIndex { $0.accountMasked == row.sectionAccountMasked }.map { $0 + 1 })
                    && annotation.sourceTransactionDateISO == row.transactionDate
                    && annotation.liabilityEffectCode == effect.rawValue
                    && annotation.originalCurrency == event.originalCurrency
                    && annotation.originalAmountDecimal == event.originalAmountDecimal,
                .campaign("\(token) Amex projection row \(index + 1)")
            )
        }
    }

    private func verifySummaryMoney(
        _ summaries: [CardStatementSummaryComponentDTO],
        code: String,
        currency: String,
        amount: String,
        token: String
    ) throws {
        let component = try requireValue(
            summaries.first { $0.componentCode == code },
            .campaign("\(token) summary \(code)")
        )
        try require(
            component.moneyCurrency == currency
                && component.moneyDecimal.map(decimal) == decimal(amount),
            .campaign("\(token) summary \(code) money")
        )
    }

    private func verifySummaryMoney(
        _ summaries: [CardStatementSummaryComponentDTO],
        code: String,
        money: Money,
        token: String
    ) throws {
        let component = try requireValue(
            summaries.first { $0.componentCode == code },
            .campaign("\(token) summary \(code)")
        )
        try require(
            moneyFieldsMatch(
                currency: component.moneyCurrency,
                minor: component.moneyMinor,
                decimal: component.moneyDecimal,
                money: money
            ),
            .campaign("\(token) summary \(code) money")
        )
    }

    private func verifySummaryMoney(
        _ summaries: [CardStatementSummaryComponentDTO],
        code: String,
        source: SourceMoney,
        token: String
    ) throws {
        let component = try requireValue(
            summaries.first { $0.componentCode == code },
            .campaign("\(token) summary \(code)")
        )
        try require(
            optionalSourceMoneyFieldsMatch(
                currency: component.moneyCurrency,
                minor: component.moneyMinor,
                decimal: component.moneyDecimal,
                source: source
            ),
            .campaign("\(token) summary \(code) money")
        )
    }

    private func moneyFieldsMatch(
        currency: String?,
        minor: Int64?,
        decimal value: String?,
        money: Money
    ) -> Bool {
        currency == money.currency.code
            && minor == (try? money.minorUnits())
            && value.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
                == money.amount
    }

    private func moneyFieldsMatch(
        currency: String,
        minor: Int64,
        decimal value: String,
        money: Money
    ) -> Bool {
        moneyFieldsMatch(currency: Optional(currency), minor: Optional(minor),
                         decimal: Optional(value), money: money)
    }

    private func moneyFieldsMatch(
        currency: String,
        minor: Int64,
        decimal value: String,
        source: SourceMoney
    ) -> Bool {
        sourceMoneyFieldsMatch(currency: currency, minor: minor, decimal: value, source: source)
    }

    private func sourceMoneyFieldsMatch(
        currency: String,
        minor: Int64,
        decimal value: String,
        source: SourceMoney
    ) -> Bool {
        guard currency == source.currency else { return false }
        if let expectedMinor = source.minorUnits, expectedMinor != minor { return false }
        if let expectedAmount = source.amount,
           decimal(expectedAmount) != decimal(value) { return false }
        return source.minorUnits != nil || source.amount != nil
    }

    private func optionalSourceMoneyFieldsMatch(
        currency: String?,
        minor: Int64?,
        decimal value: String?,
        source: SourceMoney?
    ) -> Bool {
        guard let source else { return currency == nil && minor == nil && value == nil }
        guard let currency, let minor, let value else { return false }
        return sourceMoneyFieldsMatch(
            currency: currency,
            minor: minor,
            decimal: value,
            source: source
        )
    }

    private func verifySalaryPersistence(
        _ salary: SalaryRepositorySnapshotDTO,
        hydrated: RepositoryRuntimeSnapshot,
        corpus: Corpus,
        state: RoutingState
    ) throws {
        let sourceBySession = try carriersByImportSession(corpus: corpus, state: state)
        let hydratedBySession = Dictionary(uniqueKeysWithValues: hydrated.salaryStatements.map {
            ($0.importSessionID, $0)
        })
        for statement in salary.statements {
            let carrier = try requireValue(
                sourceBySession[statement.importSessionId],
                .campaign("salary source session")
            )
            guard case .salary(let oracle) = carrier.evidence else {
                throw AcceptanceError.campaign("non-salary source owns salary statement")
            }
            let expectedKind: String
            switch oracle.kind {
            case "monthlySalary": expectedKind = "regular_salary"
            case "adhocPayment": expectedKind = "adhoc_payment"
            case "annualDiscretionaryBonus": expectedKind = "annual_discretionary_bonus"
            default: throw AcceptanceError.oracle("salary kind")
            }
            try require(
                statement.sourceFingerprintAlgorithm
                    == DocumentFingerprintDTO.sourceBytesSHA256Algorithm
                    && statement.sourceFingerprintDigest == carrier.sourceSHA256
                    && statement.sourceAuthorityCode == "qatar_airways"
                    && statement.parserProfileId == SalaryStatementEvidence.profileID
                    && statement.parserProfileVersion == SalaryStatementEvidence.profileVersion
                    && statement.financialPeriodISO == oracle.period
                    && statement.printDateISO == salaryPrintDate(oracle.printDate).canonical
                    && statement.documentKindCode == expectedKind
                    && statement.nativeCurrency == oracle.currency
                    && decimal(statement.printedEarningsDecimal)
                        == decimal(oracle.printedControls.totalEarnings)
                    && statement.printedDeductionsDecimal.map(decimal)
                        == oracle.printedControls.totalDeductions.map(decimal)
                    && decimal(statement.printedNetDecimal) == decimal(oracle.printedControls.netPay)
                    && decimal(statement.printedPaymentDecimal)
                        == decimal(oracle.printedControls.paymentTotal),
                .campaign("\(carrier.token) durable salary controls")
            )
            let earnings = statement.components.filter { $0.sideCode == "earning" }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            let deductions = statement.components.filter { $0.sideCode == "deduction" }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            try verifySalaryComponentDTOs(earnings, oracle.earnings, token: carrier.token)
            try verifySalaryComponentDTOs(deductions, oracle.deductions, token: carrier.token)
            let visible = try requireValue(
                hydratedBySession[statement.importSessionId],
                .campaign("\(carrier.token) hydrated salary statement")
            )
            try require(
                visible.documentID == statement.documentId
                    && visible.fingerprintAlgorithm == statement.sourceFingerprintAlgorithm
                    && visible.fingerprintDigest == statement.sourceFingerprintDigest,
                .campaign("\(carrier.token) hydrated salary identity")
            )
            try verifySalaryEvidence(visible.evidence, oracle: oracle, token: carrier.token)
        }
        try require(hydratedBySession.count == 20,
                    .campaign("all salary statements hydrated"))
    }

    private func verifySalaryComponentDTOs(
        _ actual: [SalaryComponentDTO],
        _ expected: [SalaryComponentSource],
        token: String
    ) throws {
        try require(actual.count == expected.count,
                    .campaign("\(token) durable salary component count"))
        for (index, pair) in zip(actual, expected).enumerated() {
            try require(
                pair.0.sourceOrdinal == pair.1.ordinal + 1
                    && pair.0.sourceLabel == pair.1.label
                    && pair.0.amountCurrency == "QAR"
                    && decimal(pair.0.amountDecimal) == decimal(pair.1.amount),
                .campaign("\(token) durable salary component \(index + 1)")
            )
        }
    }

    private func verifySalaryEvidence(
        _ evidence: SalaryStatementEvidence,
        oracle: SalarySource,
        token: String
    ) throws {
        let expectedKind: SalaryDocumentKind
        switch oracle.kind {
        case "monthlySalary": expectedKind = .regularSalary
        case "adhocPayment": expectedKind = .adhocPayment
        case "annualDiscretionaryBonus": expectedKind = .annualDiscretionaryBonus
        default: throw AcceptanceError.oracle("salary kind")
        }
        try require(
            evidence.sourceAuthority == .qatarAirways
                && evidence.profileID == SalaryStatementEvidence.profileID
                && evidence.profileVersion == SalaryStatementEvidence.profileVersion
                && evidence.financialPeriod.canonical == oracle.period
                && evidence.printDate?.canonical == salaryPrintDate(oracle.printDate).canonical
                && evidence.kind == expectedKind
                && evidence.nativeCurrency.code == oracle.currency
                && (try evidence.printedEarningsTotal.canonicalDecimalString())
                    == oracle.printedControls.totalEarnings
                && (try evidence.printedDeductionsTotal?.canonicalDecimalString())
                    == oracle.printedControls.totalDeductions
                && (try evidence.printedNet.canonicalDecimalString()) == oracle.printedControls.netPay
                && (try evidence.printedPaymentTotal.canonicalDecimalString())
                    == oracle.printedControls.paymentTotal,
            .campaign("\(token) hydrated salary controls")
        )
        try verifySalaryComponents(evidence.earnings, oracle.earnings, token: token)
        try verifySalaryComponents(evidence.deductions, oracle.deductions, token: token)
    }

    private func verifyHydratedCanonicalSources(
        _ hydrated: RepositoryRuntimeSnapshot,
        corpus: Corpus,
        state: RoutingState
    ) throws {
        let canonicalSessions = Set(state.authoritativeByLogicalStatement.values.compactMap {
            state.importSessionBySourceDigest[$0.sourceSHA256]
        })
        let transactionSessions = Set(hydrated.transactions.compactMap(\.repositoryImportSessionId))
        let expectedTransactionSessions = Set(state.authoritativeByLogicalStatement.values.compactMap {
            $0.expectedTransactionCount > 0 ? state.importSessionBySourceDigest[$0.sourceSHA256] : nil
        })
        try require(
            canonicalSessions.count == Self.expectedLogicalStatementCount
                && transactionSessions == expectedTransactionSessions,
            .campaign("canonical transaction ownership sessions")
        )
        let transactionsBySession = Dictionary(grouping: hydrated.transactions) {
            $0.repositoryImportSessionId ?? ""
        }
        for carrier in state.authoritativeByLogicalStatement.values {
            let session = try requireValue(
                state.importSessionBySourceDigest[carrier.sourceSHA256],
                .campaign("\(carrier.token) authoritative session")
            )
            let transactions = (transactionsBySession[session] ?? []).sorted {
                ($0.sourceProvenance.first?.sourceOrdinal ?? 0)
                    < ($1.sourceProvenance.first?.sourceOrdinal ?? 0)
            }
            try require(transactions.count == carrier.expectedTransactionCount,
                        .campaign("\(carrier.token) hydrated canonical row count"))
            switch carrier.evidence {
            case .axisBank(let oracle):
                try verifyHydratedAxisBank(transactions, oracle: oracle, token: carrier.token)
            case .hdfcBank(let oracle):
                try verifyHydratedHDFC(transactions, oracle: oracle, token: carrier.token)
            case .cbqBank(let oracle):
                try verifyHydratedCBQBank(transactions, oracle: oracle, token: carrier.token)
            case .axisCard(let oracle):
                try verifyHydratedAxisCard(
                    transactions,
                    session: session,
                    snapshot: hydrated.cardSnapshot,
                    oracle: oracle,
                    token: carrier.token
                )
            case .cbqCard(let oracle):
                try verifyHydratedCBQCard(
                    transactions,
                    session: session,
                    snapshot: hydrated.cardSnapshot,
                    oracle: oracle,
                    token: carrier.token
                )
            case .amexCard(let oracle):
                try verifyHydratedAmex(
                    transactions,
                    session: session,
                    snapshot: hydrated.cardSnapshot,
                    oracle: oracle,
                    token: carrier.token
                )
            case .salary:
                try require(transactions.isEmpty,
                            .campaign("\(carrier.token) salary transaction absence"))
            }
        }
    }

    private func verifyHydratedAxisBank(
        _ transactions: [Transaction],
        oracle: AxisBankCarrier,
        token: String
    ) throws {
        for (index, pair) in zip(transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let provenance = try requireValue(
                transaction.sourceProvenance.first,
                .campaign("\(token) hydrated Axis-bank provenance \(index + 1)")
            )
            let narration = try requireValue(
                row.descriptionSha256,
                .oracle("\(token) hydrated Axis-bank narration \(index + 1)")
            )
            try require(
                transaction.statementDate?.canonical == row.date
                    && transaction.valueDate == nil
                    && transaction.money.currency.code == "INR"
                    && transaction.money.amount == decimal(row.signedAmount)
                    && transaction.runningBalanceMoney?.amount == decimal(row.balance)
                    && bankDirection(transaction) == row.direction
                    && sha256(Data(collapseWhitespace(transaction.description).utf8)) == narration
                    && transaction.reference.map { sha256(Data($0.utf8)) }
                        == row.chequeReferenceSha256
                    && transaction.verifiedAxisUPIEventEvidence == nil
                    && (oracle.format == "pdf"
                        ? provenance.sourceOrdinal > 0
                        : provenance.sourceOrdinal == row.sourceOrdinal)
                    && provenance.parserProfileID == "axis.bank-account.\(oracle.format)"
                    && provenance.parserProfileVersion == (oracle.format == "csv" ? "3" : "1")
                    && provenance.sourcePage == nil
                    && provenance.structuredReferenceDigest == nil,
                .campaign("\(token) hydrated Axis-bank row \(index + 1)")
            )
        }
    }

    private func verifyHydratedHDFC(
        _ transactions: [Transaction],
        oracle: HDFCCarrier,
        token: String
    ) throws {
        let format = oracle.carrier.lowercased().hasSuffix(".pdf") ? "pdf" : "xls"
        for (index, pair) in zip(transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let provenance = try requireValue(
                transaction.sourceProvenance.first,
                .campaign("\(token) hydrated HDFC provenance \(index + 1)")
            )
            try require(
                transaction.statementDate == hdfcDate(row.date)
                    && transaction.valueDate == hdfcDate(row.valueDate)
                    && transaction.money.amount
                        == (row.withdrawal.isEmpty ? decimal(row.deposit) : -decimal(row.withdrawal))
                    && transaction.runningBalanceMoney?.amount == decimal(row.closing)
                    && transaction.reference == (row.reference.isEmpty ? nil : row.reference)
                    && compact(transaction.description) == compact(row.narration)
                    && transaction.money.currency.code == oracle.currency
                    && provenance.parserProfileID == "hdfc.bank-account.\(format)"
                    && provenance.parserProfileVersion == "1"
                    && provenance.sourcePage == nil,
                .campaign("\(token) hydrated HDFC row \(index + 1)")
            )
        }
    }

    private func verifyHydratedCBQBank(
        _ transactions: [Transaction],
        oracle: CBQBankCarrier,
        token: String
    ) throws {
        for (index, pair) in zip(transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let provenance = try requireValue(
                transaction.sourceProvenance.first,
                .campaign("\(token) hydrated CBQ-bank provenance \(index + 1)")
            )
            try require(
                transaction.statementDate == cbqDate(row.postingDate)
                    && transaction.money.amount == decimal(row.signedAmount)
                    && transaction.money.currency.code == "QAR"
                    && transaction.runningBalanceMoney?.amount == decimal(row.balance)
                    && compact(transaction.description) == compact(row.description)
                    && transaction.repositoryPreferredSourceTransactionDate
                        == cbqDate(row.sourceTransactionDate)
                    && provenance.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID
                    && provenance.parserProfileVersion == "1"
                    && provenance.sourcePage == nil,
                .campaign("\(token) hydrated CBQ-bank row \(index + 1)")
            )
        }
    }

    private func verifyHydratedAxisCard(
        _ transactions: [Transaction],
        session: String,
        snapshot: CardStoreSnapshot,
        oracle: AxisCardRecord,
        token: String
    ) throws {
        let statement = try requireValue(
            snapshot.statements.first { $0.importSessionID == session },
            .campaign("\(token) hydrated Axis-card statement")
        )
        let annotations = Dictionary(uniqueKeysWithValues: snapshot.transactionEvidence
            .filter { $0.statementID == statement.id }
            .map { ($0.transactionID, $0) })
        for (index, pair) in zip(transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let transactionID = try requireValue(
                transaction.repositoryTransactionId,
                .campaign("\(token) Axis-card durable transaction \(index + 1)")
            )
            let annotation = try requireValue(
                annotations[transactionID],
                .campaign("\(token) hydrated Axis-card annotation \(index + 1)")
            )
            let expectedSigned = row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                ? -decimal(row.amount) : decimal(row.amount)
            let expectedOriginal = row.originalMerchantMoney.map {
                signed($0, effect: row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                    ? .decreasesAmountOwed : .increasesAmountOwed)
            }
            try require(
                transaction.statementDate?.canonical == row.date
                    && transaction.money.amount == expectedSigned
                    && transaction.money.currency.code == "INR"
                    && transaction.cardLiabilityEffect?.rawValue == row.effect
                    && transaction.reference == row.reference
                    && sourceNarrationGlyphs(transaction.description) == sourceNarrationGlyphs(row.narration)
                    && annotation.liabilityEffect.rawValue == row.effect
                    && sourceMoneyMatches(annotation.originalMerchantMoney, expectedOriginal),
                .campaign("\(token) hydrated Axis-card row \(index + 1)")
            )
        }
    }

    private func verifyHydratedCBQCard(
        _ transactions: [Transaction],
        session: String,
        snapshot: CardStoreSnapshot,
        oracle: PrivateCBQOracle,
        token: String
    ) throws {
        let statement = try requireValue(
            snapshot.statements.first { $0.importSessionID == session },
            .campaign("\(token) hydrated CBQ-card statement")
        )
        let annotations = Dictionary(uniqueKeysWithValues: snapshot.transactionEvidence
            .filter { $0.statementID == statement.id }
            .map { ($0.transactionID, $0) })
        for (index, pair) in zip(transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let transactionID = try requireValue(
                transaction.repositoryTransactionId,
                .campaign("\(token) CBQ-card durable transaction \(index + 1)")
            )
            let annotation = try requireValue(
                annotations[transactionID],
                .campaign("\(token) hydrated CBQ-card annotation \(index + 1)")
            )
            let sectionOrdinal = annotation.documentScopedSectionID.flatMap { identifier in
                statement.sections.first { $0.documentScopedSectionID == identifier }?.sourceOrdinal
            }
            try require(
                transaction.statementDate == row.postingDate
                    && transaction.description == row.description
                    && transaction.reference == row.reference
                    && transaction.money == row.postedMoney
                    && annotation.sourceTransactionDate == row.purchaseDate
                    && annotation.liabilityEffect == row.effect
                    && annotation.originalMerchantMoney == row.originalMoney
                    && (annotation.financialScope == .accountLevel) == row.accountLevel
                    && sectionOrdinal == row.sectionOrdinal,
                .campaign("\(token) hydrated CBQ-card row \(index + 1)")
            )
        }
    }

    private func verifyHydratedAmex(
        _ transactions: [Transaction],
        session: String,
        snapshot: CardStoreSnapshot,
        oracle: AmexSource,
        token: String
    ) throws {
        let statement = try requireValue(
            snapshot.statements.first { $0.importSessionID == session },
            .campaign("\(token) hydrated Amex statement")
        )
        let annotations = Dictionary(uniqueKeysWithValues: snapshot.transactionEvidence
            .filter { $0.statementID == statement.id }
            .map { ($0.transactionID, $0) })
        for (index, pair) in zip(transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let transactionID = try requireValue(
                transaction.repositoryTransactionId,
                .campaign("\(token) Amex durable transaction \(index + 1)")
            )
            let annotation = try requireValue(
                annotations[transactionID],
                .campaign("\(token) hydrated Amex annotation \(index + 1)")
            )
            let effect: CardLiabilityEffect = row.creditDebitLiabilityDirection == "liability_decrease"
                ? .decreasesAmountOwed : .increasesAmountOwed
            try require(
                transaction.statementDate?.canonical == row.postingDate
                    && sha256(Data(transaction.description.utf8))
                        == row.descriptionSourceRawSegmentsSHA256
                    && sha256(Data(transaction.description
                        .replacingOccurrences(of: "\n", with: " ").utf8))
                        == sha256(Data(row.descriptionSourceExact.utf8))
                    && transaction.reference == row.sourceReference
                    && sourceMoneyMatches(transaction.money, signed(row.postedNativeMoney, effect: effect))
                    && annotation.sourceTransactionDate.canonical == row.transactionDate
                    && annotation.liabilityEffect == effect
                    && sourceMoneyMatches(
                        annotation.originalMerchantMoney,
                        row.originalForeignMoney.map { signed($0, effect: effect) }
                    )
                    && (annotation.financialScope == .accountLevel)
                        == (row.financialScope == "account_level"),
                .campaign("\(token) hydrated Amex row \(index + 1)")
            )
        }
    }

    private func acceptedSemanticDigest(
        hydrated: RepositoryRuntimeSnapshot,
        bankProjections: [StatementFinancialProjectionRecordDTO],
        cbqObservations: [CBQSourceObservationSummaryDTO],
        card: CardRepositorySnapshotDTO,
        salary: SalaryRepositorySnapshotDTO,
        corpus: Corpus,
        state: RoutingState
    ) throws -> String {
        let sourceBySession = try carriersByImportSession(corpus: corpus, state: state)
        var lines: [String] = []
        for record in bankProjections {
            let source = try requireValue(sourceBySession[record.importSessionID],
                                          .campaign("bank digest source"))
            let projection = record.projection
            lines.append(semanticLine([
                "bank", source.sourceSHA256, projection.algorithmIdentifier,
                projection.institutionCode, projection.statementFamilyCode,
                projection.parserProfileID, projection.parserProfileVersion,
                projection.sourceFormatCode, projection.statementStartDateISO,
                projection.statementEndDateISO, projection.nativeCurrency,
                projection.openingBalanceDecimal, projection.debitTotalDecimal,
                projection.creditTotalDecimal, projection.closingBalanceDecimal
            ]))
            for event in projection.events {
                lines.append(semanticLine([
                    "bank-row", source.sourceSHA256, String(event.ordinal),
                    event.statementDateISO, event.valueDateISO ?? "", event.direction,
                    event.signedAmountDecimal, event.runningBalanceDecimal,
                    event.reference.map { sha256(Data($0.utf8)) } ?? ""
                ]))
            }
        }
        for observation in cbqObservations {
            let source = try requireValue(sourceBySession[observation.importSessionId],
                                          .campaign("CBQ-bank digest source"))
            lines.append(semanticLine([
                "cbq-observation", source.sourceSHA256, observation.sourceFormatCode,
                String(observation.sourceRowCount), String(observation.importedTransactionCount),
                String(observation.representedTransactionCount),
                String(observation.transactionObservationCount)
            ]))
        }
        for projection in card.semanticProjections {
            let source = try requireValue(sourceBySession[projection.importSessionId],
                                          .campaign("card projection digest source"))
            lines.append(semanticLine([
                "card-projection", source.sourceSHA256, projection.algorithm,
                projection.institutionCode, projection.statementFamilyCode,
                projection.parserProfileId, projection.parserProfileVersion,
                projection.statementDateISO ?? "", projection.statementStartDateISO ?? "",
                projection.statementEndDateISO ?? "", projection.selectedStatementMonthISO ?? "",
                projection.cycleMonthISO ?? "", projection.nativeCurrency,
                projection.reconciliationRuleCode
            ]))
            for section in projection.sections.sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
                lines.append(semanticLine([
                    "card-projection-section", source.sourceSHA256,
                    String(section.sourceOrdinal), section.signedTotalCurrency,
                    section.signedTotalDecimal, section.reconciliationRuleCode
                ]))
            }
            for event in projection.events.sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
                lines.append(semanticLine([
                    "card-projection-row", source.sourceSHA256, String(event.sourceOrdinal),
                    event.financialDateISO, event.financialDateRoleCode,
                    event.sourceTransactionDateISO ?? "", event.liabilityEffectCode,
                    event.postedCurrency, event.postedAmountDecimal,
                    event.originalCurrency ?? "", event.originalAmountDecimal ?? "",
                    event.sourceReference.map { sha256(Data($0.utf8)) } ?? "",
                    event.rowScopeCode, event.documentSectionOrdinal.map(String.init) ?? ""
                ]))
            }
        }
        for statement in card.statements {
            let source = try requireValue(sourceBySession[statement.importSessionId],
                                          .campaign("card statement digest source"))
            lines.append(semanticLine([
                "card-statement", source.sourceSHA256, statement.parserProfileId,
                statement.parserProfileVersion, statement.statementDateISO ?? "",
                statement.statementStartDateISO ?? "", statement.statementEndDateISO ?? "",
                statement.selectedStatementMonthISO ?? "", statement.statementCurrency,
                String(statement.sourceRowCount), statement.reconciliationRuleCode
            ]))
            for summary in card.summaryComponents
                .filter({ $0.cardStatementId == statement.id })
                .sorted(by: { $0.componentCode < $1.componentCode }) {
                lines.append(semanticLine([
                    "card-summary", source.sourceSHA256, summary.componentCode,
                    summary.moneyCurrency ?? "", summary.moneyDecimal ?? "", summary.dateISO ?? ""
                ]))
            }
            for section in card.sections
                .filter({ $0.cardStatementId == statement.id })
                .sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
                lines.append(semanticLine([
                    "card-section", source.sourceSHA256, String(section.sourceOrdinal),
                    section.holderLabel.map { sha256(Data($0.utf8)) } ?? "",
                    section.signedTotalCurrency, section.signedTotalDecimal,
                    section.reconciliationRuleCode
                ]))
            }
        }
        // Durable transaction evidence belongs only to the carrier selected as
        // canonical authority. Equivalent Axis carriers legitimately preserve
        // different source-owned reference, original-money, narration, and
        // physical-section facts, so including that authority-only record here
        // would make this deliberately format-neutral parity digest depend on
        // import order. Every carrier's complete evidence is already compared
        // against its independent source oracle through the semantic projection,
        // and the selected authority's durable/hydrated evidence is verified
        // exactly above. The canonical financial multiset below is therefore the
        // appropriate cross-order representation.
        for statement in salary.statements {
            let source = try requireValue(sourceBySession[statement.importSessionId],
                                          .campaign("salary digest source"))
            lines.append(semanticLine([
                "salary", source.sourceSHA256, statement.sourceAuthorityCode,
                statement.parserProfileId, statement.parserProfileVersion,
                statement.financialPeriodISO, statement.printDateISO ?? "",
                statement.documentKindCode, statement.nativeCurrency,
                statement.printedEarningsDecimal, statement.printedDeductionsDecimal ?? "",
                statement.printedNetDecimal, statement.printedPaymentDecimal
            ]))
            for component in statement.components.sorted(by: {
                ($0.sideCode, $0.sourceOrdinal) < ($1.sideCode, $1.sourceOrdinal)
            }) {
                lines.append(semanticLine([
                    "salary-component", source.sourceSHA256, component.sideCode,
                    String(component.sourceOrdinal), sha256(Data(component.sourceLabel.utf8)),
                    component.amountCurrency, component.amountDecimal
                ]))
            }
        }
        for source in state.authoritativeByLogicalStatement.values {
            guard source.expectedTransactionCount > 0 else { continue }
            let session = try requireValue(
                state.importSessionBySourceDigest[source.sourceSHA256],
                .campaign("canonical digest session")
            )
            let transactions = hydrated.transactions.filter {
                $0.repositoryImportSessionId == session
            }
            for transaction in transactions {
                // Every source-owned fact is checked against its source oracle
                // above. This parity-only projection is deliberately an
                // unordered financial multiset: equivalent carriers may have
                // different physical order, narration, references, and
                // original-money evidence while still denoting the same
                // canonical financial events.
                lines.append(semanticLine([
                    "canonical", source.logicalStatementKey,
                    transaction.statementDate?.canonical ?? "", transaction.valueDate?.canonical ?? "",
                    transaction.money.currency.code, try transaction.money.canonicalDecimalString(),
                    try transaction.runningBalanceMoney?.canonicalDecimalString() ?? "",
                    transaction.cardLiabilityEffect?.rawValue ?? ""
                ]))
            }
        }
        return sha256(Data((lines.sorted().joined(separator: "\n") + "\n").utf8))
    }

    private func semanticLine(_ values: [String]) -> String {
        values.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private func preflightEvidenceDestination(_ resultFile: URL) throws {
        let directory = resultFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let probe = directory.appendingPathComponent("ledgerforge-evidence-probe-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: probe) }
        let marker = Data("ledgerforge-evidence-output-mechanics\n".utf8)
        try marker.write(to: probe, options: .atomic)
        try require(try Data(contentsOf: probe) == marker, .context("evidence output readback"))
        try FileManager.default.removeItem(at: probe)
    }

    private func writeEvidence(
        context: Context,
        corpus: Corpus,
        campaignDigests: [String: String]
    ) throws {
        let resultFile = context.resultFile
        let sourceInventoryDigest = sha256(Data(
            (corpus.carriers.map(\.sourceSHA256).sorted().joined(separator: "\n") + "\n").utf8
        ))
        let oracleDigests = Dictionary(uniqueKeysWithValues: corpus.oracleFileDigests.map {
            ($0.key.rawValue, $0.value)
        })
        let payload: [String: Any] = [
            "schema": "ledgerforge.global-authentic-corpus-acceptance.v1",
            "status": "passed",
            "carrier_count": Self.expectedCarrierCount,
            "logical_statement_count": Self.expectedLogicalStatementCount,
            "canonical_transaction_count": Self.expectedCanonicalTransactionCount,
            "representation_transaction_count": Self.expectedRepresentationTransactionCount,
            "source_inventory_sha256": sourceInventoryDigest,
            "frozen_oracle_sha256": oracleDigests,
            "cbq_card_source_oracle_sha256": corpus.cbqCardSourceOracleDigest,
            "campaign_semantic_sha256": campaignDigests,
            "providers": ProviderKind.allCases.map(\.rawValue),
            "orders": CampaignOrder.allCases.map(\.rawValue),
            "ordinary_queue_contract": "serial prepare-validate-confirm for each authentic carrier",
            "batch_atomicity_claimed": false,
            "ui_multi_file_intake_claimed": false,
            "supporting_source_narration_persisted": false
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try FileManager.default.createDirectory(
            at: resultFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: resultFile, options: .atomic)
    }

    private func loadCorpus(_ context: Context) async throws -> Corpus {
        var oracleFileDigests: [Family: String] = [:]
        var carriers: [Carrier] = []

        let axisBank: AxisBankOracle = try decodeOracle(
            context.axisBankOracle,
            family: .axisBank,
            snakeCase: true,
            digests: &oracleFileDigests
        )
        try verifyAxisBankOracle(axisBank)
        let axisBankSources = try sourcesByDigest(
            files: financialFiles(context.axisBankRoot, extensions: ["csv", "pdf", "xls"]),
            expectedCount: 9,
            family: .axisBank
        )
        try require(
            Set(axisBankSources.keys) == Set(axisBank.carriers.map(\.sourceSha256)),
            .source("axis-bank inventory")
        )
        carriers += try axisBank.carriers.map { source in
            let url = try requireValue(axisBankSources[source.sourceSha256], .source("axis-bank digest"))
            return Carrier(
                family: .axisBank,
                url: url,
                sourceSHA256: source.sourceSha256,
                sourceSize: source.sourceSize,
                logicalStatementKey: "axis-bank|\(source.logicalStatementId)",
                chronologicalKey: source.periodEnd,
                expectedTransactionCount: source.rowCount,
                evidence: .axisBank(source)
            )
        }

        let hdfc: HDFCOracle = try decodeOracle(
            context.hdfcOracle,
            family: .hdfcBank,
            snakeCase: false,
            digests: &oracleFileDigests
        )
        try verifyHDFCOracle(hdfc)
        let hdfcOracleCarriers = hdfc.carriers.pdf + hdfc.carriers.xls
        let hdfcSources = try sourcesByDigest(
            files: financialFiles(context.hdfcRoot, extensions: ["pdf", "xls"]),
            expectedCount: 8,
            family: .hdfcBank
        )
        try require(
            Set(hdfcSources.keys) == Set(hdfcOracleCarriers.map(\.sha256)),
            .source("hdfc inventory")
        )
        carriers += try hdfcOracleCarriers.map { source in
            let url = try requireValue(hdfcSources[source.sha256], .source("hdfc digest"))
            return Carrier(
                family: .hdfcBank,
                url: url,
                sourceSHA256: source.sha256,
                sourceSize: try sourceByteCount(url),
                logicalStatementKey: ["hdfc-bank", source.account, source.periodStart, source.periodEnd, source.currency]
                    .joined(separator: "|"),
                chronologicalKey: source.periodEnd,
                expectedTransactionCount: source.rows.count,
                evidence: .hdfcBank(source)
            )
        }

        let cbqBank: CBQBankOracle = try decodeOracle(
            context.cbqBankOracle,
            family: .cbqBank,
            snakeCase: false,
            digests: &oracleFileDigests
        )
        try verifyCBQBankOracle(cbqBank)
        let cbqRootPDFs = financialFiles(context.cbqBankRoot, extensions: ["pdf"])
        try require(cbqRootPDFs.count == 18, .source("cbq-bank standalone PDF count"))
        let cbqBankSources = try sourcesByDigest(
            files: cbqRootPDFs + [context.cbqBankAttachment],
            expectedCount: 19,
            family: .cbqBank
        )
        try require(
            Set(cbqBankSources.keys) == Set(cbqBank.carriers.map(\.sha256)),
            .source("cbq-bank PDF plus exact attachment inventory")
        )
        carriers += try cbqBank.carriers.map { source in
            let url = try requireValue(cbqBankSources[source.sha256], .source("cbq-bank digest"))
            return Carrier(
                family: .cbqBank,
                url: url,
                sourceSHA256: source.sha256,
                sourceSize: try sourceByteCount(url),
                logicalStatementKey: ["cbq-bank", source.maskedAccount, source.periodStart, source.statementDate]
                    .joined(separator: "|"),
                chronologicalKey: try cbqDate(source.statementDate.replacingOccurrences(of: " ", with: "-")).canonical,
                expectedTransactionCount: source.rows.count,
                evidence: .cbqBank(source)
            )
        }

        let axisCard: AxisCardOracle = try decodeOracle(
            context.axisCardOracle,
            family: .axisCard,
            snakeCase: true,
            digests: &oracleFileDigests
        )
        try verifyAxisCardOracle(axisCard)
        let axisCardSources = try sourcesByDigest(
            files: financialFiles(
                context.axisCardRoot,
                extensions: ["pdf", "xlsx"],
                excludingArchiveDirectories: true
            ),
            expectedCount: 32,
            family: .axisCard
        )
        try require(
            Set(axisCardSources.keys) == Set(axisCard.records.map(\.sourceSha256)),
            .source("axis-card inventory")
        )
        carriers += try axisCard.records.map { source in
            let url = try requireValue(axisCardSources[source.sourceSha256], .source("axis-card digest"))
            return Carrier(
                family: .axisCard,
                url: url,
                sourceSHA256: source.sourceSha256,
                sourceSize: try sourceByteCount(url),
                logicalStatementKey: "axis-card|\(source.cycle)",
                chronologicalKey: "\(source.cycle)-99",
                expectedTransactionCount: source.rows.count,
                evidence: .axisCard(source)
            )
        }

        let amex: AmexOracle = try decodeOracle(
            context.amexOracle,
            family: .amexCard,
            snakeCase: false,
            digests: &oracleFileDigests
        )
        try verifyAmexOracle(amex)
        let amexSources = try sourcesByDigest(
            files: financialFiles(context.amexRoot, extensions: ["pdf"]),
            expectedCount: 20,
            family: .amexCard
        )
        try require(
            Set(amexSources.keys) == Set(amex.sources.map(\.sourceSHA256)),
            .source("amex inventory")
        )
        carriers += try amex.sources.map { source in
            let url = try requireValue(amexSources[source.sourceSHA256], .source("amex digest"))
            try require(url.lastPathComponent == source.basename, .source("amex basename binding"))
            return Carrier(
                family: .amexCard,
                url: url,
                sourceSHA256: source.sourceSHA256,
                sourceSize: source.sourceByteSize,
                logicalStatementKey: "amex-card|\(source.statementPeriod.start)|\(source.statementPeriod.end)",
                chronologicalKey: source.statementDate,
                expectedTransactionCount: source.rows.count,
                evidence: .amexCard(source)
            )
        }

        let salary: SalaryOracle = try decodeOracle(
            context.salaryOracle,
            family: .salary,
            snakeCase: true,
            digests: &oracleFileDigests
        )
        try verifySalaryOracle(salary)
        let salarySources = try sourcesByDigest(
            files: financialFiles(context.salaryRoot, extensions: ["pdf"]),
            expectedCount: 20,
            family: .salary
        )
        try require(
            Set(salarySources.keys) == Set(salary.statements.map(\.sourceSha256)),
            .source("salary inventory")
        )
        carriers += try salary.statements.map { source in
            let url = try requireValue(salarySources[source.sourceSha256], .source("salary digest"))
            try require(url.lastPathComponent == source.sourceBasename, .source("salary basename binding"))
            return Carrier(
                family: .salary,
                url: url,
                sourceSHA256: source.sourceSha256,
                sourceSize: source.sourceSize,
                logicalStatementKey: "salary|\(source.sourceSha256)",
                chronologicalKey: source.period,
                expectedTransactionCount: 0,
                evidence: .salary(source)
            )
        }

        // CBQ card has no derived fixture file. Freeze the accepted independent
        // source-only oracle from complete unlocked PDF text/geometry before
        // creating any production ImportEngine used by the campaigns.
        let cbqCardURLs = financialFiles(context.cbqCardRoot, extensions: ["pdf"])
        try require(cbqCardURLs.count == 19, .source("cbq-card inventory count"))
        let cbqCardInventory = try sourcesByDigest(
            files: cbqCardURLs,
            expectedCount: 19,
            family: .cbqCard
        )
        let inventoryDigest = sha256(
            Data((cbqCardInventory.keys.sorted().joined(separator: "\n") + "\n").utf8)
        )
        try require(
            inventoryDigest == "7af9c73dd4d95d4036d4595d2474fa3cdfea0606e8958a63e92e014284d96b37",
            .source("cbq-card frozen source inventory")
        )
        var cbqOracleLines: [String] = []
        var cbqPageCount = 0
        for url in cbqCardURLs.sorted(by: { $0.path < $1.path }) {
            let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
            let digest = sha256(bytes)
            let snapshot = SourceContentSnapshot(bytes: bytes)
            defer { snapshot.invalidate() }
            let raw = try await PDFDocumentReader().read(
                request: ImportRequest(fileURL: url),
                snapshot: snapshot,
                password: context.cbqPassword
            )
            let pages = try requireValue(raw.pdfPageTexts, .oracle("cbq-card source text"))
            let positioned = try requireValue(raw.pdfPageEvidence, .oracle("cbq-card source geometry"))
            try require(!pages.isEmpty && pages.count == positioned.count, .oracle("cbq-card page evidence"))
            let oracle = try CBQCreditCardPrivateAcceptanceTests().independentOracle(
                pages: pages,
                positioned: positioned
            )
            cbqPageCount += pages.count
            let projection = try cbqCardOracleProjection(sourceSHA256: digest, oracle: oracle)
            cbqOracleLines.append(projection)
            carriers.append(Carrier(
                family: .cbqCard,
                url: url,
                sourceSHA256: digest,
                sourceSize: bytes.count,
                logicalStatementKey: "cbq-card|\(oracle.period.start.canonical)|\(oracle.period.end.canonical)",
                chronologicalKey: oracle.statementDate.canonical,
                expectedTransactionCount: oracle.rows.count,
                evidence: .cbqCard(oracle)
            ))
        }
        try require(cbqPageCount == 58, .oracle("cbq-card page count"))
        try require(
            carriers.filter { $0.family == .cbqCard }.reduce(0) { $0 + $1.expectedTransactionCount } == 352,
            .oracle("cbq-card row count")
        )
        let cbqCardSourceOracleDigest = sha256(
            Data((cbqOracleLines.sorted().joined(separator: "\n") + "\n").utf8)
        )

        let sourceDigests = try Dictionary(uniqueKeysWithValues: carriers.map { carrier in
            (carrier.sourceSHA256, try sourceDigest(carrier.url))
        })
        return Corpus(
            carriers: carriers,
            oracleFileDigests: oracleFileDigests,
            cbqCardSourceOracleDigest: cbqCardSourceOracleDigest,
            startingSourceDigests: sourceDigests
        )
    }

    private func verifyCorpusContract(_ corpus: Corpus) throws {
        try require(corpus.carriers.count == Self.expectedCarrierCount, .oracle("carrier count"))
        try require(
            Set(corpus.carriers.map(\.sourceSHA256)).count == Self.expectedCarrierCount,
            .source("unique carrier bytes")
        )
        try require(
            Set(corpus.carriers.map(\.logicalStatementKey)).count == Self.expectedLogicalStatementCount,
            .oracle("logical statement count")
        )
        try require(
            corpus.carriers.reduce(0) { $0 + $1.expectedTransactionCount }
                == Self.expectedRepresentationTransactionCount,
            .oracle("representation transaction count")
        )
        let canonicalRows = Dictionary(grouping: corpus.carriers, by: \.logicalStatementKey)
            .values.reduce(0) { partial, representations in
                partial + (representations.first?.expectedTransactionCount ?? 0)
            }
        try require(canonicalRows == Self.expectedCanonicalTransactionCount,
                    .oracle("canonical transaction count"))
        try require(
            Dictionary(grouping: corpus.carriers, by: \.family).mapValues(\.count) == [
                .axisBank: 9,
                .hdfcBank: 8,
                .cbqBank: 19,
                .axisCard: 32,
                .cbqCard: 19,
                .amexCard: 20,
                .salary: 20
            ],
            .oracle("family carrier counts")
        )
        try require(corpus.oracleFileDigests == Self.frozenOracleDigests,
                    .oracle("frozen oracle file bytes"))
        try require(corpus.cbqCardSourceOracleDigest.count == 64,
                    .oracle("cbq-card source oracle digest"))
        try require(
            corpus.startingSourceDigests == Dictionary(
                uniqueKeysWithValues: corpus.carriers.map { ($0.sourceSHA256, $0.sourceSHA256) }
            ),
            .source("all immutable source bytes")
        )
    }

    private func verifyAxisBankOracle(_ oracle: AxisBankOracle) throws {
        try require(oracle.schema == "ledgerforge.axis-bank.source-oracle.v1", .oracle("axis-bank schema"))
        try require(
            oracle.sourceInventorySha256 == "8eee75c51a522791fa387ddb5d7691647f90b4894f60b940c8e1f0d89eb189e3",
            .oracle("axis-bank inventory authority")
        )
        try require(
            oracle.corpus.carrierCount == 9 && oracle.carriers.count == 9
                && oracle.corpus.logicalStatementCount == 3
                && oracle.corpus.canonicalEventCount == 182
                && oracle.corpus.representationRowCount == 546
                && oracle.corpus.formatCounts == ["csv": 3, "pdf": 3, "xls": 3]
                && oracle.corpus.pageCounts.sorted() == [2, 3, 4]
                && oracle.carriers.allSatisfy {
                    $0.rowCount == $0.rows.count
                        && $0.rows.allSatisfy { $0.descriptionSha256 != nil }
                },
            .oracle("axis-bank complete contract")
        )
    }

    private func verifyHDFCOracle(_ oracle: HDFCOracle) throws {
        let carriers = oracle.carriers.pdf + oracle.carriers.xls
        try require(
            oracle.schema == "ledgerforge.hdfc.authentic-source-oracle.v2"
                && oracle.totals.pdfCarriers == 4 && oracle.totals.xlsCarriers == 4
                && oracle.totals.logicalStatements == 4
                && oracle.totals.canonicalRows == 165
                && oracle.totals.representationRows == 330
                && oracle.totals.allFinancialAndReferencesAgree
                && carriers.count == 8
                && carriers.reduce(0, { $0 + $1.rows.count }) == 330,
            .oracle("hdfc complete contract")
        )
    }

    private func verifyCBQBankOracle(_ oracle: CBQBankOracle) throws {
        try require(
            oracle.schema == "cbq-bank-authentic-row-oracle-v2"
                && oracle.extraction.contains("Poppler")
                && oracle.directionAuthority.contains("running balances")
                && oracle.carriers.count == 19
                && oracle.carriers.reduce(0, { $0 + $1.rows.count }) == 187,
            .oracle("cbq-bank complete contract")
        )
    }

    private func verifyAxisCardOracle(_ oracle: AxisCardOracle) throws {
        try require(
            oracle.schema == "ledgerforge.axis.source-oracle.v4"
                && oracle.authority == "raw-authentic-source-text-independent-projection"
                && oracle.sourceInventorySha256 == "64204a0eedbcd86b72a897adf21f06538b445f4ed65fb053f27f6b9c51f209c6"
                && oracle.corpus.carrierCount == 32 && oracle.records.count == 32
                && oracle.corpus.logicalStatementCount == 18
                && oracle.corpus.transactionRowCount == 1_377
                && oracle.corpus.formatCounts == ["app_pdf": 18, "xlsx": 7, "traditional_pdf": 7]
                && oracle.records.allSatisfy { $0.rowCount == $0.rows.count }
                && oracle.records.reduce(0, { $0 + $1.rows.count }) == 2_969
                && oracle.records.flatMap(\.rows).allSatisfy { !$0.narration.isEmpty }
                && oracle.records.flatMap(\.rows).filter { $0.originalMerchantMoney != nil }.count == 3,
            .oracle("axis-card complete v4 contract")
        )
    }

    private func verifyAmexOracle(_ oracle: AmexOracle) throws {
        try require(
            oracle.aggregate.statementCount == 20 && oracle.sources.count == 20
                && oracle.aggregate.financialRowCount == 902
                && oracle.aggregate.sectionCount == 31
                && oracle.aggregate.foreignMoneyRowCount == 456
                && oracle.aggregate.reconciliationFailureCount == 0
                && oracle.aggregate.sectionFailureCount == 0
                && oracle.sources.reduce(0, { $0 + $1.rows.count }) == 902
                && oracle.sources.allSatisfy {
                    $0.summary.reconciliationResidual == 0
                        && $0.summary.oracleCalculated.statementEquationResidualMinorUnits == 0
                        && $0.sections.allSatisfy { $0.oracleCalculated.allPrintedTotalsMatch }
                },
            .oracle("amex complete contract")
        )
    }

    private func verifySalaryOracle(_ oracle: SalaryOracle) throws {
        try require(
            oracle.oracleSchema == "ledgerforge.salary.source-only.private.v1"
                && oracle.oracleMethod.contains("Poppler native text and bbox extraction")
                && oracle.statements.count == 20
                && oracle.statements.reduce(0, { $0 + $1.pageCount }) == 34
                && oracle.statements.reduce(0, { $0 + $1.earnings.count }) == 158
                && oracle.statements.reduce(0, { $0 + $1.deductions.count }) == 100
                && oracle.statements.allSatisfy { !$0.encrypted && $0.currency == "QAR" && $0.reconciliation.allPass }
                && Set(oracle.statements.map(\.sourceIdentity)).count == 1,
            .oracle("salary complete contract")
        )
    }

    // MARK: Production preparation versus independent source truth

    private func verifyPrepared(_ prepared: PreparedImport, carrier: Carrier) throws {
        let snapshotDigest = try prepared.sourceSnapshot.withBytes(sha256)
        let sourceFingerprint = try requireValue(
            prepared.fingerprintSet.fingerprints.first {
                $0.algorithm == SourceContentSnapshot.algorithm
            },
            .preparation("\(carrier.token) source fingerprint")
        )
        try require(snapshotDigest == carrier.sourceSHA256, .preparation("\(carrier.token) source digest"))
        try require(
            prepared.sourceSnapshot.byteCount == Int64(carrier.sourceSize)
                && prepared.sourceSnapshot.sourceByteFingerprint.algorithm
                    == SourceContentSnapshot.algorithm
                && prepared.sourceSnapshot.sourceByteFingerprint.digest == carrier.sourceSHA256
                && prepared.sourceSnapshot.sourceByteFingerprint.byteCount == Int64(carrier.sourceSize)
                && sourceFingerprint.digest == carrier.sourceSHA256
                && sourceFingerprint.byteCount == Int64(carrier.sourceSize)
                && sourceFingerprint.isDuplicateAuthority
                    == (prepared.financialDocument.metadata.fileFormat != .csv),
            .preparation("\(carrier.token) source size")
        )
        try require(prepared.validation.passed, .preparation("\(carrier.token) validation"))
        try require(
            prepared.financialDocument.transactions.count == carrier.expectedTransactionCount,
            .preparation("\(carrier.token) row count")
        )

        switch carrier.evidence {
        case .axisBank(let oracle):
            try verifyAxisBankPrepared(prepared, oracle: oracle, token: carrier.token)
        case .hdfcBank(let oracle):
            try verifyHDFCPrepared(prepared, oracle: oracle, token: carrier.token)
        case .cbqBank(let oracle):
            try verifyCBQBankPrepared(prepared, oracle: oracle, token: carrier.token)
        case .axisCard(let oracle):
            try verifyAxisCardPrepared(prepared, oracle: oracle, token: carrier.token)
        case .cbqCard(let oracle):
            try verifyCBQCardPrepared(prepared, oracle: oracle, token: carrier.token)
        case .amexCard(let oracle):
            try verifyAmexPrepared(prepared, oracle: oracle, token: carrier.token)
        case .salary(let oracle):
            try verifySalaryPrepared(prepared, oracle: oracle, token: carrier.token)
        }
    }

    private func verifyAxisBankPrepared(
        _ prepared: PreparedImport,
        oracle: AxisBankCarrier,
        token: String
    ) throws {
        let document = prepared.financialDocument
        try require(prepared.detectedInstitution == .axis, .preparation("\(token) institution"))
        try require(prepared.detectedDocumentType == .bankAccount, .preparation("\(token) family"))
        try require(
            document.metadata.fileFormat.rawValue.lowercased() == oracle.format,
            .preparation("\(token) format")
        )
        try require(document.bookedCurrency?.code == "INR", .preparation("\(token) currency"))
        try require(
            document.declaredStatementPeriod?.start.canonical == oracle.periodStart
                && document.declaredStatementPeriod?.end.canonical == oracle.periodEnd,
            .preparation("\(token) period")
        )
        try require(
            document.financialIdentifiers.count == 1
                && document.financialIdentifiers.first?.kind == .institutionAccountId
                && document.financialIdentifiers.first?.verificationState == .verified
                && document.financialIdentifiers.first.map {
                    sha256(Data($0.normalizedValue.utf8))
                } == oracle.accountIdentifierSha256,
            .preparation("\(token) account identifier")
        )
        let expectedProfile: (String, String)
        switch oracle.format {
        case "csv": expectedProfile = (AxisBankAccountParser.profileID, AxisBankAccountParser.profileVersion)
        case "pdf": expectedProfile = (AxisBankAccountPDFParser.profileID, AxisBankAccountPDFParser.profileVersion)
        case "xls": expectedProfile = (AxisBankAccountXLSParser.profileID, AxisBankAccountXLSParser.profileVersion)
        default: throw AcceptanceError.oracle("axis-bank format")
        }
        for (index, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let rowToken = "\(token) row \(index + 1)"
            let provenance = try requireValue(transaction.sourceProvenance.first, .preparation("\(rowToken) provenance"))
            try require(
                row.sourceOrder == index + 1
                    && transaction.statementDate?.canonical == row.date
                    && transaction.valueDate == nil
                    && transaction.money.amount == decimal(row.signedAmount)
                    && transaction.runningBalanceMoney?.amount == decimal(row.balance)
                    && bankDirection(transaction) == row.direction
                    && transaction.money.currency.code == "INR"
                    && transaction.runningBalanceMoney?.currency.code == "INR"
                    && transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256
                    && transaction.verifiedAxisUPIEventEvidence?.operation.rawValue == row.upiOperation
                    && transaction.verifiedAxisUPIEventEvidence?.reference == row.upiReference
                    && transaction.verifiedAxisUPIEventEvidence.map {
                        sha256(Data($0.reference.utf8))
                    } == row.upiReferenceSha256
                    && transaction.verifiedAxisUPIEventEvidence?.subtype.rawValue == row.upiSubtype
                    && transaction.sourceProvenance.count == 1
                    && provenance.parserProfileID == expectedProfile.0
                    && provenance.parserProfileVersion == expectedProfile.1
                    && provenance.structuredReferenceDigest == row.chequeReferenceSha256
                    && provenance.sourcePage == (oracle.format == "pdf" ? row.sourcePage : nil)
                    && (oracle.format == "pdf" || provenance.sourceOrdinal == row.sourceOrdinal),
                .preparation("\(rowToken) financial semantics")
            )
            let descriptionDigest = try requireValue(
                row.descriptionSha256,
                .oracle("\(rowToken) narration digest")
            )
            try require(
                sha256(Data(collapseWhitespace(transaction.description).utf8)) == descriptionDigest,
                .preparation("\(rowToken) narration")
            )
        }
        let first = try requireValue(document.transactions.first, .preparation("\(token) opening row"))
        let last = try requireValue(document.transactions.last, .preparation("\(token) closing row"))
        let opening = try requireValue(first.runningBalanceMoney, .preparation("\(token) opening balance")) - first.money
        let zero = try Money(amount: 0, currency: try requireValue(document.bookedCurrency, .preparation("\(token) currency")))
        let debits = try document.transactions.compactMap(\.debitMoney).reduce(zero, +)
        let credits = try document.transactions.compactMap(\.creditMoney).reduce(zero, +)
        try require(
            opening.amount == decimal(oracle.controls.openingBalance)
                && last.runningBalanceMoney?.amount == decimal(oracle.controls.closingBalance)
                && debits.amount == decimal(oracle.controls.debitTotal)
                && credits.amount == decimal(oracle.controls.creditTotal),
            .preparation("\(token) financial controls")
        )
    }

    private func verifyHDFCPrepared(
        _ prepared: PreparedImport,
        oracle: HDFCCarrier,
        token: String
    ) throws {
        let document = prepared.financialDocument
        let format: String = oracle.carrier.lowercased().hasSuffix(".pdf") ? "pdf" : "xls"
        try require(
            prepared.detectedInstitution == .hdfc
                && prepared.detectedDocumentType == .bankAccount
                && document.metadata.fileFormat.rawValue.lowercased() == format
                && document.bookedCurrency?.code == oracle.currency
                && document.financialIdentifiers.count == 1
                && document.financialIdentifiers.first?.kind == .institutionAccountId
                && document.financialIdentifiers.first?.normalizedValue == oracle.account
                && document.declaredStatementPeriod?.start == hdfcDate(oracle.periodStart)
                && document.declaredStatementPeriod?.end == hdfcDate(oracle.periodEnd)
                && document.sourceStatementEvidence?.openingBalance?.amount == decimal(oracle.summary.openingBalance)
                && document.sourceStatementEvidence?.closingBalance?.amount == decimal(oracle.summary.closingBalance),
            .preparation("\(token) HDFC envelope and controls")
        )
        let projection = try StatementFinancialProjection.make(from: document)
        try require(
            projection.hasValidDigest() && projection.eventCount == oracle.rows.count
                && projection.openingBalance.amount == decimal(oracle.summary.openingBalance)
                && projection.closingBalance.amount == decimal(oracle.summary.closingBalance)
                && projection.debitCount == oracle.summary.debitCount
                && projection.creditCount == oracle.summary.creditCount
                && projection.debitTotal.amount == decimal(oracle.summary.debits)
                && projection.creditTotal.amount == decimal(oracle.summary.credits),
            .preparation("\(token) HDFC projection")
        )
        for (index, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let provenance = try requireValue(transaction.sourceProvenance.first,
                                               .preparation("\(token) row \(index + 1) provenance"))
            let signedAmount = row.withdrawal.isEmpty ? decimal(row.deposit) : -decimal(row.withdrawal)
            try require(
                transaction.statementDate == hdfcDate(row.date)
                    && transaction.valueDate == hdfcDate(row.valueDate)
                    && transaction.money.amount == signedAmount
                    && transaction.runningBalanceMoney?.amount == decimal(row.closing)
                    && transaction.reference == (row.reference.isEmpty ? nil : row.reference)
                    && compact(transaction.description) == compact(row.narration)
                    && transaction.money.currency.code == "INR"
                    && provenance.parserProfileID == (format == "pdf"
                        ? HDFCBankAccountPDFParser.profileID : HDFCBankAccountXLSParser.profileID)
                    && provenance.parserProfileVersion == "1"
                    && provenance.sourcePage == (format == "pdf" ? row.physicalPage : nil)
                    && (format == "pdf" || provenance.sourceOrdinal == row.physicalRow),
                .preparation("\(token) row \(index + 1) HDFC semantics")
            )
        }
    }

    private func verifyCBQBankPrepared(
        _ prepared: PreparedImport,
        oracle: CBQBankCarrier,
        token: String
    ) throws {
        let document = prepared.financialDocument
        let identityByKind = Dictionary(uniqueKeysWithValues:
            document.cbqSourceIdentityObservations.map { ($0.kind, $0.pattern) })
        try require(
            prepared.detectedInstitution == .cbq
                && prepared.detectedDocumentType == .bankAccount
                && document.bookedCurrency?.code == "QAR"
                && document.financialIdentifiers.isEmpty
                && document.cbqSourceIdentityObservations.count == 2
                && CBQSourceIdentityObservation.validatePair(document.cbqSourceIdentityObservations)
                && identityByKind[.maskedAccountNumber] == normalizedCBQMask(oracle.maskedAccount)
                && identityByKind[.maskedIBAN] == normalizedCBQMask(oracle.maskedIBAN)
                && document.sourceStatementEvidence?.openingBalance?.amount == decimal(oracle.openingBalance)
                && document.sourceStatementEvidence?.closingBalance?.amount == decimal(oracle.closingBalance)
                && document.sourceStatementEvidence?.statementBoundaryDate
                    == cbqDate(oracle.statementDate.replacingOccurrences(of: " ", with: "-")),
            .preparation("\(token) CBQ-bank envelope and controls")
        )
        for (index, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let provenance = try requireValue(transaction.sourceProvenance.first,
                                               .preparation("\(token) row \(index + 1) provenance"))
            try require(
                transaction.statementDate == cbqDate(row.postingDate)
                    && transaction.money.amount == decimal(row.signedAmount)
                    && transaction.money.currency.code == "QAR"
                    && transaction.runningBalanceMoney?.amount == decimal(row.balance)
                    && compact(transaction.description) == compact(row.description)
                    && provenance.sourceTransactionDate == cbqDate(row.sourceTransactionDate)
                    && provenance.sourcePage == row.sourcePage
                    && provenance.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID
                    && provenance.parserProfileVersion == "1",
                .preparation("\(token) row \(index + 1) CBQ-bank semantics")
            )
        }
    }

    private func verifyAxisCardPrepared(
        _ prepared: PreparedImport,
        oracle: AxisCardRecord,
        token: String
    ) throws {
        let document = prepared.financialDocument
        let evidence = try requireValue(document.cardStatementEvidence,
                                        .preparation("\(token) Axis-card evidence"))
        try require(
            prepared.detectedInstitution == .axis
                && prepared.detectedDocumentType == .creditCard
                && document.bookedCurrency?.code == "INR",
            .preparation("\(token) Axis-card envelope")
        )
        try require(
            try axisControls(evidence) == oracle.controls.filter { $0.key != "statement_generation_date" },
            .preparation("\(token) Axis-card printed controls")
        )
        let annotations = Dictionary(uniqueKeysWithValues: evidence.transactionAnnotations.map {
            ($0.parserTransactionID, $0)
        })
        for (index, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let annotation = try requireValue(annotations[transaction.id],
                                               .preparation("\(token) row \(index + 1) annotation"))
            let provenance = try requireValue(transaction.sourceProvenance.first,
                                               .preparation("\(token) row \(index + 1) provenance"))
            let amount = try transaction.money.canonicalDecimalString()
            let magnitude = amount.hasPrefix("-") ? String(amount.dropFirst()) : amount
            let expectedOriginal = row.originalMerchantMoney.map {
                row.effect == CardLiabilityEffect.decreasesAmountOwed.rawValue
                    ? "-" + ($0.amount ?? "") : ($0.amount ?? "")
            }
            try require(
                transaction.statementDate?.canonical == row.date
                    && transaction.money.currency.code == "INR"
                    && magnitude == row.amount
                    && transaction.cardLiabilityEffect?.rawValue == row.effect
                    && transaction.reference == row.reference
                    && sourceNarrationGlyphs(transaction.description) == sourceNarrationGlyphs(row.narration)
                    && annotation.originalMerchantMoney?.currency.code == row.originalMerchantMoney?.currency
                    && (try annotation.originalMerchantMoney?.canonicalDecimalString()) == expectedOriginal
                    && provenance.parserProfileID == (oracle.format == "xlsx"
                        ? AxisCreditCardXLSXParser.profileID : AxisCreditCardPDFParser.profileID)
                    && provenance.parserProfileVersion == "1"
                    && provenance.structuredReferenceDigest == row.reference.map {
                        sha256(Data($0.utf8))
                    },
                .preparation("\(token) row \(index + 1) Axis-card semantics")
            )
        }
    }

    private func verifyCBQCardPrepared(
        _ prepared: PreparedImport,
        oracle: PrivateCBQOracle,
        token: String
    ) throws {
        let document = prepared.financialDocument
        let evidence = try requireValue(document.cardStatementEvidence,
                                        .preparation("\(token) CBQ-card evidence"))
        try require(
            prepared.detectedInstitution == .cbq
                && prepared.detectedDocumentType == .creditCard
                && prepared.parserName == "CBQ Credit Card PDF"
                && evidence.statementDate == oracle.statementDate
                && evidence.declaredStatementPeriod == oracle.period
                && evidence.summary(code: "due_date")?.date == oracle.dueDate,
            .preparation("\(token) CBQ-card envelope")
        )
        for (code, money) in oracle.summary {
            try require(evidence.summary(code: code)?.money == money,
                        .preparation("\(token) CBQ-card summary \(code)"))
        }
        let annotations = Dictionary(uniqueKeysWithValues: evidence.transactionAnnotations.map {
            ($0.parserTransactionID, $0)
        })
        let sectionOrdinals = Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map {
            ($0.documentScopedSectionID, $0.sourceOrdinal)
        })
        for section in evidence.instrumentSections {
            let expected = try requireValue(
                oracle.sections.first { $0.sourceOrdinal == section.sourceOrdinal },
                .preparation("\(token) CBQ-card section")
            )
            let productionCard = section.sourceIdentityObservations.first {
                $0.kind == .cbqInstrumentMaskedCardNumber && $0.subject == .instrument
            }?.value
            try require(
                section.documentScopedSectionID == "instrument-section-\(expected.sourceOrdinal)"
                    && section.holderLabel == expected.holderLabel
                    && productionCard == expected.card
                    && section.signedNetTotal == expected.total,
                .preparation("\(token) CBQ-card section controls")
            )
        }
        for (index, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let annotation = try requireValue(annotations[transaction.id],
                                               .preparation("\(token) row \(index + 1) annotation"))
            let provenance = try requireValue(transaction.sourceProvenance.first,
                                               .preparation("\(token) row \(index + 1) provenance"))
            // The independent source extractor freezes every physical page.
            // This parser profile deliberately keeps that page in its hidden
            // normalized column rather than publishing it in transaction
            // provenance; the family gate compares that column to this oracle.
            try require(
                provenance.sourceOrdinal == row.sourceOrdinal
                    && row.sourcePage > 0
                    && provenance.sourcePage == nil
                    && provenance.parserProfileID == CBQCreditCardPDFParser.profileID
                    && provenance.parserProfileVersion == CBQCreditCardPDFParser.profileVersion
                    && transaction.statementDate == row.postingDate
                    && transaction.description == row.description
                    && transaction.reference == row.reference
                    && transaction.money == row.postedMoney
                    && annotation.sourceTransactionDate == row.purchaseDate
                    && annotation.liabilityEffect == row.effect
                    && annotation.originalMerchantMoney == row.originalMoney
                    && (annotation.financialScope == .accountLevel) == row.accountLevel
                    && annotation.documentScopedSectionID.flatMap { sectionOrdinals[$0] } == row.sectionOrdinal,
                .preparation("\(token) row \(index + 1) CBQ-card semantics")
            )
        }
    }

    private func verifyAmexPrepared(
        _ prepared: PreparedImport,
        oracle: AmexSource,
        token: String
    ) throws {
        let document = prepared.financialDocument
        let evidence = try requireValue(document.cardStatementEvidence,
                                        .preparation("\(token) Amex evidence"))
        try require(
            prepared.detectedInstitution == .amex
                && prepared.detectedDocumentType == .creditCard
                && document.bookedCurrency?.code == oracle.nativeCurrency
                && document.declaredStatementPeriod?.start.canonical == oracle.statementPeriod.start
                && document.declaredStatementPeriod?.end.canonical == oracle.statementPeriod.end
                && evidence.statementDate?.canonical == oracle.statementDate
                && evidence.summary(code: "due_date")?.date?.canonical == oracle.dueDate
                && evidence.accountSourceIdentityObservations.first?.value
                    == oracle.membershipLiabilityIdentityEvidence.membershipNumberMasked,
            .preparation("\(token) Amex envelope")
        )
        for pair in [
            ("previous_balance", oracle.summary.previousBalance),
            ("new_credits", oracle.summary.newCredits),
            ("new_debits", oracle.summary.newDebits),
            ("new_balance", oracle.summary.newBalance)
        ] {
            try require(
                sourceMoneyMatches(evidence.summary(code: pair.0)?.money, pair.1),
                .preparation("\(token) Amex summary \(pair.0)")
            )
        }
        try require(evidence.instrumentSections.count == oracle.sections.count,
                    .preparation("\(token) Amex section count"))
        for (actual, expected) in zip(evidence.instrumentSections, oracle.sections) {
            try require(
                actual.sourceIdentityObservations.first?.value == expected.accountMasked
                    && expected.accountKeyHash == sha256(Data(expected.accountMasked.utf8))
                    && actual.sourceOrdinal > 0
                    && sourceMoneyMatches(actual.signedNetTotal, expected.oracleCalculated.netActivity),
                .preparation("\(token) Amex section controls")
            )
        }
        let annotations = Dictionary(uniqueKeysWithValues: evidence.transactionAnnotations.map {
            ($0.parserTransactionID, $0)
        })
        for (index, pair) in zip(document.transactions, oracle.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let annotation = try requireValue(annotations[transaction.id],
                                               .preparation("\(token) row \(index + 1) annotation"))
            let provenance = try requireValue(transaction.sourceProvenance.first,
                                               .preparation("\(token) row \(index + 1) provenance"))
            let effect: CardLiabilityEffect = row.creditDebitLiabilityDirection == "liability_decrease"
                ? .decreasesAmountOwed : .increasesAmountOwed
            try require(
                provenance.sourceOrdinal == row.globalSourceOrdinal
                    && provenance.sourcePage == row.page
                    && provenance.parserProfileID == AmericanExpressCreditCardPDFParser.profileID
                    && provenance.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion
                    && transaction.statementDate?.canonical == row.postingDate
                    && sha256(Data(transaction.description.utf8))
                        == row.descriptionSourceRawSegmentsSHA256
                    && sha256(Data(transaction.description
                        .replacingOccurrences(of: "\n", with: " ").utf8))
                        == sha256(Data(row.descriptionSourceExact.utf8))
                    && transaction.reference == row.sourceReference
                    && sourceMoneyMatches(transaction.money, signed(row.postedNativeMoney, effect: effect))
                    && annotation.sourceTransactionDate.canonical == row.transactionDate
                    && annotation.liabilityEffect == effect
                    && sourceMoneyMatches(annotation.originalMerchantMoney,
                                          row.originalForeignMoney.map { signed($0, effect: effect) })
                    && (annotation.financialScope == .accountLevel) == (row.financialScope == "account_level"),
                .preparation("\(token) row \(index + 1) Amex semantics")
            )
        }
    }

    private func verifySalaryPrepared(
        _ prepared: PreparedImport,
        oracle: SalarySource,
        token: String
    ) throws {
        let evidence = try requireValue(prepared.financialDocument.salaryStatementEvidence,
                                        .preparation("\(token) salary evidence"))
        let kind: SalaryDocumentKind
        switch oracle.kind {
        case "monthlySalary": kind = .regularSalary
        case "adhocPayment": kind = .adhocPayment
        case "annualDiscretionaryBonus": kind = .annualDiscretionaryBonus
        default: throw AcceptanceError.oracle("salary kind")
        }
        try require(
            prepared.detectedInstitution == .unknown
                && prepared.detectedDocumentType == .salarySlip
                && prepared.parserName == QatarAirwaysSalaryPDFParser.name
                && prepared.financialDocument.transactions.isEmpty
                && prepared.financialDocument.financialIdentifiers.isEmpty
                && evidence.sourceAuthority == .qatarAirways
                && evidence.profileID == SalaryStatementEvidence.profileID
                && evidence.profileVersion == SalaryStatementEvidence.profileVersion
                && evidence.financialPeriod.canonical == oracle.period
                && evidence.printDate?.canonical == salaryPrintDate(oracle.printDate).canonical
                && evidence.kind == kind
                && evidence.nativeCurrency.code == oracle.currency
                && (try evidence.printedEarningsTotal.canonicalDecimalString()) == oracle.printedControls.totalEarnings
                && (try evidence.printedDeductionsTotal?.canonicalDecimalString()) == oracle.printedControls.totalDeductions
                && (try evidence.printedNet.canonicalDecimalString()) == oracle.printedControls.netPay
                && (try evidence.printedPaymentTotal.canonicalDecimalString()) == oracle.printedControls.paymentTotal,
            .preparation("\(token) salary envelope and controls")
        )
        try verifySalaryComponents(evidence.earnings, oracle.earnings, token: token)
        try verifySalaryComponents(evidence.deductions, oracle.deductions, token: token)
    }

    private func verifySalaryComponents(
        _ actual: [SalaryComponent],
        _ expected: [SalaryComponentSource],
        token: String
    ) throws {
        try require(actual.count == expected.count, .preparation("\(token) salary component count"))
        for (index, pair) in zip(actual, expected).enumerated() {
            try require(
                pair.0.sourceOrdinal == pair.1.ordinal + 1
                    && pair.0.sourceLabel == pair.1.label
                    && pair.0.money.currency.code == "QAR"
                    && (try pair.0.money.canonicalDecimalString()) == pair.1.amount,
                .preparation("\(token) salary component \(index + 1)")
            )
        }
    }

    private func axisControls(_ evidence: CardStatementEvidence) throws -> [String: String] {
        var result: [String: String] = [:]
        result["statement_period_start"] = evidence.declaredStatementPeriod?.start.canonical
        result["statement_period_end"] = evidence.declaredStatementPeriod?.end.canonical
        result["selected_statement_month"] = evidence.selectedStatementMonth?.canonical
        for pair in [("previous_balance", "opening_balance"),
                     ("axis_total_payment_due", "total_payment_due")] {
            if let money = evidence.summary(code: pair.0)?.money {
                result[pair.1] = try money.canonicalDecimalString()
            }
        }
        result["payment_due_date"] = evidence.summary(code: "due_date")?.date?.canonical
        return result
    }

    private func sourceMoneyMatches(_ actual: Money?, _ expected: SourceMoney?) -> Bool {
        guard let actual, let expected else { return actual == nil && expected == nil }
        if let minor = expected.minorUnits {
            return actual.currency.code == expected.currency && (try? actual.minorUnits()) == minor
        }
        return actual.currency.code == expected.currency
            && (try? actual.canonicalDecimalString()) == expected.amount
    }

    private func signed(_ money: SourceMoney, effect: CardLiabilityEffect) -> SourceMoney {
        let sign: Int64 = effect == .decreasesAmountOwed ? -1 : 1
        return SourceMoney(currency: money.currency,
                           minorUnits: money.minorUnits.map { $0 * sign },
                           amount: money.amount.map { effect == .decreasesAmountOwed ? "-" + $0 : $0 })
    }

    private func bankDirection(_ transaction: Transaction) -> String {
        switch (transaction.debitMoney, transaction.creditMoney) {
        case (.some, nil): "debit"
        case (nil, .some): "credit"
        default: "invalid"
        }
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value.replacingOccurrences(of: ",", with: ""),
                locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func hdfcDate(_ value: String) throws -> StatementDate {
        let pieces = value.split(separator: "/")
        guard pieces.count == 3,
              let day = Int(pieces[0]), let month = Int(pieces[1]),
              let year = Int(pieces[2]) else {
            throw AcceptanceError.oracle("HDFC date")
        }
        return try StatementDate(year: year < 100 ? year + 2_000 : year, month: month, day: day)
    }

    private func salaryPrintDate(_ value: String) throws -> StatementDate {
        let pieces = value.split(separator: "-")
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard pieces.count == 3, let day = Int(pieces[0]),
              let month = months.firstIndex(of: pieces[1].lowercased()),
              let year = Int(pieces[2]) else {
            throw AcceptanceError.oracle("salary print date")
        }
        return try StatementDate(year: year, month: month + 1, day: day)
    }

    private func compact(_ value: String) -> String {
        value.filter { !$0.isWhitespace }
    }

    private func normalizedCBQMask(_ value: String) -> String {
        String(value.uppercased().compactMap { character -> Character? in
            if character == "*" { return "X" }
            return character.isLetter || character.isNumber ? character : nil
        })
    }

    private func collapseWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func sourceNarrationGlyphs(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .filter { !$0.isWhitespace }
    }

    private func decodeOracle<T: Decodable>(
        _ url: URL,
        family: Family,
        snakeCase: Bool,
        digests: inout [Family: String]
    ) throws -> T {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let digest = sha256(data)
        try require(digest == Self.frozenOracleDigests[family], .oracle("\(family.rawValue) file digest"))
        digests[family] = digest
        let decoder = JSONDecoder()
        if snakeCase { decoder.keyDecodingStrategy = .convertFromSnakeCase }
        return try decoder.decode(T.self, from: data)
    }

    private func financialFiles(
        _ root: URL,
        extensions: Set<String>,
        excludingArchiveDirectories: Bool = false
    ) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            guard extensions.contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            if excludingArchiveDirectories {
                let excluded = url.deletingLastPathComponent().pathComponents.contains { component in
                    let compact = component.lowercased().filter { $0.isLetter || $0.isNumber }
                    return compact.contains("archive") || compact.contains("ignore")
                }
                if excluded { continue }
            }
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    private func sourcesByDigest(
        files: [URL],
        expectedCount: Int,
        family: Family
    ) throws -> [String: URL] {
        try require(files.count == expectedCount, .source("\(family.rawValue) file count"))
        var result: [String: URL] = [:]
        for url in files {
            let digest = try sourceDigest(url)
            try require(result[digest] == nil, .source("\(family.rawValue) duplicate bytes"))
            result[digest] = url
        }
        return result
    }

    private func sourceByteCount(_ url: URL) throws -> Int {
        try Data(contentsOf: url, options: [.mappedIfSafe]).count
    }

    private func sourceDigest(_ url: URL) throws -> String {
        sha256(try Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    private func cbqCardOracleProjection(
        sourceSHA256: String,
        oracle: PrivateCBQOracle
    ) throws -> String {
        var lines = [
            sourceSHA256,
            oracle.statementDate.canonical,
            oracle.period.start.canonical,
            oracle.period.end.canonical,
            oracle.dueDate.canonical
        ]
        lines += try oracle.summary.keys.sorted().map { key in
            "summary|\(key)|\(try oracle.summary[key]!.canonicalDecimalString())|\(oracle.summary[key]!.currency.code)"
        }
        lines += try oracle.sections.sorted { $0.sourceOrdinal < $1.sourceOrdinal }.map { section in
            "section|\(section.sourceOrdinal)|\(sha256(Data(section.label.utf8)))|\(section.holderLabel.map { sha256(Data($0.utf8)) } ?? "")|\(sha256(Data(section.card.utf8)))|\(section.total.currency.code)|\(try section.total.canonicalDecimalString())"
        }
        lines += try oracle.rows.map { row in
            let original = try row.originalMoney?.canonicalDecimalString() ?? ""
            return [
                "row", String(row.sourceOrdinal), String(row.sourcePage), row.postingDate.canonical,
                row.purchaseDate.canonical, sha256(Data(row.description.utf8)),
                row.reference.map { sha256(Data($0.utf8)) } ?? "", row.effect.rawValue,
                row.postedMoney.currency.code, try row.postedMoney.canonicalDecimalString(),
                row.originalMoney?.currency.code ?? "", original,
                row.accountLevel ? "account" : "instrument", String(row.sectionOrdinal)
            ].joined(separator: "|")
        }
        return lines.joined(separator: "\n")
    }

    private func cbqDate(_ value: String) throws -> StatementDate {
        let pieces = value.split(separator: "-")
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard pieces.count == 3,
              let day = Int(pieces[0]),
              let month = months.firstIndex(of: pieces[1].lowercased()),
              let shortYear = Int(pieces[2]) else {
            throw AcceptanceError.oracle("cbq date")
        }
        return try StatementDate(year: shortYear < 100 ? shortYear + 2_000 : shortYear,
                                 month: month + 1, day: day)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func require(_ condition: Bool, _ error: AcceptanceError) throws {
        #expect(condition)
        guard condition else { throw error }
    }

    private func requireValue<T>(_ value: T?, _ error: AcceptanceError) throws -> T {
        try require(value != nil, error)
        return value!
    }

    private enum AcceptanceError: Error, CustomStringConvertible {
        case context(String)
        case oracle(String)
        case source(String)
        case preparation(String)
        case campaign(String)

        var description: String {
            switch self {
            case .context(let field): "Global authentic context: \(field)"
            case .oracle(let field): "Global authentic oracle: \(field)"
            case .source(let field): "Global authentic source: \(field)"
            case .preparation(let field): "Global authentic preparation: \(field)"
            case .campaign(let field): "Global authentic campaign: \(field)"
            }
        }
    }
}
