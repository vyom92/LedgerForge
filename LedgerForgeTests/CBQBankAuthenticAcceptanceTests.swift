import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// External authentic corpus and independently extracted source facts only.
@MainActor
struct CBQBankAuthenticAcceptanceTests {
    private struct Oracle: Decodable { let carriers: [Carrier] }
    private struct Carrier: Decodable {
        let carrier: String
        let sha256: String
        let statementDate: String
        let periodStart: String
        let maskedAccount: String
        let maskedIBAN: String
        let openingBalance: String
        let closingBalance: String
        let rows: [Row]
    }
    private struct Row: Decodable {
        let postingDate: String
        let description: String
        let sourceTransactionDate: String
        let signedAmount: String
        let balance: String
        let sourcePage: Int
    }

    @Test(.globalRuntimeStateIsolation)
    func completeOriginalsPersistReplayAndReopen() async throws {
        let env = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(env["LEDGERFORGE_CBQ_BANK_ROOT"]))
        let password = try #require(try await KeychainStatementPasswordCredentialStore().password(
            institutionCode: Institution.cbq.statementPasswordCredentialScope
        ))
        let inputs = try originalPDFInputs(root: root)
        let byURL = Dictionary(uniqueKeysWithValues: inputs.map { ($0.url, $0.bytes) })
        let oracle = Oracle(carriers: try inputs.map { try independentMonthlyOracle($0, password: password) })
        expectSourceFact(oracle.carriers.count == 19)
        expectSourceFact(oracle.carriers.reduce(0) { $0 + $1.rows.count } == 187)
        for inMemory in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-CBQ-Authentic-\(UUID())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let path = directory.appendingPathComponent("acceptance.sqlite").path
            let sqlite = inMemory ? nil : try SQLiteRepositoryProvider(path: path)
            let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) }
                ?? DatabaseProvider(inMemory: true)
            let workspace = "cbq-authentic-\(UUID())"
            let store = TransactionStore()
            let hydrator = makeHydrator(provider, workspace: workspace, store: store)
            let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: provider,
                mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "CBQ authentic acceptance"))
            let credentials = InMemoryStatementPasswordCredentialStore(passwords:
                [Institution.cbq.statementPasswordCredentialScope: password])
            let engine = ImportEngine(
                importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(),
                    passwordProvider: DefaultPasswordProvider(credentialStore: credentials,
                        supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })),
                sourceSnapshotAcquirer: { url in
                    guard let bytes = byURL[url] else { throw CBQOracleError.unregisteredSource }
                    return SourceContentSnapshot(bytes: bytes)
                },
                importPersistenceCoordinator: coordinator,
                persistenceStateProvider: { provider.persistenceState },
                providerGenerationProvider: { provider.generationToken },
                forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
                rejectedAttemptHydration: {},
                developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
            )
            var successful = 0
            var expectedKeys: [String: Int] = [:]
            let firstCarrier = try #require(oracle.carriers.first)
            let firstURL = root.appendingPathComponent(firstCarrier.carrier)
            let cancelled = try await engine.prepareImport(from: firstURL)
            engine.cancelPreparedImport(cancelled)
            expectSourceFact(try provider.accountRepo.accounts(workspaceId: workspace).isEmpty)
            expectSourceFact(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
            expectSourceFact(try provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace).isEmpty)
            for carrier in oracle.carriers {
                let url = root.appendingPathComponent(carrier.carrier)
                do {
                    let prepared = try await engine.prepareImport(from: url)
                    defer { engine.cancelPreparedImport(prepared) }
                    let bytesDigest = try prepared.sourceSnapshot.withBytes {
                        SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
                    }
                    expectSourceFact(bytesDigest == carrier.sha256)
                    expectSourceFact(prepared.detectedInstitution == .cbq)
                    expectSourceFact(prepared.validation.passed, "\(carrier.carrier): validation")
                    let document = prepared.financialDocument
                    expectSourceFact(document.transactions.count == carrier.rows.count, "\(carrier.carrier)")
                    expectSourceFact(document.sourceStatementEvidence?.openingBalance?.amount == decimal(carrier.openingBalance))
                    expectSourceFact(document.sourceStatementEvidence?.closingBalance?.amount == decimal(carrier.closingBalance))
                    expectSourceFact(document.sourceStatementEvidence?.statementBoundaryDate == date(carrier.statementDate.replacingOccurrences(of: " ", with: "-")))
                    for (transaction, row) in zip(document.transactions, carrier.rows) {
                        expectSourceFact(transaction.statementDate == date(row.postingDate), "\(carrier.carrier)")
                        expectSourceFact(transaction.money.amount == decimal(row.signedAmount), "\(carrier.carrier)")
                        expectSourceFact(transaction.money.currency.code == "QAR")
                        expectSourceFact(transaction.runningBalanceMoney?.amount == decimal(row.balance))
                        expectSourceFact(compact(transaction.description) == compact(row.description), "\(carrier.carrier): narration")
                        expectSourceFact(transaction.sourceProvenance.first?.sourceTransactionDate == date(row.sourceTransactionDate))
                        expectSourceFact(transaction.sourceProvenance.first?.sourcePage == row.sourcePage)
                        expectSourceFact(transaction.sourceProvenance.first?.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID)
                        expectSourceFact(transaction.sourceProvenance.first?.parserProfileVersion == "1")
                    }
                    guard prepared.validation.passed else { continue }
                    let review = try coordinator.reviewValidatedImport(financialDocument: document, validation: prepared.validation)
                    let choice: ImportAccountChoice?
                    switch review {
                    case .unavailable:
                        choice = .createNewAccount(displayName: "CBQ reviewed account")
                    case .choiceRequired(let ids) where ids.isEmpty:
                        choice = .createNewAccount(displayName: "CBQ reviewed account")
                    case .choiceRequired(let ids) where ids.count == 1:
                        choice = .useExistingAccount(accountId: ids[0])
                    default:
                        choice = nil
                    }
                    let committed = await engine.commitPreparedImport(prepared, accountChoice: choice)
                    expectSourceFact(committed.persisted, "\(carrier.carrier): \(committed.errorMessage ?? "no error")")
                    expectSourceFact(committed.hydrationOutcome == .committedAndHydrated)
                    guard committed.persisted else { continue }
                    successful += 1
                    for row in carrier.rows { expectedKeys[oracleKey(row), default: 0] += 1 }
                    let count = try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count
                    let replay = try await engine.prepareImport(from: url)
                    defer { engine.cancelPreparedImport(replay) }
                    let replayed = await engine.commitPreparedImport(replay)
                    expectSourceFact(replayed.previousImport != nil, "\(carrier.carrier): exact replay")
                    expectSourceFact(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count == count)
                } catch {
                    Issue.record("\(carrier.carrier), memory=\(inMemory): \(error)")
                }
            }
            expectSourceFact(successful == oracle.carriers.count)
            try verifySourceObservations(provider, workspace: workspace)
            expectSourceFact(store.transactions.count == 187)
            expectSourceFact(multiset(store.transactions.map(transactionKey)) == expectedKeys)
            sqlite?.database.close()
            if !inMemory {
                let reopened = try SQLiteRepositoryProvider(path: path)
                defer { reopened.database.close() }
                let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
                let reopenedStore = TransactionStore()
                let reopenedHydrator = makeHydrator(reopenedProvider, workspace: workspace, store: reopenedStore)
                let hydrated = try reopenedHydrator.hydrateIfNeeded(forceRefresh: true)
                expectSourceFact(hydrated.didHydrate && hydrated.transactionCount == 187)
                expectSourceFact(multiset(reopenedStore.transactions.map(transactionKey)) == expectedKeys)
                try verifySourceObservations(reopenedProvider, workspace: workspace)
                expectSourceFact(reopenedStore.transactions.allSatisfy {
                    $0.sourceProvenance.contains { $0.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID && $0.parserProfileVersion == "1" }
                })
            }
        }
    }

    private enum CBQOracleError: Error {
        case unregisteredSource, unavailableOriginal, malformedMIME, ambiguousControl(String), malformedRow(String), failedEquation
    }
    private struct OriginalPDFInput {
        let carrier: String
        let url: URL
        let bytes: Data
    }

    private func originalPDFInputs(root: URL) throws -> [OriginalPDFInput] {
        guard root.resolvingSymlinksInPath().path.hasPrefix("/Users/vyom/Documents/Ledger Forge/Originals/") else {
            throw CBQOracleError.unavailableOriginal
        }
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { ["pdf", "eml"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { url in
            if url.pathExtension.lowercased() == "pdf" {
                return OriginalPDFInput(carrier: url.lastPathComponent, url: url, bytes: try Data(contentsOf: url))
            }
            // Decode the one authentic PDF attachment from its original MIME
            // carrier in memory. No extracted PDF is created. The
            // existing snapshot-acquisition seam names that attachment under
            // its real carrier, then exercises the ordinary PDF import path.
            let source = try String(contentsOf: url, encoding: .utf8)
                .replacingOccurrences(of: "\r\n", with: "\n")
            let lines = source.components(separatedBy: "\n")
            let starts = lines.indices.filter { lines[$0].lowercased().hasPrefix("content-type: application/pdf") }
            guard starts.count == 1, let start = starts.first,
                  let separator = lines[(start + 1)...].firstIndex(of: ""),
                  let end = lines[(separator + 1)...].firstIndex(where: { $0.hasPrefix("--") }) else {
                throw CBQOracleError.malformedMIME
            }
            let headers = lines[start..<separator].joined(separator: " ")
            guard headers.lowercased().contains("content-transfer-encoding: base64") else {
                throw CBQOracleError.malformedMIME
            }
            let names = try sourceGroups(#"(?i)(?:filename|name)\s*=\s*(?:"([^"]+)"|([^;\s]+))"#, in: headers)
                .compactMap { $0.first(where: { !$0.isEmpty }) }
            guard let name = names.first, names.allSatisfy({ $0 == name }),
                  !name.contains("/"), name.lowercased().hasSuffix(".pdf"),
                  let bytes = Data(base64Encoded: lines[(separator + 1)..<end].joined()),
                  bytes.starts(with: Data("%PDF-".utf8)) else { throw CBQOracleError.malformedMIME }
            let attachment = (name: name, bytes: bytes)
            let carrier = url.lastPathComponent + "/" + attachment.name
            return OriginalPDFInput(carrier: carrier, url: root.appendingPathComponent(carrier), bytes: bytes)
        }
    }

    private struct CBQSourceGlyph {
        let text: String
        let x: Double
    }
    private struct CBQSourceLine {
        let y: Double
        let glyphs: [CBQSourceGlyph]
    }
    private struct CBQPendingSourceRow {
        let postingDate: String
        let sourceTransactionDate: String
        let signedAmount: Decimal
        let balance: Decimal
        let page: Int
        var description: [String]
    }
    private func cbqSourceLines(_ page: PDFPage) throws -> [CBQSourceLine] {
        var groups: [Double: [CBQSourceGlyph]] = [:]
        var seen = Set<String>()
        for index in 0..<page.numberOfCharacters {
            guard let selection = page.selection(for: NSRange(location: index, length: 1)) else {
                throw CBQOracleError.malformedRow("source-selection")
            }
            let text = selection.string ?? ""
            if text.isEmpty || text == "\n" || text == "\r" { continue }
            let bounds = selection.bounds(for: page)
            let x = Double(bounds.origin.x), y = Double(bounds.origin.y)
            let width = Double(bounds.width)
            guard x.isFinite && y.isFinite && width.isFinite else {
                // PDFKit can expose empty non-geometric separators on advert pages.
                guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw CBQOracleError.malformedRow("source-glyph-geometry")
                }
                continue
            }
            // PDFKit line separators can repeat a preceding character selection.
            // Deduplicate only identical character/rectangle evidence.
            let key = "\((x * 10000).rounded())|\((y * 10000).rounded())|\((width * 10000).rounded())|\(text)"
            guard seen.insert(key).inserted else { continue }
            groups[(y * 100).rounded() / 100, default: []].append(
                CBQSourceGlyph(text: text, x: x)
            )
        }
        return groups.keys.sorted(by: >).map { y in
            CBQSourceLine(y: y, glyphs: groups[y]!.sorted { $0.x < $1.x })
        }
    }
    private func cbqSourceText(_ glyphs: [CBQSourceGlyph]) -> String {
        glyphs.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func cbqSourceColumns(_ line: CBQSourceLine) -> [String] {
        // Original source column roles: posting, narration, transaction date,
        // debit, credit and running balance. No production parser supplies these.
        let edges: [Double] = [0, 75, 260, 340, 420, 505, 1000]
        return (0..<6).map { index in
            cbqSourceText(line.glyphs.filter {
                $0.x >= edges[index] && $0.x < edges[index + 1]
            })
        }
    }
    private func cbqIsSourceDate(_ text: String) -> Bool {
        text.range(of: #"^\d{2}-[A-Za-z]{3}-\d{2}$"#, options: .regularExpression) != nil
    }
    private func cbqCheckSourceDate(_ text: String) throws {
        let pieces = text.replacingOccurrences(of: " ", with: "-").split(separator: "-")
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard pieces.count == 3,
              let day = Int(pieces[0]), let year = Int(pieces[2]),
              pieces[2].count == 2,
              let monthIndex = months.firstIndex(of: pieces[1].lowercased()) else {
            throw CBQOracleError.malformedRow("source-date")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: 2000 + year, month: monthIndex + 1, day: day)) else {
            throw CBQOracleError.malformedRow("source-date")
        }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == 2000 + year && check.month == monthIndex + 1 && check.day == day else {
            throw CBQOracleError.malformedRow("source-date")
        }
    }
    private func independentMonthlyOracle(_ input: OriginalPDFInput, password: String) throws -> Carrier {
        guard let pdf = PDFDocument(data: input.bytes),
              !pdf.isLocked || pdf.unlock(withPassword: password) else {
            throw CBQOracleError.unavailableOriginal
        }
        let pages = try (0..<pdf.pageCount).map { index -> [CBQSourceLine] in
            guard let page = pdf.page(at: index) else { throw CBQOracleError.unavailableOriginal }
            return try cbqSourceLines(page)
        }
        let source = pages.flatMap { $0.map { cbqSourceText($0.glyphs) } }.joined(separator: "\n")
        let statementDate = try sourceControl(#"Statement Date:\s*(\d{2} [A-Za-z]{3} \d{2})"#, in: source)
        let account = try sourceControl(#"Account No\.:\s*([0-9X-]+)"#, in: source)
        let iban = try sourceControl(#"IBAN:\s*([A-Z0-9]+)"#, in: source)
        guard try sourceControl(#"Currency:\s*([^\n]+)"#, in: source) == "QATARI RIYAL" else {
            throw CBQOracleError.ambiguousControl("currency")
        }
        try cbqCheckSourceDate(statementDate)
        var opening: Decimal?
        var periodStart: String?
        var previous: Decimal?
        var closing: Decimal?
        var rows: [Row] = []
        var pending: CBQPendingSourceRow?

        func finishPending() throws {
            guard let row = pending else { return }
            guard !row.description.isEmpty else { throw CBQOracleError.malformedRow("source-narration") }
            rows.append(Row(
                postingDate: row.postingDate,
                description: row.description.joined(separator: " "),
                sourceTransactionDate: row.sourceTransactionDate,
                signedAmount: NSDecimalNumber(decimal: row.signedAmount).stringValue,
                balance: NSDecimalNumber(decimal: row.balance).stringValue,
                sourcePage: row.page
            ))
            pending = nil
        }

        for (pageIndex, page) in pages.enumerated() {
            let headers = page.indices.filter {
                let text = cbqSourceText(page[$0].glyphs)
                return text.contains("Posting Date") && text.contains("Transaction Description")
                    && text.contains("Transaction Date") && text.contains("Debit")
                    && text.contains("Credit") && text.contains("Balance")
            }
            guard headers.count <= 1 else { throw CBQOracleError.ambiguousControl("transaction-header") }
            guard let header = headers.first else {
                // Empty/terms/advert pages are legitimate source pages. They must
                // contain neither a financial row nor a statement control.
                guard !page.contains(where: {
                    let columns = cbqSourceColumns($0)
                    let text = cbqSourceText($0.glyphs)
                    return cbqIsSourceDate(columns[0]) || cbqIsSourceDate(columns[2])
                        || text.contains("BROUGHT FORWARD") || text.contains("* CREDIT BALANCE")
                }) else { throw CBQOracleError.ambiguousControl("financial-page-without-header") }
                continue
            }
            guard closing == nil else { throw CBQOracleError.ambiguousControl("financial-page-after-closing") }
            for line in page.dropFirst(header + 1) {
                let text = cbqSourceText(line.glyphs)
                if text.isEmpty { continue }
                let cells = cbqSourceColumns(line)
                // Numeric slash fragments also occur in authentic narration. Only
                // the bottom-right source page counter is nonfinancial furniture.
                if line.y < 40,
                   cells.prefix(5).allSatisfy({ $0.isEmpty }), cells[5] == text,
                   text.range(of: #"^\d+/\d+$"#, options: .regularExpression) != nil {
                    continue
                }
                if cells[1] == "BROUGHT FORWARD" {
                    guard opening == nil, rows.isEmpty, pending == nil,
                          cbqIsSourceDate(cells[0]),
                          cells[2].isEmpty, cells[3].isEmpty, cells[4].isEmpty else {
                        throw CBQOracleError.ambiguousControl("brought-forward")
                    }
                    try cbqCheckSourceDate(cells[0])
                    let amount = try sourceDecimal(cells[5])
                    opening = amount
                    previous = amount
                    periodStart = cells[0]
                    continue
                }
                if text.hasPrefix("* CREDIT BALANCE") {
                    try finishPending()
                    guard closing == nil else { throw CBQOracleError.ambiguousControl("closing-balance") }
                    let amount = try sourceDecimal(sourceControl(#"^\* CREDIT BALANCE\s+([0-9,.]+)\s*$"#, in: text))
                    guard previous == amount else { throw CBQOracleError.failedEquation }
                    closing = amount
                    continue
                }
                guard closing == nil else { throw CBQOracleError.malformedRow("financial-content-after-closing") }
                if cbqIsSourceDate(cells[0]) {
                    try finishPending()
                    guard let prior = previous, cbqIsSourceDate(cells[2]),
                          !cells[1].isEmpty, cells[3].isEmpty != cells[4].isEmpty else {
                        throw CBQOracleError.malformedRow("source-financial-columns")
                    }
                    try cbqCheckSourceDate(cells[0])
                    try cbqCheckSourceDate(cells[2])
                    let amount = try sourceDecimal(cells[3].isEmpty ? cells[4] : cells[3])
                    let balance = try sourceDecimal(cells[5])
                    let signed = cells[3].isEmpty ? amount : -amount
                    guard amount > 0, prior + signed == balance else { throw CBQOracleError.failedEquation }
                    pending = CBQPendingSourceRow(
                        postingDate: cells[0], sourceTransactionDate: cells[2],
                        signedAmount: signed, balance: balance, page: pageIndex + 1,
                        description: [cells[1]]
                    )
                    previous = balance
                } else {
                    guard pending != nil, !cells[1].isEmpty,
                          [0, 2, 3, 4, 5].allSatisfy({ cells[$0].isEmpty }) else {
                        throw CBQOracleError.malformedRow("unowned-source-continuation")
                    }
                    pending!.description.append(cells[1])
                }
            }
        }
        guard let opening, let closing, let periodStart,
              pending == nil, previous == closing else { throw CBQOracleError.failedEquation }
        guard opening + rows.reduce(Decimal.zero, { $0 + (Decimal(string: $1.signedAmount) ?? Decimal.nan) }) == closing else {
            throw CBQOracleError.failedEquation
        }
        return Carrier(
            carrier: input.carrier,
            sha256: SHA256.hash(data: input.bytes).map { String(format: "%02x", $0) }.joined(),
            statementDate: statementDate, periodStart: periodStart,
            maskedAccount: account, maskedIBAN: iban,
            openingBalance: NSDecimalNumber(decimal: opening).stringValue,
            closingBalance: NSDecimalNumber(decimal: closing).stringValue,
            rows: rows
        )
    }


    private func sourceGroups(_ pattern: String, in source: String) throws -> [[String]] {
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).map { match in
            (1..<match.numberOfRanges).map { Range(match.range(at: $0), in: source).map { String(source[$0]) } ?? "" }
        }
    }
    private func sourceControl(_ pattern: String, in source: String) throws -> String {
        let values = try sourceGroups(pattern, in: source).compactMap(\.first)
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { throw CBQOracleError.ambiguousControl("header") }
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func sourceDecimal(_ value: String) throws -> Decimal {
        let clean = value.replacingOccurrences(of: ",", with: "")
        guard clean.range(of: #"^-?[0-9]+(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: clean, locale: Locale(identifier: "en_US_POSIX")) else {
            throw CBQOracleError.malformedRow("decimal")
        }
        return decimal
    }

    private func verifySourceObservations(_ provider: DatabaseProvider, workspace: String) throws {
        let observations = try provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace)
        expectSourceFact(observations.count == 19)
        expectSourceFact(observations.reduce(0) { $0 + $1.sourceRowCount } == 187)
        expectSourceFact(observations.reduce(0) { $0 + $1.importedTransactionCount } == 187)
        // These monthly sources do not overlap: every row was imported,
        // and no row merely represents a previously accepted transaction.
        expectSourceFact(observations.reduce(0) { $0 + $1.representedTransactionCount } == 0)
        expectSourceFact(observations.reduce(0) { $0 + $1.transactionObservationCount } == 187)
    }

    private func makeHydrator(_ provider: DatabaseProvider, workspace: String, store: TransactionStore) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            accountStore: AccountStore(), transactionStore: store, categoryStore: CategoryStore(), cardStore: CardStore(),
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            workspaceId: workspace, persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
    }
    private func compact(_ value: String) -> String { value.filter { !$0.isWhitespace } }
    private func decimal(_ value: String) -> Decimal { Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))! }
    private func date(_ value: String) -> StatementDate {
        let p = value.split(separator: "-")
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return try! StatementDate(year: 2000 + Int(p[2])!, month: months.firstIndex(of: p[1].lowercased())! + 1, day: Int(p[0])!)
    }
    private func oracleKey(_ row: Row) -> String {
        [date(row.postingDate).canonical, decimal(row.signedAmount).description, decimal(row.balance).description,
         compact(row.description), date(row.sourceTransactionDate).canonical].joined(separator: "|")
    }
    private func transactionKey(_ row: Transaction) -> String {
        [row.statementDate?.canonical ?? "", row.money.amount.description, row.runningBalanceMoney?.amount.description ?? "",
         compact(row.description), row.repositoryPreferredSourceTransactionDate?.canonical ?? ""].joined(separator: "|")
    }
    private func multiset(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { $0[$1, default: 0] += 1 }
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
