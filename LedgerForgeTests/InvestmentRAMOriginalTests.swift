import CryptoKit
import Darwin
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Explicit qualification transport for unchanged, nominated email originals.
/// A task-owned FIFO carries the original bytes and one-use unlock value in RAM.
/// No attachment, decrypted statement or financial oracle is a disk fixture.
@Suite(.serialized)
@MainActor
struct InvestmentRAMOriginalTests {
    nonisolated struct Original: Decodable, Sendable {
        let fileName: String
        let sha256: String
        let byteCount: Int
        let bytes: Data
        let password: String?
        let family: String
        let expected: [ExpectedHolding]
        let approvedFolioAliases: [[String]]?
    }

    /// Independent source interpretation arrives through the same RAM transport,
    /// before production output is read. These are comparison fields, not a
    /// FinancialDocument/DTO used as input to any import or repository.
    nonisolated struct ExpectedHolding: Decodable, Sendable {
        let container: String
        let institution: String?
        let instrument: String
        let units: String
        let currency: String
        let averageCost: String?
        let totalCost: String?
        let holdingsDate: String
        let valuationDate: String?
    }

    private enum QualificationError: Error { case invalidTransport, invalidOriginal }

    /// Reads the printed current-position controls in the observed registrar
    /// summary and detailed originals. Transaction history never supplies an
    /// expected holding. PDFKit is only the shared native text decoder.
    func casGmailOriginal(source: GmailInboxSource, bytes: Data, password: String,
                          family: String) throws -> Original {
        var sourceStage = "original decoding"
        do {
            guard let pdf = PDFDocument(data: bytes), !pdf.isLocked || pdf.unlock(withPassword: password),
                  let sha = source.sha256, GmailInboxSource.digest(bytes) == sha else { throw QualificationError.invalidOriginal }
            let pages = try (0..<pdf.pageCount).map { index in
                guard let text = pdf.page(at: index)?.string else { throw QualificationError.invalidOriginal }
                return text
            }
            let text = pages.joined(separator: "\n")
            var expected: [ExpectedHolding] = []
            var costSum = Decimal.zero
            let costControl: Decimal
            if family == "cas_summary" {
                sourceStage = "summary header and total"
                guard let page = pages.first, page.hasPrefix("Consolidated Account Summary\n"),
                      let start = page.range(of: "Cost Value\n"), let end = page.range(of: "\nTotal "),
                      start.upperBound < end.lowerBound,
                      pages.dropFirst().allSatisfy({ $0.contains("Loads and Fees") }) else {
                    throw QualificationError.invalidOriginal
                }
                let date = try sourceDate(sourceCapture(#"(?m)^As on ([0-9]{2}-[A-Za-z]{3}-[0-9]{4})$"#, page), format: "dd-MMM-yyyy")
                let table = String(page[start.upperBound..<end.lowerBound])
                costControl = try sourceNumber(sourceCapture(#"(?m)^([0-9,.]+)\s*\nTotal [0-9,.]+\s*$"#, page))
                let rowStart = try NSRegularExpression(pattern: #"(?m)^([0-9]{5,})(?=\s)"#)
                let matches = rowStart.matches(in: table, range: NSRange(table.startIndex..., in: table))
                for (index, match) in matches.enumerated() {
                    sourceStage = "summary holding \(index + 1)"
                    let upper = index + 1 < matches.count ? matches[index + 1].range.location : (table as NSString).length
                    let block = (table as NSString).substring(with: NSRange(location: match.range.location, length: upper - match.range.location))
                    let folio = (table as NSString).substring(with: match.range(at: 1))
                    let security = try sourceMatches(#"\b(INF[A-Z0-9]{9})\s+([0-9,.]+)\b"#, block)
                    let balance = try sourceMatches(#"(?m)^([0-9,.]+)\s+([0-9]{2}-[A-Z]{3}-[0-9]{4})\s+([0-9,.]+)\s+([0-9,.]+)\s*$"#, block)
                    guard security.count == 1, balance.count == 1, block.localizedCaseInsensitiveContains("Direct"),
                          !block.localizedCaseInsensitiveContains("Regular"),
                          try sourceNumber(balance[0][0]) > 0 else { throw QualificationError.invalidOriginal }
                    costSum += try sourceNumber(security[0][1])
                    expected.append(.init(container: folio, institution: nil, instrument: security[0][0],
                        units: balance[0][0], currency: "INR", averageCost: nil, totalCost: security[0][1],
                        holdingsDate: date, valuationDate: try sourceDate(balance[0][1], format: "dd-MMM-yyyy")))
                }
            } else if family == "cas_detailed" {
                sourceStage = "detailed period and total"
                guard let first = pages.first, first.hasPrefix("Consolidated Account Statement\n") else {
                    throw QualificationError.invalidOriginal
                }
                let period = try sourceMatches(#"(?m)^([0-9]{2}-[A-Za-z]{3}-[0-9]{4}) To ([0-9]{2}-[A-Za-z]{3}-[0-9]{4})$"#, first)
                guard period.count == 1 else { throw QualificationError.invalidOriginal }
                let date = try sourceDate(period[0][1], format: "dd-MMM-yyyy")
                costControl = try sourceNumber(sourceCapture(#"(?m)^Total ([0-9,.]+) [0-9,.]+$"#, first))
                let sectionStart = try NSRegularExpression(pattern: #"Folio No\s*:\s*([0-9]+(?:\s*/\s*[0-9]+)?)"#)
                let matches = sectionStart.matches(in: text, range: NSRange(text.startIndex..., in: text))
                var closingCount = 0
                for (index, match) in matches.enumerated() {
                    sourceStage = "detailed folio section \(index + 1)"
                    let upper = index + 1 < matches.count ? matches[index + 1].range.location : (text as NSString).length
                    let block = (text as NSString).substring(with: NSRange(location: match.range.location, length: upper - match.range.location))
                    let folio = (text as NSString).substring(with: match.range(at: 1))
                    let isin = try sourceCapture(#"ISIN:\s*(INF[A-Z0-9]{9})\b"#, block)
                    let unitsToken = try sourceCapture(#"Closing Unit Balance:\s*([0-9,.]+)"#, block)
                    let nav = try sourceMatches(#"NAV on\s+([0-9]{2}-[A-Z]{3}-[0-9]{4})\s*:\s*INR\s+([0-9,.]+)"#, block)
                    let costToken = try sourceCapture(#"Total Cost Value\s*:\s*INR\s+([0-9,.]+)"#, block)
                    // Native PDF reading order interleaves historical columns on
                    // some pages. Require each printed current control exactly once
                    // within its folio, without treating their text adjacency as
                    // financial meaning.
                    guard nav.count == 1, block.contains("Opening Unit Balance"),
                          let isinLabel = block.range(of: "ISIN:") else {
                        throw QualificationError.invalidOriginal
                    }
                    closingCount += 1
                    let units = try sourceNumber(unitsToken), cost = try sourceNumber(costToken)
                    if units == 0 {
                        guard cost == 0 else { throw QualificationError.invalidOriginal }
                        continue
                    }
                    let identity = String(block[..<isinLabel.lowerBound]).components(separatedBy: "(Advisor:")[0]
                    guard units > 0, cost >= 0, identity.localizedCaseInsensitiveContains("Direct"),
                          !identity.localizedCaseInsensitiveContains("Regular") else { throw QualificationError.invalidOriginal }
                    let valuationDate = try sourceDate(nav[0][0], format: "dd-MMM-yyyy")
                    let marketDate = try sourceDate(sourceCapture(#"Market Value on\s+([0-9]{2}-[A-Z]{3}-[0-9]{4})\s*:\s*INR"#, block), format: "dd-MMM-yyyy")
                    guard marketDate == valuationDate else { throw QualificationError.invalidOriginal }
                    costSum += cost
                    expected.append(.init(container: folio, institution: nil, instrument: isin, units: unitsToken,
                        currency: "INR", averageCost: nil, totalCost: costToken, holdingsDate: date, valuationDate: valuationDate))
                }
                guard closingCount == text.components(separatedBy: "Closing Unit Balance:").count - 1 else {
                    throw QualificationError.invalidOriginal
                }
            } else { throw QualificationError.invalidOriginal }
            sourceStage = "complete current-holding inventory and printed cost total"
            guard text.contains("(INR)"), !expected.isEmpty,
                  Set(expected.map(\.instrument)).count == expected.count, costSum == costControl else {
                throw QualificationError.invalidOriginal
            }
            return Original(fileName: source.displayName, sha256: sha, byteCount: bytes.count, bytes: bytes,
                            password: password, family: family, expected: expected, approvedFolioAliases: nil)
        } catch {
            print("CAS source oracle \(source.sha256?.prefix(12) ?? "unknown") failed at \(sourceStage).")
            throw error
        }
    }

    /// Source-only interpretation of the two observed CBQ layouts. PDFKit is
    /// shared only as a low-level decoder; no RawDocument, production layout
    /// helper, parser or prepared result supplies any expected field.
    func cbqGmailOriginal(source: GmailInboxSource, bytes: Data, password: String,
                          family: String) throws -> Original {
        guard let pdf = PDFDocument(data: bytes), !pdf.isLocked || pdf.unlock(withPassword: password),
              let sha = source.sha256, GmailInboxSource.digest(bytes) == sha else { throw QualificationError.invalidOriginal }
        let pages = try (0..<pdf.pageCount).map { index in
            guard let text = pdf.page(at: index)?.string else { throw QualificationError.invalidOriginal }
            return text
        }
        let text = pages.joined(separator: "\n")
        let expected: [ExpectedHolding]
        if text.contains("Customer Investment Portfolio Holding Statement") {
            let holder = try sourceCapture(#"Unit Holder Id\s*:\s*([0-9]+)"#, text)
            let currency = try sourceCapture(#"Fund Currency\s*:\s*([A-Z]{3})"#, text)
            let reportDate = try sourceDate(sourceCapture(#"Date of Report\s*:\s*([0-9]{2}-[A-Za-z]{3}-[0-9]{4})"#, text), format: "dd-MMM-yyyy")
            let control = try sourceNumber(sourceCapture(#"Total Cost of Holdings:\s*([0-9,.]+)"#, text))
            guard pages.count == 1, let header = text.range(of: "Value Unrealized P/L\n"),
                  let footer = text.range(of: "*Unrealized Gain / Loss"), header.upperBound < footer.lowerBound else {
                throw QualificationError.invalidOriginal
            }
            let table = String(text[header.upperBound..<footer.lowerBound])
            let expression = try NSRegularExpression(pattern: #"(?m)^([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+(-?[0-9,.]+|\([0-9,.]+\))\s*$"#)
            var cursor = table.startIndex
            var rows: [ExpectedHolding] = []
            var costs = Decimal.zero
            for match in expression.matches(in: table, range: NSRange(table.startIndex..., in: table)) {
                guard let range = Range(match.range, in: table), cursor <= range.lowerBound else { throw QualificationError.invalidOriginal }
                let name = table[cursor..<range.lowerBound].split(whereSeparator: \.isWhitespace).joined(separator: " ")
                guard !name.isEmpty else { throw QualificationError.invalidOriginal }
                let fields = try (1..<match.numberOfRanges).map { index in
                    guard let range = Range(match.range(at: index), in: table) else { throw QualificationError.invalidOriginal }
                    return String(table[range])
                }
                costs += try sourceNumber(fields[2])
                rows.append(.init(container: holder, institution: "CBQ", instrument: name,
                    units: fields[0], currency: currency, averageCost: fields[1], totalCost: fields[2],
                    holdingsDate: reportDate, valuationDate: nil))
                cursor = range.upperBound
            }
            guard !rows.isEmpty, table[cursor...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  costs == control else { throw QualificationError.invalidOriginal }
            expected = rows
        } else {
            let holder = try sourceCapture(#"Client ID\s+([0-9]+)"#, text)
            guard try sourceCapture(#"CIF:\s*([0-9]+)"#, text) == holder else { throw QualificationError.invalidOriginal }
            let reportDate = try sourceDate(sourceCapture(#"Report date\s+([0-9]{2}/[0-9]{2}/[0-9]{4})"#, text), format: "dd/MM/yyyy")
            let periodEnd = try sourceDate(sourceCapture(#"Reporting period\s+[0-9]{2}/[0-9]{2}/[0-9]{4}\s*-\s*([0-9]{2}/[0-9]{2}/[0-9]{4})"#, text), format: "dd/MM/yyyy")
            guard reportDate == periodEnd else { throw QualificationError.invalidOriginal }
            let reportingCurrency = try sourceCapture(#"Reporting currency\s+([A-Z]{3})"#, text)
            let detailPages = pages.filter { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ").contains("Holding Purchase date Currency Number of units") }
            guard !detailPages.isEmpty else { throw QualificationError.invalidOriginal }
            let details = detailPages.joined(separator: "\n")
            let identifiers = try sourceMatches(#"\b([A-Z]{2}[A-Z0-9]{9}[0-9])\b"#, details).map { $0[0] }
            // Both observed layouts preserve the printed fund sequence in the
            // native string: one emits names before numbers, the other interleaves
            // them. Separate ordered lists must be one-to-one and complete.
            let rows = try sourceMatches(#"(?m)^([0-9]{2}/[0-9]{2}/[0-9]{4})\s+([A-Z]{3})\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9]{2}/[0-9]{2}/[0-9]{4})\s+([0-9,.]+)\b"#, details)
            guard !rows.isEmpty, rows.count == identifiers.count, Set(identifiers).count == identifiers.count,
                  Set(rows.map { $0[1] }).count == 1 else { throw QualificationError.invalidOriginal }
            let nativeCurrency = rows[0][1]
            let exchange: Decimal
            if nativeCurrency == reportingCurrency { exchange = 1 }
            else { exchange = try sourceNumber(sourceCapture("\\b" + nativeCurrency + "\\s+" + reportingCurrency + #"\s+([0-9.]+)\b"#, text)) }
            let control = try sourceNumber(sourceCapture("(?m)^Total " + reportingCurrency + #"\s+([0-9,.]+)\s"#, details))
            var nativeCost = Decimal.zero
            var holdings: [ExpectedHolding] = []
            for (row, isin) in zip(rows, identifiers) {
                let totalCost = row[5]
                nativeCost += try sourceNumber(totalCost)
                holdings.append(.init(container: holder, institution: "CBQ", instrument: isin,
                    units: row[2], currency: nativeCurrency,
                    averageCost: row[3], totalCost: totalCost,
                    holdingsDate: reportDate, valuationDate: try sourceDate(row[7], format: "dd/MM/yyyy")))
            }
            var converted = nativeCost * exchange, rounded = Decimal.zero
            NSDecimalRound(&rounded, &converted, 2, .plain)
            guard rounded == control else { throw QualificationError.invalidOriginal }
            expected = holdings
        }
        return Original(fileName: source.displayName, sha256: sha, byteCount: bytes.count, bytes: bytes,
                        password: password, family: family, expected: expected, approvedFolioAliases: nil)
    }

    private func sourceMatches(_ pattern: String, _ text: String) throws -> [[String]] {
        let expression = try NSRegularExpression(pattern: pattern)
        return try expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            try (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { throw QualificationError.invalidOriginal }
                return String(text[range])
            }
        }
    }
    private func sourceCapture(_ pattern: String, _ text: String) throws -> String {
        let values = try sourceMatches(pattern, text)
        guard values.count == 1, let value = values.first?.first else { throw QualificationError.invalidOriginal }
        return value
    }
    private func sourceNumber(_ text: String) throws -> Decimal {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        guard cleaned.range(of: #"^-?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { throw QualificationError.invalidOriginal }
        return value
    }
    private func sourceDate(_ text: String, format: String) throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian); formatter.dateFormat = format; formatter.isLenient = false
        guard let date = formatter.date(from: text),
              formatter.string(from: date).caseInsensitiveCompare(text) == .orderedSame else { throw QualificationError.invalidOriginal }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEDGERFORGE_INVESTMENT_RAM_PIPE"] != nil))
    func nominatedOriginalsPrepareCommitAndReopen() async throws {
        var transport = stat()
        guard let path = ProcessInfo.processInfo.environment["LEDGERFORGE_INVESTMENT_RAM_PIPE"],
              lstat(path, &transport) == 0, transport.st_mode & S_IFMT == S_IFIFO,
              transport.st_uid == getuid() else {
            throw QualificationError.invalidTransport
        }
        let pipe = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? pipe.close() }
        let payload = try pipe.readToEnd() ?? Data()
        guard !payload.isEmpty, payload.count <= 64 * 1_024 * 1_024 else { throw QualificationError.invalidTransport }
        let originals = try JSONDecoder().decode([Original].self, from: payload)
        try await qualifyOriginals(originals)
    }

    func qualifyGmailOriginals(_ originals: [Original], sources: [String: GmailInboxSource]) async throws {
        guard originals.allSatisfy({ sources[$0.sha256]?.sha256 == $0.sha256 }) else {
            throw QualificationError.invalidOriginal
        }
        try await qualifyOriginals(originals, gmailSources: sources)
    }

    private func qualifyOriginals(_ originals: [Original], gmailSources: [String: GmailInboxSource] = [:]) async throws {
        guard !originals.isEmpty, Set(originals.map(\.sha256)).count == originals.count else {
            throw QualificationError.invalidOriginal
        }
        for (index, original) in originals.enumerated() {
            guard original.bytes.count == original.byteCount,
                  SHA256.hash(data: original.bytes).map({ String(format: "%02x", $0) }).joined() == original.sha256,
                  ["pdf", "csv"].contains(URL(fileURLWithPath: original.fileName).pathExtension.lowercased()),
                  original.fileName == URL(fileURLWithPath: original.fileName).lastPathComponent else {
                throw QualificationError.invalidOriginal
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-investment-ram-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let databaseURL = folder.appendingPathComponent("holdings.sqlite")
            let sqlite = try SQLiteRepositoryProvider(path: databaseURL.path)
            defer { sqlite.database.close() }
            for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
                let gmailSource = gmailSources[original.sha256]
                if let gmailSource {
                    var inbox = GmailInboxState(account: gmailSource.account)
                    inbox.sources[gmailSource.id] = gmailSource
                    _ = try provider.gmailInboxRepo.save(inbox, originals: [original.sha256: original.bytes], expectedRevision: 0)
                }
                let store = InvestmentStore()
                let engine = makeEngine(provider, original: original, store: store, gmailSource: gmailSource)
                do {
                    let url = gmailSource?.importURL ?? URL(string: "gmail-original://\(original.sha256)/")!.appendingPathComponent(original.fileName)
                    let cancelled = try await engine.prepareImport(from: url)
                    engine.cancelPreparedImport(cancelled)
                    let empty = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == .empty
                    #expect(empty)
                    let noAccounts = try provider.accountRepo.accounts(workspaceId: "default-workspace").isEmpty
                    let noTransactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty
                    #expect(noAccounts && noTransactions)
                    let prepared = try await engine.prepareImport(from: url)
                    guard prepared.validation.passed, !prepared.investmentConfirmationBlocked,
                          let expected = prepared.investmentReview?.snapshot,
                          let sourceProfile = prepared.financialDocument.investmentStatementEvidence?.parserProfile else {
                        Issue.record("RAM original held at inventory index \(index).");
                        engine.cancelPreparedImport(prepared); continue
                    }
                    guard agreesWithOriginal(expected, expected: original.expected) else {
                        engine.cancelPreparedImport(prepared)
                        throw QualificationError.invalidOriginal
                    }
                    if gmailSource != nil {
                        // Technical source/profile coverage only. The independent
                        // financial projection remains in RAM.
                        print("GMAIL_INV_SOURCE_PROFILE sha=\(original.sha256) family=\(original.family) profile=\(sourceProfile)")
                    }
                    let result = await engine.commitPreparedImport(prepared)
                    let committed = result.succeeded
                    let exact = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                    let hydrated = store.snapshot == expected
                    let currentOnly = expected.holdings.allSatisfy { $0.units.value > 0 }
                    #expect(committed && exact && hydrated && currentOnly)
                    let sourceAgrees = agreesWithOriginal(store.snapshot, expected: original.expected)
                    #expect(sourceAgrees, "Independent original comparison failed at inventory index \(index).")
                    let replay = try await engine.prepareImport(from: url)
                    let replayResult = await engine.commitPreparedImport(replay)
                    let unchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                    #expect(replayResult.previousImport != nil && unchanged)
                } catch {
                    let reason = (error as? InvestmentError).map { String(describing: $0) } ?? "reader-or-persistence"
                    Issue.record("RAM original failed at inventory index \(index): \(reason).")
                }
            }
            let before = try sqlite.investmentRepo.snapshot(workspaceID: "default-workspace")
            try sqlite.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: databaseURL.path)
            let exact = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == before
            #expect(exact)
            let originalAgreesAfterReopen = try agreesWithOriginal(
                reopened.investmentRepo.snapshot(workspaceID: "default-workspace"), expected: original.expected)
            #expect(originalAgreesAfterReopen, "Independent original reopen comparison failed at inventory index \(index).")
            try BackupCompatibility.verifyDatabase(reopened.database)
            reopened.database.close()
        }
        try await confirmFolioAliasesAndSameDateSourceChoices(originals, gmailSources: gmailSources)
    }

    private func confirmFolioAliasesAndSameDateSourceChoices(_ originals: [Original],
                                                            gmailSources: [String: GmailInboxSource]) async throws {
        let latest = originals.filter { ["cas_detailed", "cas_summary"].contains($0.family) }
        guard !latest.isEmpty else { return }
        guard latest.count == 2 else { throw QualificationError.invalidOriginal }
        let earlier = originals.filter { $0.family == "local-IndianMutualFunds" }
            .sorted { $0.expected[0].holdingsDate < $1.expected[0].holdingsDate }
        func folio(_ text: String) -> String { text.filter { !$0.isWhitespace } }
        for ordered in [latest, Array(latest.reversed())] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-folio-ram-\(UUID())")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
            defer { sqlite.database.close() }
            for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
                let store = InvestmentStore()
                for (index, original) in (earlier + ordered).enumerated() {
                    let gmailSource = gmailSources[original.sha256]
                    if let gmailSource {
                        var inbox = try provider.gmailInboxRepo.load(account: gmailSource.account)
                        let revision = inbox.revision
                        inbox.sources[gmailSource.id] = gmailSource
                        _ = try provider.gmailInboxRepo.save(inbox, originals: [original.sha256: original.bytes], expectedRevision: revision)
                    }
                    let engine = makeEngine(provider, original: original, store: store, gmailSource: gmailSource)
                    let url = gmailSource?.importURL ?? URL(string: "original://\(original.sha256)/")!.appendingPathComponent(original.fileName)
                    var prepared = try await engine.prepareImport(from: url)
                    guard let plan = prepared.investmentPlan else { throw QualificationError.invalidOriginal }
                    var choices = plan.choices
                    for scope in plan.evidence.scopes {
                        let approved = (original.approvedFolioAliases ?? []).filter { $0.map(folio).contains(folio(scope.identity)) }
                        guard approved.count <= 1 else { throw QualificationError.invalidOriginal }
                        if let pair = approved.first {
                            let aliases = Set(pair.map(folio))
                            let targets = plan.baseline.containers.filter {
                                $0.identityKind == "folio" && !Set($0.aliases.map(folio)).isDisjoint(with: aliases)
                            }
                            guard targets.count <= 1 else { throw QualificationError.invalidOriginal }
                            if let target = targets.first { choices.containerTargets[scope.key] = target.id }
                        }
                    }
                    prepared.updateInvestmentChoices(choices)
                    if let mapped = prepared.investmentReview, !mapped.mappingQuestions.isEmpty,
                       gmailSource != nil, original.approvedFolioAliases == nil {
                        // These Gmail nominations contain no owner-confirmed
                        // aliases. Their genuine ambiguity must hold the second
                        // representation, not silently merge its printed folios.
                        let before = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
                        #expect(index == earlier.count + 1 && prepared.investmentConfirmationBlocked)
                        let blocked = await engine.commitPreparedImport(prepared)
                        let unchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == before
                        #expect(!blocked.succeeded && !blocked.persisted && unchanged && store.snapshot == before)
                        let retained = try provider.gmailInboxRepo.original(sha256: original.sha256, byteCount: original.byteCount) == original.bytes
                        #expect(retained)
                        print("Gmail CAS sequence held for unconfirmed folio aliases; accepted holdings unchanged.")
                        continue
                    }
                    guard let mapped = prepared.investmentReview, mapped.mappingQuestions.isEmpty else {
                        Issue.record("Confirmed folio choices did not resolve the authentic sequence at index \(index).")
                        engine.cancelPreparedImport(prepared); continue
                    }
                    if index == earlier.count + 1 { #expect(!mapped.sameDateConflictScopes.isEmpty) }
                    // Both genuine same-date representations must offer the same
                    // explicit choice; this branch exercises choosing the incoming one.
                    choices.replaceSameDateScopes = mapped.sameDateConflictScopes
                    prepared.updateInvestmentChoices(choices)
                    let result = await engine.commitPreparedImport(prepared)
                    let exact = agreesWithOriginal(store.snapshot, expected: original.expected)
                    let currentContainers = store.snapshot.containers.count == Set(original.expected.map { folio($0.container) }).count
                    #expect(result.succeeded && exact && currentContainers,
                        "Authentic folio sequence failed at index \(index).")
                    let replay = try await engine.prepareImport(from: url)
                    let replayNeedsNoMapping = replay.investmentReview?.mappingQuestions.isEmpty != false
                    let repeated = await engine.commitPreparedImport(replay)
                    #expect(repeated.previousImport != nil && replayNeedsNoMapping)
                }
                let snapshot = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
                for pair in latest.flatMap({ $0.approvedFolioAliases ?? [] }) {
                    let aliases = Set(pair.map(folio))
                    let matching = snapshot.containers.filter { !Set($0.aliases.map(folio)).isDisjoint(with: aliases) }
                    let preserved = matching.count == 1 && aliases.isSubset(of: Set(matching[0].aliases.map(folio)))
                    #expect(preserved)
                }
            }
        }
    }

    func gmailCohortPreparedComparison(_ prepared: PreparedImport, original: Original) throws {
        guard prepared.validation.passed,
              prepared.sourceSnapshot.sourceByteFingerprint.digest == original.sha256,
              let evidence = prepared.financialDocument.investmentStatementEvidence else { throw QualificationError.invalidOriginal }
        let positions = evidence.scopes.flatMap { scope in
            scope.positions.filter { $0.units.value > 0 }.map { (scope, $0) }
        }
        guard positions.count == original.expected.count else { throw QualificationError.invalidOriginal }
        var matched: Set<Int> = []
        func folio(_ value: String) -> String { value.filter { !$0.isWhitespace } }
        for source in original.expected {
            let candidates = positions.indices.filter { index in
                let (scope, position) = positions[index]
                return (scope.aliases + [scope.identity]).contains(where: { folio($0) == folio(source.container) })
                    && (position.instrumentIdentity == "isin:" + source.instrument
                        || position.sourceAliases.contains("isin:" + source.instrument)
                        || position.instrumentIdentity == "cbq-fund-name:" + source.instrument)
            }
            guard candidates.count == 1, let index = candidates.first, matched.insert(index).inserted else { throw QualificationError.invalidOriginal }
            let (scope, position) = positions[index]
            guard position.units.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == source.units.trimmingCharacters(in: .whitespacesAndNewlines),
                  position.averageCost?.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == source.averageCost?.trimmingCharacters(in: .whitespacesAndNewlines),
                  position.totalCost?.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == source.totalCost?.trimmingCharacters(in: .whitespacesAndNewlines),
                  position.currency == source.currency, scope.holdingsDate == source.holdingsDate,
                  position.valuationDate == source.valuationDate,
                  source.institution == nil || scope.institution.caseInsensitiveCompare(source.institution!) == .orderedSame else {
                throw QualificationError.invalidOriginal
            }
        }
    }

    func configureGmailCohort(_ prepared: inout PreparedImport, original: Original,
        retainUnresolvedInstrumentHold: Bool = false) throws {
        guard let plan = prepared.investmentPlan else { throw QualificationError.invalidOriginal }
        var choices = plan.choices
        func folio(_ text: String) -> String { text.filter { !$0.isWhitespace } }
        for scope in plan.evidence.scopes {
            let authority = (original.approvedFolioAliases ?? []).filter { $0.map(folio).contains(folio(scope.identity)) }
            guard authority.count <= 1 else { throw QualificationError.invalidOriginal }
            if let pair = authority.first {
                let aliases = Set(pair.map(folio))
                let targets = plan.baseline.containers.filter {
                    $0.identityKind == "folio" && !Set($0.aliases.map(folio)).isDisjoint(with: aliases)
                }
                guard targets.count <= 1 else { throw QualificationError.invalidOriginal }
                if let target = targets.first { choices.containerTargets[scope.key] = target.id }
            }
        }
        prepared.updateInvestmentChoices(choices)
        guard let configuredPlan = prepared.investmentPlan else { throw QualificationError.invalidOriginal }
        let review = try InvestmentUpdatePlanner.review(configuredPlan, current: configuredPlan.baseline)
        guard review.mappingQuestions.isEmpty else {
            print("GMAIL_COHORT_MAPPING_ATTENTION \(original.sha256) questions=\(review.mappingQuestions.count) kinds=\(review.mappingQuestions.map { String(describing: $0.kind) }.joined(separator: ","))")
            if let path = ProcessInfo.processInfo.environment["LEDGERFORGE_GMAIL_COHORT_MAPPING_PIPE"] {
                var fileInfo = stat()
                guard lstat(path, &fileInfo) == 0, fileInfo.st_mode & S_IFMT == S_IFIFO,
                      let pdf = PDFDocument(data: original.bytes),
                      !pdf.isLocked || pdf.unlock(withPassword: original.password ?? "") else { throw QualificationError.invalidTransport }
                let record: [String: Any] = [
                    "sha256": original.sha256, "family": original.family, "unlocked": true,
                    "pages": (0..<pdf.pageCount).map { pdf.page(at: $0)?.string ?? "" },
                    "mapping": [
                        "questions": review.mappingQuestions.map { question in
                            ["scope": question.scopeKey, "kind": String(describing: question.kind), "label": question.label,
                             "candidates": question.candidates.map { ["id": $0.id, "label": $0.label] }] as [String: Any]
                        },
                        "containers": try JSONSerialization.jsonObject(with: JSONEncoder().encode(configuredPlan.baseline.containers)),
                        "holdings": try JSONSerialization.jsonObject(with: JSONEncoder().encode(configuredPlan.baseline.holdings))
                    ]
                ]
                let pipe = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
                defer { try? pipe.close() }
                try pipe.write(contentsOf: JSONSerialization.data(withJSONObject: [record]))
            }
            if retainUnresolvedInstrumentHold, original.family == "cbq_investment",
               review.mappingQuestions.allSatisfy({ $0.kind == .instrument }),
               configuredPlan.evidence.scopes.allSatisfy({ $0.institution == "CBQ" }) {
                // Preserve the ordinary unresolved review. The caller records
                // a mapping hold and proves no accepted financial mutation;
                // this supplies no alias or new-instrument choice.
                return
            }
            throw InvestmentError.identityChoiceRequired
        }
        choices.replaceSameDateScopes = review.sameDateConflictScopes
        prepared.updateInvestmentChoices(choices)
    }

    func verifyGmailCohortSnapshot(_ snapshot: InvestmentSnapshot, prepared: PreparedImport, original: Original) throws {
        guard let review = prepared.investmentReview, snapshot == review.snapshot else { throw QualificationError.invalidOriginal }
        let ids = review.affectedContainerIDs
        let affected = InvestmentSnapshot(containers: snapshot.containers.filter { ids.contains($0.id) },
                                          holdings: snapshot.holdings.filter { ids.contains($0.containerID) })
        guard agreesWithOriginal(affected, expected: original.expected) else { throw QualificationError.invalidOriginal }
    }

    private func agreesWithOriginal(_ snapshot: InvestmentSnapshot, expected: [ExpectedHolding]) -> Bool {
        func folio(_ value: String) -> String { value.filter { !$0.isWhitespace } }
        func sameNumber(_ actual: InvestmentDecimal?, _ source: String?) -> Bool {
            switch (actual, source) {
            case (nil, nil): true
            case let (actual?, source?): actual.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                == source.trimmingCharacters(in: .whitespacesAndNewlines)
            default: false
            }
        }
        guard snapshot.holdings.count == expected.count else { return false }
        var matched = Set<String>()
        for source in expected {
            let candidates = snapshot.holdings.filter { holding in
                guard let container = snapshot.containers.first(where: { $0.id == holding.containerID }),
                      container.aliases.contains(where: { folio($0) == folio(source.container) }) else { return false }
                if let institution = source.institution,
                   container.institution.caseInsensitiveCompare(institution) != .orderedSame { return false }
                return holding.instrumentIdentity == "isin:" + source.instrument
                    || holding.sourceAliases.contains("isin:" + source.instrument)
                    || holding.instrumentIdentity == "cbq-fund-name:" + source.instrument
                    || holding.instrumentIdentity == "zurich-fund-name:" + source.instrument
            }
            guard candidates.count == 1, let holding = candidates.first, matched.insert(holding.id).inserted,
                  sameNumber(holding.units, source.units), sameNumber(holding.averageCost, source.averageCost),
                  sameNumber(holding.totalCost, source.totalCost), holding.currency == source.currency,
                  holding.holdingsDate == source.holdingsDate, holding.valuationDate == source.valuationDate,
                  holding.costCurrency == ((source.averageCost != nil || source.totalCost != nil) ? source.currency : nil),
                  !holding.displayName.contains("PAN:"), holding.priceMapping == nil else { return false }
        }
        return true
    }

    private func makeEngine(_ provider: DatabaseProvider, original: Original, store: InvestmentStore,
                            gmailSource: GmailInboxSource? = nil) -> ImportEngine {
        let passwords = DefaultPasswordProvider(
            credentialStore: InMemoryStatementPasswordCredentialStore(), supportedInstitutionCodes: [],
            challenge: { _ in original.password })
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(),
            cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore(), investmentStore: store,
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            persistenceState: provider.persistenceState, providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
        return ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { url in
                if gmailSource != nil { return try GmailImportSource.acquireSnapshot(from: url, repository: provider.gmailInboxRepo) }
                return SourceContentSnapshot(bytes: original.bytes)
            },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
    }
}
