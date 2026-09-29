import CryptoKit
import Darwin
import Foundation
import PDFKit
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
        let oracleBytes: Data
        if let path = environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_PIPE"] {
            var info = stat()
            guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFIFO, info.st_uid == getuid() else {
                throw AcceptanceError.campaign(provider: "oracle", order: "source-only", field: "RAM transport")
            }
            let pipe = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            defer { try? pipe.close() }
            oracleBytes = try pipe.readToEnd() ?? Data()
            guard !oracleBytes.isEmpty, oracleBytes.count <= 64 * 1_024 * 1_024 else {
                throw AcceptanceError.campaign(provider: "oracle", order: "source-only", field: "RAM transport size")
            }
        } else {
            // Historical file-backed campaigns are retained; current source
            // processing uses the RAM transport above and unchanged originals.
            let oracleURL = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_FILE"]))
            oracleBytes = try Data(contentsOf: oracleURL)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let oracle = try decoder.decode(Oracle.self, from: oracleBytes)
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

    /// Gmail qualification has no file-backed source oracle.  It builds the two
    /// regular-payslip expectations from the exact original bytes in RAM using
    /// PDFKit's native text plus positioned word selections.  It deliberately
    /// does not invoke PDFDocumentReader, RawDocument, a normalizer, or a
    /// production parser while deriving those expectations.
    func qualifyGmailOriginals(
        _ originals: [(source: GmailInboxSource, bytes: Data)]
    ) async throws {
        guard !originals.isEmpty else {
            throw AcceptanceError.campaign(
                provider: "gmail",
                order: "source-only",
                field: "observed regular payslip selection"
            )
        }

        // Build every source-only expectation before constructing an engine or
        // beginning any production preparation.
        let expected = try originals.map {
            try GmailSalarySourceOracle.statement(source: $0.source, bytes: $0.bytes)
        }
        guard Set(expected.map(\.sourceSha256)).count == expected.count else {
            throw AcceptanceError.campaign(
                provider: "gmail",
                order: "source-only",
                field: "distinct original byte identities"
            )
        }

        for (original, statement) in zip(originals, expected) {
            for providerKind in ProviderKind.allCases {
                try await qualifyGmailOriginal(
                    original,
                    expected: statement,
                    providerKind: providerKind
                )
            }
        }
    }

    /// Opaque source-bound comparisons for the mixed Gmail cohort. The private
    /// source model stays here; only actual production output reaches the hooks.
    func gmailCohortComparisons(source: GmailInboxSource, bytes: Data) throws -> (
        prepared: (PreparedImport) throws -> Void,
        persisted: (DatabaseProvider, RepositoryRuntimeSnapshot, String) throws -> Void
    ) {
        let expected = try GmailSalarySourceOracle.statement(source: source, bytes: bytes)
        return ({ prepared in
            try self.verifyPrepared(prepared, against: expected)
        }, { provider, hydrated, sessionID in
            let rows = try provider.salaryRepo.snapshot(workspaceId: "default-workspace").statements
                .filter { $0.importSessionId == sessionID }
            guard rows.count == 1, let row = rows.first,
                  let document = try provider.importSessionRepo.importedDocument(id: row.documentId),
                  document.importSessionId == sessionID,
                  let session = try provider.importSessionRepo.importSession(id: sessionID), session.validationStatus == "passed",
                  row.components.allSatisfy({ $0.salaryStatementId == row.id }),
                  let published = hydrated.salaryStatements.first(where: { $0.id == row.id }),
                  published.documentID == row.documentId, published.importSessionID == sessionID else {
                throw AcceptanceError.mismatch(sourceToken: expected.sourceToken, field: "cohort salary relationships")
            }
            try self.verifyPersisted(row, against: expected)
            try self.verifyEvidence(published.evidence, against: expected)
        })
    }

    private func qualifyGmailOriginal(
        _ original: (source: GmailInboxSource, bytes: Data),
        expected: Statement,
        providerKind: ProviderKind
    ) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Gmail-Salary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let databaseURL = folder.appendingPathComponent("gmail-salary.sqlite")
        let sqlite = providerKind == .sqlite
            ? try SQLiteRepositoryProvider(path: databaseURL.path)
            : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map {
            DatabaseProvider.verifiedSQLite($0, protectsGeneration: false)
        } ?? DatabaseProvider(inMemory: true)
        let workspace = "gmail-salary-\(providerKind.rawValue)-\(UUID().uuidString)"
        let stores = SalaryAcceptanceRuntimeStores()
        let hydrator = makeHydrator(provider: provider, workspace: workspace, stores: stores)

        let source = original.source
        let digest = GmailInboxSource.digest(original.bytes)
        guard source.family == .salary,
              source.fileExtension == "pdf",
              source.acquisition == .available,
              source.expectedByteCount == original.bytes.count,
              source.sha256 == digest,
              digest == expected.sourceSha256,
              let sourceURL = source.importURL else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "Gmail original receipt/locator"
            )
        }

        var inbox = try provider.gmailInboxRepo.load(account: source.account)
        guard inbox.sources[source.id] == nil else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "fresh Gmail inbox source state"
            )
        }
        inbox.sources[source.id] = source
        _ = try provider.gmailInboxRepo.save(
            inbox,
            originals: [digest: original.bytes],
            expectedRevision: inbox.revision
        )
        try verifyGmailOriginal(
            source: source,
            bytes: original.bytes,
            repository: provider.gmailInboxRepo,
            sourceToken: expected.sourceToken
        )

        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry()),
            sourceSnapshotAcquirer: { url in
                try GmailImportSource.acquireSnapshot(from: url, repository: provider.gmailInboxRepo)
            },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspace,
                    workspaceName: "Gmail salary authentic acceptance"
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

        let cancelled = try await engine.prepareImport(from: sourceURL)
        defer { engine.cancelPreparedImport(cancelled) }
        try verifyPrepared(cancelled, against: expected)
        engine.cancelPreparedImport(cancelled)
        try verifyNoAcceptedResidue(provider: provider, workspace: workspace)

        let prepared = try await engine.prepareImport(from: sourceURL)
        defer { engine.cancelPreparedImport(prepared) }
        try verifyPrepared(prepared, against: expected)
        let result = await engine.commitPreparedImport(prepared)
        guard result.persisted,
              result.validationPassed,
              result.isSalaryImport,
              result.transactionCount == 0,
              result.previousImport == nil,
              result.errorMessage == nil,
              result.hydrationOutcome == .committedAndHydrated else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "ordinary Gmail salary confirmation result"
            )
        }
        try verifyGmailPersistedAndHydrated(
            provider: provider,
            workspace: workspace,
            stores: stores,
            expected: expected,
            expectedAttemptCount: 1
        )
        let stableSalaryProjection = try provider.salaryRepo.snapshot(workspaceId: workspace)

        let replayPrepared = try await engine.prepareImport(from: sourceURL)
        defer { engine.cancelPreparedImport(replayPrepared) }
        try verifyPrepared(replayPrepared, against: expected)
        guard replayPrepared.advisoryPreviousImport != nil else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "Gmail exact replay advisory"
            )
        }
        let replay = await engine.commitPreparedImport(replayPrepared)
        guard !replay.persisted,
              replay.validationPassed,
              replay.isSalaryImport,
              replay.transactionCount == 0,
              replay.previousImport != nil,
              replay.hydrationOutcome == .notRequired else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "Gmail exact replay result"
            )
        }
        guard try provider.salaryRepo.snapshot(workspaceId: workspace) == stableSalaryProjection else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "Gmail exact replay changed salary source projection"
            )
        }
        try verifyGmailPersistedAndHydrated(
            provider: provider,
            workspace: workspace,
            stores: stores,
            expected: expected,
            expectedAttemptCount: 2
        )

        guard let sqlite else { return }
        try sqlite.database.checkpointAndClose()
        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        try BackupCompatibility.verifyDatabase(reopenedSQLite.database)
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        try verifyGmailOriginal(
            source: source,
            bytes: original.bytes,
            repository: reopenedProvider.gmailInboxRepo,
            sourceToken: expected.sourceToken
        )
        let reopenedStores = SalaryAcceptanceRuntimeStores()
        try verifyGmailPersistedAndHydrated(
            provider: reopenedProvider,
            workspace: workspace,
            stores: reopenedStores,
            expected: expected,
            expectedAttemptCount: 2
        )
        try reopenedSQLite.database.checkpointAndClose()
    }

    private func verifyGmailOriginal(
        source: GmailInboxSource,
        bytes: Data,
        repository: any GmailInboxRepository,
        sourceToken: String
    ) throws {
        guard let digest = source.sha256,
              try repository.original(sha256: digest, byteCount: source.expectedByteCount) == bytes,
              GmailInboxSource.digest(bytes) == digest else {
            throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "stored Gmail original bytes")
        }
        guard let sourceURL = source.importURL else {
            throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "Gmail snapshot locator")
        }
        let snapshot = try GmailImportSource.acquireSnapshot(
            from: sourceURL,
            repository: repository
        )
        defer { snapshot.invalidate() }
        guard snapshot.byteCount == Int64(bytes.count),
              try snapshot.recomputedSourceByteFingerprint().digest == digest else {
            throw AcceptanceError.mismatch(sourceToken: sourceToken, field: "Gmail snapshot integrity")
        }
    }

    private func verifyGmailPersistedAndHydrated(
        provider: DatabaseProvider,
        workspace: String,
        stores: SalaryAcceptanceRuntimeStores,
        expected: Statement,
        expectedAttemptCount: Int
    ) throws {
        let persisted = try provider.salaryRepo.snapshot(workspaceId: workspace)
        guard persisted.statements.count == 1,
              let actual = persisted.statements.first else {
            throw AcceptanceError.mismatch(sourceToken: expected.sourceToken, field: "sole Gmail salary DTO")
        }
        try verifyPersisted(actual, against: expected)
        guard actual.workspaceId == workspace,
              !actual.id.isEmpty,
              !actual.documentId.isEmpty,
              !actual.importSessionId.isEmpty,
              !actual.normalizedDocumentId.isEmpty,
              actual.components.allSatisfy({ $0.salaryStatementId == actual.id }),
              let session = try provider.importSessionRepo.importSession(id: actual.importSessionId),
              session.workspaceId == workspace,
              session.validationStatus == "passed",
              let document = try provider.importSessionRepo.importedDocument(id: actual.documentId),
              document.workspaceId == workspace,
              document.importSessionId == actual.importSessionId,
              try provider.importSessionRepo.successfulImportContainsFingerprint(
                algorithm: actual.sourceFingerprintAlgorithm,
                fingerprint: actual.sourceFingerprintDigest
              ) else {
            throw AcceptanceError.mismatch(
                sourceToken: expected.sourceToken,
                field: "salary/session/document/source-fingerprint relationship"
            )
        }

        let hydrator = makeHydrator(provider: provider, workspace: workspace, stores: stores)
        let staged = try hydrator.stageHydration()
        guard staged.accounts.isEmpty,
              staged.transactions.isEmpty,
              staged.salaryStatements.count == 1,
              staged.importSessions.count == 1,
              staged.importAttempts.count == expectedAttemptCount,
              let hydrated = staged.salaryStatements.first,
              hydrated.workspaceID == workspace,
              hydrated.documentID == actual.documentId,
              hydrated.importSessionID == actual.importSessionId,
              hydrated.fingerprintDigest == expected.sourceSha256 else {
            throw AcceptanceError.mismatch(sourceToken: expected.sourceToken, field: "staged Gmail salary hydration")
        }
        try verifyEvidence(hydrated.evidence, against: expected)
        hydrator.publish(staged)
        guard stores.accounts.accounts.isEmpty,
              stores.transactions.transactions.isEmpty,
              stores.salaries.statements.count == 1,
              stores.sessions.importSessions.count == 1,
              stores.attempts.attempts.count == expectedAttemptCount,
              let published = stores.salaries.statements.first,
              published == hydrated else {
            throw AcceptanceError.mismatch(sourceToken: expected.sourceToken, field: "published Gmail salary hydration")
        }
    }

    /// Independent, source-only PDFKit decoder for the two observed regular
    /// Gmail payslips.  Its output exists only as a RAM expectation and it does
    /// not construct any LedgerForge import/document/parser carrier.
    private enum GmailSalarySourceOracle {
        private struct Word {
            let text: String
            let x: Double
            let baselineY: Double
        }

        private struct MutableComponent {
            var label: String
            let amount: String
        }

        static func statement(source: GmailInboxSource, bytes: Data) throws -> Statement {
            let digest = GmailInboxSource.digest(bytes)
            guard source.family == .salary,
                  source.fileExtension == "pdf",
                  source.expectedByteCount == bytes.count,
                  source.sha256 == digest,
                  let document = PDFDocument(data: bytes),
                  !document.isLocked,
                  (1...2).contains(document.pageCount),
                  let firstPage = document.page(at: 0),
                  let firstText = firstPage.string else {
                throw failure(digest, "source/original PDF shape")
            }
            let pages = try (0..<document.pageCount).map { index in
                guard let page = document.page(at: index) else { throw failure(digest, "source page") }
                return page
            }
            let printText: String
            if pages.count == 2, let text = pages[1].string, let marker = text.range(of: "Printed by:") {
                let prefix = normalized(String(text[..<marker.lowerBound]))
                // Independently observed medical-notice continuations only;
                // no financial line may be ignored on the second page.
                let end = "Alkoot Health Insurance) and on Alkoot website: www.alkoot.com.qa"
                let form = "The Claim form and Treatment Guarantee form are available on Intranet (Human Resources; Forms; " + end
                let notice = "To avoid any delay in settlement of your medical claims, please mention employee IBAN number while completing Alkoot Medical Claims. " + form
                guard ["", end, form, notice].map(normalized).contains(prefix) else {
                    throw failure(digest, "unowned content on second page")
                }
                printText = String(text[marker.lowerBound...])
            }
            else if let marker = firstText.range(of: "Printed by:") { printText = String(firstText[marker.lowerBound...]) }
            else { throw failure(digest, "printed-by record") }
            let pageWords = try pages.map(words(on:))
            guard pageWords.allSatisfy({ !$0.isEmpty }) else {
                throw failure(digest, "positioned native source text")
            }
            guard normalized(printText).contains("printed by:"),
                  !normalized(printText).contains("total earnings"),
                  !normalized(printText).contains("payment details") else {
                throw failure(digest, "page-two nonfinancial print record")
            }

            let identity = try sourceIdentity(firstText, digest: digest)
            let title = try monthlyTitle(firstText, digest: digest)
            let printRecord = try printedBy(printText, digest: digest)
            let printDate = printRecord.date
            guard printRecord.name == identity.employeeName, printRecord.number == identity.employeeNumber else {
                throw failure(digest, "repeated identity and period controls")
            }
            if title.kind == "monthlySalary" {
                guard let netPeriod = captures(#"Net pay for the month of ([A-Za-z]+) ([0-9]{4})"#, in: firstText),
                      netPeriod.count == 2, monthNumber(netPeriod[0]) == title.month, Int(netPeriod[1]) == title.year else {
                    throw failure(digest, "repeated financial period")
                }
            }
            let table = try components(from: pageWords[0], digest: digest)
            let controls = try printedControls(
                firstText,
                rows: rows(from: pageWords[0]),
                digest: digest
            )

            guard sum(table.earnings) == controls.totalEarnings,
                  sum(table.deductions) == (controls.totalDeductions ?? "0.00"),
                  (controls.totalDeductions != nil || table.deductions.isEmpty),
                  subtract(controls.totalEarnings, controls.totalDeductions ?? "0.00") == controls.net,
                  controls.payment == controls.net else {
                throw failure(digest, "independent printed-control reconciliation")
            }
            let period = try SelectedStatementMonth(year: title.year, month: title.month)
            _ = try StatementDate(
                year: printDate.year,
                month: printDate.month,
                day: printDate.day
            )
            let sourceText = pages.compactMap(\.string).joined(separator: "\n")
            return Statement(
                sourceBasename: source.originalFilename,
                sourceSha256: digest,
                sourceSize: bytes.count,
                pageCount: document.pageCount,
                encrypted: document.isLocked,
                extractedTextSha256: sha256(sourceText.data(using: .utf8) ?? Data()),
                extractedBboxSha256: sha256(geometryBytes(pageWords)),
                sourceIdentity: identity,
                documentTitle: title.rendered,
                period: period.canonical,
                printDate: printRecord.literalDate,
                kind: title.kind,
                currency: "QAR",
                earnings: table.earnings.enumerated().map {
                    Component(ordinal: $0.offset, label: $0.element.label, amount: $0.element.amount)
                },
                deductions: table.deductions.enumerated().map {
                    Component(ordinal: $0.offset, label: $0.element.label, amount: $0.element.amount)
                },
                printedControls: .init(
                    totalEarnings: controls.totalEarnings,
                    totalDeductions: controls.totalDeductions,
                    netPay: controls.net,
                    paymentTotal: controls.payment
                ),
                reconciliation: .init(
                    earningsSumMatches: true,
                    deductionsSumMatchesOrAbsent: true,
                    netMatchesEarningsLessDeductions: true,
                    paymentTotalMatchesNet: true
                )
            )
        }

        private static func sourceIdentity(_ text: String, digest: String) throws -> SourceIdentity {
            guard normalized(text).contains("ispadmin@qatarairways.com.qa"),
                  let name = capture(#"Name\s*:?\s*(.+?)\s*Employee\s+Number"#, in: text),
                  let number = capture(#"Employee\s+Number\s*:?\s*(.+?)\s*Department"#, in: text),
                  let position = capture(#"Position\s*:?\s*(.+?)\s*Grade"#, in: text),
                  let payment = capture(#"\b(QA[0-9]{2}[A-Z0-9]{25})\b"#, in: text),
                  !name.isEmpty, !number.isEmpty, !position.isEmpty, !payment.isEmpty else {
                throw failure(digest, "required page-one identity/payment headers")
            }
            return SourceIdentity(
                employer: "Qatar Airways",
                employeeName: name,
                employeeNumber: number,
                position: position,
                paymentIban: payment
            )
        }

        private static func monthlyTitle(_ text: String, digest: String) throws -> (rendered: String, month: Int, year: Int, kind: String) {
            let titles = [
                ("monthlySalary", #"((?:Payslip|Salary)\s+for\s+the\s+month\s+of\s+([A-Za-z]+)\s+([0-9]{4}))"#),
                ("adhocPayment", #"(Adhoc\s+Payment\s*-\s*([A-Za-z]+)\s+([0-9]{4}))"#)
            ]
            let matches = titles.compactMap { kind, pattern -> (String, [String])? in
                captures(pattern, in: text).map { (kind, $0) }
            }
            guard matches.count == 1, let (kind, values) = matches.first, values.count == 3,
                  let month = monthNumber(values[1]), let year = Int(values[2]) else {
                throw failure(digest, "observed salary document title")
            }
            return (values[0], month, year, kind)
        }

        private static func printedBy(_ text: String, digest: String) throws -> (name: String, number: String, literalDate: String, date: (year: Int, month: Int, day: Int)) {
            guard let values = captures(#"^\s*Printed\s+by:\s*(.*?)\s*\(([0-9]+)\)\s*([0-9]{2}-[A-Za-z]{3}-[0-9]{4})\s*$"#, in: text),
                  values.count == 3, let date = calendarDate(values[2]) else {
                throw failure(digest, "page-two printed-by date")
            }
            return (name: values[0], number: values[1], literalDate: values[2], date: date)
        }

        private static func components(
            from words: [Word],
            digest: String
        ) throws -> (earnings: [MutableComponent], deductions: [MutableComponent]) {
            let sourceRows = rows(from: words)
            let headers = sourceRows.indices.filter {
                contains($0, in: sourceRows, phrase: "Earning Amount (QAR)")
            }
            let totals = sourceRows.indices.filter {
                contains($0, in: sourceRows, phrase: "Total Earnings")
            }
            guard headers.count == 1, totals.count == 1,
                  let header = headers.first, let total = totals.first, header < total else {
                throw failure(digest, "positioned earnings/deductions table ownership")
            }
            let deductionX = sourceRows[header].first(where: { $0.text == "Deduction" })?.x ?? .greatestFiniteMagnitude

            var earnings: [MutableComponent] = []
            var deductions: [MutableComponent] = []
            var pendingEarning: [String] = []
            var pendingDeduction: [String] = []
            for row in sourceRows[(header + 1)..<total] {
                try consume(
                    row.filter { $0.x < deductionX },
                    components: &earnings,
                    pending: &pendingEarning,
                    digest: digest
                )
                try consume(
                    row.filter { $0.x >= deductionX },
                    components: &deductions,
                    pending: &pendingDeduction,
                    digest: digest
                )
            }
            guard !earnings.isEmpty,
                  pendingEarning.isEmpty, pendingDeduction.isEmpty else {
                throw failure(digest, "complete positioned salary components")
            }
            return (earnings, deductions)
        }

        private static func consume(
            _ words: [Word],
            components: inout [MutableComponent],
            pending: inout [String],
            digest: String
        ) throws {
            guard !words.isEmpty else { return }
            let amounts = words.compactMap { word -> (Word, String)? in
                canonicalMoney(word.text).map { (word, $0) }
            }
            guard amounts.count <= 1 else { throw failure(digest, "ambiguous positioned amount") }
            let labels = words.filter { canonicalMoney($0.text) == nil }.map(\.text)
            if let (_, amount) = amounts.first {
                let label = (pending + labels).joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty, decimal(amount) > .zero else {
                    throw failure(digest, "component label/value")
                }
                components.append(.init(label: label, amount: amount))
                pending = []
                return
            }
            let continuation = labels.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !continuation.isEmpty else { return }
            if components.isEmpty {
                pending.append(continuation)
            } else {
                components[components.count - 1].label += " " + continuation
            }
        }

        private static func printedControls(
            _ text: String,
            rows: [[Word]],
            digest: String
        ) throws -> (totalEarnings: String, totalDeductions: String?, net: String, payment: String) {
            guard normalized(text).contains("payment details"),
                  normalized(text).contains("bank name"),
                  normalized(text).contains("account number"),
                  text.range(of: #"Amount\s+Transferred\s*\(QAR\)"#, options: [.regularExpression, .caseInsensitive]) != nil,
                  let totalEarnings = amount(after: "Total\\s+Earnings", in: text),
                  let net = amount(after: "Net\\s+pay.*?\\(QAR\\)", in: text),
                  let payment = amount(after: "Total\\s+Amount", in: text) else {
                throw failure(digest, "printed payroll/payment controls")
            }
            let totalDeductions = amount(after: "Total\\s+Deductions", in: text)
            guard !normalized(text).contains("total deductions") || totalDeductions != nil else {
                throw failure(digest, "printed deduction control")
            }
            let paymentHeaders = rows.indices.filter { contains($0, in: rows, phrase: "Payment Details") }
            let paymentTotals = rows.indices.filter { contains($0, in: rows, phrase: "Total Amount") }
            guard paymentHeaders.count == 1, paymentTotals.count == 1,
                  let header = paymentHeaders.first, let total = paymentTotals.first, header < total else {
                throw failure(digest, "single payment table")
            }
            let paymentRows = rows[(header + 1)..<total]
            let transferred = paymentRows.flatMap { $0.compactMap { canonicalMoney($0.text) } }
            guard transferred.count == 1, transferred[0] == payment else {
                throw failure(digest, "one transferred payment matching total")
            }
            return (totalEarnings, totalDeductions, net, payment)
        }

        private static func words(on page: PDFPage) throws -> [Word] {
            guard let text = page.string,
                  let expression = try? NSRegularExpression(pattern: #"\S+"#) else {
                throw AcceptanceError.campaign(provider: "gmail", order: "source-only", field: "PDFKit native text")
            }
            return try expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
                guard let range = Range(match.range, in: text),
                      let selection = page.selection(for: match.range) else {
                    throw AcceptanceError.campaign(provider: "gmail", order: "source-only", field: "PDFKit positioned word")
                }
                let bounds = selection.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0 else {
                    throw AcceptanceError.campaign(provider: "gmail", order: "source-only", field: "PDFKit positioned word bounds")
                }
                return Word(text: String(text[range]), x: bounds.minX, baselineY: bounds.midY)
            }
        }

        private static func rows(from words: [Word]) -> [[Word]] {
            let ordered = words.sorted {
                if abs($0.baselineY - $1.baselineY) > 1.5 { return $0.baselineY > $1.baselineY }
                return $0.x < $1.x
            }
            var result: [[Word]] = []
            var currentY: Double?
            for word in ordered {
                if let currentY, abs(currentY - word.baselineY) <= 1.5 {
                    result[result.count - 1].append(word)
                } else {
                    result.append([word])
                    currentY = word.baselineY
                }
            }
            return result.map { $0.sorted { $0.x < $1.x } }
        }

        private static func contains(_ index: Int, in rows: [[Word]], phrase: String) -> Bool {
            normalized(rows[index].map(\.text).joined(separator: " ")).contains(normalized(phrase))
        }

        private static func captures(_ pattern: String, in text: String) -> [String]? {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                return nil
            }
            return (1..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        private static func capture(_ pattern: String, in text: String) -> String? {
            captures(pattern, in: text)?.first
        }

        private static func amount(after prefix: String, in text: String) -> String? {
            capture(prefix + #"\s*:?\s*([0-9][0-9,]*\.[0-9]{2})"#, in: text).flatMap(canonicalMoney)
        }

        private static func canonicalMoney(_ value: String) -> String? {
            guard value.range(of: #"^[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#, options: .regularExpression) != nil else {
                return nil
            }
            let canonical = value.replacingOccurrences(of: ",", with: "")
            guard decimal(canonical) >= .zero else { return nil }
            return canonical
        }

        private static func decimal(_ value: String) -> Decimal {
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
        }

        private static func sum(_ components: [MutableComponent]) -> String {
            let total = components.reduce(Decimal.zero) { $0 + decimal($1.amount) }
            return canonicalTwoDecimal(total)
        }

        private static func subtract(_ left: String, _ right: String) -> String {
            let value = decimal(left) - decimal(right)
            return canonicalTwoDecimal(value)
        }

        private static func canonicalTwoDecimal(_ value: Decimal) -> String {
            let rendered = NSDecimalNumber(decimal: value).stringValue
            guard let decimalPoint = rendered.firstIndex(of: ".") else { return rendered + ".00" }
            let fractionalCount = rendered[rendered.index(after: decimalPoint)...].count
            guard fractionalCount <= 2 else { return rendered }
            return rendered + String(repeating: "0", count: 2 - fractionalCount)
        }

        private static func calendarDate(_ value: String) -> (year: Int, month: Int, day: Int)? {
            let pieces = value.split(separator: "-")
            guard pieces.count == 3,
                  let day = Int(pieces[0]),
                  let month = monthNumber(String(pieces[1])),
                  let year = Int(pieces[2]) else { return nil }
            return (year, month, day)
        }

        private static func monthNumber(_ value: String) -> Int? {
            let names = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
            let normalized = value.lowercased()
            if let exact = names.firstIndex(of: normalized) { return exact + 1 }
            return names.firstIndex(where: { $0.hasPrefix(normalized) }).map { $0 + 1 }
        }

        private static func normalized(_ value: String) -> String {
            value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        private static func geometryBytes(_ pages: [[Word]]) -> Data {
            Data(pages.flatMap { page in
                page.map { "\($0.text)|\($0.x)|\($0.baselineY)" }
            }.joined(separator: "\n").utf8)
        }

        private static func sha256(_ data: Data) -> String {
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }

        private static func failure(_ digest: String, _ field: String) -> AcceptanceError {
            .mismatch(sourceToken: String(digest.prefix(12)), field: "Gmail source-only \(field)")
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
              (oracle.oracleMethod.contains("Poppler native text and bbox extraction")
                || oracle.oracleMethod == "Independent pdfplumber character geometry and pypdf native text from unchanged originals (RAM only)"),
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
          let oracle = environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_PIPE"] ?? environment["LEDGERFORGE_PRIVATE_SALARY_ORACLE_FILE"],
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
