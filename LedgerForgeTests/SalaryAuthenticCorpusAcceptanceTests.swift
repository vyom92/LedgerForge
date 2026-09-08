import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Complete private authentic corpus acceptance. This suite never constructs,
/// mutates, sanitizes, or substitutes a financial statement. Every statement-
/// dependent assertion starts with an immutable original PDF and proceeds
/// through the ordinary ImportEngine prepare/validate/confirm path.
@Suite(
    .enabled(
        if: salaryAuthenticAcceptanceContextConfigured,
        "Requires the private Salary originals and frozen independent source oracle"
    )
)
@MainActor
struct SalaryAuthenticCorpusAcceptanceTests {
    private struct Oracle: Decodable {
        let oracleSchema: String
        let oracleMethod: String
        let sourceRoot: String
        let statements: [Statement]
    }

    private struct Statement: Decodable {
        let sourceBasename: String
        let sourceSha256: String
        let sourceSize: Int
        let pageCount: Int
        let encrypted: Bool
        let extractedTextSha256: String
        let extractedBboxSha256: String
        let sourceIdentity: SourceIdentity
        let documentTitle: String
        let period: String
        let printDate: String
        let kind: String
        let currency: String
        let earnings: [Component]
        let deductions: [Component]
        let printedControls: PrintedControls
        let reconciliation: Reconciliation

        var sourceToken: String { String(sourceSha256.prefix(12)) }
    }

    private struct SourceIdentity: Decodable, Hashable {
        let employer: String
        let employeeName: String
        let employeeNumber: String
        let position: String
        let paymentIban: String
    }

    private struct Component: Decodable {
        let ordinal: Int
        let label: String
        let amount: String
    }

    private struct PrintedControls: Decodable {
        let totalEarnings: String
        let totalDeductions: String?
        let netPay: String
        let paymentTotal: String
    }

    private struct Reconciliation: Decodable {
        let earningsSumMatches: Bool
        let deductionsSumMatchesOrAbsent: Bool
        let netMatchesEarningsLessDeductions: Bool
        let paymentTotalMatchesNet: Bool

