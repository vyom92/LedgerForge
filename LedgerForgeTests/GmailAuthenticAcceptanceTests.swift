import Darwin
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Exact Gmail originals only. The source oracle is built before production
/// preparation. No statement, domain object or financial DTO is authored as an
/// import input; no financial comparison is written to an evidence file.
@Suite(.serialized)
@MainActor
struct GmailAuthenticAcceptanceTests {
    private struct Manifest: Decodable { let nominations: [Nomination] }
    private struct Nomination: Decodable { let sha256: String; let family: String; let sourceID: String?; let disposition: String }
    private struct SourceCase {
        let source: GmailInboxSource
        let bytes: Data
        let password: String
        let compare: (PreparedImport) throws -> Void
        var bankBalanceObservation: (date: StatementDate, balance: Decimal, zeroActivity: Bool)? = nil
        var configure: ((inout PreparedImport) throws -> Void)? = nil
        var verifyStored: ((DatabaseProvider, RepositoryRuntimeSnapshot, PreparedImport, String) throws -> Void)? = nil
        var permitsUnresolvedInstrumentHold = false
        /// Frozen inventory disposition, never inferred from the product result.
        var expectedPreparationHold: String? = nil
        var expectedHoldLayout: String? = nil
        var relationshipBalanceObservations: [(ordinal: Int, date: String, balance: Decimal, zeroActivity: Bool)] = []
    }
    /// A final namespace starts with the exact inbox state and original bytes
    /// from a verified backup. Its new revision is local compare-and-swap
    /// bookkeeping; collection provenance itself is not reconstructed here.
    private struct CohortInboxSeed {
        let state: GmailInboxState
        let originals: [String: Data]
    }
    private enum CampaignError: Error { case missingEnvironment, unsupportedSelection, sourceUnavailable, commitFailed, sourceMismatch, cohortDeadlineExceeded }
    private struct CASSourceObservation: Encodable {
        let sha256: String
        let pages: [String]
    }

    /// Diagnostic transport only: source/parsed text goes to an owner-selected
    /// RAM FIFO, never XCTest logging, an oracle file or a statement derivative.
    @Test func selectedRetainedOriginalsProvideRAMOnlyDecisionEvidence() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["LEDGERFORGE_GMAIL_DECISION_PIPE"],
              let selection = environment["LEDGERFORGE_GMAIL_DECISION_SHAS"] else { throw CampaignError.missingEnvironment }
        var fileInfo = stat()
        guard lstat(path, &fileInfo) == 0, fileInfo.st_mode & S_IFMT == S_IFIFO else { throw CampaignError.sourceUnavailable }
        let selected = Set(selection.split(separator: ",").map(String.init))
        var observed: Set<String> = []
        var evidence: [[String: Any]] = []
        let credentials = KeychainStatementPasswordCredentialStore()
        var passwordsByScope: [String: [String]] = [:]
        for family in GmailSourceFamily.allCases where family != .other {
            for (source, bytes) in try historicalOriginals(family: family) {
                let sha = try #require(source.sha256)
                guard selected.contains(sha), observed.insert(sha).inserted else { continue }
                guard let pdf = PDFDocument(data: bytes) else { throw CampaignError.sourceUnavailable }
                var password = ""
                var unlocked = !pdf.isLocked
                if !unlocked {
                    let scope: String
                    switch family {
                    case .amex: scope = Institution.amex.statementPasswordCredentialScope
                    case .axisCard: scope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
                    case .axisBank: scope = Institution.axis.statementPasswordCredentialScope
                    case .hdfcBank: scope = Institution.hdfc.statementPasswordCredentialScope
                    case .consolidatedFunds: scope = GmailCASCredential.account
                    default: scope = Institution.cbq.statementPasswordCredentialScope
                    }
                    if passwordsByScope[scope] == nil {
                        passwordsByScope[scope] = family == .consolidatedFunds
                            ? try await GmailCASCredential.read().map(\.value)
                            : try await credentials.credentials(institutionCode: scope).map(\.value)
                    }
                    for candidate in passwordsByScope[scope] ?? [] where !unlocked {
                        if pdf.unlock(withPassword: candidate) { password = candidate; unlocked = true }
                    }
                }
                var item: [String: Any] = ["sha256": sha, "family": family.rawValue, "unlocked": unlocked]
                if unlocked {
                    // A page without native text is an explicit observation,
                    // not a fabricated financial input or a layout verdict.
                    let pages = try (0..<pdf.pageCount).map { try #require(pdf.page(at: $0)) }
                    item["pages"] = pages.map { $0.string ?? "" }
                    item["textUnavailablePages"] = pages.enumerated().compactMap { $0.element.string == nil ? $0.offset + 1 : nil }
                    var footerGeometry: [[String: Any]] = []
                    for pageIndex in 0..<pdf.pageCount {
                        let page = try #require(pdf.page(at: pageIndex))
                        let text = (page.string ?? "") as NSString
                        for anchor in ["Balances shown do not include accrued interest.",
                                       "This statement is issued pursuant to the terms and conditions"] {
                            let range = text.range(of: anchor)
                            if range.location != NSNotFound, let selection = page.selection(for: range) {
                                let bounds = selection.bounds(for: page)
                                footerGeometry.append(["page": pageIndex + 1, "anchor": anchor,
                                    "x": bounds.minX, "y": bounds.minY, "width": bounds.width, "height": bounds.height])
                            }
                        }
                    }
                    item["footerGeometry"] = footerGeometry
                    if environment["LEDGERFORGE_GMAIL_DECISION_RENDER"] == "1" {
                        // Inspection only. Original pages are rendered directly
                        // into the RAM pipe, never reserialized or saved as PDFs.
                        item["pageImages"] = try pages.map { page in
                            let size = page.bounds(for: .mediaBox).size
                            let rendered = page.thumbnail(of: NSSize(width: size.width * 1.5, height: size.height * 1.5), for: .mediaBox)
                            let bitmap = try #require(rendered.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
                            return try #require(bitmap.representation(using: .png, properties: [:])).base64EncodedString()
                        }
                    }
                    if environment["LEDGERFORGE_GMAIL_DECISION_PREPARE"] == "1" {
                        let provider = DatabaseProvider(inMemory: true)
                        var state = GmailInboxState(account: source.account)
                        state.sources[source.id] = source
                        _ = try provider.gmailInboxRepo.save(state, originals: [sha: bytes], expectedRevision: 0)
                        let engine = makeEngine(provider: provider, password: password, stores: GmailQualificationStores())
                        do {
                            let prepared = try await engine.prepareImport(from: try #require(source.importURL))
                            defer { engine.cancelPreparedImport(prepared) }
                            item["preparedProfile"] = prepared.financialDocument.parserProfileID ?? "unavailable"
                            item["validationPassed"] = prepared.validation.passed
                            item["preparedRows"] = prepared.financialDocument.transactions.map {
                                ["ordinal": $0.sourceProvenance.first?.sourceOrdinal ?? 0,
                                 "page": $0.sourceProvenance.first?.sourcePage ?? 0,
                                 "narration": $0.description] as [String: Any]
                            }
                        } catch { item["preparationError"] = safeFailureKind(error) }
                    }
                }
                evidence.append(item)
            }
        }
        guard observed == selected else { throw CampaignError.sourceUnavailable }
        let pipe = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        defer { try? pipe.close() }
        try pipe.write(contentsOf: JSONSerialization.data(withJSONObject: evidence))
    }

    @Test(arguments: ["amex_card", "axis_card_traditional", "cbq_bank", "cbq_card"])
    func nominatedBankAndCardOriginalsMatchIndependentOraclesAndBothProviders(family: String) async throws {
        let cases = try await loadBankAndCardCases(family: family)
        try #require(!cases.isEmpty)
        // All source expectations already exist before this first production
        // call. Provider differences cannot become their own source oracle.
        for (index, source) in cases.enumerated() {
            let memory = try await run(source, sqlite: false, index: index)
            let durable = try await run(source, sqlite: true, index: index)
            let parity = memory == durable
            #expect(parity, "Persisted financial row parity failed at source index \(index).")
        }
    }

    @Test func cbqMonthlyNarrationOwnershipMatchesSourceAndBothProviders() async throws {
        let sha = "1f12183dcefdd5775f1d68c67902345628bea3c6c1ccc212763c7bd434215868"
        let original = try #require(historicalOriginals(family: .cbqBank).first { $0.0.sha256 == sha })
        let candidate = try await bankAndCardCase(source: original.0, bytes: original.1, family: "cbq_bank")
        let memory = try await run(candidate, sqlite: false, index: 0)
        let sqlite = try await run(candidate, sqlite: true, index: 0)
        #expect(memory == sqlite)
    }

    @Test func cbqV1PrecedingBoundaryRepaymentRetainsItsPrintedDate() async throws {
        let sha = "0524eb48079899b88fcb1d19e33f6f4c3335ef161b1f652819db50b328fb467b"
        let original = try #require(historicalOriginals(family: .cbqCard).first { $0.0.sha256 == sha })
        let candidate = try await bankAndCardCase(source: original.0, bytes: original.1, family: "cbq_card")
        let provider = DatabaseProvider(inMemory: true)
        var inbox = GmailInboxState(account: original.0.account)
        inbox.sources[original.0.id] = original.0
        _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.1], expectedRevision: 0)
        let stores = GmailQualificationStores()
        let engine = makeEngine(provider: provider, password: candidate.password, stores: stores)
        let prepared = try await engine.prepareImport(from: try #require(original.0.importURL))
        defer { engine.cancelPreparedImport(prepared) }
        try candidate.compare(prepared)
        guard let evidence = prepared.financialDocument.cardStatementEvidence,
              let period = evidence.declaredStatementPeriod else { throw CampaignError.sourceMismatch }
        let matching = evidence.transactionAnnotations.filter { annotation in
            guard annotation.financialScope == .accountLevel,
                  annotation.summaryMembership == .cbqV1PaymentReceived,
                  annotation.liabilityEffect == .decreasesAmountOwed,
                  let transaction = prepared.financialDocument.transactions.first(where: { $0.id == annotation.parserTransactionID }) else {
                return false
            }
            return transaction.statementDate == annotation.sourceTransactionDate &&
                transaction.statementDate.map { $0 < period.start } == true
        }
        #expect(prepared.validation.passed)
        #expect(matching.count == 1)
    }

    @Test func relationshipBankOriginalsRetainDrawnColumnGeometry() async throws {
        let credentials = KeychainStatementPasswordCredentialStore()
        var originalCount = 0, tableCount = 0
        for family in [GmailSourceFamily.axisBank, .hdfcBank] {
            let institution: Institution = family == .axisBank ? .axis : .hdfc
            let candidates = try await credentials.credentials(institutionCode: institution.statementPasswordCredentialScope)
            for (source, bytes) in try historicalOriginals(family: family) {
                let sha = try #require(source.sha256)
                guard GmailInboxSource.digest(bytes) == sha, let pdf = PDFDocument(data: bytes) else {
                    throw CampaignError.sourceUnavailable
                }
                var password: String?
                if pdf.isLocked {
                    password = candidates.first { pdf.unlock(withPassword: $0.value) }?.value
                    if password == nil {
                        guard sha == "fead021d076578e5791eb99c708d82146bb931a321df54c09d65226191d8e0da" else {
                            throw CampaignError.sourceUnavailable
                        }
                        continue
                    }
                }
                let snapshot = SourceContentSnapshot(bytes: bytes)
                defer { snapshot.invalidate() }
                let raw = try await PDFDocumentReader().read(
                    request: ImportRequest(fileURL: try #require(source.importURL)), snapshot: snapshot, password: password)
                var sourceTables = 0
                for page in try #require(raw.pdfPageEvidence) {
                    for anchor in page.fragments where ["withdrawal", "withdrawals"].contains(anchor.text.lowercased()) {
                        let row = page.fragments.filter { abs($0.y - anchor.y) < 2 }
                        let labels = Set(row.map { $0.text.lowercased() })
                        guard labels.contains("deposits"), labels.contains("balance"), labels.contains("date") else { continue }
                        let roles = family == .axisBank
                            ? ["date", "transaction", "chq", "withdrawal", "deposits", "balance"]
                            : ["txn", "narration", "withdrawals", "deposits", "closing"]
                        let centers = try roles.map { role -> Double in
                            guard let word = row.first(where: { $0.text.lowercased().hasPrefix(role) }) else {
                                Issue.record("Relationship source \(sha.prefix(12)) is missing drawn-header role \(role).")
                                throw CampaignError.sourceMismatch
                            }
                            let geometry = try #require(word.geometry)
                            return (geometry.minX + geometry.maxX) / 2
                        }
                        let rules = try #require(page.drawings).segments.filter {
                            abs($0.start.x - $0.end.x) < 0.5 &&
                            min($0.start.y, $0.end.y) <= anchor.y && max($0.start.y, $0.end.y) >= anchor.y
                        }.map { Double($0.start.x) }.sorted()
                        var clusters: [[Double]] = []
                        for position in rules {
                            if let last = clusters.last?.last, position - last <= 1.5 {
                                clusters[clusters.count - 1].append(position)
                            } else { clusters.append([position]) }
                        }
                        let edges = clusters.map { $0.reduce(0, +) / Double($0.count) }
                        let slots = centers.map { center in
                            edges.indices.dropLast().first { edges[$0] < center && center < edges[$0 + 1] }
                        }
                        let complete = slots.compactMap { $0 }
                        guard complete.count == roles.count, let first = complete.first,
                              complete == Array(first..<(first + roles.count)) else {
                            Issue.record("Relationship source \(sha.prefix(12)) has incomplete drawn table columns.")
                            throw CampaignError.sourceMismatch
                        }
                        sourceTables += 1
                    }
                }
                guard sourceTables > 0 else { throw CampaignError.sourceMismatch }
                originalCount += 1; tableCount += sourceTables
            }
        }
        #expect(originalCount == 87)
        print("Relationship original reader geometry: \(originalCount) authentic originals, \(tableCount) complete drawn headers; no financial import.")
    }

    @Test func allRetainedRelationshipBanksMatchIndependentSourceMeaning() async throws {
        let expectations = try BankRelationshipAuthenticOracle.load()
        let credentials = KeychainStatementPasswordCredentialStore()
        var compared = 0, sectionCount = 0, rowCount = 0, zeroSections = 0
        for family in [GmailSourceFamily.axisBank, .hdfcBank] {
            let institution: Institution = family == .axisBank ? .axis : .hdfc
            let candidates = try await credentials.credentials(institutionCode: institution.statementPasswordCredentialScope)
            for (source, bytes) in try historicalOriginals(family: family) {
                let sha = try #require(source.sha256)
                if sha == "fead021d076578e5791eb99c708d82146bb931a321df54c09d65226191d8e0da" { continue }
                let expected = try #require(expectations[sha])
                guard GmailInboxSource.digest(bytes) == sha, let pdf = PDFDocument(data: bytes) else {
                    throw CampaignError.sourceUnavailable
                }
                let password = pdf.isLocked ? candidates.first(where: { pdf.unlock(withPassword: $0.value) })?.value : ""
                guard let password else { throw CampaignError.sourceUnavailable }
                let provider = DatabaseProvider(inMemory: true)
                var inbox = GmailInboxState(account: source.account)
                inbox.sources[source.id] = source
                _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: bytes], expectedRevision: 0)
                let engine = makeEngine(provider: provider, password: password, stores: GmailQualificationStores())
                do {
                    let prepared = try await engine.prepareImport(from: try #require(source.importURL))
                    defer { engine.cancelPreparedImport(prepared) }
                    try BankRelationshipAuthenticOracle.compare(prepared, source: expected)
                    let sections = try #require(prepared.financialDocument.bankStatementEvidence?.sections)
                    compared += 1; sectionCount += sections.count
                    rowCount += prepared.financialDocument.transactions.count
                    zeroSections += sections.filter { $0.transactionIDs.isEmpty }.count
                    #expect(try provider.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
                    #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
                    print("GMAIL_SOURCE_COMPARISON \(sha) RELATIONSHIP_BANK_PREPARATION_MATCHED no-financial-commit")
                } catch {
                    Issue.record("Relationship original \(sha.prefix(12)) preparation/comparison failed: \(safeFailureKind(error)).")
                    throw error
                }
            }
        }
        #expect(compared == 87 && sectionCount == 124 && rowCount == 1318 && zeroSections == 6)
        print("Relationship source comparison: 87 originals, 124 sections, 1318 occurrences, six zero sections; independent oracle and ordinary preparation; persistence remains separate.")
    }

    private func relationshipBankCases(_ expectations: [String: BankRelationshipAuthenticOracle.Source]) async throws -> [SourceCase] {
        let credentials = KeychainStatementPasswordCredentialStore()
        var cases: [SourceCase] = []
        for family in [GmailSourceFamily.axisBank, .hdfcBank] {
            let institution: Institution = family == .axisBank ? .axis : .hdfc
            let candidates = try await credentials.credentials(institutionCode: institution.statementPasswordCredentialScope)
            for (source, bytes) in try historicalOriginals(family: family) {
                let sha = try #require(source.sha256)
                if sha == "fead021d076578e5791eb99c708d82146bb931a321df54c09d65226191d8e0da" { continue }
                let expected = try #require(expectations[sha])
                guard GmailInboxSource.digest(bytes) == sha, let pdf = PDFDocument(data: bytes) else { throw CampaignError.sourceUnavailable }
                let password = pdf.isLocked ? candidates.first(where: { pdf.unlock(withPassword: $0.value) })?.value : ""
                guard let password else { throw CampaignError.sourceUnavailable }
                cases.append(SourceCase(source: source, bytes: bytes, password: password,
                    compare: { try BankRelationshipAuthenticOracle.compare($0, source: expected) }))
            }
        }
        guard cases.count == 87 else { throw CampaignError.sourceUnavailable }
        return cases
    }

    private func relationshipChoices(_ review: ImportIdentityReview) throws -> ImportAccountChoice? {
        guard case .bankSections(let sections) = review else { throw CampaignError.sourceMismatch }
        var choices: [String: ImportBankSectionChoice] = [:]
        for section in sections {
            switch section.identityReview {
            case .matchedExisting: break
            case .choiceRequired:
                choices[section.sectionID] = .createNewAccount(displayName: "Relationship qualification \(section.product)")
            default: throw CampaignError.sourceMismatch
            }
        }
        return choices.isEmpty ? nil : .bankSections(choices)
    }

    @Test(.globalRuntimeStateIsolation)
    func relationshipBanksPersistBothProvidersReplayReopenAndRestore() async throws {
        let expectations = try BankRelationshipAuthenticOracle.load()
        let cases = try await relationshipBankCases(expectations)
        #expect(expectations.values.flatMap(\.sections).count == 124 &&
                expectations.values.flatMap(\.sections).flatMap(\.rows).count == 1318 &&
                expectations.values.flatMap(\.sections).filter { $0.rows.isEmpty }.count == 6)
        let memory = try await runRelationshipBankCohort(cases, expectations: expectations, durable: false)
        let sqlite = try await runRelationshipBankCohort(cases, expectations: expectations, durable: true)
        let parity = memory == sqlite
        #expect(parity, "Relationship bank financial fields differ between providers.")
        print("Relationship bank durable campaign: 87 originals, 124 sections, 1318 occurrences, four accounts and six zero sections; both providers, exact replay, SQLite reopen and populated ordinary backup/restore passed.")
    }

    @Test(.globalRuntimeStateIsolation)
    func relationshipZeroBalancesUseSourceDatesInBothOrdersAndSurviveRecovery() async throws {
        let expectations = try BankRelationshipAuthenticOracle.load()
        let cases = try await relationshipBankCases(expectations)
        let januarySHA = "b23b7226f584018b791c6ce0dbc90363ee728b08641ff16952fd7937fda05721"
        let january = try #require(cases.first { $0.source.sha256 == januarySHA })
        let source = try #require(expectations[januarySHA])
        #expect(source.sections.count == 2 && source.sections.map { $0.rows.count } == [1, 0])
        let zero = try #require(source.sections.first { $0.rows.isEmpty })
        func date(_ value: String) -> String {
            value.split(whereSeparator: { $0 == "/" || $0 == "-" }).reversed().joined(separator: "-")
        }
        let neighbors = expectations.values.filter { $0.family == "hdfc" }.compactMap { candidate -> (String, String)? in
            guard let section = candidate.sections.first(where: { $0.account == zero.account }),
                  !section.rows.isEmpty else { return nil }
            return (candidate.sha256, date(section.end))
        }
        let priorSHA = try #require(neighbors.filter { $0.1 < date(zero.end) }.max(by: { $0.1 < $1.1 })?.0)
        let laterSHA = try #require(neighbors.filter { $0.1 > date(zero.end) }.min(by: { $0.1 < $1.1 })?.0)
        let prior = try #require(cases.first { $0.source.sha256 == priorSHA })
        let later = try #require(cases.first { $0.source.sha256 == laterSHA })
        // Jan alone exposes the native regression; the neighboring authentic
        // sources then prove both later-row and later-zero-control precedence.
        for ordered in [[january, prior, later], [later, prior, january]] {
            let memory = try await runRelationshipBankCohort(ordered, expectations: expectations, durable: false, expectedAccountCount: 2)
            let sqlite = try await runRelationshipBankCohort(ordered, expectations: expectations, durable: true, expectedAccountCount: 2)
            let parity = memory == sqlite
            #expect(parity, "Dated zero-section balance campaign differs between providers.")
        }
        print("Authentic HDFC zero-section balances passed both providers, both source orders, unchanged canonical fields, replay, reopen and populated restore.")
    }

    private func runRelationshipBankCohort(_ cases: [SourceCase],
            expectations: [String: BankRelationshipAuthenticOracle.Source], durable: Bool,
            expectedAccountCount: Int = 4) async throws -> [String] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Relationship-Banks-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("qualification.sqlite")
        let sqlite = durable ? try SQLiteRepositoryProvider(path: path.path) : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
        let stores = GmailQualificationStores()
        var projections: [String: [String]] = [:], sourceSessions: [String: String] = [:]
        let expectedSections = try cases.flatMap { original in
            let sha = try #require(original.source.sha256)
            return try #require(expectations[sha]).sections
        }
        let expectedRowCount = expectedSections.flatMap(\.rows).count
        func verifyBalances(_ current: DatabaseProvider, graph: BankSectionRepositorySnapshotDTO) throws {
            let before = try current.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
            let runtime = try GmailQualificationStores().hydrator(current).stageHydration()
            let sources = try Dictionary(uniqueKeysWithValues: sourceSessions.map { sha, sessionID in
                (sessionID, try #require(expectations[sha]))
            })
            try BankRelationshipAuthenticOracle.compareRuntimeBalances(runtime, sections: graph.sections, sourcesBySessionID: sources)
            try verifyBankAccountHistory(runtime, graph: graph)
            let canonicalUnchanged = try current.transactionRepo.trustedTransactions(workspaceId: "default-workspace") == before
            #expect(canonicalUnchanged, "Account balance hydration changed canonical transaction fields.")
        }
        for original in cases {
            let sha = try #require(original.source.sha256)
            var inbox = try provider.gmailInboxRepo.load(account: original.source.account)
            inbox.sources[original.source.id] = original.source
            _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.bytes], expectedRevision: inbox.revision)
            let engine = makeEngine(provider: provider, password: original.password, stores: stores)
            let prepared = try await engine.prepareImport(from: try #require(original.source.importURL))
            defer { engine.cancelPreparedImport(prepared) }
            try original.compare(prepared)
            let choice = try relationshipChoices(engine.reviewPreparedImport(prepared))
            let result = await engine.commitPreparedImport(prepared, accountChoice: choice)
            guard result.succeeded, result.hydrationOutcome == .committedAndHydrated else {
                Issue.record("Relationship source \(sha.prefix(12)), SQLite=\(durable), persisted=\(result.persisted), recovery=\(result.recoveryRoute), failure=\(result.errorMessage ?? "none").")
                throw CampaignError.commitFailed
            }
            let receiptMatches = result.accountId == nil && result.bankSections.count == expectations[sha]?.sections.count &&
                result.bankSections.reduce(0, { $0 + $1.importedTransactionCount }) == prepared.financialDocument.transactions.count
            #expect(receiptMatches, "Parent receipt lost separate section destinations.")
            projections[sha] = rowProjection(prepared.financialDocument.transactions)
            sourceSessions[sha] = prepared.importSession.id.uuidString
            let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
            try BankRelationshipAuthenticOracle.compareStored(graph.sections.filter { $0.importSessionId == prepared.importSession.id.uuidString },
                transactions: provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace"), source: try #require(expectations[sha]))
            try verifyBalances(provider, graph: graph)
        }
        let baseline = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let accounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
        let countMatches = baseline.sections.count == expectedSections.count && baseline.sections.flatMap(\.rows).count == expectedRowCount &&
            baseline.sections.filter { $0.rows.isEmpty }.count == expectedSections.filter { $0.rows.isEmpty }.count && accounts.count == expectedAccountCount
        #expect(countMatches, "Relationship account/section/occurrence totals differ from independent source inventory.")
        for account in accounts {
            let identities = baseline.sections.filter { $0.accountId == account.id }.flatMap(\.identityPatterns).map(\.pattern)
            // Authentic Axis months expose different positions of the same
            // masked account. Retain every literal mask, but require all
            // visible digits to agree. HDFC prints the complete account.
            let consistent = !identities.isEmpty && identities.allSatisfy { left in
                identities.allSatisfy { right in
                    left.count == right.count && zip(left, right).allSatisfy { $0 == $1 || $0 == "X" || $1 == "X" }
                }
            }
            #expect(consistent, "Conflicting source account identities were merged.")
        }
        func verify(_ current: DatabaseProvider) throws -> [String] {
            let snapshot = try GmailQualificationStores().hydrator(current).stageHydration()
            let graph = try current.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
            let graphMatches = graph == baseline
            #expect(graphMatches, "Relationship section graph changed on replay or recovery.")
            let transactions = try current.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
            #expect(transactions.count == expectedRowCount && snapshot.transactions.count == expectedRowCount)
            try verifyBalances(current, graph: graph)
            var projection: [String] = []
            for original in cases.sorted(by: { ($0.source.sha256 ?? "") < ($1.source.sha256 ?? "") }) {
                let sha = try #require(original.source.sha256)
                let rows = rowProjection(snapshot.transactions.filter { $0.repositoryImportSessionId == sourceSessions[sha] })
                let financialMatch = rows == projections[sha]
                #expect(financialMatch, "Relationship source fields changed after commit or recovery.")
                try BankRelationshipAuthenticOracle.compareStored(graph.sections.filter { $0.importSessionId == sourceSessions[sha] },
                    transactions: transactions, source: try #require(expectations[sha]))
                let retained = try current.gmailInboxRepo.original(sha256: sha, byteCount: original.bytes.count) == original.bytes
                #expect(retained)
                projection += rows
            }
            return projection
        }
        for original in cases {
            let engine = makeEngine(provider: provider, password: original.password, stores: stores)
            let replay = try await engine.prepareImport(from: try #require(original.source.importURL))
            let result = await engine.commitPreparedImport(replay)
            #expect(!result.persisted && result.previousImport != nil)
        }
        let projection = try verify(provider)
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            defer { reopened.database.close() }
            let runtime = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            _ = try verify(runtime)
            let previous = DatabaseProvider.shared
            DatabaseProvider.shared = runtime
            defer { DatabaseProvider.shared = previous }
            let coordinator = BackupRestoreCoordinator(testingAt: path)
            coordinator.installTestProvider(reopened)
            defer { try? coordinator.closeTestProvider() }
            let folder = root.appendingPathComponent("backups")
            try BackupFiles.createDirectory(folder)
            await coordinator.createBackup(to: folder)
            let package = try #require(coordinator.lastBackupURL)
            await coordinator.verifyRestore(from: package)
            await coordinator.replaceLedger()
            guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
            _ = try verify(DatabaseProvider.shared)
        }
        return projection
    }

    @Test(.globalRuntimeStateIsolation)
    func relationshipBankOverlapBothOrdersPreservesFirstSourcesAndWholeParentHolds() async throws {
        let oracle = try BankRelationshipAuthenticOracle.loadWithOverlap()
        let relationships = try await relationshipBankCases(oracle.sources)
        let axis = try AxisBankAuthenticAcceptanceTests().standaloneComparisonsForRelationshipCampaign(
            root: URL(fileURLWithPath: "/Users/vyom/Documents/Ledger Forge/Originals/Axis/Bank Accounts"))
        let hdfc = try await HDFCBankAccountAuthenticAcceptanceTests().standaloneComparisonsForRelationshipCampaign(
            root: URL(fileURLWithPath: "/Users/vyom/Documents/Ledger Forge/Originals/HDFC"))
        #expect(axis.count == 9 && hdfc.count == 8)
        let standalone = axis + hdfc
        var passwords: [String: String] = [:]
        for original in standalone {
            let bytes = try Data(contentsOf: original.url)
            guard GmailInboxSource.digest(bytes) == original.sha256 else { throw CampaignError.sourceUnavailable }
            passwords[original.sha256] = original.url.pathExtension.lowercased() == "pdf"
                ? try await knownGmailSourcePassword(bytes: bytes,
                    scope: axis.contains(where: { $0.sha256 == original.sha256 }) ? Institution.axis.statementPasswordCredentialScope : Institution.hdfc.statementPasswordCredentialScope)
                : ""
        }
        for standaloneFirst in [true, false] {
            let memory = try await runRelationshipOverlap(relationships, standalone: standalone, passwords: passwords,
                oracle: oracle, standaloneFirst: standaloneFirst, durable: false)
            let sqlite = try await runRelationshipOverlap(relationships, standalone: standalone, passwords: passwords,
                oracle: oracle, standaloneFirst: standaloneFirst, durable: true)
            let parity = memory == sqlite
            #expect(parity, "Overlap canonical source fields differ between providers.")
        }
        print("Relationship overlap campaign: 87 retained originals and 17 standalone representations; both providers and both import orders, exact source occurrence links, immutable first financial fields, genuine Axis whole-parent holds, replay, reopen and populated backup/restore passed.")
    }

    private func makeLocalBankEngine(provider: DatabaseProvider, password: String, stores: GmailQualificationStores) -> ImportEngine {
        let hydrator = stores.hydrator(provider)
        let passwords = DefaultPasswordProvider(credentialStore: InMemoryStatementPasswordCredentialStore(),
            supportedInstitutionCodes: [], challenge: { _ in password })
        return ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
    }

    private func runRelationshipOverlap(_ relationships: [SourceCase], standalone: [AuthenticStandaloneBankComparison],
            passwords: [String: String], oracle: (sources: [String: BankRelationshipAuthenticOracle.Source], overlap: BankRelationshipAuthenticOracle.Overlap),
            standaloneFirst: Bool, durable: Bool) async throws -> [String] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Bank-Overlap-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("qualification.sqlite")
        let sqlite = durable ? try SQLiteRepositoryProvider(path: path.path) : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
        let stores = GmailQualificationStores()
        var canonicalByPDF: [String: [String]] = [:]
        var sectionsByRelationship: [String: [BankStatementSectionPlanDTO]] = [:]
        var acceptedRelationships: [SourceCase] = [], acceptedStandalone: [AuthenticStandaloneBankComparison] = []
        var relationshipHolds = 0, standaloneHolds = 0, mixed = 0, supporting = 0, allNew = 0
        func transactions() throws -> [TransactionDTO] { try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace") }
        var completedCategoryWork: [String: CategoryImportWork] = [:]
        func verifyExactNewCategoryWork(_ before: [TransactionDTO]) throws {
            let facts = try transactions()
            let metadata = try #require(try provider.categoryRepo.automationSnapshot(workspaceId: "default-workspace"))
            let newIDs = Set(facts.map(\.id)).subtracting(before.map(\.id))
            #expect(Set(metadata.work.keys).subtracting(completedCategoryWork.keys) == newIDs)
            #expect(completedCategoryWork.allSatisfy { metadata.work[$0.key] == $0.value })
            let evaluation = CategoryEvaluation.evaluate(inputs: facts.filter { newIDs.contains($0.id) }.map(CategoryRuleInput.init),
                snapshot: metadata, assignments: [:], activeCategoryIDs: [])
            #expect(try provider.categoryRepo.applyCategoryEvaluation(evaluation, workspaceId: "default-workspace", historical: false) == newIDs.count)
            completedCategoryWork = try #require(try provider.categoryRepo.automationSnapshot(workspaceId: "default-workspace")).work
        }
        func checkFirstSources(_ before: [TransactionDTO]) throws {
            let after = Dictionary(uniqueKeysWithValues: try transactions().map { ($0.id, $0) })
            let unchanged = before.allSatisfy { after[$0.id] == $0 }
            #expect(unchanged, "An accepted supporting source changed first-accepted canonical fields or provenance.")
            try verifyExactNewCategoryWork(before)
        }
        func checkHold(_ prepared: PreparedImport, _ result: ImportEngineResult,
                       before: [TransactionDTO], graph: BankSectionRepositorySnapshotDTO, accounts: [AccountDTO]) throws {
            let held = !result.persisted && result.recoveryRoute == .reviewRequired(.bankSourceOverlapHeld)
            #expect(held, "A source-proven conflict did not hold its whole original.")
            let presentation = ImportOutcomePresentation(result: result)
            let specificReason = result.errorMessage != nil && presentation.message == result.errorMessage
            #expect(specificReason, "The whole-parent hold discarded its bounded source-specific reason.")
            let current = try transactions()
            let currentGraph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
            let currentAccounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
            let heldSession = try provider.importSessionRepo.importSession(id: prepared.importSession.id.uuidString)
            let noResidue = current == before && currentGraph == graph && currentAccounts == accounts && heldSession == nil
            #expect(noResidue, "A held original left accepted financial or account-section residue.")
            #expect(try provider.categoryRepo.automationSnapshot(workspaceId: "default-workspace")?.work == completedCategoryWork)
        }
        func importStandalone() async throws {
            for original in standalone {
                let engine = makeLocalBankEngine(provider: provider, password: passwords[original.sha256] ?? "", stores: stores)
                let prepared = try await engine.prepareImport(from: original.url)
                defer { engine.cancelPreparedImport(prepared) }
                try original.compare(prepared)
                let review = try engine.reviewPreparedImport(prepared)
                let choice: ImportAccountChoice?
                switch review {
                case .matchedExisting: choice = nil
                case .choiceRequired: choice = .createNewAccount(displayName: "Standalone qualification")
                default: throw CampaignError.sourceMismatch
                }
                let before = try transactions()
                let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
                let accounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
                let result = await engine.commitPreparedImport(prepared, accountChoice: choice)
                let conflict = !standaloneFirst && oracle.overlap.links.contains { $0.standaloneSHA == original.equivalentPDFSHA && $0.conflict }
                if conflict {
                    try checkHold(prepared, result, before: before, graph: graph, accounts: accounts)
                    standaloneHolds += 1
                    continue
                }
                guard result.succeeded else {
                    Issue.record("Standalone overlap \(original.sha256.prefix(12)), first=\(standaloneFirst), SQLite=\(durable): \(result.errorMessage ?? "incomplete hydration").")
                    throw CampaignError.commitFailed
                }
                try checkFirstSources(before)
                acceptedStandalone.append(original)
                let after = try transactions()
                if standaloneFirst {
                    let created = after.filter { $0.importSessionId == prepared.importSession.id.uuidString }.sorted {
                        ($0.rawRows.first?.sourceOrdinal ?? 0) < ($1.rawRows.first?.sourceOrdinal ?? 0)
                    }
                    if !created.isEmpty {
                        #expect(created.count == original.rowCount)
                        canonicalByPDF[original.equivalentPDFSHA] = created.map(\.id)
                    }
                } else {
                    #expect(result.transactionCount == 0 && result.recognizedExistingRowCount == original.rowCount)
                    let current = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
                    let section = try #require(current.sections.first { $0.importSessionId == prepared.importSession.id.uuidString })
                    #expect(section.rows.count == original.rowCount)
                    for link in oracle.overlap.links where link.standaloneSHA == original.equivalentPDFSHA && !link.conflict {
                        let sourceSections = try #require(sectionsByRelationship[link.relationshipSHA])
                        let sourceSection = try #require(sourceSections.first { $0.sectionOrdinal == link.sectionOrdinal })
                        let exactLink = section.rows[link.standaloneOrdinal - 1].source.incomingTransactionId ==
                            sourceSection.rows[link.occurrenceIndex - 1].source.incomingTransactionId
                        #expect(exactLink, "Reverse occurrence linkage changed source order or multiplicity.")
                    }
                    for (observation, source) in zip(section.rows, prepared.financialDocument.transactions) {
                        let literalMatch = observation.literalNarration == source.description && observation.literalReference == source.reference &&
                            observation.literalBalance == source.sourceProvenance.first?.literalRunningBalance
                        #expect(literalMatch, "Standalone supporting observation lost its literal source representation.")
                    }
                }
            }
        }
        func importRelationships() async throws {
            for original in relationships {
                let sha = try #require(original.source.sha256)
                var inbox = try provider.gmailInboxRepo.load(account: original.source.account)
                inbox.sources[original.source.id] = original.source
                _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.bytes], expectedRevision: inbox.revision)
                let engine = makeEngine(provider: provider, password: original.password, stores: stores)
                let prepared = try await engine.prepareImport(from: try #require(original.source.importURL))
                defer { engine.cancelPreparedImport(prepared) }
                try original.compare(prepared)
                let choice = try relationshipChoices(engine.reviewPreparedImport(prepared))
                let before = try transactions()
                let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
                let accounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
                let result = await engine.commitPreparedImport(prepared, accountChoice: choice)
                let proof = try #require(oracle.overlap.relationships.first { $0.sha256 == sha })
                if standaloneFirst && proof.conflicts > 0 {
                    try checkHold(prepared, result, before: before, graph: graph, accounts: accounts)
                    relationshipHolds += 1
                    continue
                }
                guard result.succeeded else {
                    Issue.record("Relationship overlap \(sha.prefix(12)), standaloneFirst=\(standaloneFirst), SQLite=\(durable): \(result.errorMessage ?? "incomplete hydration").")
                    throw CampaignError.commitFailed
                }
                try checkFirstSources(before)
                let expectedNew = standaloneFirst ? proof.outside : prepared.financialDocument.transactions.count
                #expect(result.transactionCount == expectedNew)
                let current = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
                let sections = current.sections.filter { $0.importSessionId == prepared.importSession.id.uuidString }
                sectionsByRelationship[sha] = sections
                acceptedRelationships.append(original)
                try BankRelationshipAuthenticOracle.compareStored(sections, transactions: transactions(),
                    source: try #require(oracle.sources[sha]), requiresFirstSource: !standaloneFirst)
                if standaloneFirst {
                    if proof.matched == 0 { allNew += 1 }
                    else if proof.outside == 0 { supporting += 1 }
                    else { mixed += 1 }
                    for link in oracle.overlap.links where link.relationshipSHA == sha && !link.conflict {
                        let section = try #require(sections.first { $0.sectionOrdinal == link.sectionOrdinal })
                        let canonical = try #require(canonicalByPDF[link.standaloneSHA])
                        let exactLink = section.rows[link.occurrenceIndex - 1].source.incomingTransactionId == canonical[link.standaloneOrdinal - 1]
                        #expect(exactLink, "Forward occurrence linkage changed source order or multiplicity.")
                    }
                }
            }
        }
        if standaloneFirst { try await importStandalone(); try await importRelationships() }
        else { try await importRelationships(); try await importStandalone() }
        if standaloneFirst {
            #expect(relationshipHolds == 10 && allNew > 0 && mixed > 0 && supporting > 0)
        } else {
            let expectedHolds = standalone.filter { original in oracle.overlap.links.contains { $0.standaloneSHA == original.equivalentPDFSHA && $0.conflict } }.count
            #expect(standaloneHolds == expectedHolds && relationshipHolds == 0)
        }
        let baseline = try transactions()
        let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let hydrated = rowProjection(try stores.hydrator(provider).stageHydration().transactions).sorted()
        for original in acceptedRelationships {
            let engine = makeEngine(provider: provider, password: original.password, stores: stores)
            let prepared = try await engine.prepareImport(from: try #require(original.source.importURL))
            let result = await engine.commitPreparedImport(prepared)
            #expect(!result.persisted && result.previousImport != nil)
        }
        for original in acceptedStandalone {
            let engine = makeLocalBankEngine(provider: provider, password: passwords[original.sha256] ?? "", stores: stores)
            let prepared = try await engine.prepareImport(from: original.url)
            let result = await engine.commitPreparedImport(prepared)
            #expect(!result.persisted && result.previousImport != nil)
        }
        func verify(_ current: DatabaseProvider) throws {
            #expect(try current.categoryRepo.automationSnapshot(workspaceId: "default-workspace")?.work == completedCategoryWork)
            let unchanged = try current.transactionRepo.trustedTransactions(workspaceId: "default-workspace") == baseline &&
                current.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace") == graph
            #expect(unchanged, "Overlap graph changed during replay or recovery.")
            let snapshot = try GmailQualificationStores().hydrator(current).stageHydration()
            try verifyBankAccountHistory(snapshot, graph: graph)
            let rows = rowProjection(snapshot.transactions).sorted()
            let sourceFieldsMatch = rows == hydrated
            #expect(sourceFieldsMatch, "Canonical source fields changed during recovery.")
        }
        try verify(provider)
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            defer { reopened.database.close() }
            let runtime = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            try verify(runtime)
            let previous = DatabaseProvider.shared
            DatabaseProvider.shared = runtime
            defer { DatabaseProvider.shared = previous }
            let coordinator = BackupRestoreCoordinator(testingAt: path)
            coordinator.installTestProvider(reopened)
            defer { try? coordinator.closeTestProvider() }
            let folder = root.appendingPathComponent("backups")
            try BackupFiles.createDirectory(folder)
            await coordinator.createBackup(to: folder)
            await coordinator.verifyRestore(from: try #require(coordinator.lastBackupURL))
            await coordinator.replaceLedger()
            guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
            try verify(DatabaseProvider.shared)
        }
        print("Bank overlap pass: standaloneFirst=\(standaloneFirst), SQLite=\(durable), canonical=\(baseline.count), relationshipHolds=\(relationshipHolds), standaloneHolds=\(standaloneHolds), allNew=\(allNew), supporting=\(supporting), mixed=\(mixed).")
        return hydrated
    }

    @Test func relationshipBankMissingSiblingFailureAndStaleReviewLeaveNoPartialGraph() async throws {
        let expectations = try BankRelationshipAuthenticOracle.load()
        let cases = try await relationshipBankCases(expectations)
        let original = try #require(cases.first { source in
            guard let expected = expectations[source.source.sha256 ?? ""] else { return false }
            return expected.family == "hdfc" && expected.sections.count == 2 && expected.sections.allSatisfy { !$0.rows.isEmpty }
        })
        let sibling = try #require(cases.first { $0.source.sha256 != original.source.sha256 &&
            expectations[$0.source.sha256 ?? ""]?.family == "hdfc" })
        for durable in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Bank-Atomicity-\(UUID())")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: root) }
            let sqlite = durable ? try SQLiteRepositoryProvider(path: root.appendingPathComponent("qualification.sqlite").path) : nil
            defer { sqlite?.database.close() }
            let memory = InMemoryRepositoryProvider()
            let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(
                workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo, categoryRepo: memory.categoryRepo,
                accountRepo: memory.accountRepo, cardRepo: memory.cardRepo, importSessionRepo: memory.importSessionRepo,
                confirmedImportRepo: memory.confirmedImportRepo, salaryRepo: memory.salaryRepo,
                fundingPlanRepo: memory.fundingPlanRepo, investmentRepo: memory.investmentRepo,
                gmailInboxRepo: memory.gmailInboxRepo, generationToken: memory.generationToken)
            for source in [original, sibling] {
                let sha = try #require(source.source.sha256)
                var inbox = try provider.gmailInboxRepo.load(account: source.source.account)
                inbox.sources[source.source.id] = source.source
                _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: source.bytes], expectedRevision: inbox.revision)
            }
            let stores = GmailQualificationStores()
            let engine = makeEngine(provider: provider, password: original.password, stores: stores)
            func assertEmpty(_ prepared: PreparedImport) throws {
                let accounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
                let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
                let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
                let session = try provider.importSessionRepo.importSession(id: prepared.importSession.id.uuidString)
                let empty = accounts.isEmpty && transactions.isEmpty && graph.sections.isEmpty && session == nil
                #expect(empty, "Rejected parent left accepted financial residue.")
                if let sqlite {
                    for table in ["accounts", "account_identifiers", "account_identifier_observations", "documents",
                                  "document_fingerprints", "normalized_documents", "normalized_rows", "transaction_raw_rows",
                                  "bank_statement_sections", "bank_section_identity_observations", "bank_transaction_occurrences"] {
                        let count = try sqlite.database.query(sql: "SELECT COUNT(*) FROM \(table);", params: []) { $0.int64(at: 0) ?? -1 }.first
                        #expect(count == 0, "Rejected parent left source or ownership residue in \(table).")
                    }
                }
            }
            let incomplete = try await engine.prepareImport(from: try #require(original.source.importURL))
            try original.compare(incomplete)
            guard case .bankSections(let complete)? = try relationshipChoices(engine.reviewPreparedImport(incomplete)),
                  let only = complete.first else { throw CampaignError.sourceMismatch }
            let missingSibling = await engine.commitPreparedImport(incomplete, accountChoice: .bankSections([only.key: only.value]))
            #expect(!missingSibling.persisted && missingSibling.recoveryRoute == .reviewRequired(.accountChoiceRequired))
            try assertEmpty(incomplete)

            if let sqlite {
                // Nonfinancial fault injection after the first real section
                // and all incoming transactions have reached the transaction.
                try sqlite.database.execute(sql: "CREATE TEMP TRIGGER qualification_second_bank_section BEFORE INSERT ON bank_statement_sections WHEN NEW.section_ordinal=2 BEGIN SELECT RAISE(ABORT,'qualification second bank section failure'); END;")
            } else { memory.injectConfirmedImportFailure(after: .transactions) }
            let failing = try await engine.prepareImport(from: try #require(original.source.importURL))
            try original.compare(failing)
            let failureChoice = try relationshipChoices(engine.reviewPreparedImport(failing))
            let failed = await engine.commitPreparedImport(failing, accountChoice: failureChoice)
            #expect(!failed.persisted)
            try assertEmpty(failing)
            if let sqlite { try sqlite.database.execute(sql: "DROP TRIGGER qualification_second_bank_section;") }
            else { memory.injectConfirmedImportFailure(after: nil) }

            let stale = try await engine.prepareImport(from: try #require(original.source.importURL))
            defer { engine.cancelPreparedImport(stale) }
            try original.compare(stale)
            let review = try engine.reviewPreparedImport(stale)
            let choice = try relationshipChoices(review)
            let plan = try ImportPersistenceMapper().bankImportPlan(financialDocument: stale.financialDocument,
                importSession: stale.importSession, validation: stale.validation, fingerprintSet: stale.fingerprintSet,
                providerGeneration: stale.providerGeneration, review: review, accountChoice: choice)
            guard case .ready(let reviewed) = provider.confirmedImportRepo.reviewBankImport(plan) else { throw CampaignError.commitFailed }
            // Real source B establishes the accounts after source A's review.
            // No account, transaction, document or DTO is invented or mutated.
            let siblingEngine = makeEngine(provider: provider, password: sibling.password, stores: stores)
            let preparedSibling = try await siblingEngine.prepareImport(from: try #require(sibling.source.importURL))
            try sibling.compare(preparedSibling)
            let siblingChoice = try relationshipChoices(siblingEngine.reviewPreparedImport(preparedSibling))
            let siblingResult = await siblingEngine.commitPreparedImport(preparedSibling, accountChoice: siblingChoice)
            guard siblingResult.succeeded else { throw CampaignError.commitFailed }
            let before = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
            let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
            guard case .held = provider.confirmedImportRepo.commitBankImport(reviewed) else {
                Issue.record("Parent account review was not rechecked inside the provider transaction.")
                throw CampaignError.commitFailed
            }
            let unchanged = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace") == before &&
                provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace") == graph &&
                provider.importSessionRepo.importSession(id: stale.importSession.id.uuidString) == nil
            #expect(unchanged, "Stale reviewed parent changed accepted source B.")
            let fresh = try await engine.prepareImport(from: try #require(original.source.importURL))
            try original.compare(fresh)
            let freshResult = await engine.commitPreparedImport(fresh, accountChoice: try relationshipChoices(engine.reviewPreparedImport(fresh)))
            guard freshResult.succeeded else { throw CampaignError.commitFailed }
            let finalGraph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
            let finalRows = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
            let originalSHA = try #require(original.source.sha256)
            try BankRelationshipAuthenticOracle.compareStored(finalGraph.sections.filter { $0.importSessionId == fresh.importSession.id.uuidString },
                transactions: finalRows, source: try #require(expectations[originalSHA]))
            let accountCount = try provider.accountRepo.accounts(workspaceId: "default-workspace").count
            #expect(accountCount == 2 && finalGraph.sections.count == 4)
        }
        print("Authentic parent atomicity: missing sibling choice, mid-transaction SQLite failure, in-memory publication failure and real-source stale identity review all held without partial accepted graph; fresh review recovered in both providers.")
    }

    private func selectedCBQSavingsCases() async throws -> [SourceCase] {
        struct Inventory: Decodable {
            struct Entry: Decodable {
                struct Outcome: Decodable { let detail: String }
                let source: GmailInboxSource
                let beforeQualification: Outcome
            }
            let originals: [Entry]
        }
        let env = ProcessInfo.processInfo.environment
        guard let path = env["LEDGERFORGE_CBQ_CORRECTION_INVENTORY"],
              let digest = env["LEDGERFORGE_CBQ_CORRECTION_INVENTORY_SHA256"] else {
            throw CampaignError.missingEnvironment
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard GmailInboxSource.digest(data) == digest else { throw CampaignError.sourceUnavailable }
        let inventory = try JSONDecoder().decode(Inventory.self, from: data)
        let selected = inventory.originals.filter {
            ["cbq_savings", "cbq_e_savings"].contains(String($0.beforeQualification.detail.split(separator: " ").first ?? ""))
        }
        let originals = try historicalOriginals(family: .cbqBank)
        let bySHA = try Dictionary(uniqueKeysWithValues: originals.map { (try #require($0.0.sha256), $0) })
        guard selected.count == 17, Set(selected.compactMap { $0.source.sha256 }).count == 17 else {
            throw CampaignError.sourceUnavailable
        }
        var cases: [SourceCase] = []
        // Every oracle is derived from the original before production runs.
        for entry in selected {
            let sha = try #require(entry.source.sha256)
            let original = try #require(bySHA[sha])
            guard original.0.id == entry.source.id,
                  original.1.count == entry.source.expectedByteCount,
                  GmailInboxSource.digest(original.1) == sha else { throw CampaignError.sourceUnavailable }
            do {
                cases.append(try await bankAndCardCase(source: original.0, bytes: original.1, family: "cbq_bank"))
            } catch {
                print("CBQ_SAVINGS_ORACLE_FAILURE \(sha) \(error)")
                throw error
            }
        }
        return cases
    }

    @Test func selectedCBQSavingsOriginalsMatchIndependentSourceMeaning() async throws {
        let cases = try await selectedCBQSavingsCases()
        var count = 0, valueDateRows = 0, differentDates = 0, zeroSources = 0, undatedOpenings = 0
        for original in cases {
            let provider = DatabaseProvider(inMemory: true)
            var inbox = GmailInboxState(account: original.source.account)
            inbox.sources[original.source.id] = original.source
            let sha = try #require(original.source.sha256)
            _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.bytes], expectedRevision: 0)
            let engine = makeEngine(provider: provider, password: original.password, stores: GmailQualificationStores())
            let prepared = try await engine.prepareImport(from: try #require(original.source.importURL))
            defer { engine.cancelPreparedImport(prepared) }
            try original.compare(prepared)
            let document = prepared.financialDocument
            count += document.transactions.count
            valueDateRows += document.transactions.filter { $0.valueDate != nil }.count
            differentDates += document.transactions.filter {
                ($0.valueDate ?? $0.sourceProvenance.first?.sourceTransactionDate) != $0.statementDate
            }.count
            if document.transactions.isEmpty {
                zeroSources += 1
                #expect(document.zeroActivityEvidence != nil)
            }
            if document.sourceStatementEvidence?.period == nil { undatedOpenings += 1 }
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
            #expect(try provider.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
            print("GMAIL_SOURCE_COMPARISON \(sha) CBQ_SAVINGS_PREPARATION_MATCHED no-financial-commit")
        }
        #expect(count == 402 && valueDateRows == 291 && differentDates == 59)
        #expect(zeroSources == 1 && undatedOpenings == 2)
        print("CBQ selected Savings source comparison: 17 originals, 402 occurrences; 291 actual value dates, 59 second-date differences, one zero source, two undated openings. Persistence qualification remains separate.")
    }

    @Test(.globalRuntimeStateIsolation)
    func selectedCBQSavingsPersistBothProvidersZeroOrdersReplayReopenAndRestore() async throws {
        let cases = try await selectedCBQSavingsCases()
        let zeroSHA = "e141dc004b460468d4df21c64ab4f6d938af2492f34fd563d8480757b31b5628"
        let zero = try #require(cases.first { $0.source.sha256 == zeroSHA })
        let others = cases.filter { $0.source.sha256 != zeroSHA }
        guard others.count == 16 else { throw CampaignError.sourceUnavailable }
        for zeroFirst in [true, false] {
            let ordered = zeroFirst ? [zero] + others : others + [zero]
            let memory = try await runCBQSavingsCohort(ordered, durable: false, restore: false)
            let sqlite = try await runCBQSavingsCohort(ordered, durable: true, restore: zeroFirst)
            let parity = memory == sqlite
            #expect(parity, "Savings cohort financial fields differ between providers.")
        }
        print("CBQ Savings durable campaign: 17 originals, 402 occurrences, two separate accounts; both providers, zero-first/zero-last, exact replay, SQLite reopen and populated ordinary backup/restore passed.")
    }

    private func runCBQSavingsCohort(_ cases: [SourceCase], durable: Bool, restore: Bool) async throws -> [String] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-CBQ-Savings-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("qualification.sqlite")
        let sqlite = durable ? try SQLiteRepositoryProvider(path: path.path) : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
        let stores = GmailQualificationStores()
        var expectations: [String: [String]] = [:]
        var sourceSessions: [String: String] = [:]
        var sourceBalances: [String: [(date: StatementDate, balance: Decimal, zeroActivity: Bool)]] = [:]
        func verifyBalances(_ snapshot: RepositoryRuntimeSnapshot) throws {
            for account in snapshot.accounts {
                let accountID = try #require(account.repositoryAccountId)
                let candidates = try #require(sourceBalances[accountID])
                let latestDate = candidates.map(\.date).max()
                let latest = candidates.filter { $0.date == latestDate }
                let expected: Decimal?
                let expectedDate: String?
                if let first = latest.first, latest.filter({ !$0.zeroActivity }).count <= 1,
                   latest.allSatisfy({ $0.balance == first.balance }) {
                    expected = first.balance; expectedDate = first.date.canonical
                } else { expected = nil; expectedDate = nil }
                let positions = DashboardPositionProjection.make(accounts: snapshot.accounts,
                    transactions: snapshot.transactions, cardSnapshot: snapshot.cardSnapshot).flatMap(\.banks)
                let position = try #require(positions.first { $0.id == accountID })
                let matches = account.currentBalance == (expected ?? .zero) && account.currentBalanceAsOfISO == expectedDate &&
                    position.amount?.amount == expected && position.asOf?.canonical == expectedDate
                #expect(matches, "Savings balance differs from independently extracted dated source evidence.")
            }
        }
        for original in cases {
            let sha = try #require(original.source.sha256)
            var inbox = try provider.gmailInboxRepo.load(account: original.source.account)
            inbox.sources[original.source.id] = original.source
            _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.bytes], expectedRevision: inbox.revision)
            let engine = makeEngine(provider: provider, password: original.password, stores: stores)
            let prepared = try await engine.prepareImport(from: try #require(original.source.importURL))
            defer { engine.cancelPreparedImport(prepared) }
            try original.compare(prepared)
            let review = try engine.reviewPreparedImport(prepared)
            let choice: ImportAccountChoice?
            switch review {
            case .matchedExisting: choice = nil
            case .unavailable: choice = .createNewAccount(displayName: "CBQ Savings qualification")
            default: throw CampaignError.sourceMismatch
            }
            let committed = await engine.commitPreparedImport(prepared, accountChoice: choice)
            guard committed.hydrationOutcome == .committedAndHydrated else {
                Issue.record("Savings cohort source \(sha.prefix(12)), SQLite=\(durable), persisted=\(committed.persisted), hydration=\(committed.hydrationOutcome), recovery=\(committed.recoveryRoute).")
                throw CampaignError.commitFailed
            }
            expectations[sha] = rowProjection(prepared.financialDocument.transactions)
            sourceSessions[sha] = prepared.importSession.id.uuidString
            let accountID = try #require(committed.accountId)
            sourceBalances[accountID, default: []].append(try #require(original.bankBalanceObservation))
            try verifyBankSectionEvidence(provider, prepared: prepared)
            try verifyBalances(stores.hydrator(provider).stageHydration())
        }
        let baseline = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let baselineRows = try stores.hydrator(provider).stageHydration().transactions
        let accountCount = try provider.accountRepo.accounts(workspaceId: "default-workspace").count
        let countsMatch = baseline.sections.count == 17 && baselineRows.count == 402 &&
            baseline.sections.filter { $0.rows.isEmpty }.count == 1 &&
            baseline.sections.flatMap(\.rows).filter { $0.valueDateISO != nil }.count == 291 &&
            accountCount == 2
        #expect(countsMatch, "Savings sources or account ownership were lost or duplicated.")
        func verify(_ current: DatabaseProvider) throws -> [String] {
            let snapshot = try GmailQualificationStores().hydrator(current).stageHydration()
            try verifyBalances(snapshot)
            let graphMatches = try current.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace") == baseline
            #expect(graphMatches, "Savings section graph changed on replay or recovery.")
            try verifyBankAccountHistory(snapshot, graph: baseline)
            var projection: [String] = []
            for original in cases.sorted(by: { ($0.source.sha256 ?? "") < ($1.source.sha256 ?? "") }) {
                let sha = try #require(original.source.sha256)
                let rows = rowProjection(snapshot.transactions.filter { $0.repositoryImportSessionId == sourceSessions[sha] })
                let financialMatch = rows == expectations[sha]
                #expect(financialMatch, "Savings source fields changed after commit or recovery.")
                let retained = try current.gmailInboxRepo.original(sha256: sha, byteCount: original.bytes.count) == original.bytes
                #expect(retained)
                projection += rows
            }
            return projection
        }
        for original in cases {
            let engine = makeEngine(provider: provider, password: original.password, stores: stores)
            let replay = try await engine.prepareImport(from: try #require(original.source.importURL))
            let result = await engine.commitPreparedImport(replay)
            #expect(!result.persisted && result.previousImport != nil)
        }
        let projection = try verify(provider)
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            defer { reopened.database.close() }
            let runtime = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            _ = try verify(runtime)
            if restore {
                let previous = DatabaseProvider.shared
                DatabaseProvider.shared = runtime
                defer { DatabaseProvider.shared = previous }
                let coordinator = BackupRestoreCoordinator(testingAt: path)
                coordinator.installTestProvider(reopened)
                defer { try? coordinator.closeTestProvider() }
                let folder = root.appendingPathComponent("backups")
                try BackupFiles.createDirectory(folder)
                await coordinator.createBackup(to: folder)
                let package = try #require(coordinator.lastBackupURL)
                let manifest = try BackupFiles.verifyPackage(package)
                #expect(manifest.schemaVersion == BackupCompatibility.supportedSchemaVersion)
                await coordinator.verifyRestore(from: package)
                await coordinator.replaceLedger()
                guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
                _ = try verify(DatabaseProvider.shared)
            }
        }
        return projection
    }

    private func verifyBankAccountHistory(_ snapshot: RepositoryRuntimeSnapshot, graph: BankSectionRepositorySnapshotDTO) throws {
        let sectionsByAccount = Dictionary(grouping: graph.sections, by: \.accountId)
        let sessionsByID = Dictionary(grouping: snapshot.importSessions, by: \.id)
        let transactionsByAccount = Dictionary(grouping: snapshot.transactions, by: \.repositoryAccountId)
        for account in snapshot.accounts {
            let accountID = try #require(account.repositoryAccountId)
            let groups = Dictionary(grouping: sectionsByAccount[accountID] ?? [], by: \.importSessionId)
            let transactionsBySession = Dictionary(grouping: transactionsByAccount[accountID] ?? [], by: \.repositoryImportSessionId)
            let history = AccountsViewModel.importHistory(accountID: accountID, transactions: snapshot.transactions, sessions: snapshot.importSessions)
            let historyByID = Dictionary(grouping: history, by: \.id)
            for (sessionID, sections) in groups {
                let row = try #require(historyByID[sessionID]?.first)
                let ownedTransactions = transactionsBySession[sessionID] ?? []
                let sourceCount = sections.reduce(0) { $0 + $1.rows.count }
                let matches = row.transactionCount == ownedTransactions.count && row.sourceRowCount == sourceCount &&
                    row.recognizedExistingRowCount == sourceCount - ownedTransactions.count && row.currencyCode == account.currencyCode &&
                    historyByID[sessionID]?.count == 1 && sessionsByID[sessionID]?.count == 1
                #expect(matches, "Account history lost a source section or borrowed a sibling's transaction counts.")
                if sourceCount == 0 {
                    let undated = row.firstTransactionDate == nil && row.lastTransactionDate == nil
                    #expect(undated, "A zero-activity account history row borrowed a sibling's transaction date.")
                }
            }
        }
    }

    @Test func completeCBQBankCorrectionCorpusPreservesSourceMeaningAndHolds() async throws {
        struct Inventory: Decodable {
            struct Entry: Decodable {
                struct Outcome: Decodable { let disposition: String; let detail: String }
                let source: GmailInboxSource
                let beforeQualification: Outcome
            }
            let originals: [Entry]
        }
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["LEDGERFORGE_CBQ_CORRECTION_INVENTORY"],
              let digest = environment["LEDGERFORGE_CBQ_CORRECTION_INVENTORY_SHA256"] else { throw CampaignError.missingEnvironment }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard GmailInboxSource.digest(data) == digest else { throw CampaignError.sourceUnavailable }
        let inventory = try JSONDecoder().decode(Inventory.self, from: data)
        let originals = try historicalOriginals(family: .cbqBank)
        guard Set(originals.map { $0.0.sha256 }) == Set(inventory.originals.map { $0.source.sha256 }),
              originals.count == inventory.originals.count else { throw CampaignError.sourceUnavailable }
        let bySHA = try Dictionary(uniqueKeysWithValues: originals.map { (try #require($0.0.sha256), $0) })
        var unsupported: [(Nomination, GmailInboxSource, Data)] = []
        var qualified = 0
        for (index, entry) in inventory.originals.enumerated() {
            let sha = try #require(entry.source.sha256)
            let original = try #require(bySHA[sha])
            guard original.0.id == entry.source.id, original.1.count == entry.source.expectedByteCount,
                  GmailInboxSource.digest(original.1) == sha else { throw CampaignError.sourceUnavailable }
            let kind = String(try #require(entry.beforeQualification.detail.split(separator: " ").first))
            // Keep the frozen inventory unchanged while selecting only the
            // source families whose exact parser contracts are now present:
            // Savings/E-Savings plus every retained legacy Current and USD
            // Current original. Other historical layouts remain held.
            let selectedBankFamily = ["cbq_savings", "cbq_e_savings",
                                      "cbq_legacy_value_date_bank", "cbq_usd_current_account"].contains(kind)
            if entry.beforeQualification.disposition == "KNOWN_UNSUPPORTED_LAYOUT", !selectedBankFamily {
                unsupported.append((.init(sha256: sha, family: kind, sourceID: original.0.id, disposition: "available"), original.0, original.1))
                continue
            }
            // Frozen scope came from source account/currency/column roles.
            // Rebuild complete source meaning before touching production.
            let candidate: SourceCase
            do {
                candidate = try await bankAndCardCase(source: original.0, bytes: original.1, family: "cbq_bank")
            } catch {
                Issue.record("CBQ bank source \(sha.prefix(12)) source oracle preparation failed: \(safeFailureKind(error))")
                throw error
            }
            if entry.beforeQualification.detail.contains("CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage") {
                // The original independently establishes an exact neutral-zero
                // closing control. It now qualifies through the ordinary
                // source comparison and both-provider/reopen path.
                guard let pdf = PDFDocument(data: original.1), !pdf.isLocked || pdf.unlock(withPassword: candidate.password) else {
                    throw CampaignError.sourceUnavailable
                }
                let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
                guard text.range(of: #"(?m)^\*\s+BALANCE\s+0\.00\s*$"#, options: .regularExpression) != nil else {
                    throw CampaignError.sourceMismatch
                }
            }
            let memory = try await run(candidate, sqlite: false, index: index)
            let durable = try await run(candidate, sqlite: true, index: index)
            #expect(memory == durable)
            qualified += 1
            print("GMAIL_DISPOSITION \(sha) SUPPORTED_AND_QUALIFIED \(selectedBankFamily ? kind : "cbq_monthly") independent-artwork-and-glyph-oracle both-providers-replay-reopen")
        }
        try await verifyUnsupportedBankOriginals(unsupported)
        #expect(qualified + unsupported.count == inventory.originals.count)
        #expect(qualified == 81 && unsupported.count == 50)
        print("CBQ correction frozen corpus: \(inventory.originals.count) originals, \(qualified) qualified, \(unsupported.count) unsupported; all exact bytes verified.")
    }

    @Test func nominatedCBQInvestmentOriginalsMatchIndependentOraclesAndBothProviders() async throws {
        let selected = try nominatedOriginals(families: ["cbq_portfolio_holding", "cbq_investment_client"])
        let password = try #require(try await KeychainStatementPasswordCredentialStore().password(
            institutionCode: Institution.cbq.statementPasswordCredentialScope))
        let qualification = InvestmentRAMOriginalTests()
        // Finish every source-only expectation before preparing the first item.
        let originals = try selected.map { nomination, source, bytes in
            try qualification.cbqGmailOriginal(source: source, bytes: bytes, password: password, family: nomination.family)
        }
        let sources = Dictionary(uniqueKeysWithValues: selected.map { ($0.0.sha256, $0.1) })
        try await qualification.qualifyGmailOriginals(originals, sources: sources)
    }

    @Test func nominatedSalaryOriginalsMatchIndependentOraclesAndBothProviders() async throws {
        let selected = try nominatedOriginals(families: ["salary"])
        try await SalaryAuthenticCorpusAcceptanceTests().qualifyGmailOriginals(
            selected.map { (source: $0.1, bytes: $0.2) })
    }

    /// Differential gate only: five already nominated/qualified initial Gmail
    /// bank/card originals, not the wider 18- or 416-original Gmail corpus.
    @Test(.globalRuntimeStateIsolation)
    func boundedFiveOriginalCohortMatchesAcrossOneAndTwoPreparationSlots() async throws {
        try await qualifyInitialBoundedCohort(includingCorrectedBank: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func correctedCBQHandoffMatchesAcrossOneAndTwoPreparationSlots() async throws {
        try await qualifyInitialBoundedCohort(includingCorrectedBank: true)
    }

    private func qualifyInitialBoundedCohort(includingCorrectedBank: Bool) async throws {
        let amex = try await loadBankAndCardCases(family: "amex_card")
        let axis = try await loadBankAndCardCases(family: "axis_card_traditional")
        let cbqCards = try await loadBankAndCardCases(family: "cbq_card")
        let julyCBQBankSHA = "f53a209521c1321359b41d28dfbc86d77d86846a36172e83509e57588f99b95c"
        let bankCandidates = try nominatedOriginals(families: ["cbq_bank"])
        guard amex.count == 1, axis.count == 1, cbqCards.count == 2,
              let july = bankCandidates.first(where: { $0.0.sha256 == julyCBQBankSHA }),
              bankCandidates.filter({ $0.0.sha256 == julyCBQBankSHA }).count == 1 else {
            throw CampaignError.sourceUnavailable
        }
        let bank = try await bankAndCardCase(source: july.1, bytes: july.2, family: july.0.family)
        var cohort = amex + axis + cbqCards + [bank]
        if includingCorrectedBank {
            let corrected = try #require(historicalOriginals(family: .cbqBank).first {
                $0.0.sha256 == "1f12183dcefdd5775f1d68c67902345628bea3c6c1ccc212763c7bd434215868"
            })
            cohort.append(try await bankAndCardCase(source: corrected.0, bytes: corrected.1, family: "cbq_bank"))
        }
        let expectedCount = includingCorrectedBank ? 6 : 5
        guard cohort.count == expectedCount,
              Set(cohort.compactMap { $0.source.sha256 }).count == expectedCount else {
            throw CampaignError.sourceUnavailable
        }

        // `bankAndCardCase` has completed every independent source comparison
        // before either coordinator starts ordinary production preparation.
        let serial = try await runBoundedCoordinatorCohort(cohort, preparationLimit: 1)
        let dual = try await runBoundedCoordinatorCohort(cohort, preparationLimit: 2)
        guard serial.preparedFinancialFields == dual.preparedFinancialFields,
              serial.financialFields == dual.financialFields,
              serial.relationships == dual.relationships,
              serial.dispositions == dual.dispositions,
              serial.sourceOrder == dual.sourceOrder else {
            throw CampaignError.sourceMismatch
        }
        guard serial.peakActivePreparations <= 1,
              dual.peakActivePreparations <= 2,
              serial.peakConcurrentCommits <= 1,
              dual.peakConcurrentCommits <= 1 else {
            throw CampaignError.commitFailed
        }
        print("Gmail bounded \(cohort.count)-source cohort (milliseconds): preparation serial=\(serial.preparationMilliseconds), dual=\(dual.preparationMilliseconds); commit excluding hydration serial=\(serial.commitMilliseconds), dual=\(dual.commitMilliseconds); hydration serial=\(serial.hydrationMilliseconds), dual=\(dual.hydrationMilliseconds); end-to-end serial=\(serial.endToEndMilliseconds), dual=\(dual.endToEndMilliseconds); peak active-preparation source bytes serial=\(serial.peakPreparationSourceBytes), dual=\(dual.peakPreparationSourceBytes).")
    }

    @Test(.globalRuntimeStateIsolation)
    func nominatedCASOriginalsMatchIndependentOraclesAndBothProviders() async throws {
        let selected = try nominatedOriginals(families: ["cas_detailed", "cas_summary"])
        let provider = DatabaseProvider(inMemory: true)
        let previous = DatabaseProvider.shared
        DatabaseProvider.shared = provider
        defer { DatabaseProvider.shared = previous }
        var state = GmailInboxState(account: try #require(selected.first).1.account)
        var bytesByDigest: [String: Data] = [:]
        for (nomination, source, bytes) in selected {
            state.sources[source.id] = source
            bytesByDigest[nomination.sha256] = bytes
        }
        _ = try provider.gmailInboxRepo.save(state, originals: bytesByDigest, expectedRevision: 0)
        let request = ImportRequest(fileURL: try #require(selected.first?.1.importURL))
        let credentials = try await GmailImportSource.additionalCASCredential(request)
        guard credentials.count == 1, let password = credentials.first?.value else { throw CampaignError.sourceUnavailable }
        let qualification = InvestmentRAMOriginalTests()
        // Complete both independent source interpretations before production.
        let originals = try selected.map { nomination, source, bytes in
            try qualification.casGmailOriginal(source: source, bytes: bytes, password: password, family: nomination.family)
        }
        let sources = Dictionary(uniqueKeysWithValues: selected.map { ($0.0.sha256, $0.1) })
        try await qualification.qualifyGmailOriginals(try applyingExistingCASAliasAuthority(to: originals), sources: sources)
    }

    private func applyingExistingCASAliasAuthority(to originals: [InvestmentRAMOriginalTests.Original]) throws
        -> [InvestmentRAMOriginalTests.Original] {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["LEDGERFORGE_GMAIL_CAS_ALIAS_AUTHORITY"] else { return originals }
        let authority = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let expectedDigest = environment["LEDGERFORGE_GMAIL_CAS_ALIAS_AUTHORITY_SHA256"],
              GmailInboxSource.digest(authority) == expectedDigest,
              let text = String(data: authority, encoding: .utf8) else { throw CampaignError.sourceUnavailable }
        // Only explicit pairs in the previously approved owner packet qualify.
        // Whitespace is inert; suffixes, identities and instruments are retained.
        let expression = try NSRegularExpression(pattern: #"(?m)^- ([0-9]+\s*/\s*[0-9]+)\s*↔\s*([0-9]+)\s*$"#)
        let ns = text as NSString
        let pairs = expression.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            [ns.substring(with: $0.range(at: 1)), ns.substring(with: $0.range(at: 2))]
        }
        guard !pairs.isEmpty else { throw CampaignError.sourceUnavailable }
        func folio(_ value: String) -> String { value.filter { !$0.isWhitespace } }
        let holdings = originals.flatMap(\.expected)
        let observed = Set(holdings.map { folio($0.container) })
        let applicable = pairs.filter { Set($0.map(folio)).isSubset(of: observed) }
        guard !applicable.isEmpty else { throw CampaignError.sourceMismatch }
        for pair in applicable {
            let left = Set(holdings.filter { folio($0.container) == folio(pair[0]) }.map(\.instrument))
            let right = Set(holdings.filter { folio($0.container) == folio(pair[1]) }.map(\.instrument))
            guard !left.isEmpty, left == right else { throw CampaignError.sourceMismatch }
        }
        print("Gmail CAS reused \(applicable.count) existing owner-confirmed alias pairs with matching current source instrument sets.")
        return originals.map {
            .init(fileName: $0.fileName, sha256: $0.sha256, byteCount: $0.byteCount, bytes: $0.bytes,
                  password: $0.password, family: $0.family, expected: $0.expected, approvedFolioAliases: applicable)
        }
    }

    @Test func allRetainedSalaryOriginalsAreIndependentlyQualifiedOrExplicitlyHeld() async throws {
        guard let directory = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"] else {
            throw CampaignError.missingEnvironment
        }
        let database = SQLiteDatabase(path: URL(fileURLWithPath: directory).appendingPathComponent("acquisition.sqlite").path)
        try database.open(access: .readOnlySnapshot); defer { database.close() }
        let inbox = SQLiteGmailInboxRepository(database: database)
        let state = try inbox.load(account: soleCampaignAccount(in: inbox))
        let sources = state.orderedSources.filter { $0.family == .salary }
        try #require(!sources.isEmpty)
        var qualified: [(source: GmailInboxSource, bytes: Data)] = []
        var held: [(source: GmailInboxSource, bytes: Data)] = []
        for source in sources {
            guard source.acquisition == .available, let sha = source.sha256 else { throw CampaignError.sourceUnavailable }
            let bytes = try inbox.original(sha256: sha, byteCount: source.expectedByteCount)
            guard let pdf = PDFDocument(data: bytes), !pdf.isLocked,
                  let firstPage = pdf.page(at: 0)?.string else { throw CampaignError.sourceUnavailable }
            // The original's title establishes an unregistered historical kind.
            // Do not reinterpret One-Time Payment as Annual Discretionary Bonus.
            if firstPage.contains("One-Time Payment for the month of ") { held.append((source, bytes)) }
            else { qualified.append((source, bytes)) }
        }
        try await SalaryAuthenticCorpusAcceptanceTests().qualifyGmailOriginals(qualified)
        for (source, _) in qualified {
            print("GMAIL_DISPOSITION \(try #require(source.sha256)) SUPPORTED_AND_QUALIFIED salary both-providers-replay-reopen")
        }
        for (source, bytes) in held {
            let sha = try #require(source.sha256)
            for durable in [false, true] {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Salary-Held-\(UUID())")
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
                defer { try? FileManager.default.removeItem(at: root) }
                let path = root.appendingPathComponent("held.sqlite").path
                let sqlite = durable ? try SQLiteRepositoryProvider(path: path) : nil
                defer { sqlite?.database.close() }
                let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) }
                    ?? DatabaseProvider(inMemory: true)
                var state = GmailInboxState(account: source.account)
                state.sources[source.id] = source
                _ = try provider.gmailInboxRepo.save(state, originals: [sha: bytes], expectedRevision: 0)
                let stores = GmailQualificationStores()
                let engine = makeEngine(provider: provider, password: "", stores: stores)
                var unsupported = false
                do {
                    let prepared = try await engine.prepareImport(from: try #require(source.importURL))
                    engine.cancelPreparedImport(prepared)
                } catch ImportError.invalidDocument(let message) where message == "No suitable PDF normalizer found." {
                    unsupported = true
                }
                func verifyEmpty(_ provider: DatabaseProvider) throws {
                    let staged = try GmailQualificationStores().hydrator(provider).stageHydration()
                    #expect(staged.transactions.isEmpty && staged.accounts.isEmpty && staged.salaryStatements.isEmpty
                        && staged.importSessions.isEmpty && staged.investments == .empty)
                    #expect(try provider.gmailInboxRepo.original(sha256: sha, byteCount: bytes.count) == bytes)
                }
                #expect(unsupported, "Historical One-Time Payment must remain unaccepted.")
                try verifyEmpty(provider)
                if let sqlite {
                    try sqlite.database.checkpointAndClose()
                    let reopened = try SQLiteRepositoryProvider(path: path)
                    defer { reopened.database.close() }
                    try verifyEmpty(DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false))
                }
            }
            print("GMAIL_DISPOSITION \(sha) KNOWN_UNSUPPORTED_LAYOUT salary_one_time_payment both-providers-zero-residue-reopen")
        }
        print("Gmail salary source campaign: \(qualified.count) independently qualified originals; \(held.count) historical unsupported originals held.")
    }

    @Test(arguments: [GmailSourceFamily.amex, .axisCard, .cbqCard])
    func allRetainedCardOriginalsUseIndependentComparisons(family: GmailSourceFamily) async throws {
        let familyName: String
        switch family {
        case .amex: familyName = "amex_card"
        case .axisCard: familyName = "axis_card_traditional"
        case .cbqCard: familyName = "cbq_card"
        default: throw CampaignError.unsupportedSelection
        }
        let originals = try historicalOriginals(family: family)
        for (index, original) in originals.enumerated() {
            var phase = "source comparison setup"
            do {
                let source = try await bankAndCardCase(source: original.0, bytes: original.1, family: familyName)
                phase = "in-memory preparation/commit/comparison"
                let memory = try await run(source, sqlite: false, index: index)
                phase = "SQLite preparation/commit/reopen/comparison"
                let durable = try await run(source, sqlite: true, index: index)
                let parity = memory == durable
                #expect(parity, "Historical Gmail card provider parity differs at index \(index).")
            } catch {
                Issue.record("Historical Gmail \(family.rawValue) source \(original.0.sha256?.prefix(12) ?? "unknown") is not qualified during \(phase): \(safeFailureKind(error)).")
            }
        }
    }

    @Test func retainedAxisCardDatesUseIndependentPrintedFields() async throws {
        try await allRetainedCardOriginalsUseIndependentComparisons(family: .axisCard)
    }

    @Test(.timeLimit(.minutes(20))) func completeRetainedCardCorpusHasSourceBoundedDispositions() async throws {
        try await qualifyRetainedCardCorpus(families: [.amex, .axisCard, .cbqCard])
    }

    @Test func retainedCBQCardCorpusHasSourceBoundedDispositions() async throws {
        try await qualifyRetainedCardCorpus(families: [.cbqCard])
    }

    @Test(.globalRuntimeStateIsolation)
    func ownerConfirmedAmexUSDHistoryOnlySurvivesReplayAndRecovery() async throws {
        let originals = try historicalOriginals(family: .amex).filter {
            $0.0.sha256 == "bb06263ab2a34bfc04e1b9b946ccb7973c5cd9a15437de4b7c02d9fc6cf41518"
        }
        let original = try #require(originals.count == 1 ? originals.first : nil)
        let source = try await bankAndCardCase(source: original.0, bytes: original.1, family: "amex_card")
        let memory = try await run(source, sqlite: false, index: 0, historyOnly: true)
        let durable = try await run(source, sqlite: true, index: 0, historyOnly: true)
        let parity = memory == durable
        #expect(parity)
        print("Owner-confirmed Amex USD history-only: original controls retained; both providers, current projection exclusion, historical import eligibility, replay, reopen and populated backup/restore passed.")
    }

    @Test(.globalRuntimeStateIsolation)
    func populatedV24BankLedgerMigratesAndRestoresAtCurrentSchema() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let sourcePath = environment["LEDGERFORGE_AUTHENTIC_V24_BANK_LEDGER"],
              let expectedHash = environment["LEDGERFORGE_AUTHENTIC_V24_BANK_LEDGER_SHA256"] else {
            throw CampaignError.missingEnvironment
        }
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        guard sourceURL.path.contains("/Development/Namespaces/s98-bank-native-"),
              try BackupFiles.hash(sourceURL).sha256 == expectedHash else { throw CampaignError.sourceUnavailable }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-V24-Bank-Recovery-\(UUID())")
        try BackupFiles.createDirectory(directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("qualification.sqlite")
        let source = try SQLiteRepositoryProvider(path: sourcePath, migrations: Array(allMigrations.prefix(24)), access: .readOnlySnapshot)
        defer { source.database.close() }
        let original = DatabaseProvider.verifiedSQLite(source, protectsGeneration: false)
        let baselineAccounts = try original.accountRepo.accounts(workspaceId: "default-workspace")
        let baselineTransactions = try original.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let baselineSections = try original.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let baseline = try GmailQualificationStores().hydrator(original).stageHydration()
        guard !baselineSections.sections.isEmpty, !baselineTransactions.isEmpty else { throw CampaignError.sourceUnavailable }
        // Complete rows from the three rebuilt tables stay in RAM. Their
        // identifiers, literal observations and creation times must all survive.
        func sectionTableRows(_ database: SQLiteDatabase) throws -> [String: [[String?]]] {
            var tables = [String: [[String?]]]()
            for table in ["bank_statement_sections", "bank_section_identity_observations", "bank_transaction_occurrences"] {
                let count = try database.query(sql: "PRAGMA table_info(\(table));") { _ in 1 }.count
                tables[table] = try database.query(sql: "SELECT * FROM \(table) ORDER BY id;") { row in
                    (0..<count).map { row.string(at: Int32($0)) }
                }
            }
            return tables
        }
        let baselineTables = try sectionTableRows(source.database)
        try source.database.createBackup(at: path.path)
        source.database.close()
        func verify(_ provider: DatabaseProvider) throws {
            let accountsMatch = try provider.accountRepo.accounts(workspaceId: "default-workspace") == baselineAccounts
            let transactionsMatch = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace") == baselineTransactions
            let sectionsMatch = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace") == baselineSections
            let snapshot = try GmailQualificationStores().hydrator(provider).stageHydration()
            let projectionMatches = rowProjection(snapshot.transactions) == rowProjection(baseline.transactions)
                && snapshot.importSessions == baseline.importSessions && snapshot.cardSnapshot == baseline.cardSnapshot
            #expect(accountsMatch && transactionsMatch && sectionsMatch && projectionMatches,
                    "Authentic V24 account, transaction, section or canonical evidence changed during recovery.")
        }
        let migrated = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { migrated.database.close() }
        try BackupCompatibility.verifyDatabase(migrated.database)
        let rowsPreserved = try sectionTableRows(migrated.database) == baselineTables
        #expect(rowsPreserved, "The V26 table rebuild changed authentic persisted rows.")
        try verify(DatabaseProvider.verifiedSQLite(migrated, protectsGeneration: false))
        try migrated.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
        try verify(reopenedProvider)
        let previous = DatabaseProvider.shared
        DatabaseProvider.shared = reopenedProvider
        defer { DatabaseProvider.shared = previous }
        let coordinator = BackupRestoreCoordinator(testingAt: path)
        coordinator.installTestProvider(reopened)
        defer { try? coordinator.closeTestProvider() }
        let backups = directory.appendingPathComponent("backups")
        try BackupFiles.createDirectory(backups)
        await coordinator.createBackup(to: backups)
        let package = try #require(coordinator.lastBackupURL)
        _ = try BackupFiles.verifyPackage(package)
        await coordinator.verifyRestore(from: package)
        await coordinator.replaceLedger()
        guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
        try verify(DatabaseProvider.shared)
        #expect(try BackupFiles.hash(sourceURL).sha256 == expectedHash)
        print("Authentic populated V24 bank ledger: current migration, exact rebuilt-table preservation, canonical reopen and ordinary backup/restore passed; original ledger unchanged.")
    }

    private func qualifyRetainedCardCorpus(families: [GmailSourceFamily]) async throws {
        var qualified = 0
        var total = 0
        for family in families {
            for (index, original) in try historicalOriginals(family: family).enumerated() {
                total += 1
                let (source, bytes) = original
                let sha = try #require(source.sha256)
                let familyName = family == .amex ? "amex_card" : family == .axisCard ? "axis_card_traditional" : "cbq_card"
                print("GMAIL_CARD_SOURCE_BEGIN sha=\(sha) family=\(family.rawValue) stage=independent-source-comparison")
                let candidate = try await bankAndCardCase(source: source, bytes: bytes, family: familyName)
                let memory = try await run(candidate, sqlite: false, index: index)
                let durable = try await run(candidate, sqlite: true, index: index)
                #expect(memory == durable)
                qualified += 1
                print("GMAIL_DISPOSITION \(sha) SUPPORTED_AND_QUALIFIED \(familyName) both-providers-replay-reopen")
            }
        }
        #expect(qualified == total)
        print("Gmail complete card dispositions: \(total) originals, \(qualified) qualified, 0 unsupported.")
    }

    @Test func allRetainedCBQInvestmentOriginalsUseIndependentComparisons() async throws {
        let originals = try historicalOriginals(family: .cbqInvestment)
        let password = try #require(try await KeychainStatementPasswordCredentialStore().password(
            institutionCode: Institution.cbq.statementPasswordCredentialScope))
        let qualification = InvestmentRAMOriginalTests()
        for (source, bytes) in originals {
            do {
                let original = try qualification.cbqGmailOriginal(source: source, bytes: bytes, password: password,
                                                                  family: "cbq_investment")
                try await qualification.qualifyGmailOriginals([original], sources: [original.sha256: source])
            } catch {
                Issue.record("Historical CBQ investment source \(source.sha256?.prefix(12) ?? "unknown") is not qualified: \(safeFailureKind(error)).")
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func nativeProductCASCredentialUnlocksRetainedOriginals() async throws {
        let originals = try historicalOriginals(family: .consolidatedFunds)
        let provider = DatabaseProvider(inMemory: true)
        let previous = DatabaseProvider.shared
        DatabaseProvider.shared = provider
        defer { DatabaseProvider.shared = previous }
        var state = GmailInboxState(account: try #require(originals.first).0.account)
        var bytesByDigest: [String: Data] = [:]
        for (source, bytes) in originals {
            state.sources[source.id] = source
            bytesByDigest[try #require(source.sha256)] = bytes
        }
        _ = try provider.gmailInboxRepo.save(state, originals: bytesByDigest, expectedRevision: 0)
        let request = ImportRequest(fileURL: try #require(originals.first?.0.importURL))
        print("Native product CAS credential read started.")
        let credentials = try await GmailImportSource.additionalCASCredential(request)
        guard credentials.count == 1, let password = credentials.first?.value else { throw CampaignError.sourceUnavailable }
        print("Native product CAS credential read completed.")
        var unlockedCount = 0
        var observations: [CASSourceObservation] = []
        for (source, bytes) in originals {
            guard let pdf = PDFDocument(data: bytes), pdf.isLocked else { throw CampaignError.sourceUnavailable }
            let unlocked = pdf.unlock(withPassword: password)
            if unlocked {
                unlockedCount += 1
                if ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_CAS_SOURCE_PIPE"] != nil {
                    observations.append(.init(sha256: try #require(source.sha256), pages: try (0..<pdf.pageCount).map {
                        try #require(pdf.page(at: $0)?.string)
                    }))
                }
            }
            print("Native CAS original \(source.sha256 ?? "unknown"): \(unlocked ? "unlocked" : "password-held").")
            #expect(unlocked, "Retained registrar original \(source.sha256?.prefix(12) ?? "unknown") did not unlock.")
        }
        let noFinancialImport = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == .empty
        #expect(noFinancialImport)
        print("Native CAS credential unlocked \(unlockedCount) of \(originals.count) retained originals; financial acceptance remains separate.")
        // Optional source observation is a RAM-only FIFO, never an evidence
        // file. It carries native source text, not credentials or expectations.
        if let path = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_CAS_SOURCE_PIPE"] {
            var transport = stat()
            guard lstat(path, &transport) == 0, transport.st_mode & S_IFMT == S_IFIFO else {
                throw CampaignError.sourceUnavailable
            }
            let pipe = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            defer { try? pipe.close() }
            try pipe.write(contentsOf: JSONEncoder().encode(observations))
        }
    }

    @Test func nominatedUnsupportedBankOriginalsRemainHeldWithoutFinancialResidue() async throws {
        let originals = try nominatedOriginals(families: ["axis_combined", "hdfc_combined", "cbq_savings", "cbq_e_savings"])
        try await verifyUnsupportedBankOriginals(originals)
    }

    private func verifyUnsupportedBankOriginals(_ originals: [(Nomination, GmailInboxSource, Data)]) async throws {
        let credentials = KeychainStatementPasswordCredentialStore()
        for (nomination, source, bytes) in originals {
            let institution: Institution = nomination.family == "amex_usd_card" ? .amex
                : nomination.family == "axis_combined" ? .axis
                : nomination.family == "hdfc_combined" ? .hdfc : .cbq
            guard let pdf = PDFDocument(data: bytes) else { throw CampaignError.sourceUnavailable }
            var password = ""
            if pdf.isLocked {
                let candidates = try await credentials.credentials(institutionCode: institution.statementPasswordCredentialScope)
                guard let candidate = candidates.first(where: { pdf.unlock(withPassword: $0.value) }) else {
                    throw CampaignError.sourceUnavailable
                }
                password = candidate.value
            }
            for durable in [false, true] {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Gmail-Held-\(UUID())")
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
                defer { try? FileManager.default.removeItem(at: root) }
                let path = root.appendingPathComponent("held.sqlite").path
                let sqlite = durable ? try SQLiteRepositoryProvider(path: path) : nil
                defer { sqlite?.database.close() }
                let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
                var state = GmailInboxState(account: source.account)
                state.sources[source.id] = source
                let sha = try #require(source.sha256)
                _ = try provider.gmailInboxRepo.save(state, originals: [sha: bytes], expectedRevision: 0)
                let stores = GmailQualificationStores()
                let engine = makeEngine(provider: provider, password: password, stores: stores)
                var held = false
                do {
                    let prepared = try await engine.prepareImport(from: try #require(source.importURL))
                    held = !prepared.validation.passed
                    engine.cancelPreparedImport(prepared)
                } catch {
                    print("GMAIL_EXACT_HOLD sha=\(sha) sqlite=\(durable) error=\(safeFailureKind(error))")
                    let normalizationRejection = error is AxisBankAccountPDFNormalizationError
                        || error is HDFCBankAccountPDFNormalizationError || error is CBQCurrentAccountPDFNormalizationError
                        || error is AxisCreditCardPDFNormalizationError || error is CBQCreditCardPDFNormalizationError
                    guard normalizationRejection || ImportFailureSummary.from(error).stage == .documentPreparation else {
                        Issue.record("Unexpected hold failure for \(sha.prefix(12)): \(safeFailureKind(error)).")
                        throw error
                    }
                    held = true
                }
                let staged = try stores.hydrator(provider).stageHydration()
                let noResidue = staged.accounts.isEmpty && staged.transactions.isEmpty && staged.salaryStatements.isEmpty
                    && staged.importSessions.isEmpty && staged.investments == .empty
                #expect(held && noResidue, "Known unsupported original \(sha.prefix(12)) must remain held.")
                let retained = try provider.gmailInboxRepo.original(sha256: sha, byteCount: bytes.count) == bytes
                #expect(retained)
                if let sqlite {
                    try sqlite.database.checkpointAndClose()
                    let reopened = try SQLiteRepositoryProvider(path: path)
                    defer { reopened.database.close() }
                    let unchanged = try reopened.gmailInboxRepo.original(sha256: sha, byteCount: bytes.count) == bytes
                    #expect(unchanged)
                }
            }
            print("GMAIL_DISPOSITION \(source.sha256 ?? "missing") KNOWN_UNSUPPORTED_LAYOUT \(nomination.family) zero-residue-both-providers-reopen")
        }
    }

    @Test func allRetainedBankOriginalsReceiveSourceBoundedDispositions() async throws {
        let credentials = KeychainStatementPasswordCredentialStore()
        var unsupported: [(Nomination, GmailInboxSource, Data)] = []
        for family in [GmailSourceFamily.axisBank, .hdfcBank, .cbqBank] {
            let institution: Institution = family == .axisBank ? .axis : family == .hdfcBank ? .hdfc : .cbq
            let candidates = try await credentials.credentials(institutionCode: institution.statementPasswordCredentialScope)
            for (index, entry) in try historicalOriginals(family: family).enumerated() {
                let (source, bytes) = entry
                let sha = try #require(source.sha256)
                guard let pdf = PDFDocument(data: bytes) else { throw CampaignError.sourceUnavailable }
                var password = ""
                if pdf.isLocked {
                    guard let candidate = candidates.first(where: { pdf.unlock(withPassword: $0.value) }) else {
                        try await verifyKnownCredentialPasswordHold(source: source, bytes: bytes, credentials: candidates)
                        print("GMAIL_DISPOSITION \(sha) HELD_PASSWORD_SUPPORT_UNCONFIRMED \(family.rawValue)")
                        continue
                    }
                    password = candidate.value
                }
                let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
                let compact = text.filter { !$0.isWhitespace }
                func unresolvedLayout() {
                    print("GMAIL_DISPOSITION \(sha) SOURCE_LAYOUT_UNRESOLVED \(family.rawValue)")
                    Issue.record("Retained bank source \(sha.prefix(12)) needs independent layout classification.")
                }
                let unsupportedKind: String?
                if family == .axisBank, compact.lowercased().contains("relationshipstatementfortheperiodfrom:"), compact.lowercased().contains("relationshipsummary") {
                    unsupportedKind = "axis_combined"
                } else if family == .hdfcBank, compact.contains("AccountRelationshipSummary") {
                    unsupportedKind = "hdfc_combined"
                } else if family == .cbqBank {
                    let typeExpression = try NSRegularExpression(pattern: #"(?m)Account Type:\s*([^\r\n]+)"#)
                    let ns = text as NSString
                    let types = Set(typeExpression.matches(in: text, range: NSRange(location: 0, length: ns.length))
                        .map { ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces) })
                    guard types.count == 1, let type = types.first else { unresolvedLayout(); continue }
                    switch type {
                    case "Savings Account", "E Savings Account": unsupportedKind = nil
                    case "Regular Saver Deposit": unsupportedKind = "cbq_regular_saver_deposit"
                    case "Personal Loan - Variable Rate": unsupportedKind = "cbq_personal_loan"
                    case "Current Account-Retail":
                        // This earlier statement owns a Value Date/Book Balance
                        // table, not the accepted Transaction Date monthly grammar.
                        if compact.contains("PostDateNarrativeValueDateDebitCreditBookBalance"), compact.contains("Stmt.Date:") {
                            unsupportedKind = "cbq_legacy_value_date_bank"
                        } else if compact.contains("Currency:USDOLLARS") {
                            unsupportedKind = "cbq_usd_current_account"
                        } else { unsupportedKind = nil }
                    default: unresolvedLayout(); continue
                    }
                } else { unresolvedLayout(); continue }
                if let unsupportedKind {
                    unsupported.append((.init(sha256: sha, family: unsupportedKind, sourceID: source.id, disposition: "available"), source, bytes))
                    continue
                }
                guard family == .cbqBank,
                      (compact.contains("PostingDateTransactionDescriptionTransactionDateDebitCreditBalance") ||
                       compact.contains("PostDateNarrativeValueDateDebitCreditBookBalance")) else {
                    unresolvedLayout(); continue
                }
                var phase = "source-oracle"
                do {
                    let compare = try CBQBankAuthenticAcceptanceTests().gmailComparison(bytes: bytes,
                        url: try #require(source.importURL), password: password)
                    let candidate = SourceCase(source: source, bytes: bytes, password: password, compare: compare)
                    if text.range(of: #"(?m)^\*\s+BALANCE\s+0\.00\s*$"#, options: .regularExpression) != nil {
                        // The exact neutral-zero control remains explicit in
                        // the full inventory, while qualifying through the
                        // same source/oracle and provider path as other
                        // monthly statements.
                        guard text.range(of: #"(?m)^\*\s+BALANCE\s+(?!0\.00\s*$)[0-9,.]+\s*$"#, options: .regularExpression) == nil else {
                            throw CampaignError.sourceMismatch
                        }
                    }
                    phase = "ordinary-memory"
                    let memory = try await run(candidate, sqlite: false, index: index)
                    phase = "ordinary-sqlite-reopen"
                    let durable = try await run(candidate, sqlite: true, index: index)
                    #expect(memory == durable)
                    print("GMAIL_DISPOSITION \(sha) SUPPORTED_AND_QUALIFIED cbq_monthly both-providers-replay-reopen")
                } catch {
                    print("GMAIL_DISPOSITION \(sha) SUPPORTED_BUT_QUALIFICATION_PENDING \(phase) \(safeFailureKind(error))")
                    Issue.record("Retained CBQ monthly source \(sha.prefix(12)) unresolved at \(phase): \(safeFailureKind(error)).")
                }
            }
        }
        try await verifyUnsupportedBankOriginals(unsupported)
    }

    private func verifyKnownCredentialPasswordHold(source: GmailInboxSource, bytes: Data,
        credentials: [StatementPasswordStoredCredential]) async throws {
        let sha = try #require(source.sha256)
        for durable in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Gmail-PasswordHold-\(UUID())")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: root) }
            let path = root.appendingPathComponent("held.sqlite").path
            let sqlite = durable ? try SQLiteRepositoryProvider(path: path) : nil
            defer { sqlite?.database.close() }
            let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
            var state = GmailInboxState(account: source.account)
            state.sources[source.id] = source
            _ = try provider.gmailInboxRepo.save(state, originals: [sha: bytes], expectedRevision: 0)
            let passwords = DefaultPasswordProvider(credentialStore: InMemoryStatementPasswordCredentialStore(),
                supportedInstitutionCodes: [], additionalRememberedCandidates: { _ in credentials }, challenge: { _ in nil })
            let stores = GmailQualificationStores()
            let hydrator = stores.hydrator(provider)
            let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
                sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
                importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
                persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
                forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
                developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
            await #expect(throws: ImportError.passwordRequired) {
                try await engine.prepareImport(from: try #require(source.importURL))
            }
            let staged = try hydrator.stageHydration()
            #expect(staged.accounts.isEmpty && staged.transactions.isEmpty && staged.salaryStatements.isEmpty
                && staged.importSessions.isEmpty && staged.investments == .empty)
            if let sqlite {
                try sqlite.database.checkpointAndClose()
                let reopened = try SQLiteRepositoryProvider(path: path)
                defer { reopened.database.close() }
                #expect(try reopened.gmailInboxRepo.original(sha256: sha, byteCount: bytes.count) == bytes)
                #expect(try reopened.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func retainedCASOriginalsWithDifferentPasswordsRemainHeldWithoutFinancialResidue() async throws {
        let originals = try historicalOriginals(family: .consolidatedFunds)
        let previous = DatabaseProvider.shared
        let credentialProvider = DatabaseProvider(inMemory: true)
        DatabaseProvider.shared = credentialProvider
        defer { DatabaseProvider.shared = previous }
        var credentialInbox = GmailInboxState(account: try #require(originals.first).0.account)
        for (source, _) in originals { credentialInbox.sources[source.id] = source }
        let originalBytes = try Dictionary(uniqueKeysWithValues: originals.map { (try #require($0.0.sha256), $0.1) })
        _ = try credentialProvider.gmailInboxRepo.save(credentialInbox, originals: originalBytes, expectedRevision: 0)
        let request = ImportRequest(fileURL: try #require(originals.first?.0.importURL))
        let credentials = try await GmailImportSource.additionalCASCredential(request)
        guard credentials.count == 1, let password = credentials.first?.value else { throw CampaignError.sourceUnavailable }
        let held = try originals.filter { _, bytes in
            guard let pdf = PDFDocument(data: bytes), pdf.isLocked else { throw CampaignError.sourceUnavailable }
            return !pdf.unlock(withPassword: password)
        }
        try #require(!held.isEmpty)
        for (source, bytes) in held {
            for durable in [false, true] {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-CAS-Held-\(UUID())")
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
                defer { try? FileManager.default.removeItem(at: root) }
                let path = root.appendingPathComponent("held.sqlite").path
                let sqlite = durable ? try SQLiteRepositoryProvider(path: path) : nil
                defer { sqlite?.database.close() }
                let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
                var state = GmailInboxState(account: source.account)
                state.sources[source.id] = source
                let sha = try #require(source.sha256)
                _ = try provider.gmailInboxRepo.save(state, originals: [sha: bytes], expectedRevision: 0)
                let passwords = DefaultPasswordProvider(credentialStore: InMemoryStatementPasswordCredentialStore(),
                    supportedInstitutionCodes: [], additionalRememberedCandidates: { _ in credentials }, challenge: { _ in nil })
                let stores = GmailQualificationStores()
                let hydrator = stores.hydrator(provider)
                let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
                    sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
                    importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
                    persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
                    forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
                    developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
                var needsPassword = false
                do {
                    let prepared = try await engine.prepareImport(from: try #require(source.importURL))
                    engine.cancelPreparedImport(prepared)
                } catch ImportError.passwordRequired { needsPassword = true }
                let staged = try hydrator.stageHydration()
                let empty = staged.accounts.isEmpty && staged.transactions.isEmpty && staged.salaryStatements.isEmpty
                    && staged.investments == .empty && staged.importSessions.isEmpty
                #expect(needsPassword && empty, "Locked CAS source \(sha.prefix(12)) must remain unaccepted.")
                if let sqlite {
                    try sqlite.database.checkpointAndClose()
                    let reopened = try SQLiteRepositoryProvider(path: path)
                    defer { reopened.database.close() }
                    let retained = try reopened.gmailInboxRepo.original(sha256: sha, byteCount: bytes.count) == bytes
                    let noAcceptedInvestments = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == .empty
                    #expect(retained && noAcceptedInvestments)
                }
            }
        }
        for (source, _) in held {
            print("GMAIL_DISPOSITION \(try #require(source.sha256)) HELD_PASSWORD_SUPPORT_UNCONFIRMED consolidatedFunds both-providers-zero-residue-reopen")
        }
        print("CAS password-held originals: \(held.count); zero accepted financial residue in both providers, exact bytes retained after reopen.")
    }

    /// Enum case names are technical diagnostics. Associated source values or
    /// custom descriptions must never be copied into XCTest evidence files.
    private func safeFailureKind(_ error: any Error) -> String {
        let reflected = Mirror(reflecting: error)
        let typeName = String(describing: type(of: error))
        guard reflected.displayStyle == .enum else { return typeName }
        if let child = reflected.children.first { return typeName + "." + (child.label ?? "associated-case") }
        return typeName + "." + String(describing: error)
    }

    private func matchesFrozenPreparationHold(_ error: any Error, original: SourceCase) -> Bool {
        if original.expectedPreparationHold == "SUPPORTED_BUT_HELD_PASSWORD" {
            guard let failure = error as? ImportError else { return false }
            switch failure { case .passwordRequired, .incorrectPassword: return true; default: return false }
        }
        // An arbitrary parse/validation error is not evidence that the frozen
        // unsupported product boundary still behaves truthfully.
        if let failure = error as? ImportError, case .invalidDocument(let message) = failure,
           message == "No suitable PDF normalizer found." { return true }
        switch original.source.family {
        case .amex:
            return original.expectedHoldLayout == "amex_usd_card" &&
                (error as? AmericanExpressCreditCardPDFNormalizationError) == .unsupportedFamily
        case .cbqCard:
            return original.expectedHoldLayout?.hasPrefix("cbq_companions_") == true &&
                (error as? CBQCreditCardPDFNormalizationError) == .unsupportedFamily
        case .cbqBank:
            if ["cbq_personal_loan", "cbq_regular_saver_deposit", "cbq_legacy_value_date_bank"].contains(original.expectedHoldLayout ?? "") {
                return (error as? CBQCurrentAccountPDFNormalizationError) == .ambiguousFamily
            }
            return original.expectedHoldLayout == "cbq_usd_current_account" &&
                (error as? CBQCurrentAccountPDFNormalizationError) == .malformedPreamble
        default: return false
        }
    }

    private func historicalOriginals(family: GmailSourceFamily) throws -> [(GmailInboxSource, Data)] {
        guard let directory = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"] else {
            throw CampaignError.missingEnvironment
        }
        let database = SQLiteDatabase(path: URL(fileURLWithPath: directory).appendingPathComponent("acquisition.sqlite").path)
        try database.open(access: .readOnlySnapshot); defer { database.close() }
        let inbox = SQLiteGmailInboxRepository(database: database)
        let state = try inbox.load(account: soleCampaignAccount(in: inbox))
        let sources = state.orderedSources.filter { $0.family == family }
        try #require(!sources.isEmpty)
        return try sources.map { source in
            guard source.acquisition == .available, let sha = source.sha256 else { throw CampaignError.sourceUnavailable }
            return (source, try inbox.original(sha256: sha, byteCount: source.expectedByteCount))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func ordinaryBackupRestoreReconcilesOriginalAgainstTheRestoredLedger() async throws {
        try await qualifyGmailBackupRestore(completeHistoricalInbox: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func completeHistoricalInboxBackupRestorePreservesOriginalsAndReceipts() async throws {
        try await qualifyGmailBackupRestore(completeHistoricalInbox: true)
    }

    private func qualifyGmailBackupRestore(completeHistoricalInbox: Bool) async throws {
        let original = try #require(try await loadBankAndCardCases(family: "amex_card").first)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Gmail-Recovery-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("qualification.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: path.path)
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let previous = DatabaseProvider.shared
        DatabaseProvider.shared = provider
        defer { DatabaseProvider.shared = previous; sqlite.database.close() }
        var inbox = GmailInboxState(account: original.source.account)
        inbox.sources[original.source.id] = original.source
        inbox.senderRules = [.init(address: original.source.sender, isSelected: true)]
        let digest = try #require(original.source.sha256)
        var originals = [digest: original.bytes]
        if completeHistoricalInbox {
            guard let directory = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"] else {
                throw CampaignError.missingEnvironment
            }
            let history = SQLiteDatabase(path: URL(fileURLWithPath: directory).appendingPathComponent("acquisition.sqlite").path)
            try history.open(access: .readOnlySnapshot)
            defer { history.close() }
            let repository = SQLiteGmailInboxRepository(database: history)
            inbox = try repository.load(account: original.source.account)
            guard inbox.activeScan == nil, !inbox.completedIntervals.isEmpty,
                  inbox.sources[original.source.id]?.sha256 == digest else { throw CampaignError.sourceUnavailable }
            inbox.revision = 0
            inbox.senderRules = inbox.configuredSenders
            inbox.senderRules?[0].isSelected = false
            originals = try Dictionary(uniqueKeysWithValues: inbox.orderedSources.map {
                let sha = try #require($0.sha256)
                return (sha, try repository.original(sha256: sha, byteCount: $0.expectedByteCount))
            })
        }
        var savedInbox = try provider.gmailInboxRepo.save(inbox, originals: originals, expectedRevision: 0)
        let preferencesName = "LedgerForge.GmailRecovery.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: preferencesName))
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        let session = GmailIntakeSession(preferences: preferences)
        await session.reloadInbox()
        if completeHistoricalInbox {
            let candidates = savedInbox.orderedSources.filter { $0.id != original.source.id }
            let dismissed = try #require(candidates.first)
            let revisited = try #require(candidates.dropFirst().first)
            session.selectedSourceID = dismissed.id
            session.dismissSelected()
            session.selectedSourceID = revisited.id
            session.dismissSelected()
            session.revisitSelected()
            savedInbox = try provider.gmailInboxRepo.load(account: original.source.account)
            #expect(savedInbox.sources[dismissed.id]?.dismissed == true)
            #expect(savedInbox.sources[revisited.id]?.dismissed == false && savedInbox.sources[revisited.id]?.attention == .pending)
        }
        let expectedUnimportedQueue = savedInbox.orderedSources.filter {
            !$0.dismissed && $0.acquisition == .available && [.pending, .review, .skipped].contains($0.attention)
        }.map(\.id)
        let coordinator = BackupRestoreCoordinator(testingAt: path)
        coordinator.installTestProvider(sqlite)
        defer { try? coordinator.closeTestProvider() }
        let beforeFolder = root.appendingPathComponent("before-import")
        try BackupFiles.createDirectory(beforeFolder)
        await coordinator.createBackup(to: beforeFolder)
        let beforePackage = try #require(coordinator.lastBackupURL)
        let beforeHash = try BackupFiles.hash(beforePackage.appendingPathComponent("ledger.sqlite")).sha256
        await session.reloadInbox()
        #expect(session.importedSourceIDs.isEmpty && session.account == original.source.account && !session.isConnected)

        let stores = GmailQualificationStores()
        let engine = makeEngine(provider: provider, password: original.password, stores: stores)
        let prepared = try await engine.prepareImport(from: try #require(original.source.importURL))
        defer { engine.cancelPreparedImport(prepared) }
        try original.compare(prepared)
        let expectedRows = rowProjection(prepared.financialDocument.transactions)
        let committed = await engine.commitPreparedImport(prepared,
            accountChoice: .createNewCardLiabilityAccountAndInstrument(displayName: "Gmail recovery qualification"))
        guard committed.hydrationOutcome == .committedAndHydrated else { throw CampaignError.commitFailed }
        await session.reloadInbox()
        #expect(session.importedSourceIDs == [original.source.id])
        let afterFolder = root.appendingPathComponent("after-import")
        try BackupFiles.createDirectory(afterFolder)
        await coordinator.createBackup(to: afterFolder)
        let afterPackage = try #require(coordinator.lastBackupURL)
        let afterManifest = try BackupFiles.verifyPackage(afterPackage)
        #expect(afterManifest.formatVersion == 1 && afterManifest.schemaVersion == BackupCompatibility.supportedSchemaVersion)
        let afterHash = try BackupFiles.hash(afterPackage.appendingPathComponent("ledger.sqlite")).sha256
        await coordinator.verifyRestore(from: afterPackage)
        await coordinator.replaceLedger()
        guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
        let restored = DatabaseProvider.shared
        let restoredRowsMatch = rowProjection(try GmailQualificationStores().hydrator(restored).stageHydration().transactions) == expectedRows
        let restoredInboxMatches = try restored.gmailInboxRepo.load(account: original.source.account) == savedInbox
        #expect(restoredRowsMatch && restoredInboxMatches)
        for source in savedInbox.orderedSources {
            let sha = try #require(source.sha256)
            #expect(try restored.gmailInboxRepo.original(sha256: sha, byteCount: source.expectedByteCount) == originals[sha])
        }
        try verifyCardEvidence(restored, prepared: prepared)
        await session.reloadInbox()
        #expect(session.importedSourceIDs == [original.source.id])

        // Restore the real earlier package with the original and receipts but no
        // financial import. The session must recompute membership from this ledger.
        await coordinator.verifyRestore(from: beforePackage)
        await coordinator.replaceLedger()
        guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
        await session.reloadInbox()
        let isQueuedAgain = session.importedSourceIDs.isEmpty && session.batchSources.map(\.id) == expectedUnimportedQueue
        #expect(isQueuedAgain)
        try coordinator.closeTestProvider()
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)
        let startup = BackupRestoreCoordinator(testingAt: path)
        try startup.recoverBeforeStartup()
        let reopened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
        startup.installTestProvider(reopened)
        defer { try? startup.closeTestProvider() }
        let runtime = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
        DatabaseProvider.shared = runtime
        let hydrator = GmailQualificationStores().hydrator(runtime)
        let staged = try hydrator.stageHydration()
        let noAcceptedRows = staged.transactions.isEmpty && staged.accounts.isEmpty && staged.importSessions.isEmpty
        #expect(noAcceptedRows)
        hydrator.publish(staged)
        await startup.startupDidHydrate()
        let originalMatches = try runtime.gmailInboxRepo.original(sha256: digest, byteCount: original.bytes.count) == original.bytes
        let receiptMatches = try runtime.gmailInboxRepo.load(account: original.source.account) == savedInbox
        let packagesUnchanged = try BackupFiles.hash(beforePackage.appendingPathComponent("ledger.sqlite")).sha256 == beforeHash
            && BackupFiles.hash(afterPackage.appendingPathComponent("ledger.sqlite")).sha256 == afterHash
        #expect(originalMatches && receiptMatches && packagesUnchanged)
        #expect(startup.restoredReceipt?.phase == .relaunchConfirmed && !DatabaseActivityGate.shared.hasExclusiveOperation)
        await session.reloadInbox()
        #expect(session.importedSourceIDs.isEmpty)
        for source in savedInbox.orderedSources {
            let sha = try #require(source.sha256)
            #expect(try runtime.gmailInboxRepo.original(sha256: sha, byteCount: source.expectedByteCount) == originals[sha])
        }
        let freshEngine = makeEngine(provider: runtime, password: original.password, stores: GmailQualificationStores())
        let freshPreparation = try await freshEngine.prepareImport(from: try #require(original.source.importURL))
        defer { freshEngine.cancelPreparedImport(freshPreparation) }
        try original.compare(freshPreparation)
        #expect(freshPreparation.advisoryPreviousImport == nil)
        #expect(session.batchSources.map(\.id) == expectedUnimportedQueue)
        print("Gmail populated backup/restore: \(savedInbox.sources.count) originals, \(savedInbox.messages.count) message receipts, \(savedInbox.completedIntervals.count) completed intervals; all bytes, sender selection, dismiss/Revisit and ledger membership preserved; fresh preparation after restored-ledger reopen.")
    }

    private func nominatedOriginals(families: Set<String>) throws -> [(Nomination, GmailInboxSource, Data)] {
        guard let directory = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_CAMPAIGN_DIRECTORY"] else {
            throw CampaignError.missingEnvironment
        }
        let root = URL(fileURLWithPath: directory)
        let manifest = try JSONDecoder().decode(Manifest.self,
            from: Data(contentsOf: root.appendingPathComponent("acquisition-manifest.json")))
        let database = SQLiteDatabase(path: root.appendingPathComponent("acquisition.sqlite").path)
        try database.open(access: .readOnlySnapshot); defer { database.close() }
        let inbox = SQLiteGmailInboxRepository(database: database)
        let state = try inbox.load(account: soleCampaignAccount(in: inbox))
        let selected = manifest.nominations.filter { families.contains($0.family) }
        try #require(!selected.isEmpty)
        return try selected.map { nomination in
            guard nomination.disposition == "available", let id = nomination.sourceID,
                  let source = state.sources[id], source.sha256 == nomination.sha256,
                  source.importURL != nil else { throw CampaignError.sourceUnavailable }
            let bytes = try inbox.original(sha256: nomination.sha256, byteCount: source.expectedByteCount)
            return (nomination, source, bytes)
        }
    }

    private func loadBankAndCardCases(family: String) async throws -> [SourceCase] {
        let credentials = KeychainStatementPasswordCredentialStore()
        var cases: [SourceCase] = []
        for (nomination, source, bytes) in try nominatedOriginals(families: [family]) {
            cases.append(try await bankAndCardCase(source: source, bytes: bytes, family: nomination.family, credentials: credentials))
        }
        return cases
    }

    private func soleCampaignAccount(in repository: any GmailInboxRepository) throws -> String {
        let accounts = try repository.storedAccounts()
        guard accounts.count == 1, let account = accounts.first else { throw CampaignError.sourceUnavailable }
        return account
    }

    private func bankAndCardCase(source: GmailInboxSource, bytes: Data, family: String,
                                credentials: KeychainStatementPasswordCredentialStore = .init()) async throws -> SourceCase {
            guard let url = source.importURL else { throw CampaignError.sourceUnavailable }
            let scope: String
            switch family {
            case "amex_card": scope = Institution.amex.statementPasswordCredentialScope
            case "axis_card_traditional": scope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
            default: scope = Institution.cbq.statementPasswordCredentialScope
            }
            let password = try await knownGmailSourcePassword(bytes: bytes, scope: scope, credentials: credentials)
            let compare: (PreparedImport) throws -> Void
            var balanceObservation: (date: StatementDate, balance: Decimal, zeroActivity: Bool)?
            switch family {
            case "amex_card": compare = try AmericanExpressPrivateAcceptanceTests().gmailComparison(bytes: bytes, url: url, password: password)
            case "axis_card_traditional": compare = try AxisCreditCardAuthenticAcceptanceTests.gmailTraditionalComparison(bytes: bytes, password: password)
            case "cbq_bank": compare = try CBQBankAuthenticAcceptanceTests().gmailComparison(bytes: bytes, url: url, password: password,
                balanceObservation: { balanceObservation = ($0, $1, $2) })
            case "cbq_card": compare = try await CBQCreditCardPrivateAcceptanceTests().gmailComparison(bytes: bytes, url: url, password: password)
            default: throw CampaignError.unsupportedSelection
            }
            return .init(source: source, bytes: bytes, password: password, compare: compare, bankBalanceObservation: balanceObservation)
    }

    /// Read only the existing product credential contract. The Axis contract
    /// deliberately includes its app/traditional/canonical and one registered
    /// legacy candidate; a successful native import can update the preferred
    /// family entry, so that single entry is not the entire authorized set.
    private func knownGmailSourcePassword(bytes: Data, scope: String,
        credentials: KeychainStatementPasswordCredentialStore = .init()) async throws -> String {
        guard let pdf = PDFDocument(data: bytes) else { throw CampaignError.sourceUnavailable }
        if !pdf.isLocked { return "" }
        let credentialScope = scope == KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
            ? KeychainStatementPasswordCredentialStore.axisInstitutionScope : scope
        let candidates = try await credentials.credentials(institutionCode: credentialScope)
        for candidate in candidates where pdf.unlock(withPassword: candidate.value) { return candidate.value }
        throw CampaignError.sourceUnavailable
    }

    private func run(_ original: SourceCase, sqlite durable: Bool, index: Int, historyOnly: Bool = false) async throws -> [String] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Gmail-Authentic-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("qualification.sqlite").path
        let sqlite = durable ? try SQLiteRepositoryProvider(path: path) : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) } ?? DatabaseProvider(inMemory: true)
        var inbox = GmailInboxState(account: original.source.account)
        inbox.sources[original.source.id] = original.source
        let sha = try #require(original.source.sha256)
        _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.bytes], expectedRevision: 0)
        let stores = GmailQualificationStores()
        let hydrator = stores.hydrator(provider)
        let engine = makeEngine(provider: provider, password: original.password, stores: stores)
        let url = try #require(original.source.importURL)
        let cancelled = try await engine.prepareImport(from: url)
        engine.cancelPreparedImport(cancelled)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
        #expect(try provider.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        let prepared = try await engine.prepareImport(from: url)
        defer { engine.cancelPreparedImport(prepared) }
        try original.compare(prepared)
        let expected = rowProjection(prepared.financialDocument.transactions)
        let review = try engine.reviewPreparedImport(prepared)
        let choice: ImportAccountChoice?
        switch review {
        case .cardChoiceRequired: choice = .createNewCardLiabilityAccountAndInstrument(displayName: "Gmail qualification")
        case .choiceRequired, .liabilityAccountChoiceRequired: choice = .createNewAccount(displayName: "Gmail qualification")
        case .matchedExisting(let id): choice = .useExistingAccount(accountId: id)
        case .unavailable: choice = nil
        case .ambiguous, .conflict, .bankSections: throw CampaignError.commitFailed
        }
        let result = await engine.commitPreparedImport(prepared, accountChoice: choice)
        guard result.hydrationOutcome == .committedAndHydrated else {
            Issue.record("Ordinary Gmail confirmation did not commit/hydrate at source index \(index), SQLite=\(durable), persisted=\(result.persisted), hydration=\(result.hydrationOutcome), recovery=\(result.recoveryRoute).")
            throw CampaignError.commitFailed
        }
        let hydrated = rowProjection(stores.transactions.transactions)
        let sourceAgreement = hydrated == expected
        #expect(sourceAgreement, "Hydrated source fields differ at index \(index).")
        try verifyRelationships(provider, expectedCount: expected.count)
        try verifyCardEvidence(provider, prepared: prepared)
        try verifyBankSectionEvidence(provider, prepared: prepared)
        let historyBaseline: RepositoryRuntimeSnapshot? = historyOnly ? try hydrator.stageHydration() : nil
        var classificationTime: String?
        if let baseline = historyBaseline {
            let account = try #require(provider.accountRepo.accounts(workspaceId: "default-workspace").first)
            var profileState = DevelopmentProfileAcknowledgementState(
                providerGeneration: provider.generationToken, profileKind: .persistentDebug)
            let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { profileState })
            let metadata = AccountMetadataCoordinator(provider: { provider }, developerConsole: nil,
                forcedHydration: { _, _ in try hydrator.hydrateIfNeeded(forceRefresh: true) },
                acknowledgementGate: gate)
            let presentation = AccountsViewModel(accountStore: stores.accounts,
                transactionStore: stores.transactions, importSessionStore: stores.sessions,
                metadataCoordinator: metadata, cardStore: stores.cards, acknowledgementGate: gate)
            // Exercise the same entry point as the Accounts confirmation, then
            // prove cancelled and stale acknowledgements cannot perform it.
            presentation.markCreditCardHistoryOnly(accountID: account.id)
            #expect(presentation.requiresDevelopmentProfileAcknowledgement)
            presentation.cancelDevelopmentProfileAcknowledgement()
            #expect(try provider.accountRepo.account(id: account.id)?.closedAtISO == nil)
            presentation.markCreditCardHistoryOnly(accountID: account.id)
            profileState = DevelopmentProfileAcknowledgementState(
                providerGeneration: ProviderGenerationToken(), profileKind: .persistentDebug)
            presentation.approveDevelopmentProfileAcknowledgement()
            #expect(presentation.presentationState == .developmentProfileChanged)
            #expect(try provider.accountRepo.account(id: account.id)?.closedAtISO == nil)
            profileState = DevelopmentProfileAcknowledgementState(
                providerGeneration: provider.generationToken, profileKind: .persistentDebug)
            presentation.markCreditCardHistoryOnly(accountID: account.id)
            presentation.approveDevelopmentProfileAcknowledgement()
            #expect(presentation.presentationState == .ready)
            #expect(presentation.selectedAccount?.isHistoryOnly == true)
            classificationTime = try #require(provider.accountRepo.account(id: account.id)?.closedAtISO)
            #expect(try !metadata.markCreditCardHistoryOnly(accountId: account.id, workspaceId: account.workspaceId))
            // Reusing the authentic pre-classification account snapshot must
            // not clear the later owner metadata in either provider.
            _ = try provider.accountRepo.upsertAccount(account)
            #expect(try metadata.updateDisplayName(accountId: account.id, workspaceId: account.workspaceId,
                displayName: "Historical card"))
            let review = try engine.reviewPreparedImport(prepared)
            let remainsEligible = review == .matchedExisting(accountId: account.id)
                || review.eligibleAccountIds.contains(account.id)
            #expect(remainsEligible, "Historical source import must remain eligible for this account.")
            #expect(baseline.accounts.count == 1 && baseline.cardSnapshot.statements.count == 1)
        }
        func verifyHistoryOnly(_ current: DatabaseProvider) throws {
            guard let baseline = historyBaseline else { return }
            let currentStores = GmailQualificationStores()
            _ = try currentStores.hydrator(current).hydrateIfNeeded(forceRefresh: true)
            let snapshot = try currentStores.hydrator(current).stageHydration()
            let account = try #require(snapshot.accounts.first)
            let accountID = try #require(account.repositoryAccountId)
            let persistedAccount = try current.accountRepo.account(id: accountID)
            let persisted = try #require(persistedAccount)
            #expect(persisted.closedAtISO == classificationTime)
            #expect(account.isHistoryOnly && !account.includeInNetWorth)
            let financialGraphUnchanged = snapshot.cardSnapshot == baseline.cardSnapshot
                && rowProjection(snapshot.transactions) == rowProjection(baseline.transactions)
                && snapshot.importSessions == baseline.importSessions
                && account.currentBalanceMoney == baseline.accounts.first?.currentBalanceMoney
                && account.identitySummaries == baseline.accounts.first?.identitySummaries
            #expect(financialGraphUnchanged, "Owner metadata must not change any historical financial field.")
            #expect(DashboardPositionProjection.make(accounts: snapshot.accounts,
                transactions: snapshot.transactions, cardSnapshot: snapshot.cardSnapshot).isEmpty)
            let metadata = AccountMetadataCoordinator(databaseProvider: current, developerConsole: nil,
                acknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
            let presentation = AccountsViewModel(accountStore: currentStores.accounts,
                transactionStore: currentStores.transactions, importSessionStore: currentStores.sessions,
                metadataCoordinator: metadata, cardStore: currentStores.cards,
                acknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
            #expect(presentation.selectedAccount?.isHistoryOnly == true)
            #expect(presentation.selectedAccount?.currentBalanceLabel == "Historical Statement Balance")
            #expect(presentation.nativeBalanceSummaries.isEmpty)
            #expect(presentation.importHistory.count == 1 && presentation.transactionCount == 0)
            let historicalPresentationMatches = presentation.selectedAccount?.currentBalance
                    == baseline.cardSnapshot.statements.first?.newBalance?.amount
                && presentation.selectedAccount?.dueDate == baseline.cardSnapshot.statements.first?.dueDate?.presentation
            #expect(historicalPresentationMatches)
            let retained = try current.gmailInboxRepo.original(sha256: sha, byteCount: original.bytes.count) == original.bytes
            #expect(retained)
        }
        try verifyHistoryOnly(provider)
        let replay = try await engine.prepareImport(from: url)
        let replayed = await engine.commitPreparedImport(replay)
        #expect(replayed.previousImport != nil && !replayed.persisted)
        let unchanged = rowProjection(try hydrator.stageHydration().transactions) == expected
        #expect(unchanged)
        try verifyHistoryOnly(provider)
        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            let reopenedHydrator = GmailQualificationStores().hydrator(reopenedProvider)
            let matchesAfterReopen = rowProjection(try reopenedHydrator.stageHydration().transactions) == expected
            #expect(matchesAfterReopen, "Source fields differ after reopen at index \(index).")
            try verifyRelationships(reopenedProvider, expectedCount: expected.count)
            try verifyCardEvidence(reopenedProvider, prepared: prepared)
            try verifyBankSectionEvidence(reopenedProvider, prepared: prepared)
            let originalBytes = try reopened.gmailInboxRepo.original(sha256: sha, byteCount: original.source.expectedByteCount)
            #expect(GmailInboxSource.digest(originalBytes) == sha)
            try BackupCompatibility.verifyDatabase(reopened.database)
            try verifyHistoryOnly(reopenedProvider)
            if historyOnly {
                let previous = DatabaseProvider.shared
                DatabaseProvider.shared = reopenedProvider
                defer { DatabaseProvider.shared = previous }
                let coordinator = BackupRestoreCoordinator(testingAt: URL(fileURLWithPath: path))
                coordinator.installTestProvider(reopened)
                defer { try? coordinator.closeTestProvider() }
                let folder = directory.appendingPathComponent("backups")
                try BackupFiles.createDirectory(folder)
                await coordinator.createBackup(to: folder)
                let package = try #require(coordinator.lastBackupURL)
                _ = try BackupFiles.verifyPackage(package)
                await coordinator.verifyRestore(from: package)
                await coordinator.replaceLedger()
                guard coordinator.restoredReceipt?.phase == .activated else { throw CampaignError.commitFailed }
                try verifyHistoryOnly(DatabaseProvider.shared)
            }
            if sha == "1f12183dcefdd5775f1d68c67902345628bea3c6c1ccc212763c7bd434215868",
               let nativeDirectory = ProcessInfo.processInfo.environment["LEDGERFORGE_CBQ_NATIVE_REVIEW_DIRECTORY"] {
                let destination = URL(fileURLWithPath: nativeDirectory).standardizedFileURL
                guard destination.path.contains("/LedgerForge/Development/Namespaces/s98-cbq-correction-") else {
                    throw CampaignError.sourceUnavailable
                }
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                // A fresh exact database snapshot for native inspection. This
                // never overwrites an existing database or opens ordinary Current.
                try reopened.database.createBackup(at: destination.appendingPathComponent("ledgerforge-development.sqlite").path)
            }
        }
        return hydrated
    }

    private struct BoundedCohortResult {
        let sourceOrder: [String]
        let preparedFinancialFields: [[String]]
        let financialFields: [[String]]
        let relationships: [String]
        let dispositions: [String]
        let peakActivePreparations: Int
        let peakConcurrentCommits: Int
        let peakPreparationSourceBytes: Int
        let preparationMilliseconds: Int
        let commitMilliseconds: Int
        let hydrationMilliseconds: Int
        let endToEndMilliseconds: Int
    }

    private struct CohortCommitIdentity: Equatable {
        let preparationID: UUID
        let sourceSHA: String
        let sessionID: String
        let generation: ProviderGenerationToken
    }

    private struct CohortPublishedHydration {
        let commit: CohortCommitIdentity
        let snapshot: RepositoryRuntimeSnapshot
        let changeCounter: Int64
    }

    @MainActor
    private final class BoundedCohortObserver {
        var activeCommitIdentity: CohortCommitIdentity?
        var publishedHydration: CohortPublishedHydration?
        var preparedBySource: [String: [String]] = [:]
        var preparedValuesBySource: [String: PreparedImport] = [:]
        var sessionBySource: [String: String] = [:]
        var dispositionBySource: [String: String] = [:]
        var resultBySource: [String: ImportEngineResult] = [:]
        var semanticBySource: [String: [String]] = [:]
        var graphBySource: [String: [String]] = [:]
        var heldMappingBySource: [String: [String]] = [:]
        var heldPreparationBySource: [String: [String]] = [:]
        var verificationFailure: (any Error)?
        var activePreparations = 0
        var activePreparationBytes = 0
        var peakActivePreparations = 0
        var peakPreparationSourceBytes = 0
        var preparationMilliseconds = 0
        var preparationWorkerMilliseconds: [String: Int] = [:]
        var mappingRevalidationMilliseconds = 0
        var verificationMilliseconds = 0
        var graphProjectionMilliseconds = 0
        var verificationStageHydrationMilliseconds = 0
        var postCommitSourceAndIdentityMilliseconds = 0
        var activeCommits = 0
        var peakConcurrentCommits = 0
        var commitMilliseconds = 0
        var hydrationMilliseconds = 0
    }

    private func runBoundedCoordinatorCohort(
        _ cohort: [SourceCase],
        preparationLimit: Int
    ) async throws -> BoundedCohortResult {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Gmail-Bounded-Cohort-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("qualification.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        for original in cohort {
            guard let sha = original.source.sha256 else { throw CampaignError.sourceUnavailable }
            var inbox = try provider.gmailInboxRepo.load(account: original.source.account)
            guard inbox.sources[original.source.id] == nil else { throw CampaignError.sourceUnavailable }
            inbox.sources[original.source.id] = original.source
            _ = try provider.gmailInboxRepo.save(inbox, originals: [sha: original.bytes], expectedRevision: inbox.revision)
        }

        let stores = GmailQualificationStores()
        let passwords = Dictionary(uniqueKeysWithValues: cohort.compactMap { original in
            original.source.importURL.map { ($0, original.password) }
        })
        guard passwords.count == cohort.count else { throw CampaignError.sourceUnavailable }
        let passwordProvider = DefaultPasswordProvider(
            credentialStore: InMemoryStatementPasswordCredentialStore(),
            supportedInstitutionCodes: [],
            challenge: { request in await MainActor.run { passwords[request.fileURL] } }
        )
        let hydrator = stores.hydrator(provider)
        let observer = BoundedCohortObserver()
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwordProvider),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: {
                let started = Date()
                defer { observer.hydrationMilliseconds += Int(Date().timeIntervalSince(started) * 1_000) }
                return try hydrator.hydrateIfNeeded(forceRefresh: true)
            },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
        let byURL = Dictionary(uniqueKeysWithValues: try cohort.map { original in
            (try #require(original.source.importURL), original)
        })
        let coordinator = observedProductionCoordinator(engine: engine, originalsByURL: byURL, observer: observer)
        defer { coordinator.cancelBatch() }
        let sourceURLs = try cohort.map { original -> URL in
            guard let url = original.source.importURL else { throw CampaignError.sourceUnavailable }
            return url
        }
        let startedAt = Date()
        guard coordinator.startConfirmedBatch(sourceURLs, preparationLimit: preparationLimit) else {
            throw CampaignError.commitFailed
        }

        let deadline = Date().addingTimeInterval(60)
        while !coordinator.hasTerminalOutcomesForEntireBatch {
            observer.peakActivePreparations = max(observer.peakActivePreparations,
                coordinator.items.filter { $0.phase == .preparing }.count)
            observer.peakConcurrentCommits = max(observer.peakConcurrentCommits,
                coordinator.items.filter { $0.phase == .committing }.count)
            if let item = coordinator.currentItem, item.phase == .awaitingConfirmation {
                if item.accountChoice == nil {
                    switch item.identityReview {
                    case .cardChoiceRequired:
                        coordinator.updateAccountChoice(.createNewCardLiabilityAccountAndInstrument(displayName: "Gmail cohort qualification"))
                    case .choiceRequired, .liabilityAccountChoiceRequired:
                        coordinator.updateAccountChoice(.createNewAccount(displayName: "Gmail cohort qualification"))
                    case .matchedExisting:
                        // The ordinary engine resolves the prior confirmed
                        // account/instrument mapping when no new choice is made.
                        // A generic bank-style account choice would discard the
                        // card-section decision already represented by review.
                        break
                    case .unavailable:
                        break
                    case .ambiguous, .conflict, .bankSections:
                        print("Bounded cohort \(preparationLimit): unresolved identity at queue position \(item.queuePosition).")
                        throw CampaignError.commitFailed
                    }
                }
                await coordinator.confirmCurrent()
            }
            if coordinator.items.contains(where: { $0.phase == .failed || $0.phase == .validationFailed }) {
                for item in coordinator.items where item.phase == .failed || item.phase == .validationFailed {
                    print("Bounded cohort \(preparationLimit): queue position \(item.queuePosition), phase \(item.phase), failure family \(String(describing: item.preparationFailure?.family)).")
                }
                throw CampaignError.commitFailed
            }
            if let item = coordinator.currentItem, item.phase == .completed, item.completionDisposition != .committed {
                print("Bounded cohort \(preparationLimit): attention at queue position \(item.queuePosition), disposition \(String(describing: item.completionDisposition)).")
                throw CampaignError.commitFailed
            }
            guard Date() < deadline else { throw CampaignError.commitFailed }
            try await Task.sleep(for: .milliseconds(2))
        }
        let elapsed = Int(Date().timeIntervalSince(startedAt) * 1_000)
        guard observer.activePreparations == 0, observer.activeCommits == 0,
              coordinator.items.count == cohort.count,
              coordinator.items.allSatisfy({ $0.phase == .completed && $0.completionDisposition == .committed && $0.outcome?.persisted == true }) else {
            for item in coordinator.items {
                print("Bounded cohort \(preparationLimit): terminal queue position \(item.queuePosition), phase \(item.phase), disposition \(String(describing: item.completionDisposition)), persisted \(item.outcome?.persisted == true).")
            }
            throw CampaignError.commitFailed
        }

        let staged = try hydrator.stageHydration()
        let sourceOrder = try cohort.map { try #require($0.source.sha256) }
        for source in sourceOrder {
            guard let prepared = observer.preparedValuesBySource[source], let session = observer.sessionBySource[source] else {
                throw CampaignError.sourceMismatch
            }
            try verifyCardEvidence(provider, prepared: prepared, sessionID: session)
        }
        let preparedFinancial = try sourceOrder.map { source in
            guard let projection = observer.preparedBySource[source] else { throw CampaignError.sourceMismatch }
            return projection
        }
        let financial = try sourceOrder.map { source in
            guard let session = observer.sessionBySource[source] else { throw CampaignError.sourceMismatch }
            return rowProjection(staged.transactions.filter { $0.repositoryImportSessionId == session })
        }
        guard financial == preparedFinancial else { throw CampaignError.sourceMismatch }
        var accountOrdinals: [String: Int] = [:]
        var instrumentOrdinals: [String: Int] = [:]
        let relationships = try sourceOrder.map { source in
            guard let session = observer.sessionBySource[source] else { throw CampaignError.sourceMismatch }
            return try durableRelationshipProjection(provider: provider, sessionID: session,
                accountOrdinals: &accountOrdinals, instrumentOrdinals: &instrumentOrdinals)
        }
        let dispositions = try sourceOrder.map { source in
            guard let disposition = observer.dispositionBySource[source] else { throw CampaignError.sourceMismatch }
            return disposition
        }
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        try BackupCompatibility.verifyDatabase(reopened.database)
        let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
        let reopenedSnapshot = try GmailQualificationStores().hydrator(reopenedProvider).stageHydration()
        for source in sourceOrder {
            guard let prepared = observer.preparedValuesBySource[source], let session = observer.sessionBySource[source] else {
                throw CampaignError.sourceMismatch
            }
            try verifyCardEvidence(reopenedProvider, prepared: prepared, sessionID: session)
        }
        let reopenedFinancial = try sourceOrder.map { source in
            guard let session = observer.sessionBySource[source] else { throw CampaignError.sourceMismatch }
            return rowProjection(reopenedSnapshot.transactions.filter { $0.repositoryImportSessionId == session })
        }
        var reopenedAccountOrdinals: [String: Int] = [:]
        var reopenedInstrumentOrdinals: [String: Int] = [:]
        let reopenedRelationships = try sourceOrder.map { source in
            guard let session = observer.sessionBySource[source] else { throw CampaignError.sourceMismatch }
            return try durableRelationshipProjection(provider: reopenedProvider, sessionID: session,
                accountOrdinals: &reopenedAccountOrdinals, instrumentOrdinals: &reopenedInstrumentOrdinals)
        }
        guard financial == reopenedFinancial, relationships == reopenedRelationships else {
            throw CampaignError.sourceMismatch
        }
        return .init(sourceOrder: sourceOrder, preparedFinancialFields: preparedFinancial,
            financialFields: financial, relationships: relationships,
            dispositions: dispositions, peakActivePreparations: observer.peakActivePreparations,
            peakConcurrentCommits: observer.peakConcurrentCommits,
            peakPreparationSourceBytes: observer.peakPreparationSourceBytes,
            preparationMilliseconds: observer.preparationMilliseconds,
            commitMilliseconds: observer.commitMilliseconds, hydrationMilliseconds: observer.hydrationMilliseconds,
            endToEndMilliseconds: elapsed)
    }

    /// This is the existing production coordinator adapter with only two
    /// observations added: source-oracle comparison at review (before commit),
    /// and technical active preparation/commit timing. It retains the ordinary
    /// engine refresh/review/confirmation closures and provider-owned commit.
    private func observedProductionCoordinator(
        engine: ImportEngine,
        originalsByURL: [URL: SourceCase],
        observer: BoundedCohortObserver,
        afterCommit: ((PreparedImport, ImportEngineResult) throws -> Void)? = nil
    ) -> ImportCentreCoordinator<PreparedImport> {
        ImportCentreCoordinator(dependencies: .init(
            prepare: { sourceURL, operationID, progress in
                guard let original = originalsByURL[sourceURL] else { throw CampaignError.sourceUnavailable }
                let started = Date()
                observer.activePreparations += 1
                observer.activePreparationBytes += original.bytes.count
                observer.peakActivePreparations = max(observer.peakActivePreparations, observer.activePreparations)
                observer.peakPreparationSourceBytes = max(observer.peakPreparationSourceBytes, observer.activePreparationBytes)
                defer {
                    observer.activePreparations -= 1
                    observer.activePreparationBytes -= original.bytes.count
                }
                let initial: PreparedImport
                do {
                    initial = try await engine.prepareImport(from: sourceURL, requestId: operationID, progress: progress)
                } catch {
                    if let sha = original.source.sha256 {
                        observer.preparationWorkerMilliseconds[sha] = Int(Date().timeIntervalSince(started) * 1_000)
                        observer.preparationMilliseconds += observer.preparationWorkerMilliseconds[sha] ?? 0
                        if let expected = original.expectedPreparationHold {
                            let matches = self.matchesFrozenPreparationHold(error, original: original)
                            guard matches else {
                                print("GMAIL_COHORT_UNEXPECTED_HOLD sha=\(sha) layout=\(original.expectedHoldLayout ?? "unknown") expected=\(expected) observed=\(self.safeFailureKind(error))")
                                observer.verificationFailure = CampaignError.sourceMismatch
                                throw error
                            }
                            observer.heldPreparationBySource[sha] = [expected, self.safeFailureKind(error)]
                        }
                    }
                    throw error
                }
                var prepared = initial
                let workerMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)
                observer.preparationMilliseconds += workerMilliseconds
                if let sha = original.source.sha256 { observer.preparationWorkerMilliseconds[sha] = workerMilliseconds }
                let mappingStarted = Date()
                defer { observer.mappingRevalidationMilliseconds += Int(Date().timeIntervalSince(mappingStarted) * 1_000) }
                try original.configure?(&prepared)
                return prepared
            },
            refreshQueuedPreparation: { preparation in
                let started = Date()
                defer { observer.mappingRevalidationMilliseconds += Int(Date().timeIntervalSince(started) * 1_000) }
                var refreshed = try engine.refreshQueuedPreparation(preparation)
                guard let original = originalsByURL[refreshed.sourceURL] else { throw CampaignError.sourceUnavailable }
                try original.configure?(&refreshed)
                return refreshed
            },
            review: { preparation in
                guard let original = originalsByURL[preparation.sourceURL], let source = original.source.sha256 else {
                    throw CampaignError.sourceUnavailable
                }
                // A discrepancy throws here, before the coordinator can offer
                // or schedule its normal provider commit.
                let verificationStarted = Date()
                try original.compare(preparation)
                if let expected = original.expectedPreparationHold {
                    guard !preparation.validation.passed, expected != "SUPPORTED_BUT_HELD_PASSWORD" else { throw CampaignError.sourceMismatch }
                    observer.heldPreparationBySource[source] = [expected, "validation-held"]
                }
                observer.preparedBySource[source] = self.rowProjection(preparation.financialDocument.transactions)
                observer.semanticBySource[source] = try self.cohortPreparedProjection(preparation)
                observer.preparedValuesBySource[source] = preparation
                observer.sessionBySource[source] = preparation.importSession.id.uuidString
                observer.verificationMilliseconds += Int(Date().timeIntervalSince(verificationStarted) * 1_000)
                let mappingStarted = Date()
                defer { observer.mappingRevalidationMilliseconds += Int(Date().timeIntervalSince(mappingStarted) * 1_000) }
                let identityReview = preparation.validation.passed
                    ? try engine.reviewPreparedImport(preparation) : .unavailable
                let partialReview = preparation.validation.passed && preparation.advisoryPreviousImport == nil
                    ? try engine.reviewPreparedPartialImport(preparation) : .ordinaryFullImport
                return .init(identityReview: identityReview,
                    initialAccountChoice: ImportAccountConfirmationPolicy.initialChoice(for: identityReview),
                    partialReview: partialReview, validationPassed: preparation.validation.passed)
            },
            refreshPartialReview: { preparation, choice in
                let started = Date()
                defer { observer.mappingRevalidationMilliseconds += Int(Date().timeIntervalSince(started) * 1_000) }
                return try engine.reviewPreparedPartialImport(preparation, accountChoice: choice)
            },
            commit: { preparation, accountChoice, reviewedPartialPlan in
                let started = Date()
                let priorHydrationMilliseconds = observer.hydrationMilliseconds
                if observer.activeCommitIdentity != nil || observer.publishedHydration != nil {
                    observer.verificationFailure = CampaignError.sourceMismatch
                }
                observer.publishedHydration = nil
                observer.activeCommitIdentity = originalsByURL[preparation.sourceURL]?.source.sha256.map {
                    CohortCommitIdentity(preparationID: preparation.id, sourceSHA: $0,
                        sessionID: preparation.importSession.id.uuidString, generation: preparation.providerGeneration)
                }
                observer.activeCommits += 1
                observer.peakConcurrentCommits = max(observer.peakConcurrentCommits, observer.activeCommits)
                defer {
                    if observer.publishedHydration != nil {
                        observer.verificationFailure = CampaignError.sourceMismatch
                    }
                    observer.publishedHydration = nil
                    observer.activeCommitIdentity = nil
                    observer.activeCommits -= 1
                }
                let result = await engine.commitPreparedImport(preparation,
                    accountChoice: accountChoice, reviewedPartialPlan: reviewedPartialPlan)
                observer.commitMilliseconds += max(0, Int(Date().timeIntervalSince(started) * 1_000)
                    - (observer.hydrationMilliseconds - priorHydrationMilliseconds))
                if let source = originalsByURL[preparation.sourceURL]?.source.sha256 {
                    observer.resultBySource[source] = result
                    print("Bounded cohort source \(source.prefix(12)): persisted \(result.persisted), hydrated \(result.hydrationOutcome == .committedAndHydrated), previous import \(result.previousImport != nil), account outcome \(result.accountOutcome), recovery \(result.recoveryRoute), transaction-event block \(result.transactionEventBlock != nil).")
                    observer.dispositionBySource[source] = result.persisted && result.hydrationOutcome == .committedAndHydrated
                        ? "committed" : "noncommitted"
                }
                let verificationStarted = Date()
                do { try afterCommit?(preparation, result) }
                catch { observer.verificationFailure = error }
                observer.verificationMilliseconds += Int(Date().timeIntervalSince(verificationStarted) * 1_000)
                return ImportOutcomePresentation(result: result)
            },
            cancelPreparation: { engine.cancelPreparedImport($0) },
            cancelPasswordChallenge: { StatementPasswordChallengeController.shared.cancel(challengeID: $0) },
            failureSummary: { error in
                print("Bounded cohort preparation/review failure: \(self.safeFailureKind(error)).")
                return ImportFailureSummary.from(error)
            },
            isRetryablePreparationFailure: { error in
                guard let importError = error as? ImportError else { return false }
                switch importError {
                case .readerFailure, .unknown: return true
                case .unsupportedFile, .passwordRequired, .incorrectPassword, .readerUnavailable,
                        .invalidDocument, .unsupportedStatement, .cancelled: return false
                }
            },
            isAutomaticallyCommittable: { preparation, review in
                guard review.validationPassed else { return false }
                let salaryOrInvestment = preparation.financialDocument.salaryStatementEvidence != nil
                    || preparation.financialDocument.investmentStatementEvidence != nil
                let resolvedAccount = ImportAccountConfirmationPolicy.allowsConfirmation(
                    review: review.identityReview, choice: review.initialAccountChoice,
                    requiredCardSectionIDs: preparation.financialDocument.cardStatementEvidence?.instrumentSections.map(\.documentScopedSectionID),
                    requiresNamedCreation: preparation.detectedDocumentType == .bankAccount
                )
                if preparation.advisoryPreviousImport != nil { return salaryOrInvestment || resolvedAccount }
                if !salaryOrInvestment && !resolvedAccount { return false }
                if preparation.investmentConfirmationBlocked { return false }
                switch preparation.statementEquivalenceReview {
                case .conflict, .evidenceUnavailable, .formatAlreadyRecorded: return false
                case .notApplicable, .firstAcceptedSource, .equivalent: break
                }
                switch review.partialReview {
                case .ordinaryFullImport, .eligible, .unsupportedEvidence: return true
                case .fullSupportedOverlap, .repeatedIncomingEvidence, .ownershipConflict, .repositoryIntegrityConflict: return false
                }
            }
        ))
    }

    private func cohortFields(_ values: [String]) -> String {
        values.map { "\($0.utf8.count):\($0)" }.joined()
    }

    private func cohortMoney(_ value: Money?) throws -> String {
        guard let value else { return "absent" }
        return try cohortFields([value.currency.code, String(value.minorUnits()), value.canonicalDecimalString()])
    }

    private func cohortSalaryProjection(_ salary: SalaryStatementEvidence) throws -> [String] {
        var result = [try cohortFields([salary.sourceAuthority.rawValue, salary.profileID, salary.profileVersion,
            salary.financialPeriod.canonical, salary.printDate?.canonical ?? "", salary.kind.rawValue,
            salary.nativeCurrency.code, cohortMoney(salary.printedEarningsTotal), cohortMoney(salary.printedDeductionsTotal),
            cohortMoney(salary.printedNet), cohortMoney(salary.printedPaymentTotal)])]
        result += try (salary.earnings + salary.deductions).map {
            try cohortFields([$0.side.rawValue, String($0.sourceOrdinal), $0.sourceLabel, cohortMoney($0.money)])
        }
        return result
    }

    private func cohortPreparedProjection(_ prepared: PreparedImport) throws -> [String] {
        let document = prepared.financialDocument
        var result = [cohortFields([prepared.sourceSnapshot.sourceByteFingerprint.digest,
            document.metadata.institution.rawValue, document.metadata.documentType.rawValue,
            document.parserName, document.parserProfileID ?? "", document.parserProfileVersion ?? "",
            document.bookedCurrency?.code ?? "", document.declaredStatementPeriod?.start.canonical ?? "",
            document.declaredStatementPeriod?.end.canonical ?? "", String(prepared.validation.passed)])]
        result += document.financialIdentifiers.map {
            cohortFields([$0.kind.rawValue, $0.normalizedValue, $0.strength.rawValue, $0.verificationState.rawValue, $0.provenance.rawValue])
        }
        result += document.cbqSourceIdentityObservations.map { cohortFields([$0.kind.rawValue, $0.pattern]) }
        if let evidence = document.sourceStatementEvidence {
            result.append(try cohortFields([evidence.sourceFormatCode, evidence.statementBoundaryDate?.canonical ?? "",
                evidence.period?.start.canonical ?? "", evidence.period?.end.canonical ?? "",
                cohortMoney(evidence.openingBalance), cohortMoney(evidence.closingBalance)]))
        }
        result += rowProjection(document.transactions)
        if let bank = document.bankStatementEvidence {
            result.append(cohortFields(["bank-parent", String(bank.isAccountRelationshipStatement)]))
            let rows = Dictionary(uniqueKeysWithValues: document.transactions.map { ($0.id, $0) })
            for section in bank.sections {
                result.append(cohortFields(["bank-section", section.id, String(section.ordinal),
                    String(describing: section.sourceIdentity), section.productLabel, section.nativeCurrency.code,
                    section.period.start.canonical, section.period.end.canonical,
                    String(section.firstSourceOrdinal), String(section.lastSourceOrdinal), String(section.firstPage), String(section.lastPage)]))
                result += section.financialIdentifiers.map {
                    cohortFields(["bank-identity", $0.kind.rawValue, $0.normalizedValue, $0.strength.rawValue,
                        $0.verificationState.rawValue, $0.provenance.rawValue])
                }
                for control in section.controls {
                    result.append(try cohortFields(["bank-control", control.kind.rawValue, control.label, control.literal,
                        cohortMoney(control.money), control.count.map(String.init) ?? "nil", String(control.sourceOrdinal), String(control.sourcePage)]))
                }
                let region = section.exhaustedRegion
                result.append(cohortFields(["bank-region", region.descriptor, String(describing: region.sourceUnit),
                    String(region.startOrdinal), String(region.endOrdinal), String(region.recognizedFinancialRowCount), region.signature]))
                for id in section.transactionIDs { result += rowProjection([try #require(rows[id])]) }
            }
        }
        if let card = document.cardStatementEvidence {
            result.append(cohortFields([card.statementDate?.canonical ?? "", card.declaredStatementPeriod?.start.canonical ?? "",
                card.declaredStatementPeriod?.end.canonical ?? "", card.selectedStatementMonth?.canonical ?? "",
                card.nativeCurrency.code, card.reconciliationRuleIdentifier]))
            result += card.accountSourceIdentityObservations.map { cohortFields([$0.kind.rawValue, $0.subject.rawValue, $0.value]) }
            result += try card.summaryComponents.map { try cohortFields([$0.persistenceCode, cohortMoney($0.money), $0.date?.canonical ?? ""]) }
            for section in card.instrumentSections {
                result.append(try cohortFields([section.documentScopedSectionID, String(section.sourceOrdinal), section.holderLabel ?? "",
                    cohortMoney(section.signedNetTotal), section.reconciliationRuleIdentifier]))
                result += section.sourceIdentityObservations.map { cohortFields([$0.kind.rawValue, $0.subject.rawValue, $0.value]) }
            }
            for annotation in card.transactionAnnotations {
                let transaction = try #require(document.transactions.first { $0.id == annotation.parserTransactionID })
                result.append(try cohortFields([String(try #require(transaction.sourceProvenance.first?.sourceOrdinal)),
                    annotation.financialScope.persistenceCode, annotation.documentScopedSectionID ?? "",
                    annotation.liabilityEffect.rawValue, annotation.sourceTransactionDate.canonical,
                    cohortMoney(annotation.originalMerchantMoney), annotation.summaryMembership?.rawValue ?? ""]))
            }
        }
        if let salary = document.salaryStatementEvidence { result += try cohortSalaryProjection(salary) }
        if let investment = document.investmentStatementEvidence {
            result.append(cohortFields([investment.parserProfile, investment.issueDate ?? "", investment.excludedSectionDescription]))
            for scope in investment.scopes {
                result.append(cohortFields([scope.institution, scope.identityKind, scope.identity, cohortFields(scope.aliases),
                    scope.displayName, scope.holdingsDate, String(scope.isComplete)]))
                for position in scope.positions {
                    result.append(cohortFields([position.instrumentIdentity, cohortFields(position.sourceAliases), position.displayName,
                        position.units.sourceText, NSDecimalNumber(decimal: position.units.value).stringValue, position.currency,
                        position.averageCost?.sourceText ?? "", position.totalCost?.sourceText ?? "", position.averageCostLabel ?? "",
                        position.totalCostLabel ?? "", position.costCurrency ?? "", String(position.sourceOrdinal), position.valuationDate ?? ""]))
                }
            }
            if let plan = prepared.investmentPlan {
                result.append(cohortFields(["investment-attention", String(prepared.investmentConfirmationBlocked),
                    cohortFields(prepared.investmentReview?.sameDateConflictScopes.sorted() ?? [])]))
                for question in prepared.investmentReview?.mappingQuestions ?? [] {
                    let candidates = try question.candidates.map { candidate in
                        switch question.kind {
                        case .instrument:
                            let holding = try #require(plan.baseline.holdings.first { $0.id == candidate.id })
                            let container = try #require(plan.baseline.containers.first { $0.id == holding.containerID })
                            return cohortFields([container.institution, container.identityKind, container.identity,
                                holding.instrumentIdentity, cohortFields(holding.sourceAliases), holding.currency])
                        case .container:
                            let container = try #require(plan.baseline.containers.first { $0.id == candidate.id })
                            return cohortFields([container.institution, container.identityKind, container.identity, cohortFields(container.aliases)])
                        }
                    }.sorted()
                    result.append(cohortFields(["mapping-question", question.scopeKey, String(describing: question.kind), question.label,
                        cohortFields(candidates)]))
                }
                for key in plan.choices.containerTargets.keys.sorted() {
                    let id = try #require(plan.choices.containerTargets[key])
                    let target = try #require(plan.baseline.containers.first { $0.id == id })
                    result.append(cohortFields(["container-choice", key, target.institution, target.identityKind, target.identity, cohortFields(target.aliases)]))
                }
                for key in plan.choices.instrumentTargets.keys.sorted() {
                    let id = try #require(plan.choices.instrumentTargets[key])
                    let target = try #require(plan.baseline.holdings.first { $0.id == id })
                    result.append(cohortFields(["instrument-choice", key, target.instrumentIdentity, target.currency, cohortFields(target.sourceAliases)]))
                }
                result += [cohortFields(plan.choices.newContainerScopes.sorted()), cohortFields(plan.choices.newInstrumentKeys.sorted()),
                           cohortFields(plan.choices.replaceSameDateScopes.sorted())]
            }
        }
        return result
    }

    private func completeQualifiedHistoricalCases() async throws -> [SourceCase] {
        let environment = ProcessInfo.processInfo.environment
        let compareMappingHolds = environment["LEDGERFORGE_GMAIL_COMPARE_MAPPING_HOLDS"] == "1"
        guard let path = environment["LEDGERFORGE_GMAIL_QUALIFIED_COHORT_MANIFEST"],
              let digest = environment["LEDGERFORGE_GMAIL_QUALIFIED_COHORT_SHA256"],
              let directory = environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"] else { throw CampaignError.missingEnvironment }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard GmailInboxSource.digest(data) == digest else { throw CampaignError.sourceUnavailable }
        let nominations = try JSONDecoder().decode(Manifest.self, from: data).nominations
        let database = SQLiteDatabase(path: URL(fileURLWithPath: directory).appendingPathComponent("acquisition.sqlite").path)
        try database.open(access: .readOnlySnapshot); defer { database.close() }
        let repository = SQLiteGmailInboxRepository(database: database)
        let state = try repository.load(account: soleCampaignAccount(in: repository))
        guard state.activeScan == nil, !state.completedIntervals.isEmpty,
              Set(nominations.map(\.sha256)).count == nominations.count else { throw CampaignError.sourceUnavailable }
        let bySHA = Dictionary(uniqueKeysWithValues: nominations.map { ($0.sha256, $0) })
        var selected = state.orderedSources.filter { bySHA[$0.sha256 ?? ""] != nil }
        guard selected.count == nominations.count else { throw CampaignError.sourceUnavailable }
        let investment = InvestmentRAMOriginalTests()
        let cbqPassword = try #require(try await KeychainStatementPasswordCredentialStore().password(institutionCode: Institution.cbq.statementPasswordCredentialScope))
        let casPassword = try #require(try await GmailCASCredential.read().first?.value)
        var cases: [String: SourceCase] = [:]
        var cas: [InvestmentRAMOriginalTests.Original] = []
        var cacheVerificationMilliseconds = 0
        let started = Date()
        func investmentCase(_ source: GmailInboxSource, _ original: InvestmentRAMOriginalTests.Original) -> SourceCase {
            var candidate = SourceCase(source: source, bytes: original.bytes, password: original.password ?? "",
                compare: { try investment.gmailCohortPreparedComparison($0, original: original) })
            let permitsHold = compareMappingHolds && source.family == .cbqInvestment
            candidate.permitsUnresolvedInstrumentHold = permitsHold
            candidate.configure = { try investment.configureGmailCohort(&$0, original: original,
                retainUnresolvedInstrumentHold: permitsHold) }
            candidate.verifyStored = { provider, hydrated, prepared, _ in
                let durable = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
                guard durable == hydrated.investments else { throw CampaignError.sourceMismatch }
                try investment.verifyGmailCohortSnapshot(durable, prepared: prepared, original: original)
            }
            return candidate
        }
        for source in selected {
            let sha = try #require(source.sha256), nomination = try #require(bySHA[sha])
            let cacheStarted = Date()
            let bytes = try repository.original(sha256: sha, byteCount: source.expectedByteCount)
            cacheVerificationMilliseconds += Int(Date().timeIntervalSince(cacheStarted) * 1_000)
            guard source.id == nomination.sourceID, nomination.disposition == "available" else { throw CampaignError.sourceUnavailable }
            switch nomination.family {
            case "amex_card", "axis_card_traditional", "cbq_bank", "cbq_card":
                cases[sha] = try await bankAndCardCase(source: source, bytes: bytes, family: nomination.family)
            case "salary":
                let checks = try SalaryAuthenticCorpusAcceptanceTests().gmailCohortComparisons(source: source, bytes: bytes)
                var candidate = SourceCase(source: source, bytes: bytes, password: "", compare: checks.prepared)
                candidate.verifyStored = { provider, hydrated, _, sessionID in try checks.persisted(provider, hydrated, sessionID) }
                cases[sha] = candidate
            case "cbq_investment":
                let original = try investment.cbqGmailOriginal(source: source, bytes: bytes, password: cbqPassword, family: nomination.family)
                cases[sha] = investmentCase(source, original)
            case "cas_detailed", "cas_summary":
                cas.append(try investment.casGmailOriginal(source: source, bytes: bytes, password: casPassword, family: nomination.family))
            default: throw CampaignError.unsupportedSelection
            }
        }
        for original in try applyingExistingCASAliasAuthority(to: cas) {
            let source = try #require(selected.first { $0.sha256 == original.sha256 })
            cases[original.sha256] = investmentCase(source, original)
        }
        if let qualificationPath = environment["LEDGERFORGE_S98_SELECTED_QUALIFICATION"] {
            struct Qualification: Decodable {
                struct Entry: Decodable {
                    let sha256: String
                    let family: String
                    let layout: String
                    let priorCombinedDispositionName: String
                    let selectedQualificationStatus: String
                    let selectedScope: String?
                }
                let entries: [Entry]
            }
            let qualificationBytes = try Data(contentsOf: URL(fileURLWithPath: qualificationPath))
            guard GmailInboxSource.digest(qualificationBytes) == environment["LEDGERFORGE_S98_SELECTED_QUALIFICATION_SHA256"],
                  compareMappingHolds else { throw CampaignError.sourceUnavailable }
            let entries = try JSONDecoder().decode(Qualification.self, from: qualificationBytes).entries
            let inventory = Dictionary(grouping: entries, by: \.sha256)
            guard entries.count == 416, inventory.count == 416,
                  Set(state.orderedSources.compactMap(\.sha256)) == Set(inventory.keys),
                  state.orderedSources.count == 416 else { throw CampaignError.sourceUnavailable }
            let oldSelection = Set(cases.keys)
            let selectedEntries = entries.filter { $0.selectedQualificationStatus == "PASS" }
            guard oldSelection.count == 170, selectedEntries.count == 187 else { throw CampaignError.sourceMismatch }
            let relationshipOracle = try BankRelationshipAuthenticOracle.load()
            let relationships = try await relationshipBankCases(relationshipOracle)
            let savings = try await selectedCBQSavingsCases()
            for var candidate in relationships {
                let sha = try #require(candidate.source.sha256), expected = try #require(relationshipOracle[sha])
                // Reuse the source oracle's dated row/zero-closing observations,
                // never the prepared document or a persisted running balance.
                func canonical(_ date: String) -> String { date.split(whereSeparator: { $0 == "/" || $0 == "-" }).reversed().joined(separator: "-") }
                func amount(_ value: String) throws -> Decimal {
                    guard let parsed = Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) else { throw CampaignError.sourceMismatch }
                    return parsed
                }
                for (index, section) in expected.sections.enumerated() {
                    let sourceDates = [section.start, section.end] + section.rows.flatMap { [$0.date] + ($0.valueDate.map { [$0] } ?? []) }
                    guard sourceDates.allSatisfy({ $0.range(of: #"^\d{2}[-/]\d{2}[-/]\d{4}$"#, options: .regularExpression) != nil }) else {
                        throw CampaignError.sourceMismatch
                    }
                    if section.rows.isEmpty {
                        if let closing = section.closing ?? section.summary?.closing {
                            candidate.relationshipBalanceObservations.append((index + 1, canonical(section.end), try amount(closing), true))
                        }
                    } else if let last = section.rows.enumerated().max(by: {
                        (canonical($0.element.date), $0.offset) < (canonical($1.element.date), $1.offset)
                    }) {
                        candidate.relationshipBalanceObservations.append((index + 1, canonical(last.element.date), try amount(last.element.balance), false))
                    }
                }
                candidate.verifyStored = { provider, _, prepared, _ in
                    let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
                    try BankRelationshipAuthenticOracle.compareStored(graph.sections.filter { $0.importSessionId == prepared.importSession.id.uuidString },
                        transactions: provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace"), source: expected)
                    // This full-cohort callback is immediately followed by
                    // completeCohortGraph, which checks the same runtime history.
                }
                cases[sha] = candidate
            }
            for candidate in savings { cases[try #require(candidate.source.sha256)] = candidate }
            let sourcesBySHA = Dictionary(uniqueKeysWithValues: state.orderedSources.map { ($0.sha256 ?? "", $0) })
            for entry in selectedEntries where cases[entry.sha256] == nil {
                let family: String
                switch entry.selectedScope {
                case "axis_card_correction": family = "axis_card_traditional"
                case "cbq_card_correction", "cbq_companion_card_expansion": family = "cbq_card"
                case "cbq_bank_zero_correction", "cbq_current_legacy_expansion", "cbq_current_usd_expansion": family = "cbq_bank"
                case "amex_usd_zero_expansion": family = "amex_card"
                default: throw CampaignError.unsupportedSelection
                }
                let source = try #require(sourcesBySHA[entry.sha256])
                let bytes = try repository.original(sha256: entry.sha256, byteCount: source.expectedByteCount)
                cases[entry.sha256] = try await bankAndCardCase(source: source, bytes: bytes, family: family)
            }
            let selectedSet = Set(selectedEntries.map(\.sha256))
            guard Set(relationships.compactMap { $0.source.sha256 }) == Set(selectedEntries.filter { $0.selectedScope == "combined_relationship_bank" }.map(\.sha256)),
                  Set(savings.compactMap { $0.source.sha256 }) == Set(selectedEntries.filter { $0.selectedScope == "cbq_savings_esavings" }.map(\.sha256)),
                  Set(cases.keys) == oldSelection.union(selectedSet) else { throw CampaignError.sourceMismatch }
            print("GMAIL_EXPANDED_MEMBERSHIP old=\(oldSelection.count) selected=\(selectedSet.count) intersection=\(oldSelection.intersection(selectedSet).count) union=\(cases.count) inventory=\(entries.count)")
            let credentials = KeychainStatementPasswordCredentialStore()
            var knownPasswords: [GmailSourceFamily: [String]] = [:]
            for entry in entries where cases[entry.sha256] == nil {
                guard ["SUPPORTED_BUT_HELD_PASSWORD", "KNOWN_UNSUPPORTED_LAYOUT"].contains(entry.priorCombinedDispositionName) else {
                    throw CampaignError.unsupportedSelection
                }
                let source = try #require(sourcesBySHA[entry.sha256])
                let bytes = try repository.original(sha256: entry.sha256, byteCount: source.expectedByteCount)
                guard GmailInboxSource.digest(bytes) == entry.sha256 else { throw CampaignError.sourceMismatch }
                if knownPasswords[source.family] == nil {
                    let scope = source.family == .axisBank ? Institution.axis.statementPasswordCredentialScope
                        : source.family == .amex ? Institution.amex.statementPasswordCredentialScope
                        : Institution.cbq.statementPasswordCredentialScope
                    knownPasswords[source.family] = source.family == .consolidatedFunds
                        ? try await GmailCASCredential.read().map(\.value)
                        : try await credentials.credentials(institutionCode: scope).map(\.value)
                }
                var password = ""
                if let pdf = PDFDocument(data: bytes), pdf.isLocked {
                    let unlocked = knownPasswords[source.family]?.first { pdf.unlock(withPassword: $0) }
                    if entry.priorCombinedDispositionName == "SUPPORTED_BUT_HELD_PASSWORD" {
                        guard unlocked == nil else { throw CampaignError.sourceMismatch }
                    } else { password = try #require(unlocked) }
                } else if entry.priorCombinedDispositionName == "SUPPORTED_BUT_HELD_PASSWORD" { throw CampaignError.sourceMismatch }
                var held = SourceCase(source: source, bytes: bytes, password: password, compare: { _ in
                    // No exact validation-stage outcome is frozen for these
                    // sources. Require their explicit preparation boundary;
                    // attribute a changed outcome before accepting it.
                    throw CampaignError.sourceMismatch
                })
                held.expectedPreparationHold = entry.priorCombinedDispositionName
                held.expectedHoldLayout = entry.layout
                cases[entry.sha256] = held
            }
            guard cases.count == 416,
                  cases.values.filter({ $0.expectedPreparationHold == "SUPPORTED_BUT_HELD_PASSWORD" }).count == 8 else {
                throw CampaignError.sourceMismatch
            }
            selected = state.orderedSources
        }
        let cohort = try selected.map { source in
            let sha = try #require(source.sha256)
            return try #require(cases[sha])
        }
        print("Gmail full cohort frozen sources=\(cohort.count), cache verification milliseconds=\(cacheVerificationMilliseconds), source-oracle setup milliseconds=\(Int(Date().timeIntervalSince(started) * 1_000) - cacheVerificationMilliseconds), immutable input bytes=\(cohort.reduce(0) { $0 + $1.bytes.count }).")
        return cohort
    }

    /// One explicitly authorized, one-time publication path for the final
    /// adoption candidate. The older acquisition ledger remains the source
    /// oracle for prepared comparisons; the newer verified backup is the sole
    /// authority for the destination inbox, originals, receipts and coverage.
    @Test(.globalRuntimeStateIsolation, .timeLimit(.minutes(30)))
    func populateFinalAdoptionCandidateFromFrozenGmailCohort() async throws {
        let environment = ProcessInfo.processInfo.environment
        let namespace = URL(fileURLWithPath: "/Users/vyom/Library/Containers/com.vyom.LedgerForge/Data/Library/Application Support/LedgerForge/Development/Namespaces/s98-adoption-candidate-01a0b713", isDirectory: true)
        let destination = namespace.appendingPathComponent("ledgerforge-development.sqlite")
        let backup = URL(fileURLWithPath: "/Users/vyom/.codex/tmp/ledgerforge-s98-01a0afcf/native-backup-20260920-r1/LedgerForge-2026-09-20T08-02-57Z-FD8166D7.ledgerforgebackup", isDirectory: true)
        guard environment["LEDGERFORGE_S98_ADOPTION_CANDIDATE"] == "1",
              environment["LEDGERFORGE_S98_ADOPTION_CANDIDATE_DIRECTORY"] == namespace.path,
              !BackupFiles.exists(namespace), !BackupFiles.exists(destination) else {
            throw CampaignError.missingEnvironment
        }

        let manifest = try BackupFiles.verifyPackage(backup)
        guard manifest.database.sha256 == "59d233f650b2ffd3b4b8ce2cc29d89e281ac99cd6108d344fb6067336f9a6f78" else {
            throw CampaignError.sourceUnavailable
        }
        let inboxDatabase = SQLiteDatabase(path: backup.appendingPathComponent("ledger.sqlite").path)
        try inboxDatabase.open(access: .readOnlySnapshot)
        defer { inboxDatabase.close() }
        let inboxRepository = SQLiteGmailInboxRepository(database: inboxDatabase)
        let account = try soleCampaignAccount(in: inboxRepository)
        let inbox = try inboxRepository.load(account: account)
        guard inbox.activeScan == nil, inbox.orderedSources.count == 416, inbox.messages.count == 557,
              inbox.completedThrough == Date(timeIntervalSinceReferenceDate: 811_522_549.616777) else {
            throw CampaignError.sourceUnavailable
        }
        let originals = try Dictionary(uniqueKeysWithValues: inbox.orderedSources.map { source in
            let sha = try #require(source.sha256)
            return (sha, try inboxRepository.original(sha256: sha, byteCount: source.expectedByteCount))
        })
        guard originals.count == 416 else { throw CampaignError.sourceUnavailable }

        let oracleCohort = try await completeQualifiedHistoricalCases()
        let sourceBySHA = Dictionary(uniqueKeysWithValues: try inbox.orderedSources.map { source in
            (try #require(source.sha256), source)
        })
        let cohort = try oracleCohort.map { candidate -> SourceCase in
            let sha = try #require(candidate.source.sha256)
            guard let source = sourceBySHA[sha], source.importURL == candidate.source.importURL,
                  let bytes = originals[sha], bytes == candidate.bytes else {
                throw CampaignError.sourceMismatch
            }
            var replacement = SourceCase(source: source, bytes: bytes, password: candidate.password, compare: candidate.compare)
            replacement.bankBalanceObservation = candidate.bankBalanceObservation
            replacement.configure = candidate.configure
            replacement.verifyStored = candidate.verifyStored
            replacement.permitsUnresolvedInstrumentHold = candidate.permitsUnresolvedInstrumentHold
            replacement.expectedPreparationHold = candidate.expectedPreparationHold
            replacement.expectedHoldLayout = candidate.expectedHoldLayout
            replacement.relationshipBalanceObservations = candidate.relationshipBalanceObservations
            return replacement
        }
        guard cohort.count == 416, cohort.map(\.source.id) == inbox.orderedSources.map(\.id) else {
            throw CampaignError.sourceMismatch
        }
        _ = try await runCompleteHistoricalCohort(cohort, preparationLimit: 2,
            nativeSnapshot: destination, inboxSeed: .init(state: inbox, originals: originals),
            sourceBackedAccountNames: true)
        print("GMAIL_ADOPTION_CANDIDATE_READY originals=416 receipts=557 coverage_through=2026-09-19T14:55:49.616777Z; committed and held attention recorded through the ordinary inbox repository.")
    }

    @Test(.globalRuntimeStateIsolation)
    func prepareIsolatedNativeResponsivenessInbox() async throws {
        try await prepareNativeInbox(prefixCount: nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func prepareIsolatedNativeTimingPrefix() async throws {
        guard let value = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_NATIVE_PREFIX_COUNT"],
              let count = Int(value), count > 0 else { throw CampaignError.missingEnvironment }
        try await prepareNativeInbox(prefixCount: count)
    }

    @Test(.globalRuntimeStateIsolation)
    func prepareIsolatedBackgroundQualificationInbox() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let historyPath = environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"],
              let targetPath = environment["LEDGERFORGE_BACKGROUND_QUALIFICATION_DIRECTORY"] else {
            throw CampaignError.missingEnvironment
        }
        let target = URL(fileURLWithPath: targetPath).standardizedFileURL.resolvingSymlinksInPath()
        guard target.lastPathComponent.hasPrefix("s98-background-live-"),
              target.deletingLastPathComponent().lastPathComponent == "Namespaces",
              target.path.contains("/LedgerForge/Development/Namespaces/"),
              FileManager.default.fileExists(atPath: target.appendingPathComponent("ledgerforge-development.sqlite").path) else {
            throw CampaignError.sourceUnavailable
        }
        // The native restore flow already installed the genuine qualified
        // portfolio backup here. Add only the retained original inbox through
        // its ordinary repository; never manufacture financial inputs/coverage.
        let destination = try SQLiteRepositoryProvider(path: target.appendingPathComponent("ledgerforge-development.sqlite").path,
            migrations: allMigrations, access: .existing)
        defer { destination.database.close() }
        try BackupCompatibility.verifyDatabase(destination.database)
        try #require(destination.gmailInboxRepo.storedAccounts().isEmpty)
        let before = try destination.investmentRepo.snapshot(workspaceID: "default-workspace")
        let history = SQLiteDatabase(path: URL(fileURLWithPath: historyPath).appendingPathComponent("acquisition.sqlite").path)
        try history.open(access: .readOnlySnapshot)
        defer { history.close() }
        let repository = SQLiteGmailInboxRepository(database: history)
        var state = try repository.load(account: soleCampaignAccount(in: repository))
        try #require(state.activeScan == nil && !state.completedIntervals.isEmpty)
        let originals = try Dictionary(uniqueKeysWithValues: state.orderedSources.map { source in
            let sha = try #require(source.sha256)
            return (sha, try repository.original(sha256: sha, byteCount: source.expectedByteCount))
        })
        try #require(originals.count == 416)
        // Only this new repository's compare-and-swap revision changes; retain
        // authentic sender choices, receipt coverage, attention and timestamps.
        state.revision = 0
        let saved = try destination.gmailInboxRepo.save(state, originals: originals, expectedRevision: 0)
        state.revision = saved.revision
        let exactStateRetained = try destination.gmailInboxRepo.load(account: state.account) == state
        let financialStateUnchanged = try destination.investmentRepo.snapshot(workspaceID: "default-workspace") == before
        #expect(exactStateRetained && financialStateUnchanged)
        for source in state.orderedSources {
            let sha = try #require(source.sha256)
            let exactBytesRetained = try destination.gmailInboxRepo.original(sha256: sha, byteCount: source.expectedByteCount) == originals[sha]
            #expect(exactBytesRetained)
        }
        try BackupCompatibility.verifyDatabase(destination.database)
        try destination.database.checkpointAndClose()
        print("BACKGROUND_NATIVE_INBOX_READY originals=\(originals.count) receipts=\(state.messages.count); retained history, no network or financial import.")
    }

    @Test(.globalRuntimeStateIsolation)
    func prepareFinalNativeCacheReuseCheckpoint() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let templatePath = environment["LEDGERFORGE_GMAIL_NATIVE_TEMPLATE_DIRECTORY"],
              let destinationPath = environment["LEDGERFORGE_GMAIL_NATIVE_REVIEW_DIRECTORY"] else {
            throw CampaignError.missingEnvironment
        }
        let template = URL(fileURLWithPath: templatePath).standardizedFileURL
        let destination = URL(fileURLWithPath: destinationPath).standardizedFileURL
        guard template.path.contains("/LedgerForge/Development/Namespaces/s98-gmail-native-"),
              destination.path.contains("/LedgerForge/Development/Namespaces/s98-gmail-native-"),
              template != destination, !FileManager.default.fileExists(atPath: destination.path) else {
            throw CampaignError.sourceUnavailable
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let name = "ledgerforge-development.sqlite"
        let source = SQLiteDatabase(path: template.appendingPathComponent(name).path)
        try source.open(access: .readOnlySnapshot)
        defer { source.close() }
        try source.createBackup(at: destination.appendingPathComponent(name).path)
        let sqlite = try SQLiteRepositoryProvider(path: destination.appendingPathComponent(name).path)
        defer { sqlite.database.close() }
        var state = try sqlite.gmailInboxRepo.load(account: soleCampaignAccount(in: sqlite.gmailInboxRepo))
        guard state.activeScan == nil, !state.sources.isEmpty else { throw CampaignError.sourceUnavailable }
        let formatter = ISO8601DateFormatter()
        // The final native measurement reuses the exact initial authorized
        // interval and a populated qualification snapshot. The authoritative
        // historical inbox and the template ledger are never written here.
        let initialFrom: Date = try #require(formatter.date(from: "2026-08-01T00:00:00Z"))
        state.activeScan = GmailInboxScan(interval: try .init(
            from: initialFrom,
            until: #require(formatter.date(from: "2026-09-17T11:13:18Z")),
            timeZoneIdentifier: "UTC", senders: Set(state.configuredSenders.map(\.address))))
        _ = try sqlite.gmailInboxRepo.save(state, originals: [:], expectedRevision: state.revision)
        try BackupCompatibility.verifyDatabase(sqlite.database)
        try sqlite.database.checkpointAndClose()
        print("GMAIL_FINAL_NATIVE_CHECKPOINT_READY originals=\(state.sources.count); existing qualification ledger preserved, exact initial interval pending.")
    }

    private func prepareNativeInbox(prefixCount: Int?) async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let destinationPath = environment["LEDGERFORGE_GMAIL_NATIVE_REVIEW_DIRECTORY"],
              let historyPath = environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"] else { throw CampaignError.missingEnvironment }
        let destination = URL(fileURLWithPath: destinationPath).standardizedFileURL
        guard destination.path.contains("/LedgerForge/Development/Namespaces/s98-gmail-native-"),
              !FileManager.default.fileExists(atPath: destination.path) else { throw CampaignError.sourceUnavailable }
        let cohort = try await completeQualifiedHistoricalCases()
        let selectedCohort = cohort.filter {
            [.amex, .axisCard, .cbqCard, .cbqBank, .salary].contains($0.source.family)
        }
        let selection = Set(selectedCohort.map(\.source.id))
        guard !selection.isEmpty else { throw CampaignError.sourceUnavailable }
        if let prefixCount {
            guard prefixCount < selectedCohort.count else { throw CampaignError.unsupportedSelection }
            _ = try await runCompleteHistoricalCohort(Array(selectedCohort.prefix(prefixCount)), preparationLimit: 1,
                nativeSnapshot: destination.appendingPathComponent("ledgerforge-development.sqlite"))
        }
        let history = SQLiteDatabase(path: URL(fileURLWithPath: historyPath).appendingPathComponent("acquisition.sqlite").path)
        try history.open(access: .readOnlySnapshot)
        defer { history.close() }
        let repository = SQLiteGmailInboxRepository(database: history)
        var state = try repository.load(account: try #require(cohort.first).source.account)
        guard state.activeScan == nil, !state.completedIntervals.isEmpty else { throw CampaignError.sourceUnavailable }
        state.revision = 0
        state.senderRules = state.configuredSenders.map { .init(address: $0.address, isSelected: true) }
        let retained = state.orderedSources
        let originals = try Dictionary(uniqueKeysWithValues: retained.map { source in
            let sha = try #require(source.sha256)
            return (sha, try repository.original(sha256: sha, byteCount: source.expectedByteCount))
        })
        for source in retained {
            // This is an explicit selection in a fresh native qualification
            // namespace. The authoritative history inbox is read-only.
            state.sources[source.id]?.dismissed = !selection.contains(source.id)
            if selection.contains(source.id) { state.sources[source.id]?.attention = .pending }
        }
        let formatter = ISO8601DateFormatter()
        let lower = try #require(formatter.date(from: "2026-08-01T00:00:00Z"))
        let upper = try #require(formatter.date(from: "2026-09-17T11:13:18Z"))
        // Native Resume exercises the already-authorized fixed initial interval
        // with cached bytes. It neither changes the historical campaign window
        // nor fabricates coverage, and it performs no financial import.
        state.activeScan = GmailInboxScan(interval: try .init(from: lower, until: upper,
            timeZoneIdentifier: "UTC", senders: Set(state.configuredSenders.map(\.address))))
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let sqlite = try SQLiteRepositoryProvider(path: destination.appendingPathComponent("ledgerforge-development.sqlite").path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        state.revision = try provider.gmailInboxRepo.load(account: state.account).revision
        let saved = try provider.gmailInboxRepo.save(state, originals: originals, expectedRevision: state.revision)
        let hydrated = try GmailQualificationStores().hydrator(provider).stageHydration()
        guard hydrated.importSessions.count == (prefixCount ?? 0), hydrated.investments == .empty,
              Set(saved.sources.values.filter { !$0.dismissed }.map(\.id)) == selection else { throw CampaignError.sourceMismatch }
        if prefixCount == nil {
            guard hydrated.transactions.isEmpty, hydrated.accounts.isEmpty, hydrated.salaryStatements.isEmpty else {
                throw CampaignError.sourceMismatch
            }
        }
        try BackupCompatibility.verifyDatabase(sqlite.database)
        try sqlite.database.checkpointAndClose()
        print("GMAIL_NATIVE_INBOX_READY originals=\(retained.count) selected=\(selection.count) qualified_prefix=\(prefixCount ?? 0) transactions=\(hydrated.transactions.count); fixed initial UTC interval retained for cache-reuse collection.")
    }

    // Keep every per-prefix comparison for both runs, using the exact published
    // snapshot instead of repeating repository staging after each commit.
    // The expanded 416-source corpus takes about 16 minutes per complete pass;
    // allow both passes and their independent reopen checks to finish.
    @Test(.globalRuntimeStateIsolation, .timeLimit(.minutes(45)))
    func fullQualifiedHistoricalCohortMatchesOneAndTwoPreparationSlots() async throws {
        let cohort = try await completeQualifiedHistoricalCases()
        let serial = try await runCompleteHistoricalCohort(cohort, preparationLimit: 1)
        let dual = try await runCompleteHistoricalCohort(cohort, preparationLimit: 2)
        guard serial == dual else { throw CampaignError.sourceMismatch }
        print("Gmail FULL_COHORT_EQUIVALENCE_PASS sources=\(cohort.count) slots=1,2; prepared fields, mapping outcomes, per-commit graphs, hydration and reopen equal.")
    }

    private func runCompleteHistoricalCohort(_ cohort: [SourceCase], preparationLimit: Int,
        nativeSnapshot: URL? = nil, inboxSeed: CohortInboxSeed? = nil,
        sourceBackedAccountNames: Bool = false) async throws -> [[String]] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Gmail-Full-Cohort-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("qualification.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        var inbox: GmailInboxState
        let bytes: [String: Data]
        if let inboxSeed {
            inbox = inboxSeed.state
            inbox.revision = 0
            bytes = inboxSeed.originals
            guard inbox.orderedSources.map(\.id) == cohort.map(\.source.id),
                  inbox.orderedSources.allSatisfy({ source in
                      guard let sha = source.sha256,
                            let original = cohort.first(where: { $0.source.id == source.id }) else { return false }
                      return original.source == source && bytes[sha] == original.bytes
                  }) else { throw CampaignError.sourceMismatch }
        } else {
            inbox = GmailInboxState(account: try #require(cohort.first).source.account)
            var collected: [String: Data] = [:]
            for original in cohort {
                let sha = try #require(original.source.sha256)
                inbox.sources[original.source.id] = original.source
                collected[sha] = original.bytes
            }
            bytes = collected
        }
        inbox = try provider.gmailInboxRepo.save(inbox, originals: bytes, expectedRevision: 0)
        guard inbox.orderedSources.map(\.id) == cohort.map(\.source.id) else { throw CampaignError.sourceMismatch }
        let stores = GmailQualificationStores(), observer = BoundedCohortObserver()
        let hydrator = stores.hydrator(provider)
        let byURL = try Dictionary(uniqueKeysWithValues: cohort.map { (try #require($0.source.importURL), $0) })
        let passwords = byURL.mapValues(\.password)
        let passwordHeldURLs = Set(byURL.filter { $0.value.expectedPreparationHold == "SUPPORTED_BUT_HELD_PASSWORD" }.keys)
        let passwordProvider = DefaultPasswordProvider(credentialStore: InMemoryStatementPasswordCredentialStore(),
            supportedInstitutionCodes: [], challenge: { request in await MainActor.run {
                if passwordHeldURLs.contains(request.fileURL) { return nil }
                return passwords[request.fileURL]
            } })
        let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwordProvider),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: {
                let started = Date()
                defer { observer.hydrationMilliseconds += Int(Date().timeIntervalSince(started) * 1_000) }
                let commit = try #require(observer.activeCommitIdentity)
                guard observer.publishedHydration == nil, observer.verificationFailure == nil,
                      commit.generation == provider.generationToken else { throw CampaignError.sourceMismatch }
                var captureError: (any Error)?
                do {
                    let result = try hydrator.hydrateIfNeeded(forceRefresh: true) { snapshot in
                        do {
                            guard observer.activeCommitIdentity == commit,
                                  observer.publishedHydration == nil,
                                  snapshot.providerGeneration == commit.generation else { throw CampaignError.sourceMismatch }
                            observer.publishedHydration = CohortPublishedHydration(commit: commit,
                                snapshot: snapshot, changeCounter: try sqlite.database.totalChangeCounter())
                        } catch { captureError = error }
                    }
                    if let captureError { throw captureError }
                    guard observer.publishedHydration != nil else { throw CampaignError.sourceMismatch }
                    return result
                } catch {
                    observer.publishedHydration = nil
                    throw error
                }
            }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
        var accountOrdinals: [String: Int] = [:]
        var instrumentOrdinals: [String: Int] = [:]
        var axisLiabilityAccountID: String?
        // Retain the accepted QAR Amex campaign's explicit account choice,
        // while keeping the newly selected USD account in its native currency.
        var amexLiabilityAccountIDs: [String: String] = [:]
        var cbqLiabilityAccountIDs: [String: String] = [:]
        func cbqLiabilityKey(_ document: FinancialDocument) throws -> String {
            guard document.metadata.institution == .cbq,
                  let evidence = document.cardStatementEvidence,
                  evidence.accountSourceIdentityObservations.count == 1,
                  let observation = evidence.accountSourceIdentityObservations.first else {
                throw CampaignError.sourceMismatch
            }
            return self.cohortFields([evidence.nativeCurrency.code,
                observation.kind.rawValue, observation.value])
        }
        var expectedBankBalances: [String: [(date: String, balance: Decimal, zeroActivity: Bool)]] = [:]
        var priorCanonicalTransactions: [String: TransactionDTO] = [:]
        var latestValidatedGraph: [String]?
        func newAccountChoice(for prepared: PreparedImport, cardLiability: Bool,
                              legacyDisplayName: String = "Gmail cohort qualification") throws -> ImportAccountChoice {
            let displayName: String
            if sourceBackedAccountNames {
                displayName = ImportPersistenceMapper.displayAccountName(
                    institutionName: prepared.importSession.institution?.rawValue ?? "Unknown",
                    documentType: prepared.importSession.documentType,
                    currency: prepared.financialDocument.bookedCurrency?.code,
                    fallbackFileName: prepared.importSession.fileName
                )
            } else {
                displayName = legacyDisplayName
            }
            return cardLiability
                ? .createNewCardLiabilityAccountAndInstrument(displayName: displayName)
                : .createNewAccount(displayName: displayName)
        }
        func selectedRelationshipChoices(for review: ImportIdentityReview) throws -> ImportAccountChoice? {
            guard sourceBackedAccountNames else { return try relationshipChoices(review) }
            guard case .bankSections(let sections) = review else { throw CampaignError.sourceMismatch }
            var choices: [String: ImportBankSectionChoice] = [:]
            for section in sections {
                switch section.identityReview {
                case .matchedExisting: break
                case .choiceRequired:
                    let label = section.sourceAccountLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !label.isEmpty else { throw CampaignError.sourceMismatch }
                    choices[section.sectionID] = .createNewAccount(displayName: label)
                default: throw CampaignError.sourceMismatch
                }
            }
            return choices.isEmpty ? nil : .bankSections(choices)
        }
        let coordinator = observedProductionCoordinator(engine: engine, originalsByURL: byURL, observer: observer) { prepared, result in
            let source = try #require(byURL[prepared.sourceURL])
            let sha = try #require(source.source.sha256)
            if source.source.family == .axisCard, result.persisted {
                let accountID = try #require(result.accountId)
                if let prior = axisLiabilityAccountID, prior != accountID { throw CampaignError.sourceMismatch }
                axisLiabilityAccountID = accountID
            }
            if source.source.family == .amex, result.persisted {
                let accountID = try #require(result.accountId)
                let currency = try #require(prepared.financialDocument.bookedCurrency?.code)
                if let prior = amexLiabilityAccountIDs[currency], prior != accountID { throw CampaignError.sourceMismatch }
                guard amexLiabilityAccountIDs.allSatisfy({ $0.key == currency || $0.value != accountID }) else {
                    throw CampaignError.sourceMismatch
                }
                amexLiabilityAccountIDs[currency] = accountID
            }
            if source.source.family == .cbqCard, result.persisted {
                let accountID = try #require(result.accountId)
                let key = try cbqLiabilityKey(prepared.financialDocument)
                if let prior = cbqLiabilityAccountIDs[key], prior != accountID { throw CampaignError.sourceMismatch }
                guard cbqLiabilityAccountIDs.allSatisfy({ $0.key == key || $0.value != accountID }) else {
                    throw CampaignError.sourceMismatch
                }
                cbqLiabilityAccountIDs[key] = accountID
            }
            let sessionID = result.previousImport?.importSessionId ?? prepared.importSession.id.uuidString
            guard result.persisted || result.previousImport != nil else {
                print("GMAIL_COHORT_ATTENTION \(sha) persisted=false previous=false account=\(result.accountOutcome) recovery=\(result.recoveryRoute)")
                throw CampaignError.commitFailed
            }
            let snapshot: RepositoryRuntimeSnapshot
            if result.persisted, result.hydrationOutcome == .committedAndHydrated {
                let captured = try #require(observer.publishedHydration)
                observer.publishedHydration = nil
                let expectedCommit = CohortCommitIdentity(preparationID: prepared.id, sourceSHA: sha,
                    sessionID: sessionID, generation: provider.generationToken)
                guard captured.commit == expectedCommit,
                      observer.activeCommitIdentity == expectedCommit,
                      captured.snapshot.providerGeneration == provider.generationToken,
                      captured.snapshot.importSessions.contains(where: { $0.id == sessionID }),
                      try sqlite.database.totalChangeCounter() == captured.changeCounter else { throw CampaignError.sourceMismatch }
                snapshot = captured.snapshot
            } else {
                guard observer.publishedHydration == nil else { throw CampaignError.sourceMismatch }
                let stagedHydrationStarted = Date()
                snapshot = try hydrator.stageHydration()
                observer.verificationStageHydrationMilliseconds += Int(Date().timeIntervalSince(stagedHydrationStarted) * 1_000)
            }
            let sourceAndIdentityStarted = Date()
            let changeCounter = try sqlite.database.totalChangeCounter()
            let durable = try self.cohortDurableSnapshot(provider)
            let canonical = Dictionary(uniqueKeysWithValues: durable.transactions.map { ($0.id, $0) })
            guard priorCanonicalTransactions.allSatisfy({ canonical[$0.key] == $0.value }) else { throw CampaignError.sourceMismatch }
            priorCanonicalTransactions = canonical
            if let observation = source.bankBalanceObservation, let accountID = result.accountId, result.persisted {
                expectedBankBalances[accountID, default: []].append((observation.date.canonical, observation.balance, observation.zeroActivity))
            }
            if !source.relationshipBalanceObservations.isEmpty, result.persisted {
                for section in durable.bankSections.sections where section.importSessionId == prepared.importSession.id.uuidString {
                    for observation in source.relationshipBalanceObservations where observation.ordinal == section.sectionOrdinal {
                        expectedBankBalances[section.accountId, default: []].append((observation.date, observation.balance, observation.zeroActivity))
                    }
                }
            }
            try self.verifyCohortBankBalances(snapshot, expected: expectedBankBalances)
            if let verify = source.verifyStored {
                try verify(provider, snapshot, prepared, sessionID)
            } else {
                let actual = snapshot.transactions.filter { $0.repositoryImportSessionId == sessionID }
                guard self.rowProjection(actual) == self.rowProjection(prepared.financialDocument.transactions) else {
                    print("GMAIL_COHORT_ATTENTION \(sha) transaction-source-association requires-review")
                    throw CampaignError.sourceMismatch
                }
                try self.verifyCardEvidence(provider, prepared: prepared, sessionID: sessionID, loaded: durable)
                try self.verifyBankSectionEvidence(provider, prepared: prepared, loaded: durable.bankSections)
            }
            observer.postCommitSourceAndIdentityMilliseconds += Int(Date().timeIntervalSince(sourceAndIdentityStarted) * 1_000)
            observer.graphBySource[sha] = try self.completeCohortGraph(provider: provider, database: sqlite.database,
                snapshot: snapshot, observer: observer, accountOrdinals: &accountOrdinals, instrumentOrdinals: &instrumentOrdinals,
                loaded: durable)
            guard try sqlite.database.totalChangeCounter() == changeCounter else { throw CampaignError.sourceMismatch }
            latestValidatedGraph = observer.graphBySource[sha]
        }
        defer { coordinator.cancelBatch() }
        let started = Date()
        print("GMAIL_COHORT_RUN_BEGIN slots=\(preparationLimit) sources=\(cohort.count)")
        guard coordinator.startConfirmedBatch(try cohort.map { try #require($0.source.importURL) }, preparationLimit: preparationLimit) else {
            throw CampaignError.commitFailed
        }
        // A sleeping Mac makes no qualification progress. Retain the same
        // execution allowance without treating sleep as a failed commit.
        let executionClock = SuspendingClock()
        let deadline = executionClock.now.advanced(by: .seconds(max(120, cohort.count * 10)))
        while !coordinator.hasTerminalOutcomesForEntireBatch {
            if let failure = observer.verificationFailure { throw failure }
            if let item = coordinator.currentItem, item.phase == .failed || item.phase == .validationFailed,
               let original = byURL[item.sourceURL], let sha = original.source.sha256,
               original.expectedPreparationHold != nil {
                guard observer.heldPreparationBySource[sha] != nil else { throw CampaignError.sourceMismatch }
                if coordinator.permitsContinue {
                    let before = try sqlite.database.totalChangeCounter()
                    let sessionsBefore = try sqlite.database.queryInt("SELECT count(*) FROM import_sessions;")
                    guard try provider.gmailInboxRepo.original(sha256: sha, byteCount: original.bytes.count) == original.bytes,
                          coordinator.continueAfterCurrent() else { throw CampaignError.sourceMismatch }
                    guard try sqlite.database.totalChangeCounter() == before,
                          try sqlite.database.queryInt("SELECT count(*) FROM import_sessions;") == sessionsBefore else {
                        throw CampaignError.sourceMismatch
                    }
                    print("GMAIL_COHORT_SOURCE_HELD slots=\(preparationLimit) sha=\(sha) disposition=\(original.expectedPreparationHold!) graph_unchanged=true original_retained=true")
                    continue
                }
            }
            if let item = coordinator.currentItem, item.phase == .awaitingConfirmation {
                let sourceCase = try #require(byURL[item.sourceURL])
                let sourceSHA = try #require(sourceCase.source.sha256)
                if sourceCase.permitsUnresolvedInstrumentHold,
                   let prepared = observer.preparedValuesBySource[sourceSHA],
                   let review = prepared.investmentReview, !review.mappingQuestions.isEmpty {
                    guard prepared.validation.passed, prepared.investmentConfirmationBlocked,
                          review.mappingQuestions.allSatisfy({ $0.kind == .instrument }),
                          sourceCase.source.family == .cbqInvestment else { throw CampaignError.sourceMismatch }
                    if latestValidatedGraph == nil {
                        latestValidatedGraph = try completeCohortGraph(provider: provider, database: sqlite.database,
                            snapshot: hydrator.stageHydration(), observer: observer,
                            accountOrdinals: &accountOrdinals, instrumentOrdinals: &instrumentOrdinals)
                    }
                    let beforeChanges = try sqlite.database.totalChangeCounter()
                    let beforeSessions = try sqlite.database.queryInt("SELECT count(*) FROM import_sessions;")
                    let beforeAttempts = try provider.importSessionRepo.importAttempts(workspaceId: "default-workspace")
                    coordinator.skipCurrent()
                    let afterSessions = try sqlite.database.queryInt("SELECT count(*) FROM import_sessions;")
                    let afterAttempts = try provider.importSessionRepo.importAttempts(workspaceId: "default-workspace")
                    guard try sqlite.database.totalChangeCounter() == beforeChanges,
                          beforeSessions == afterSessions, beforeAttempts == afterAttempts,
                          observer.resultBySource[sourceSHA] == nil else { throw CampaignError.sourceMismatch }
                    observer.heldMappingBySource[sourceSHA] = review.mappingQuestions.map {
                        self.cohortFields([String(describing: $0.kind), $0.scopeKey, String($0.candidates.count)])
                    }.sorted()
                    guard let heldGraph = latestValidatedGraph else { throw CampaignError.sourceMismatch }
                    observer.graphBySource[sourceSHA] = heldGraph
                    print("GMAIL_COHORT_MAPPING_HELD slots=\(preparationLimit) sha=\(sourceSHA) questions=\(review.mappingQuestions.count) financial_graph_unchanged=true")
                    continue
                }
                if item.accountChoice == nil {
                    switch item.identityReview {
                    case .cardChoiceRequired(let eligible, _):
                        let source = try #require(byURL[item.sourceURL])
                        let sha = try #require(source.source.sha256)
                        let prepared = try #require(observer.preparedValuesBySource[sha])
                        let currency = try #require(prepared.financialDocument.bookedCurrency?.code)
                        if source.source.family == .amex, let accountID = amexLiabilityAccountIDs[currency] {
                            guard eligible.contains(accountID) else { throw CampaignError.sourceMismatch }
                            coordinator.updateAccountChoice(try AmericanExpressPrivateAcceptanceTests()
                                .gmailExistingLiabilityAccountChoice(document: prepared.financialDocument,
                                    accountID: accountID, provider: provider))
                        } else if source.source.family == .cbqCard,
                                  let accountID = cbqLiabilityAccountIDs[try cbqLiabilityKey(prepared.financialDocument)] {
                            guard eligible.contains(accountID) else { throw CampaignError.sourceMismatch }
                            coordinator.updateAccountChoice(try CBQCreditCardPrivateAcceptanceTests()
                                .gmailExistingLiabilityAccountChoice(document: prepared.financialDocument,
                                    accountID: accountID, provider: provider))
                        } else {
                            coordinator.updateAccountChoice(try newAccountChoice(for: prepared, cardLiability: true))
                        }
                    case .liabilityAccountChoiceRequired(let eligible):
                        // Preserve the accepted Axis corpus campaign's explicit
                        // one-liability-account choice; do not create a new
                        // account for every statement that lacks instruments.
                        let source = try #require(byURL[item.sourceURL])
                        guard source.source.family == .axisCard else { throw CampaignError.unsupportedSelection }
                        if let accountID = axisLiabilityAccountID {
                            guard eligible.contains(accountID) else { throw CampaignError.sourceMismatch }
                            coordinator.updateAccountChoice(.useExistingAccount(accountId: accountID))
                        } else {
                            let sha = try #require(source.source.sha256)
                            coordinator.updateAccountChoice(try newAccountChoice(
                                for: #require(observer.preparedValuesBySource[sha]), cardLiability: false,
                                legacyDisplayName: "Gmail Axis qualification"))
                        }
                    case .choiceRequired:
                        let sha = try #require(sourceCase.source.sha256)
                        coordinator.updateAccountChoice(try newAccountChoice(
                            for: #require(observer.preparedValuesBySource[sha]), cardLiability: false))
                    case .matchedExisting: break
                    case .unavailable:
                        if sourceCase.bankBalanceObservation != nil {
                            let sha = try #require(sourceCase.source.sha256)
                            coordinator.updateAccountChoice(try newAccountChoice(
                                for: #require(observer.preparedValuesBySource[sha]), cardLiability: false))
                        }
                    case .bankSections:
                        coordinator.updateAccountChoice(try selectedRelationshipChoices(for: item.identityReview))
                    case .ambiguous, .conflict:
                        print("GMAIL_COHORT_ATTENTION queue=\(item.queuePosition) new-identity-authority-required")
                        throw CampaignError.commitFailed
                    }
                }
                await coordinator.confirmCurrent()
            }
            if let failed = coordinator.items.first(where: {
                ($0.phase == .failed || $0.phase == .validationFailed) && byURL[$0.sourceURL]?.expectedPreparationHold == nil
            }) {
                let sha = byURL[failed.sourceURL]?.source.sha256 ?? "unknown"
                print("GMAIL_COHORT_ATTENTION \(sha) phase=\(failed.phase) family=\(String(describing: failed.preparationFailure?.family))")
                throw CampaignError.commitFailed
            }
            guard executionClock.now < deadline else {
                print("GMAIL_COHORT_DEADLINE_EXCEEDED slots=\(preparationLimit) completed=\(coordinator.terminalItems.count) total=\(cohort.count)")
                throw CampaignError.cohortDeadlineExceeded
            }
            try await Task.sleep(for: .milliseconds(2))
        }
        if let failure = observer.verificationFailure { throw failure }
        guard observer.activePreparations == 0, observer.activeCommits == 0,
              observer.peakActivePreparations <= preparationLimit, observer.peakConcurrentCommits <= 1,
              coordinator.items.count == cohort.count,
              coordinator.items.allSatisfy({ item in
                  if item.phase == .completed { return true }
                  if let sha = byURL[item.sourceURL]?.source.sha256,
                     observer.heldPreparationBySource[sha] != nil,
                     item.phase == .failed || item.phase == .validationFailed { return true }
                  guard item.phase == .skipped,
                        let sha = byURL[item.sourceURL]?.source.sha256 else { return false }
                  return observer.heldMappingBySource[sha] != nil
              }) else { throw CampaignError.commitFailed }
        if cohort.count == 416 {
            guard observer.heldMappingBySource.count == 24,
                  observer.heldPreparationBySource.count == cohort.filter({ $0.expectedPreparationHold != nil }).count,
                  observer.resultBySource.count + observer.heldMappingBySource.count + observer.heldPreparationBySource.count == cohort.count else {
                throw CampaignError.sourceMismatch
            }
        }
        let snapshot = try hydrator.stageHydration()
        let finalGraph = try completeCohortGraph(provider: provider, database: sqlite.database, snapshot: snapshot,
            observer: observer, accountOrdinals: &accountOrdinals, instrumentOrdinals: &instrumentOrdinals)
        let finalCanonical = Dictionary(uniqueKeysWithValues: try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").map { ($0.id, $0) })
        guard finalCanonical == priorCanonicalTransactions else { throw CampaignError.sourceMismatch }
        if inboxSeed != nil {
            try await replayOneCommittedSourcePerFamily(engine: engine, provider: provider, database: sqlite.database,
                cohort: cohort, observer: observer)
            inbox = try persistCohortTerminalAttention(provider: provider, coordinator: coordinator,
                originalsByURL: byURL, observer: observer)
        }
        let acceptedSessions = Set(try observer.resultBySource.compactMap { sha, result -> String? in
            if result.persisted {
                guard let sessionID = observer.sessionBySource[sha] else { throw CampaignError.sourceMismatch }
                return sessionID
            }
            return result.previousImport?.importSessionId
        })
        let storedSessions = Set(try sqlite.database.query(sql: "SELECT id FROM import_sessions;") { try #require($0.string(at: 0)) })
        guard storedSessions == acceptedSessions else { throw CampaignError.sourceMismatch }
        for original in cohort {
            let sha = try #require(original.source.sha256)
            guard try provider.gmailInboxRepo.original(sha256: sha, byteCount: original.bytes.count) == original.bytes else {
                throw CampaignError.sourceMismatch
            }
            if original.expectedPreparationHold != nil {
                guard observer.heldPreparationBySource[sha] != nil, observer.resultBySource[sha] == nil else { throw CampaignError.sourceMismatch }
                if let session = observer.sessionBySource[sha] {
                    guard try provider.importSessionRepo.importSession(id: session) == nil,
                          !snapshot.transactions.contains(where: { $0.repositoryImportSessionId == session }),
                          !snapshot.importSessions.contains(where: { $0.id == session }) else { throw CampaignError.sourceMismatch }
                }
            }
        }
        let durableSalary = try provider.salaryRepo.snapshot(workspaceId: "default-workspace")
        let durableInvestment = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
        let reopenedSnapshot = try GmailQualificationStores().hydrator(reopenedProvider).stageHydration()
        try verifyCohortBankBalances(reopenedSnapshot, expected: expectedBankBalances)
        let reopenedSalary = try reopenedProvider.salaryRepo.snapshot(workspaceId: "default-workspace")
        let reopenedInvestment = try reopenedProvider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let reopenedGraph = try completeCohortGraph(provider: reopenedProvider, database: reopened.database, snapshot: reopenedSnapshot,
            observer: observer, accountOrdinals: &accountOrdinals, instrumentOrdinals: &instrumentOrdinals)
        guard reopenedSalary == durableSalary,
              reopenedInvestment == durableInvestment,
              reopenedSnapshot.investments == durableInvestment,
              reopenedGraph == finalGraph else {
            throw CampaignError.sourceMismatch
        }
        for original in cohort {
            let sha = try #require(original.source.sha256)
            guard try reopenedProvider.gmailInboxRepo.original(sha256: sha, byteCount: original.bytes.count) == original.bytes else {
                throw CampaignError.sourceMismatch
            }
        }
        if inboxSeed != nil {
            guard try reopenedProvider.gmailInboxRepo.load(account: inbox.account) == inbox else {
                throw CampaignError.sourceMismatch
            }
        }
        try BackupCompatibility.verifyDatabase(reopened.database)
        if let nativeSnapshot {
            let path = nativeSnapshot.standardizedFileURL.path
            let isLegacyNativeReview = preparationLimit == 1
                && path.contains("/LedgerForge/Development/Namespaces/s98-gmail-native-")
            let isFinalAdoptionCandidate = inboxSeed != nil && preparationLimit == 2
                && path == "/Users/vyom/Library/Containers/com.vyom.LedgerForge/Data/Library/Application Support/LedgerForge/Development/Namespaces/s98-adoption-candidate-01a0b713/ledgerforge-development.sqlite"
            guard (isLegacyNativeReview || isFinalAdoptionCandidate), !BackupFiles.exists(nativeSnapshot) else {
                throw CampaignError.sourceUnavailable
            }
            try FileManager.default.createDirectory(at: nativeSnapshot.deletingLastPathComponent(), withIntermediateDirectories: true)
            try reopened.database.createBackup(at: nativeSnapshot.path)
        }
        let receiptSectionsByID = Dictionary(uniqueKeysWithValues: try reopenedProvider.importSessionRepo
            .bankSectionSnapshot(workspaceId: "default-workspace").sections.map { ($0.id, $0) })
        var output: [[String]] = []
        for original in cohort {
            let sha = try #require(original.source.sha256)
            if let held = observer.heldPreparationBySource[sha] {
                let item = try #require(coordinator.items.first { $0.sourceURL == original.source.importURL })
                guard item.phase == .failed || item.phase == .validationFailed else { throw CampaignError.sourceMismatch }
                output.append([cohortFields([sha, "expected-source-hold", cohortFields(held), "original-retained-no-financial-session"])])
                continue
            }
            let prepared = try #require(observer.semanticBySource[sha])
            let item = try #require(coordinator.items.first { $0.sourceURL == original.source.importURL })
            if let questions = observer.heldMappingBySource[sha] {
                guard item.phase == .skipped, observer.resultBySource[sha] == nil else { throw CampaignError.sourceMismatch }
                output += [prepared, [cohortFields([sha, "SUPPORTED_BUT_HELD_MAPPING", "no financial mutation", cohortFields(questions)])],
                    try #require(observer.graphBySource[sha])]
                continue
            }
            let result = try #require(observer.resultBySource[sha])
            let outcome = cohortFields([sha, String(describing: item.completionDisposition), String(result.persisted),
                String(describing: result.hydrationOutcome), String(result.previousImport != nil), String(result.isEquivalentSupportingSource),
                String(result.isPartialImport), String(result.isSalaryImport), String(result.isInvestmentImport),
                String(result.sourceRowCount ?? -1), String(result.recognizedExistingRowCount ?? -1),
                String(describing: result.accountOutcome), String(describing: result.recoveryRoute)])
            let sectionReceipts = try result.bankSections.map { receipt in
                let section = try #require(receiptSectionsByID[receipt.sectionID])
                guard section.importSessionId == observer.sessionBySource[sha] else { throw CampaignError.sourceMismatch }
                return try cohortFields([String(section.sectionOrdinal), String(#require(accountOrdinals[receipt.accountID])),
                    String(receipt.sourceRowCount), String(receipt.importedTransactionCount)])
            }
            output += [prepared, [outcome] + sectionReceipts, try #require(observer.graphBySource[sha])]
        }
        output.append(finalGraph)
        print("GMAIL_COHORT_DISPOSITIONS slots=\(preparationLimit) committed=\(observer.resultBySource.values.filter(\.persisted).count) mapping_held=\(observer.heldMappingBySource.count) source_held=\(observer.heldPreparationBySource.count) total=\(cohort.count)")
        print("GMAIL_COHORT_RUN_END slots=\(preparationLimit) sources=\(cohort.count) preparation_ms=\(observer.preparationMilliseconds) mapping_revalidation_ms=\(observer.mappingRevalidationMilliseconds) commit_ms=\(observer.commitMilliseconds) hydration_ms=\(observer.hydrationMilliseconds) verification_including_projection_and_staged_hydration_ms=\(observer.verificationMilliseconds) total_ms=\(Int(Date().timeIntervalSince(started) * 1_000)) active_source_byte_peak=\(observer.peakPreparationSourceBytes) workers_closed=\(observer.activePreparations == 0)")
        print("GMAIL_COHORT_VERIFICATION_COMPONENTS slots=\(preparationLimit) graph_projection_all_calls_ms=\(observer.graphProjectionMilliseconds) post_commit_staged_hydration_ms=\(observer.verificationStageHydrationMilliseconds) post_commit_source_identity_balance_checks_ms=\(observer.postCommitSourceAndIdentityMilliseconds); components overlap aggregate verification, graph includes final/reopen calls")
        for original in cohort {
            let sha = try #require(original.source.sha256)
            let lifetime = try #require(observer.preparationWorkerMilliseconds[sha])
            print("GMAIL_COHORT_WORKER_LIFETIME slots=\(preparationLimit) sha=\(sha) milliseconds=\(lifetime)")
        }
        return output
    }

    /// The final candidate has one ordinary duplicate replay per source family,
    /// selected only from actual committed sessions. It exercises the durable
    /// duplicate path without turning the one-off population into a second
    /// 416-source campaign.
    private func replayOneCommittedSourcePerFamily(
        engine: ImportEngine,
        provider: DatabaseProvider,
        database: SQLiteDatabase,
        cohort: [SourceCase],
        observer: BoundedCohortObserver
    ) async throws {
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let cards = try provider.cardRepo.snapshot(workspaceId: "default-workspace")
        let sections = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let investments = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let acceptedCount = try database.queryInt("SELECT count(*) FROM import_sessions;")
        var families: Set<GmailSourceFamily> = []
        let replaySources = try cohort.compactMap { original -> SourceCase? in
            let sha = try #require(original.source.sha256)
            guard let sessionID = observer.sessionBySource[sha], observer.resultBySource[sha]?.persisted == true,
                  try provider.importSessionRepo.importSession(id: sessionID) != nil,
                  families.insert(original.source.family).inserted else { return nil }
            return original
        }
        guard !replaySources.isEmpty else { throw CampaignError.sourceMismatch }
        for original in replaySources {
            let replay = try await engine.prepareImport(from: try #require(original.source.importURL))
            defer { engine.cancelPreparedImport(replay) }
            let result = await engine.commitPreparedImport(replay)
            guard result.previousImport != nil, !result.persisted else { throw CampaignError.sourceMismatch }
        }
        let unchanged = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace") == transactions
            && provider.cardRepo.snapshot(workspaceId: "default-workspace") == cards
            && provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace") == sections
            && provider.investmentRepo.snapshot(workspaceID: "default-workspace") == investments
            && database.queryInt("SELECT count(*) FROM import_sessions;") == acceptedCount
        guard unchanged else { throw CampaignError.sourceMismatch }
        print("GMAIL_ADOPTION_REPLAY families=\(replaySources.count) financial_unchanged=\(unchanged)")
    }

    /// The normal session owns this mapping in production. This isolated
    /// coordinator has no session observer, so the one-off candidate records
    /// the same terminal attention after every financial comparison has passed.
    private func persistCohortTerminalAttention(
        provider: DatabaseProvider,
        coordinator: ImportCentreCoordinator<PreparedImport>,
        originalsByURL: [URL: SourceCase],
        observer: BoundedCohortObserver
    ) throws -> GmailInboxState {
        let repository = provider.gmailInboxRepo
        let baseline = try repository.load(account: try soleCampaignAccount(in: repository))
        var next = baseline
        var seenSourceIDs: Set<String> = []
        for item in coordinator.items {
            let original = try #require(originalsByURL[item.sourceURL])
            let sha = try #require(original.source.sha256)
            guard seenSourceIDs.insert(original.source.id).inserted,
                  next.sources[original.source.id] == original.source else { throw CampaignError.sourceMismatch }
            let attention: GmailInboxSource.Attention
            switch item.phase {
            case .completed:
                attention = item.completionDisposition == .rejected || item.completionDisposition == .transactionEventBlocked
                    ? .review : .pending
            case .skipped:
                guard observer.heldMappingBySource[sha] != nil else { throw CampaignError.sourceMismatch }
                attention = .skipped
            case .validationFailed:
                guard original.expectedPreparationHold == "KNOWN_UNSUPPORTED_LAYOUT",
                      observer.heldPreparationBySource[sha] != nil else { throw CampaignError.sourceMismatch }
                attention = .invalid
            case .failed:
                guard let expected = original.expectedPreparationHold,
                      observer.heldPreparationBySource[sha] != nil else { throw CampaignError.sourceMismatch }
                switch item.preparationFailure?.family {
                case .unsupportedInput, .unsupportedStatement:
                    guard expected == "KNOWN_UNSUPPORTED_LAYOUT" else { throw CampaignError.sourceMismatch }
                    attention = .unsupported
                case .credentials:
                    guard expected == "SUPPORTED_BUT_HELD_PASSWORD" else { throw CampaignError.sourceMismatch }
                    attention = .password
                case .invalidDocument:
                    guard expected == "KNOWN_UNSUPPORTED_LAYOUT" else { throw CampaignError.sourceMismatch }
                    attention = .invalid
                default:
                    guard expected == "KNOWN_UNSUPPORTED_LAYOUT" else { throw CampaignError.sourceMismatch }
                    attention = .failed
                }
            case .pending, .preparing, .awaitingReview, .awaitingConfirmation, .committing, .cancelled:
                throw CampaignError.sourceMismatch
            }
            next.sources[original.source.id]?.attention = attention
        }
        guard seenSourceIDs == Set(next.sources.keys),
              next.activeScan == baseline.activeScan,
              next.completedIntervals == baseline.completedIntervals,
              next.messages == baseline.messages,
              next.senderRules == baseline.senderRules else { throw CampaignError.sourceMismatch }
        let saved = try repository.save(next, originals: [:], expectedRevision: baseline.revision)
        for (id, before) in baseline.sources {
            guard let actual = saved.sources[id] else { throw CampaignError.sourceMismatch }
            var expected = before
            expected.attention = next.sources[id]?.attention ?? before.attention
            guard actual == expected else { throw CampaignError.sourceMismatch }
        }
        guard saved.sources.values.filter({ $0.attention == .pending }).count == 333,
              saved.sources.values.filter({ $0.attention == .skipped }).count == 24,
              saved.sources.values.filter({ $0.attention == .password }).count == 8,
              saved.sources.values.filter({ $0.attention == .unsupported || $0.attention == .invalid || $0.attention == .failed }).count == 51 else {
            throw CampaignError.sourceMismatch
        }
        return saved
    }

    private func verifyCohortBankBalances(_ snapshot: RepositoryRuntimeSnapshot,
        expected: [String: [(date: String, balance: Decimal, zeroActivity: Bool)]]) throws {
        let positions = DashboardPositionProjection.make(accounts: snapshot.accounts,
            transactions: snapshot.transactions, cardSnapshot: snapshot.cardSnapshot).flatMap(\.banks)
        for account in snapshot.accounts {
            let id = try #require(account.repositoryAccountId)
            guard let candidates = expected[id], !candidates.isEmpty else { continue }
            let latest = candidates.filter { $0.date == candidates.map(\.date).max() }
            let amount: Decimal?, date: String?
            if let first = latest.first, latest.filter({ !$0.zeroActivity }).count <= 1,
               latest.allSatisfy({ $0.balance == first.balance }) {
                amount = first.balance; date = first.date
            } else { amount = nil; date = nil }
            let position = try #require(positions.first { $0.id == id })
            guard account.currentBalance == (amount ?? .zero), account.currentBalanceAsOfISO == date,
                  position.amount?.amount == amount, position.asOf?.canonical == date else { throw CampaignError.sourceMismatch }
        }
    }

    private struct CohortDurableSnapshot {
        let transactions: [TransactionDTO]
        let cards: CardRepositorySnapshotDTO
        let bankSections: BankSectionRepositorySnapshotDTO
    }

    private func cohortDurableSnapshot(_ provider: DatabaseProvider) throws -> CohortDurableSnapshot {
        .init(transactions: try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace"),
              cards: try provider.cardRepo.snapshot(workspaceId: "default-workspace"),
              bankSections: try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace"))
    }

    private func completeCohortGraph(provider: DatabaseProvider, database: SQLiteDatabase,
        snapshot: RepositoryRuntimeSnapshot, observer: BoundedCohortObserver,
        accountOrdinals: inout [String: Int], instrumentOrdinals: inout [String: Int],
        loaded: CohortDurableSnapshot? = nil) throws -> [String] {
        let projectionStarted = Date()
        defer { observer.graphProjectionMilliseconds += Int(Date().timeIntervalSince(projectionStarted) * 1_000) }
        let sourceBySession = Dictionary(uniqueKeysWithValues: observer.sessionBySource.map { ($0.value, $0.key) })
        func sessionKey(_ id: String) throws -> String { try #require(sourceBySession[id]) }
        var documentKeys: [String: String] = [:]
        func documentKey(_ id: String) throws -> String {
            if let key = documentKeys[id] { return key }
            let storedDocument = try provider.importSessionRepo.importedDocument(id: id)
            let document = try #require(storedDocument)
            let key = try cohortFields([sessionKey(document.importSessionId), document.workspaceId, document.filename,
                document.mimeType ?? "", String(document.sizeBytes ?? -1), document.legacyRawTextSHA256])
            documentKeys[id] = key
            return key
        }
        var result: [String] = []
        let normalized = try database.query(sql: "SELECT id,document_id,import_session_id,profile_id,profile_version FROM normalized_documents;") { row in
            (0..<5).compactMap { row.string(at: Int32($0)) }
        }
        var normalizedKeys: [String: String] = [:]
        for row in normalized {
            guard row.count == 5 else { throw CampaignError.sourceMismatch }
            let key = try cohortFields([documentKey(row[1]), sessionKey(row[2]), row[3], row[4]])
            normalizedKeys[row[0]] = key
            result.append("normalized" + key)
        }
        // Reuse only values read in this synchronous, serialized post-commit
        // observation. Never carry a durable snapshot across accepted commits.
        let durable = try loaded ?? cohortDurableSnapshot(provider)
        let transactions = durable.transactions
        guard Set(transactions.map(\.id)).count == transactions.count else { throw CampaignError.sourceMismatch }
        // Each persisted ID must resolve to exactly the same DTO as the former
        // per-row linear lookup. Index once so complete per-commit verification
        // does not copy the entire growing DTO list for every hydrated row.
        let transactionsByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        let cards = durable.cards
        let bankGraph = durable.bankSections
        let orderedSections = try bankGraph.sections.sorted {
            (try sessionKey($0.importSessionId), $0.sectionOrdinal) < (try sessionKey($1.importSessionId), $1.sectionOrdinal)
        }
        for section in orderedSections where accountOrdinals[section.accountId] == nil {
            accountOrdinals[section.accountId] = accountOrdinals.count
        }
        for section in orderedSections {
            let evidence = section.sourceEvidence
            let key = try cohortFields([sessionKey(section.importSessionId), String(section.sectionOrdinal)])
            result.append(try cohortFields(["bank-section", key, String(#require(accountOrdinals[section.accountId])),
                documentKey(section.documentId), #require(normalizedKeys[section.normalizedDocumentId]),
                section.parserProfileId, section.parserProfileVersion, section.nativeCurrency, section.productLabel,
                section.sourceRangeStart.map(String.init) ?? "nil", section.sourceRangeEnd.map(String.init) ?? "nil"]))
            result.append(cohortFields(["bank-statement", key, evidence.sourceFormatCode,
                evidence.statementBoundaryDateISO ?? "nil", evidence.statementStartDateISO ?? "nil", evidence.statementEndDateISO ?? "nil",
                evidence.openingBalanceMinor.map(String.init) ?? "nil", evidence.openingBalanceDecimal ?? "nil",
                evidence.closingBalanceMinor.map(String.init) ?? "nil", evidence.closingBalanceDecimal ?? "nil"]))
            result += section.identityPatterns.map { cohortFields(["bank-pattern", key, $0.kind, $0.pattern]) }
            if let details = section.sourceDetails {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                result.append(try cohortFields(["bank-controls", key, String(decoding: encoder.encode(details), as: UTF8.self)]))
            }
            for occurrence in section.rows {
                let row = occurrence.source
                let canonical = try #require(transactionsByID[row.incomingTransactionId])
                guard canonical.accountId == section.accountId else { throw CampaignError.sourceMismatch }
                let owner = try cohortFields([sessionKey(#require(canonical.importSessionId)),
                    documentKey(#require(canonical.documentId)), cohortFields(canonical.rawRows.map { String($0.sourceOrdinal ?? -1) })])
                result.append(cohortFields(["bank-occurrence", key, String(row.sourceOrdinal), owner,
                    row.normalizedRecordDigest, row.postingDateISO, row.sourceTransactionDateISO ?? "nil", occurrence.valueDateISO ?? "nil",
                    row.nativeCurrency, String(row.signedAmountMinor), row.signedAmountDecimal, row.direction,
                    String(row.runningBalanceMinor), row.runningBalanceDecimal, row.structuredReferenceDigest ?? "nil",
                    occurrence.literalNarration, occurrence.literalReference ?? "nil", occurrence.literalBalance]))
            }
        }
        // A genuine zero-activity card still owns a statement, account and
        // source observations even though it contributes no transaction rows.
        let sessions = Set(transactions.compactMap(\.importSessionId))
            .union(cards.statements.map(\.importSessionId))
        let bankSessions = Set(bankGraph.sections.map(\.importSessionId))
        for (session, _) in sourceBySession.sorted(by: { $0.value < $1.value }) where sessions.contains(session) && !bankSessions.contains(session) {
            result.append("relations" + (try durableRelationshipProjection(provider: provider, sessionID: session,
                accountOrdinals: &accountOrdinals, instrumentOrdinals: &instrumentOrdinals,
                loadedTransactions: transactions, loadedCards: cards)))
        }
        for row in snapshot.transactions {
            let provenance = try row.sourceProvenance.map {
                try cohortFields([#require(normalizedKeys[$0.normalizedDocumentID]), String($0.sourceOrdinal),
                    $0.normalizedRecordDigest, $0.parserProfileID, $0.parserProfileVersion])
            }.sorted()
            let transactionID = try #require(row.repositoryTransactionId)
            let storedTransaction = try #require(transactionsByID[transactionID])
            let accountID = try #require(storedTransaction.accountId)
            guard row.repositoryAccountId == accountID else { throw CampaignError.sourceMismatch }
            result.append(try cohortFields(["transaction", String(#require(accountOrdinals[accountID])),
                cohortFields(rowProjection([row])), cohortFields(provenance)]))
        }
        for account in try provider.accountRepo.accounts(workspaceId: "default-workspace") {
            result.append(try cohortFields(["account", String(#require(accountOrdinals[account.id])), account.workspaceId,
                account.name, account.institutionId ?? "", account.accountType ?? "", account.nativeCurrency, account.description ?? ""]))
            for identifier in try provider.accountRepo.identifiers(accountId: account.id, workspaceId: "default-workspace") {
                result.append(try cohortFields(["account-identifier", String(#require(accountOrdinals[account.id])),
                    identifier.scheme, identifier.identifier, identifier.strength, identifier.verificationState, identifier.provenance]))
            }
        }
        for account in snapshot.accounts {
            let id = try #require(account.repositoryAccountId)
            result.append(try cohortFields(["runtime-balance", String(#require(accountOrdinals[id])),
                cohortMoney(account.currentBalanceMoney), account.currentBalanceAsOfISO ?? "unresolved"]))
        }
        for session in snapshot.importSessions {
            for (accountID, history) in session.bankAccountHistory {
                result.append(try cohortFields(["bank-history", sessionKey(session.id), String(#require(accountOrdinals[accountID])),
                    String(history.sourceRowCount), String(history.importedTransactionCount), String(history.recognizedExistingRowCount), history.nativeCurrency]))
            }
        }
        try verifyBankAccountHistory(snapshot, graph: bankGraph)
        for salary in try provider.salaryRepo.snapshot(workspaceId: "default-workspace").statements {
            let published = try #require(snapshot.salaryStatements.first { $0.id == salary.id })
            guard published.documentID == salary.documentId, published.importSessionID == salary.importSessionId,
                  published.fingerprintDigest == salary.sourceFingerprintDigest,
                  salary.components.allSatisfy({ $0.salaryStatementId == salary.id }) else { throw CampaignError.sourceMismatch }
            result.append(try cohortFields(["salary", sessionKey(salary.importSessionId), documentKey(salary.documentId),
                #require(normalizedKeys[salary.normalizedDocumentId]), salary.workspaceId, salary.sourceFingerprintAlgorithm,
                salary.sourceFingerprintDigest, salary.sourceAuthorityCode, salary.parserProfileId, salary.parserProfileVersion,
                salary.financialPeriodISO, salary.printDateISO ?? "", salary.documentKindCode, salary.nativeCurrency,
                String(salary.printedEarningsMinor), salary.printedEarningsDecimal, String(salary.printedDeductionsMinor ?? -1),
                salary.printedDeductionsDecimal ?? "", String(salary.printedNetMinor), salary.printedNetDecimal,
                String(salary.printedPaymentMinor), salary.printedPaymentDecimal, cohortFields(cohortSalaryProjection(published.evidence))]))
            result += try salary.components.map {
                try cohortFields(["salary-component", sessionKey(salary.importSessionId), $0.sideCode, String($0.sourceOrdinal),
                    $0.sourceLabel, $0.amountCurrency, String($0.amountMinor), $0.amountDecimal])
            }
        }
        let investment = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        guard investment == snapshot.investments else { throw CampaignError.sourceMismatch }
        var containerKeys: [String: String] = [:]
        for container in investment.containers {
            let key = cohortFields([container.workspaceID, container.institution, container.identityKind, container.identity])
            guard !containerKeys.values.contains(key), container.zioSource == nil, container.lastZioAccount == nil else { throw CampaignError.sourceMismatch }
            containerKeys[container.id] = key
            result.append(try cohortFields(["investment-container", key, cohortFields(container.aliases), container.displayName,
                container.holdingsDate, String(container.completeAtHoldingsDate), documentKey(#require(container.documentID)),
                sessionKey(#require(container.importSessionID))]))
        }
        for holding in investment.holdings {
            guard holding.zioObservationID == nil, holding.zioFundCode == nil else { throw CampaignError.sourceMismatch }
            let normalizedDocumentID = try #require(holding.normalizedDocumentID)
            let normalizedKey = try #require(normalizedKeys[normalizedDocumentID])
            let mapping = holding.priceMapping.map {
                cohortFields([$0.provider, $0.code, $0.currency, $0.priceKind ?? "", $0.instrumentReference ?? "", $0.listing ?? "", $0.evidence ?? ""])
            } ?? "absent"
            result.append(try cohortFields(["investment-holding", #require(containerKeys[holding.containerID]), holding.instrumentIdentity,
                cohortFields(holding.sourceAliases), holding.displayName, holding.units.sourceText, NSDecimalNumber(decimal: holding.units.value).stringValue,
                holding.currency, holding.averageCost?.sourceText ?? "", holding.totalCost?.sourceText ?? "", holding.averageCostLabel ?? "",
                holding.totalCostLabel ?? "", holding.costCurrency ?? "", holding.holdingsDate, documentKey(#require(holding.documentID)),
                sessionKey(#require(holding.importSessionID)), normalizedKey,
                String(holding.sourceOrdinal), holding.parserProfile, holding.issueDate ?? "", holding.valuationDate ?? "", mapping]))
        }
        return result.sorted()
    }

    private func durableRelationshipProjection(
        provider: DatabaseProvider,
        sessionID: String,
        accountOrdinals: inout [String: Int],
        instrumentOrdinals: inout [String: Int],
        loadedTransactions: [TransactionDTO]? = nil,
        loadedCards: CardRepositorySnapshotDTO? = nil
    ) throws -> String {
        let allRows = try loadedTransactions ?? provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let rows = allRows.filter { $0.importSessionId == sessionID }
        let cards = try loadedCards ?? provider.cardRepo.snapshot(workspaceId: "default-workspace")
        let statements = cards.statements.filter { $0.importSessionId == sessionID }
        let documentIDs = Set(rows.compactMap(\.documentId)).union(statements.map(\.documentId))
        guard documentIDs.count == 1, let documentID = documentIDs.first,
              let session = try provider.importSessionRepo.importSession(id: sessionID),
              let document = try provider.importSessionRepo.importedDocument(id: documentID) else {
            throw CampaignError.sourceMismatch
        }
        let accountIDs = Set(rows.compactMap(\.accountId)).union(statements.map(\.liabilityAccountId))
        var accounts: [AccountDTO] = []
        for accountID in accountIDs {
            guard let account = try provider.accountRepo.account(id: accountID) else {
                throw CampaignError.sourceMismatch
            }
            accounts.append(account)
        }
        guard accounts.count == 1, let account = accounts.first, document.importSessionId == sessionID,
              rows.allSatisfy({ $0.importSessionId == sessionID && $0.documentId == documentID && $0.accountId == account.id }) else {
            throw CampaignError.sourceMismatch
        }
        guard statements.allSatisfy({ $0.documentId == documentID && $0.liabilityAccountId == account.id }) else {
            throw CampaignError.sourceMismatch
        }
        let statementIDs = Set(statements.map(\.id))
        let sections = cards.sections.filter { statementIDs.contains($0.cardStatementId) }
        let sectionIDs = Set(sections.map(\.id))
        if accountOrdinals[account.id] == nil { accountOrdinals[account.id] = accountOrdinals.count }
        for section in sections.sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
            guard cards.instruments.contains(where: { $0.id == section.instrumentId && $0.liabilityAccountId == account.id }) else {
                throw CampaignError.sourceMismatch
            }
            if instrumentOrdinals[section.instrumentId] == nil { instrumentOrdinals[section.instrumentId] = instrumentOrdinals.count }
        }
        let evidence = try cards.transactionEvidence.filter { statementIDs.contains($0.cardStatementId) }.map { evidence in
            guard let transaction = rows.first(where: { $0.id == evidence.transactionId }), !transaction.rawRows.isEmpty else {
                throw CampaignError.sourceMismatch
            }
            let instrument: String
            if let id = evidence.instrumentId {
                if instrumentOrdinals[id] == nil {
                    guard cards.instruments.contains(where: { $0.id == id && $0.liabilityAccountId == account.id }) else {
                        throw CampaignError.sourceMismatch
                    }
                    instrumentOrdinals[id] = instrumentOrdinals.count
                }
                guard let ordinal = instrumentOrdinals[id] else { throw CampaignError.sourceMismatch }
                instrument = String(ordinal)
            } else { instrument = "absent" }
            let sourceRows = try transaction.rawRows.map { sourceRow in
                guard let ordinal = sourceRow.sourceOrdinal else { throw CampaignError.sourceMismatch }
                return String(ordinal)
            }.sorted().joined(separator: ",")
            return [sourceRows, instrument, evidence.rowScopeCode, evidence.liabilityEffectCode, evidence.sourceTransactionDateISO,
                    evidence.documentScopedSectionId ?? "", evidence.originalCurrency ?? "", String(evidence.originalAmountMinor ?? -1),
                    evidence.originalAmountDecimal ?? "", evidence.summaryMembershipCode ?? ""].joined(separator: "|")
        }.sorted().joined(separator: "~")
        let statementFields = statements.map {
            [$0.parserProfileId, $0.parserProfileVersion, $0.statementDateISO ?? "", $0.statementStartDateISO ?? "",
             $0.statementEndDateISO ?? "", $0.statementCurrency, String($0.sourceRowCount), $0.reconciliationRuleCode]
                .joined(separator: "|")
        }.sorted().joined(separator: "~")
        let summaryFields = cards.summaryComponents.filter { statementIDs.contains($0.cardStatementId) }.map {
            [$0.componentCode, $0.moneyCurrency ?? "", String($0.moneyMinor ?? -1), $0.moneyDecimal ?? "", $0.dateISO ?? ""]
                .joined(separator: "|")
        }.sorted().joined(separator: "~")
        let sectionFields = sections.map {
            [$0.documentScopedSectionId, String($0.sourceOrdinal), String(instrumentOrdinals[$0.instrumentId] ?? -1),
             $0.holderLabel ?? "", $0.signedTotalCurrency, String($0.signedTotalMinor), $0.signedTotalDecimal, $0.reconciliationRuleCode]
                .joined(separator: "|")
        }.sorted().joined(separator: "~")
        let sectionObservations = cards.sectionObservations.filter { sectionIDs.contains($0.cardStatementSectionId) }.map {
            [$0.observationKind, $0.sourceValue, $0.associationAuthority].joined(separator: "|")
        }.sorted().joined(separator: "~")
        let sourceObservations = cards.sourceObservations.filter { $0.importSessionId == sessionID }.map {
            [$0.observationKind, $0.sourceValue, $0.associationAuthority].joined(separator: "|")
        }.sorted().joined(separator: "~")
        let accountOrdinal = try #require(accountOrdinals[account.id])
        let projection: [String] = [
            session.validationStatus, session.parserVersion ?? "", document.filename, document.mimeType ?? "",
            String(document.sizeBytes ?? -1), account.institutionId ?? "", account.accountType ?? "", account.nativeCurrency,
            String(accountOrdinal), statementFields, summaryFields, evidence, sectionFields, sectionObservations, sourceObservations
        ]
        return projection.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private func makeEngine(provider: DatabaseProvider, password: String, stores: GmailQualificationStores) -> ImportEngine {
        let hydrator = stores.hydrator(provider)
        let passwords = DefaultPasswordProvider(credentialStore: InMemoryStatementPasswordCredentialStore(),
            supportedInstitutionCodes: [], challenge: { _ in password })
        return ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
    }

    private func verifyBankSectionEvidence(_ provider: DatabaseProvider, prepared: PreparedImport,
        loaded: BankSectionRepositorySnapshotDTO? = nil) throws {
        let document = prepared.financialDocument
        let savingsProfiles = ["cbq.savings-account.legacy.pdf", "cbq.savings-account.monthly.pdf", "cbq.e-savings-account.monthly.pdf"]
        guard savingsProfiles.contains(document.parserProfileID ?? "") ||
                (document.parserProfileID == "cbq.current-account.monthly.pdf" && document.transactions.isEmpty) else { return }
        let graph = try loaded ?? provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let sections = graph.sections.filter { $0.importSessionId == prepared.importSession.id.uuidString }
        guard sections.count == 1, let section = sections.first else { throw CampaignError.sourceMismatch }
        let envelopeMatches = section.parserProfileId == document.parserProfileID &&
            section.parserProfileVersion == document.parserProfileVersion &&
            section.sectionOrdinal == 1 && section.nativeCurrency == document.bookedCurrency?.code &&
            section.rows.count == document.transactions.count &&
            section.identityPatterns == document.cbqSourceIdentityObservations.map {
                CBQSourceIdentityPatternDTO(kind: $0.kind.rawValue, pattern: $0.pattern)
            }.sorted { ($0.kind, $0.pattern) < ($1.kind, $1.pattern) }
        #expect(envelopeMatches, "Bank section envelope did not survive persistence.")
        for (occurrence, expected) in zip(section.rows, document.transactions) {
            let provenance = try #require(expected.sourceProvenance.first)
            let expectedMinor = try expected.money.minorUnits()
            let matches = occurrence.source.postingDateISO == expected.statementDate?.canonical &&
                occurrence.source.sourceTransactionDateISO == provenance.sourceTransactionDate?.canonical &&
                occurrence.valueDateISO == expected.valueDate?.canonical &&
                occurrence.source.signedAmountMinor == expectedMinor &&
                occurrence.source.sourceOrdinal == provenance.sourceOrdinal &&
                occurrence.source.normalizedRecordDigest == provenance.normalizedRecordDigest &&
                occurrence.source.structuredReferenceDigest == provenance.structuredReferenceDigest &&
                occurrence.literalNarration == expected.description &&
                occurrence.literalReference == expected.reference &&
                occurrence.literalBalance == provenance.literalRunningBalance
            #expect(matches, "Bank occurrence fields did not survive persistence.")
        }
    }

    private func verifyRelationships(_ provider: DatabaseProvider, expectedCount: Int) throws {
        let rows = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let accounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
        #expect(rows.count == expectedCount && accounts.count == 1)
        for row in rows {
            let valid = row.accountId == accounts.first?.id && row.importSessionId != nil && row.documentId != nil
            #expect(valid)
            if let id = row.importSessionId {
                let session = try provider.importSessionRepo.importSession(id: id)
                #expect(session != nil)
            }
            if let id = row.documentId {
                let document = try provider.importSessionRepo.importedDocument(id: id)
                #expect(document != nil)
            }
        }
    }

    private func verifyCardEvidence(_ provider: DatabaseProvider, prepared: PreparedImport, sessionID: String? = nil,
        loaded: CohortDurableSnapshot? = nil) throws {
        guard let expected = prepared.financialDocument.cardStatementEvidence else { return }
        let snapshot = try loaded?.cards ?? provider.cardRepo.snapshot(workspaceId: "default-workspace")
        let statements = snapshot.statements.filter { sessionID == nil || $0.importSessionId == sessionID }
        guard statements.count == 1, let statement = statements.first else { throw CampaignError.sourceMismatch }
        let headerMatches = statement.statementDateISO == expected.statementDate?.canonical
            && statement.statementStartDateISO == expected.declaredStatementPeriod?.start.canonical
            && statement.statementEndDateISO == expected.declaredStatementPeriod?.end.canonical
            && statement.statementCurrency == expected.nativeCurrency.code
            && statement.sourceRowCount == prepared.financialDocument.transactions.count
            && snapshot.transactionEvidence.filter { $0.cardStatementId == statement.id }.count == expected.transactionAnnotations.count
            && snapshot.sections.filter { $0.cardStatementId == statement.id }.count == expected.instrumentSections.count
        #expect(headerMatches)
        for component in expected.summaryComponents {
            let matches = snapshot.summaryComponents.filter { $0.cardStatementId == statement.id && $0.componentCode == component.persistenceCode }
            guard matches.count == 1, let actual = matches.first else { throw CampaignError.sourceMismatch }
            let expectedDecimal = try component.money?.canonicalDecimalString()
            let expectedMinor = try component.money?.minorUnits()
            let correct = actual.moneyCurrency == component.money?.currency.code
                && actual.moneyDecimal == expectedDecimal
                && actual.moneyMinor == expectedMinor && actual.dateISO == component.date?.canonical
            #expect(correct)
        }
        let allRows = try loaded?.transactions ?? provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let rows = allRows.filter { $0.importSessionId == statement.importSessionId }
        for transaction in prepared.financialDocument.transactions {
            guard let ordinal = transaction.sourceProvenance.first?.sourceOrdinal,
                  let row = rows.first(where: { $0.rawRows.contains(where: { $0.sourceOrdinal == ordinal }) }),
                  let annotation = expected.transactionAnnotations.first(where: { $0.parserTransactionID == transaction.id }),
                  let actual = snapshot.transactionEvidence.first(where: { $0.transactionId == row.id && $0.cardStatementId == statement.id }) else { throw CampaignError.sourceMismatch }
            let originalDecimal = try annotation.originalMerchantMoney?.canonicalDecimalString()
            let originalMinor = try annotation.originalMerchantMoney?.minorUnits()
            let correct = actual.cardStatementId == statement.id
                && actual.sourceTransactionDateISO == annotation.sourceTransactionDate.canonical
                && actual.liabilityEffectCode == annotation.liabilityEffect.rawValue
                && actual.originalCurrency == annotation.originalMerchantMoney?.currency.code
                && actual.originalAmountDecimal == originalDecimal
                && actual.originalAmountMinor == originalMinor
                && actual.documentScopedSectionId == annotation.documentScopedSectionID
                && actual.rowScopeCode == annotation.financialScope.persistenceCode
                && row.direction == annotation.liabilityEffect.rawValue
            #expect(correct)
        }
        for section in expected.instrumentSections {
            guard let actual = snapshot.sections.first(where: { $0.cardStatementId == statement.id && $0.documentScopedSectionId == section.documentScopedSectionID }) else { throw CampaignError.sourceMismatch }
            let signedTotal = try section.signedNetTotal.canonicalDecimalString()
            let correct = actual.cardStatementId == statement.id && actual.sourceOrdinal == section.sourceOrdinal
                && actual.signedTotalCurrency == section.signedNetTotal.currency.code
                && actual.signedTotalDecimal == signedTotal
                && actual.holderLabel == section.holderLabel
                && snapshot.instruments.contains(where: { $0.id == actual.instrumentId && $0.liabilityAccountId == statement.liabilityAccountId })
            #expect(correct)
            for observation in section.sourceIdentityObservations {
                let preserved = snapshot.sectionObservations.contains {
                    $0.cardStatementSectionId == actual.id && $0.observationKind == observation.kind.rawValue && $0.sourceValue == observation.value
                }
                #expect(preserved)
            }
        }
        for observation in expected.accountSourceIdentityObservations {
            let preserved = snapshot.sourceObservations.contains {
                $0.subjectId == statement.liabilityAccountId && $0.importSessionId == statement.importSessionId
                    && $0.observationKind == observation.kind.rawValue && $0.sourceValue == observation.value
            }
            #expect(preserved)
        }
    }

    /// The preparation has already matched an independent original oracle.
    /// This projection proves those exact financial fields survived persistence
    /// and hydration, including source order and multiplicity. Runtime IDs and
    /// account display names are checked separately through relationships.
    private func rowProjection(_ rows: [Transaction]) -> [String] {
        func field(_ text: String) -> String { "\(text.utf8.count):\(text)" }
        func money(_ value: Money?) -> String {
            guard let value else { return "absent" }
            return value.currency.code + ":" + ((try? value.canonicalDecimalString()) ?? "invalid")
        }
        return rows.sorted { ($0.sourceProvenance.first?.sourceOrdinal ?? 0) < ($1.sourceProvenance.first?.sourceOrdinal ?? 0) }.map { row in
            let provenance = row.sourceProvenance.map {
                [String($0.sourceOrdinal), $0.normalizedRecordDigest, $0.parserProfileID, $0.parserProfileVersion].map(field).joined()
            }.joined()
            // Card purchase dates/original money live in canonical card
            // evidence; its derived debit/credit display fields are not the
            // source's booked amount. Bank source dates/references use the
            // existing preferred-source fields after hydration.
            let card = row.cardLiabilityEffect != nil
            let sourceDate = card ? nil : (row.repositoryPreferredSourceTransactionDate ?? row.sourceProvenance.first?.sourceTransactionDate)
            let sourceReference = card ? nil : (row.repositoryPreferredStructuredReferenceDigest ?? row.sourceProvenance.first?.structuredReferenceDigest)
            return [row.statementDate?.canonical ?? "", row.valueDate?.canonical ?? "", String(describing: row.financialDateRole),
                row.statementTimezoneEvidence.persistenceCode, row.description, row.reference ?? "", money(row.money),
                money(card ? nil : row.debitMoney), money(card ? nil : row.creditMoney), money(row.runningBalanceMoney),
                row.cardLiabilityEffect?.rawValue ?? "", provenance, sourceDate?.canonical ?? "", sourceReference ?? ""].map(field).joined()
        }
    }
}

@MainActor
private final class GmailQualificationStores {
    let accounts = AccountStore(), transactions = TransactionStore(), categories = CategoryStore()
    let cards = CardStore(), salary = SalaryStore(), plans = FundingPlanStore(), investments = InvestmentStore()
    let sessions = ImportSessionStore(), attempts = ImportAttemptStore()
    func hydrator(_ provider: DatabaseProvider) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            accountStore: accounts, transactionStore: transactions, categoryStore: categories, cardStore: cards,
            salaryStore: salary, fundingPlanStore: plans, investmentStore: investments, importSessionStore: sessions,
            importAttemptStore: attempts, persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
    }
}