        var allPass: Bool {
            earningsSumMatches
                && deductionsSumMatchesOrAbsent
                && netMatchesEarningsLessDeductions
                && paymentTotalMatchesNet
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

    private enum AcceptanceError: Error, CustomStringConvertible {
        case mismatch(sourceToken: String, field: String)
        case campaign(provider: String, order: String, field: String)

        var description: String {
            switch self {
            case .mismatch(let sourceToken, let field):
                return "Salary source \(sourceToken) mismatch: \(field)"
            case .campaign(let provider, let order, let field):
                return "Salary campaign \(provider)/\(order) mismatch: \(field)"
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusUsesOrdinaryImportPersistenceReplayAndReopen() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(
            fileURLWithPath: try #require(environment["LEDGERFORGE_PRIVATE_SALARY_ORIGINALS_ROOT"]),
            isDirectory: true
        )
        let oracleURL = URL(
            fileURLWithPath: try #require(environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_FILE"])
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let oracle = try decoder.decode(Oracle.self, from: Data(contentsOf: oracleURL))
        try verifyOracleContract(oracle, root: root)

        let startingDigests = try sourceDigests(oracle.statements, root: root)
        for providerKind in ProviderKind.allCases {
            for order in CampaignOrder.allCases {
                try await runCampaign(
                    providerKind: providerKind,
                    order: order,
                    oracle: oracle,
                    root: root
                )
            }
        }
        let endingDigests = try sourceDigests(oracle.statements, root: root)
        guard endingDigests == startingDigests else {
            throw AcceptanceError.campaign(
                provider: "all",
                order: "all",
                field: "authentic source bytes changed"
            )
        }
    }

    private func runCampaign(
        providerKind: ProviderKind,
        order: CampaignOrder,
        oracle: Oracle,
        root: URL
    ) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Salary-Authentic-\(UUID().uuidString)", isDirectory: true)
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
        let workspace = "salary-authentic-\(providerKind.rawValue)-\(order.rawValue)-\(UUID().uuidString)"
        let stores = SalaryAcceptanceRuntimeStores()
        let hydrator = makeHydrator(provider: provider, workspace: workspace, stores: stores)
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry()),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspace,
                    workspaceName: "Authentic Salary acceptance"
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

        let ordered = orderedStatements(oracle.statements, order: order)
        let cancellationSource = try #require(ordered.first)
        let cancelled = try await engine.prepareImport(
            from: root.appendingPathComponent(cancellationSource.sourceBasename)
        )
        try verifyPrepared(cancelled, against: cancellationSource)
        engine.cancelPreparedImport(cancelled)
        try verifyNoAcceptedResidue(provider: provider, workspace: workspace)

        for statement in ordered {
            let prepared = try await engine.prepareImport(
                from: root.appendingPathComponent(statement.sourceBasename)
            )
            defer { engine.cancelPreparedImport(prepared) }
            try verifyPrepared(prepared, against: statement)
            let result = await engine.commitPreparedImport(prepared)
            guard result.persisted,
                  result.validationPassed,
                  result.isSalaryImport,
                  result.transactionCount == 0,
                  result.previousImport == nil,
                  result.errorMessage == nil,
                  result.hydrationOutcome == .committedAndHydrated else {
                throw AcceptanceError.mismatch(
                    sourceToken: statement.sourceToken,
                    field: "ordinary confirmation result"
                )
            }
        }

        try verifyPersistedAndHydrated(
            provider: provider,
            workspace: workspace,
            stores: stores,
            oracle: oracle,
            expectedAttemptCount: 20
        )
        let stableSalary = try provider.salaryRepo.snapshot(workspaceId: workspace)

        for statement in ordered.reversed() {
            let prepared = try await engine.prepareImport(
                from: root.appendingPathComponent(statement.sourceBasename)
            )
            defer { engine.cancelPreparedImport(prepared) }
            try verifyPrepared(prepared, against: statement)
            guard prepared.advisoryPreviousImport != nil else {
                throw AcceptanceError.mismatch(
                    sourceToken: statement.sourceToken,
                    field: "exact replay advisory"
                )
            }
            let replay = await engine.commitPreparedImport(prepared)
            guard !replay.persisted,
                  replay.validationPassed,
                  replay.isSalaryImport,
                  replay.transactionCount == 0,
                  replay.previousImport != nil,
                  replay.hydrationOutcome == .notRequired else {
                throw AcceptanceError.mismatch(
                    sourceToken: statement.sourceToken,
                    field: "exact replay result"
                )
            }
            guard try provider.salaryRepo.snapshot(workspaceId: workspace) == stableSalary else {
                throw AcceptanceError.mismatch(
                    sourceToken: statement.sourceToken,
                    field: "exact replay changed accepted salary state"
                )
            }
        }

        try verifyPersistedAndHydrated(
            provider: provider,
            workspace: workspace,
            stores: stores,
            oracle: oracle,
            expectedAttemptCount: 40
        )

        guard let sqlite else { return }
        try sqlite.database.checkpointAndClose()
        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        let reopenedStores = SalaryAcceptanceRuntimeStores()
        let reopenedHydrator = makeHydrator(
            provider: reopenedProvider,
            workspace: workspace,
            stores: reopenedStores
        )
        let staged = try reopenedHydrator.stageHydration()
        try verifyHydrationSnapshot(
            staged,
            oracle: oracle,
            expectedAttemptCount: 40,
            providerKind: providerKind,
            order: order
        )
        guard reopenedStores.salaries.statements.isEmpty,
              reopenedStores.sessions.importSessions.isEmpty else {
            throw AcceptanceError.campaign(
                provider: providerKind.rawValue,
                order: order.rawValue,
                field: "reopen stage published before explicit hydration"
            )
        }
        reopenedHydrator.publish(staged)
        try verifyRuntimeStores(
            reopenedStores,
            oracle: oracle,
            expectedAttemptCount: 40,
            providerKind: providerKind,
            order: order
        )
        try reopenedSQLite.database.checkpointAndClose()
    }

    private func verifyOracleContract(_ oracle: Oracle, root: URL) throws {
        guard oracle.oracleSchema == "ledgerforge.salary.source-only.private.v1",
              oracle.oracleMethod.contains("Poppler native text and bbox extraction"),
              oracle.statements.count == 20,
              Set(oracle.statements.map(\.sourceSha256)).count == 20,
              oracle.statements.reduce(0, { $0 + $1.pageCount }) == 34,
              oracle.statements.filter({ $0.pageCount == 1 }).count == 6,
              oracle.statements.filter({ $0.pageCount == 2 }).count == 14,
              oracle.statements.allSatisfy({ !$0.encrypted }),
              oracle.statements.reduce(0, { $0 + $1.earnings.count }) == 158,
              oracle.statements.reduce(0, { $0 + $1.deductions.count }) == 100,
              oracle.statements.filter({ $0.kind == "monthlySalary" }).count == 18,
              oracle.statements.filter({ $0.kind == "adhocPayment" }).count == 1,
              oracle.statements.filter({ $0.kind == "annualDiscretionaryBonus" }).count == 1,
              oracle.statements.allSatisfy({ $0.currency == "QAR" && $0.reconciliation.allPass }) else {
            throw AcceptanceError.campaign(
                provider: "oracle",
                order: "source-only",
                field: "frozen oracle contract"
            )
        }

        let identities = Set(oracle.statements.map(\.sourceIdentity))
        guard identities.count == 1,
              let identity = identities.first,
              identity.employer == "Qatar Airways",
              !identity.employeeName.isEmpty,
              !identity.employeeNumber.isEmpty,
              !identity.position.isEmpty,
              identity.paymentIban.hasPrefix("QA") else {
            throw AcceptanceError.campaign(
                provider: "oracle",
                order: "source-only",
                field: "source identity controls"
            )
        }

        let discovered = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "pdf" }
        .map(\.lastPathComponent)
        guard discovered.count == 20,
              Set(discovered) == Set(oracle.statements.map(\.sourceBasename)) else {
            throw AcceptanceError.campaign(
                provider: "oracle",
                order: "source-only",
                field: "complete authentic root enumeration"
            )
        }
        for statement in oracle.statements {
            let url = root.appendingPathComponent(statement.sourceBasename)
            guard try sourceDigest(url) == statement.sourceSha256 else {
                throw AcceptanceError.mismatch(
                    sourceToken: statement.sourceToken,
                    field: "source-byte digest"
                )
            }
        }
    }

    private func verifyPrepared(_ prepared: PreparedImport, against expected: Statement) throws {
        let digest = try prepared.sourceSnapshot.withBytes { data in
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        guard digest == expected.sourceSha256,
              prepared.sourceSnapshot.byteCount == Int64(expected.sourceSize),
              prepared.detectedInstitution == .unknown,
              prepared.detectedDocumentType == .salarySlip,
              prepared.parserName == QatarAirwaysSalaryPDFParser.name,
              prepared.financialDocument.metadata.institution == .unknown,
              prepared.financialDocument.metadata.documentType == .salarySlip,
              prepared.financialDocument.metadata.fileFormat == .pdf,
              prepared.financialDocument.transactions.isEmpty,
              prepared.financialDocument.financialIdentifiers.isEmpty,
              prepared.validation.passed,
              prepared.transactionCount == 0 else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "ordinary preparation routing/validation"
            )
        }
        let evidence = try #require(prepared.financialDocument.salaryStatementEvidence)
        try verifyEvidence(evidence, against: expected)
        guard prepared.financialDocument.sourceDocument.rowCount
                == expected.earnings.count + expected.deductions.count,
              prepared.financialDocument.sourceDocument.parserVersion
                == SalaryStatementEvidence.profileVersion else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "source-document provenance"
            )
        }
    }

    private func verifyEvidence(_ actual: SalaryStatementEvidence, against expected: Statement) throws {
        let expectedKind: SalaryDocumentKind
        switch expected.kind {
        case "monthlySalary": expectedKind = .regularSalary
        case "adhocPayment": expectedKind = .adhocPayment
        case "annualDiscretionaryBonus": expectedKind = .annualDiscretionaryBonus
        default:
            throw AcceptanceError.mismatch(sourceToken: expected.sourceToken, field: "oracle kind")
        }
        let expectedPrintDate = try canonicalPrintDate(expected.printDate)
        guard actual.sourceAuthority == .qatarAirways,
              actual.profileID == SalaryStatementEvidence.profileID,
              actual.profileVersion == SalaryStatementEvidence.profileVersion,
              actual.financialPeriod.canonical == expected.period,
              actual.printDate?.canonical == expectedPrintDate,
              actual.kind == expectedKind,
              actual.nativeCurrency.code == expected.currency,
              try actual.printedEarningsTotal.canonicalDecimalString()
                == expected.printedControls.totalEarnings,
              try actual.printedDeductionsTotal?.canonicalDecimalString()
                == expected.printedControls.totalDeductions,
              try actual.printedNet.canonicalDecimalString() == expected.printedControls.netPay,
              try actual.printedPaymentTotal.canonicalDecimalString()
                == expected.printedControls.paymentTotal else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "salary semantic projection"
            )
        }
        try verifyComponents(actual.earnings, expected.earnings, sourceToken: expected.sourceToken)
        try verifyComponents(actual.deductions, expected.deductions, sourceToken: expected.sourceToken)
    }

    private func verifyComponents(
        _ actual: [SalaryComponent],
        _ expected: [Component],
        sourceToken: String
    ) throws {
        guard actual.count == expected.count else {
            throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "component count")
        }
        for (actualComponent, expectedComponent) in zip(actual, expected) {
            guard actualComponent.sourceOrdinal == expectedComponent.ordinal + 1,
                  actualComponent.sourceLabel == expectedComponent.label,
                  actualComponent.money.currency.code == "QAR",
                  try actualComponent.money.canonicalDecimalString() == expectedComponent.amount else {
                throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "ordered component")
            }
        }
    }

    private func verifyPersistedAndHydrated(
        provider: DatabaseProvider,
        workspace: String,
        stores: SalaryAcceptanceRuntimeStores,
        oracle: Oracle,
        expectedAttemptCount: Int
    ) throws {
        let snapshot = try provider.salaryRepo.snapshot(workspaceId: workspace)
        guard snapshot.statements.count == 20 else {
            throw AcceptanceError.campaign(
                provider: provider.persistenceState.displayName,
                order: "active",
                field: "salary statement count"
            )
        }
        let expectedByDigest = Dictionary(
            uniqueKeysWithValues: oracle.statements.map { ($0.sourceSha256, $0) }
        )
        for statement in snapshot.statements {
            let expected = try #require(expectedByDigest[statement.sourceFingerprintDigest])
            try verifyPersisted(statement, against: expected)
        }
        let staged = try makeHydrator(
            provider: provider,
            workspace: workspace,
            stores: stores
        ).stageHydration()
        try verifyHydrationSnapshot(
            staged,
            oracle: oracle,
            expectedAttemptCount: expectedAttemptCount,
            providerKind: provider.persistenceState.isDurable ? .sqlite : .inMemory,
            order: .deterministicMixed
        )
        try verifyRuntimeStores(
            stores,
            oracle: oracle,
            expectedAttemptCount: expectedAttemptCount,
            providerKind: provider.persistenceState.isDurable ? .sqlite : .inMemory,
            order: .deterministicMixed
        )
    }

    private func verifyPersisted(_ actual: SalaryStatementDTO, against expected: Statement) throws {
        let projectedKind = try expectedKind(expected.kind)
        let expectedPrintDate = try canonicalPrintDate(expected.printDate)
        guard actual.sourceFingerprintAlgorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
              actual.sourceFingerprintDigest == expected.sourceSha256,
              actual.sourceAuthorityCode == SalarySourceAuthority.qatarAirways.rawValue,
              actual.parserProfileId == SalaryStatementEvidence.profileID,
              actual.parserProfileVersion == SalaryStatementEvidence.profileVersion,
              actual.financialPeriodISO == expected.period,
              actual.printDateISO == expectedPrintDate,
              actual.documentKindCode == projectedKind.rawValue,
              actual.nativeCurrency == expected.currency,
              actual.printedEarningsDecimal == expected.printedControls.totalEarnings,
              actual.printedDeductionsDecimal == expected.printedControls.totalDeductions,
              actual.printedNetDecimal == expected.printedControls.netPay,
              actual.printedPaymentDecimal == expected.printedControls.paymentTotal else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "durable statement projection"
            )
        }
        let actualEarnings = actual.components
            .filter { $0.sideCode == SalaryComponentSide.earning.rawValue }
            .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        let actualDeductions = actual.components
            .filter { $0.sideCode == SalaryComponentSide.deduction.rawValue }
            .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        try verifyPersistedComponents(
            actualEarnings,
            expected.earnings,
            sourceToken: expected.sourceToken
        )
        try verifyPersistedComponents(
            actualDeductions,
            expected.deductions,
            sourceToken: expected.sourceToken
        )
    }

    private func verifyPersistedComponents(
        _ actual: [SalaryComponentDTO],
        _ expected: [Component],
        sourceToken: String
    ) throws {
        guard actual.count == expected.count else {
            throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "durable component count")
        }
        for (actualComponent, expectedComponent) in zip(actual, expected) {
            guard actualComponent.sourceOrdinal == expectedComponent.ordinal + 1,
                  actualComponent.sourceLabel == expectedComponent.label,
                  actualComponent.amountCurrency == "QAR",
                  actualComponent.amountDecimal == expectedComponent.amount else {
                throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "durable ordered component")
            }
        }
    }

    private func verifyHydrationSnapshot(
        _ snapshot: RepositoryRuntimeSnapshot,
        oracle: Oracle,
        expectedAttemptCount: Int,
        providerKind: ProviderKind,
        order: CampaignOrder
    ) throws {
        guard snapshot.accounts.isEmpty,
              snapshot.transactions.isEmpty,
              snapshot.salaryStatements.count == 20,
              snapshot.importSessions.count == 20,
              snapshot.importAttempts.count == expectedAttemptCount else {
            throw AcceptanceError.campaign(
                provider: providerKind.rawValue,
                order: order.rawValue,
                field: "canonical hydration snapshot counts"
            )
        }
        try verifyHydratedStatements(snapshot.salaryStatements, oracle: oracle)
    }

    private func verifyRuntimeStores(
        _ stores: SalaryAcceptanceRuntimeStores,
        oracle: Oracle,
        expectedAttemptCount: Int,
        providerKind: ProviderKind,
        order: CampaignOrder
    ) throws {
        guard stores.accounts.accounts.isEmpty,
              stores.transactions.transactions.isEmpty,
              stores.salaries.statements.count == 20,
              stores.sessions.importSessions.count == 20,
              stores.attempts.attempts.count == expectedAttemptCount else {
            throw AcceptanceError.campaign(
                provider: providerKind.rawValue,
                order: order.rawValue,
                field: "published runtime store counts"
            )
        }
        try verifyHydratedStatements(stores.salaries.statements, oracle: oracle)
    }

    private func verifyHydratedStatements(_ actual: [SalaryStatement], oracle: Oracle) throws {
        let expectedByDigest = Dictionary(
            uniqueKeysWithValues: oracle.statements.map { ($0.sourceSha256, $0) }
        )
        guard Set(actual.map(\.fingerprintDigest)) == Set(expectedByDigest.keys) else {
            throw AcceptanceError.campaign(
                provider: "hydration",
                order: "semantic",
                field: "source identity set"
            )
        }
        for statement in actual {
            let expected = try #require(expectedByDigest[statement.fingerprintDigest])
            guard statement.fingerprintAlgorithm
                    == DocumentFingerprintDTO.sourceBytesSHA256Algorithm else {
                throw AcceptanceError.mismatch(
                    sourceToken: expected.sourceToken,
                    field: "hydrated fingerprint algorithm"
                )
            }
            try verifyEvidence(statement.evidence, against: expected)
        }
    }

    private func verifyNoAcceptedResidue(
        provider: DatabaseProvider,
        workspace: String
    ) throws {
        let hydration = try makeHydrator(
            provider: provider,
            workspace: workspace,
            stores: SalaryAcceptanceRuntimeStores()
        ).stageHydration()
        guard try provider.salaryRepo.snapshot(workspaceId: workspace).statements.isEmpty,
              hydration.accounts.isEmpty,
              hydration.transactions.isEmpty,
              hydration.salaryStatements.isEmpty,
              hydration.importSessions.isEmpty,
              hydration.importAttempts.isEmpty else {
            throw AcceptanceError.campaign(
                provider: provider.persistenceState.displayName,
                order: "cancel",
                field: "accepted residue after cancellation"
            )
        }
    }

    private func makeHydrator(
        provider: DatabaseProvider,
        workspace: String,
        stores: SalaryAcceptanceRuntimeStores
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

    private func orderedStatements(
        _ statements: [Statement],
        order: CampaignOrder
    ) -> [Statement] {
        let chronological = statements.sorted {
            ($0.period, $0.printDate, $0.sourceSha256)
                < ($1.period, $1.printDate, $1.sourceSha256)
        }
        switch order {
        case .chronological:
            return chronological
        case .reverse:
            return Array(chronological.reversed())
        case .deterministicMixed:
            let even = chronological.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? $0.element : nil }
            let odd = chronological.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? nil : $0.element }
            return even + Array(odd.reversed())
        }
    }

    private func sourceDigests(
        _ statements: [Statement],
        root: URL
    ) throws -> [String: String] {
        try Dictionary(uniqueKeysWithValues: statements.map { statement in
            let url = root.appendingPathComponent(statement.sourceBasename)
            return (statement.sourceSha256, try sourceDigest(url))
        })
    }

    private func sourceDigest(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func canonicalPrintDate(_ value: String) throws -> String {
        let pieces = value.split(separator: "-")
        guard pieces.count == 3,
              let day = Int(pieces[0]),
              let month = monthNumber(String(pieces[1])),
              let year = Int(pieces[2]) else {
            throw AcceptanceError.campaign(
                provider: "oracle",
                order: "source-only",
                field: "print date"
            )
        }
        return try StatementDate(year: year, month: month, day: day).canonical
    }

    private func monthNumber(_ value: String) -> Int? {
        let names = [
            "jan", "feb", "mar", "apr", "may", "jun",
            "jul", "aug", "sep", "oct", "nov", "dec"
        ]
        return names.firstIndex(of: value.lowercased()).map { $0 + 1 }
    }

    private func expectedKind(_ value: String) throws -> SalaryDocumentKind {
        switch value {
        case "monthlySalary": return .regularSalary
        case "adhocPayment": return .adhocPayment
        case "annualDiscretionaryBonus": return .annualDiscretionaryBonus
        default:
            throw AcceptanceError.campaign(
                provider: "oracle",
                order: "source-only",
                field: "document kind"
            )
        }
    }
}

private let salaryAuthenticAcceptanceContextConfigured: Bool = {
    let environment = ProcessInfo.processInfo.environment
    guard let root = environment["LEDGERFORGE_PRIVATE_SALARY_ORIGINALS_ROOT"],
          !root.isEmpty,
          FileManager.default.fileExists(atPath: root),
          let oracle = environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_FILE"],
          !oracle.isEmpty,
          FileManager.default.fileExists(atPath: oracle) else {
        return false
    }
    return true
}()

@MainActor
private final class SalaryAcceptanceRuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let categories = CategoryStore()
    let cards = CardStore()
    let salaries = SalaryStore()
    let fundingPlans = FundingPlanStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
}
