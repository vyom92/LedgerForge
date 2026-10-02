import Darwin
import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AuthenticStandaloneBankComparison {
    let url: URL
    let sha256: String
    let equivalentPDFSHA: String
    let rowCount: Int
    let compare: (PreparedImport) throws -> Void
}

/// Independent PDFPlumber source observations arrive through a RAM-only FIFO.
/// They are comparisons, never import inputs or persisted financial fixtures.
@MainActor
struct BankRelationshipAuthenticOracle {
    enum Failure: Error { case missingPipe, invalidEnvelope, sourceMismatch }
    struct Envelope: Decodable { let method: String; let version: String; let sources: [Source]; let overlap: Overlap? }
    struct Overlap: Decodable {
        struct Standalone: Decodable { let sha256: String; let family: String; let rowCount: Int }
        struct Relationship: Decodable { let sha256: String; let matched: Int; let outside: Int; let conflicts: Int }
        struct Link: Decodable {
            let relationshipSHA: String; let sectionOrdinal: Int; let occurrenceIndex: Int
            let standaloneSHA: String; let standaloneOrdinal: Int; let conflict: Bool
        }
        let semantics: String
        let standalone: [Standalone]; let relationships: [Relationship]; let links: [Link]
    }
    struct Source: Decodable {
        let sha256: String
        let family: String
        let sections: [Section]
    }
    struct Section: Decodable {
        struct Summary: Decodable {
            let opening: String; let debits: String; let credits: String; let closing: String
            let debitCount: Int; let creditCount: Int
        }
        let account: String; let product: String; let currency: String
        let start: String; let end: String; let opening: String
        let closing: String?; let total: [String]?; let summary: Summary?
        let pages: [Int]; let lastPage: Int?
        let rows: [Row]
    }
    struct Row: Decodable {
        let date: String; let valueDate: String?; let page: Int
        let narration: [String]; let cheque: [String]?; let reference: String?
        let withdrawal: String?; let deposit: String?; let balance: String; let signed: String
    }

    static func load() throws -> [String: Source] {
        let envelope = try loadEnvelope()
        return Dictionary(uniqueKeysWithValues: envelope.sources.map { ($0.sha256, $0) })
    }

    static func loadWithOverlap() throws -> (sources: [String: Source], overlap: Overlap) {
        let envelope = try loadEnvelope()
        guard let overlap = envelope.overlap,
              overlap.semantics == "independent-source-meaning-injective-per-parent-v2",
              overlap.standalone.count == 7, Set(overlap.standalone.map(\.sha256)).count == 7,
              overlap.relationships.count == envelope.sources.count,
              Set(overlap.relationships.map(\.sha256)) == Set(envelope.sources.map(\.sha256)),
              overlap.standalone.allSatisfy({ $0.rowCount > 0 && ["axis", "hdfc"].contains($0.family) }) else {
            throw Failure.invalidEnvelope
        }
        let sources = Dictionary(uniqueKeysWithValues: envelope.sources.map { ($0.sha256, $0) })
        let standalone = Dictionary(uniqueKeysWithValues: overlap.standalone.map { ($0.sha256, $0) })
        for link in overlap.links {
            guard let source = sources[link.relationshipSHA], let other = standalone[link.standaloneSHA],
                  source.family == other.family, link.sectionOrdinal > 0, link.sectionOrdinal <= source.sections.count,
                  link.occurrenceIndex > 0,
                  link.occurrenceIndex <= source.sections[link.sectionOrdinal - 1].rows.count,
                  (1...other.rowCount).contains(link.standaloneOrdinal) else { throw Failure.invalidEnvelope }
        }
        for proof in overlap.relationships {
            guard let source = sources[proof.sha256], proof.matched >= 0, proof.outside >= 0, proof.conflicts >= 0,
                  proof.matched + proof.outside + proof.conflicts == source.sections.reduce(0, { $0 + $1.rows.count }) else {
                throw Failure.invalidEnvelope
            }
            let links = overlap.links.filter { $0.relationshipSHA == proof.sha256 }
            let matches = links.filter { !$0.conflict }, conflicts = links.filter(\.conflict)
            func occurrence(_ link: Overlap.Link) -> String { "\(link.sectionOrdinal):\(link.occurrenceIndex)" }
            let matchedOccurrences = Set(matches.map(occurrence))
            let conflictingOccurrences = Set(conflicts.map(occurrence))
            guard matches.count == proof.matched, matchedOccurrences.count == matches.count,
                  conflictingOccurrences.count == proof.conflicts,
                  matchedOccurrences.isDisjoint(with: conflictingOccurrences),
                  Set(matches.map { "\($0.standaloneSHA):\($0.standaloneOrdinal)" }).count == matches.count else {
                throw Failure.invalidEnvelope
            }
        }
        return (sources, overlap)
    }

    private static func loadEnvelope() throws -> Envelope {
        guard let path = ProcessInfo.processInfo.environment["LEDGERFORGE_BANK_RELATIONSHIP_ORACLE_PIPE"] else {
            throw Failure.missingPipe
        }
        var metadata = stat()
        guard lstat(path, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFIFO else { throw Failure.missingPipe }
        let input = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? input.close() }
        let data = input.readDataToEndOfFile()
        guard data.count < 10_000_000,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.method == "independent PDFPlumber drawn-grid and source-word oracle",
              envelope.sources.count == 87, Set(envelope.sources.map(\.sha256)).count == 87 else {
            throw Failure.invalidEnvelope
        }
        print("Independent relationship oracle loaded: 87 original hashes, PDFPlumber \(envelope.version); RAM-only source expectations.")
        return envelope
    }

    static func compare(_ prepared: PreparedImport, source: Source) throws {
        let document = prepared.financialDocument
        guard let bank = document.bankStatementEvidence else { throw Failure.sourceMismatch }
        let envelope = prepared.sourceSnapshot.sourceByteFingerprint.digest == source.sha256 &&
            prepared.validation.passed && document.parserProfileID == source.family + ".relationship-bank.pdf" &&
            document.parserProfileVersion == "1" && bank.isAccountRelationshipStatement &&
            bank.sections.count == source.sections.count && document.financialIdentifiers.isEmpty &&
            document.transactions.count == source.sections.reduce(0, { $0 + $1.rows.count })
        guard envelope else {
            Issue.record("Relationship source \(source.sha256.prefix(12)) envelope differs from its independent oracle.")
            throw Failure.sourceMismatch
        }
        let byID = Dictionary(uniqueKeysWithValues: document.transactions.map { ($0.id, $0) })
        for (sectionIndex, pair) in zip(bank.sections, source.sections).enumerated() {
            let (section, expected) = pair
            let closing = expected.closing ?? expected.summary?.closing
            let headerChecks = [
                "account": section.sourceIdentity.literal == expected.account,
                "product": compact(section.productLabel) == compact(expected.product),
                "currency": section.nativeCurrency.code == expected.currency,
                "period-start": section.period.start.canonical == canonicalDate(expected.start),
                "period-end": section.period.end.canonical == canonicalDate(expected.end),
                "section-order": section.ordinal == sectionIndex + 1,
                "rows": section.transactionIDs.count == expected.rows.count,
                "first-page": section.firstPage == expected.pages.first,
                "last-page": section.lastPage == (expected.lastPage ?? expected.pages.last),
                "opening": section.controls.first(where: { $0.kind == .openingBalance })?.money?.amount == decimal(expected.opening),
                "closing": section.controls.last(where: { $0.kind == .closingBalance })?.money?.amount == closing.map(decimal)
            ]
            guard headerChecks.values.allSatisfy({ $0 }) else {
                Issue.record("Relationship source \(source.sha256.prefix(12)) section \(sectionIndex + 1) mismatch: \(headerChecks.filter { !$0.value }.keys.sorted().joined(separator: ", ")).")
                throw Failure.sourceMismatch
            }
            for (index, expectedRow) in expected.rows.enumerated() {
                guard let actual = byID[section.transactionIDs[index]] else { throw Failure.sourceMismatch }
                let reference = source.family == "axis" ? expectedRow.cheque?.joined(separator: " ") : expectedRow.reference
                let debit = expectedRow.withdrawal.map(decimal) ?? .zero
                let credit = expectedRow.deposit.map(decimal) ?? .zero
                let checks = [
                    "date": actual.statementDate?.canonical == canonicalDate(expectedRow.date),
                    "value-date": actual.valueDate?.canonical == expectedRow.valueDate.map(canonicalDate),
                    "date-role": actual.financialDateRole == .transactionDate,
                    "native-currency": actual.money.currency.code == expected.currency,
                    "signed-amount": actual.money.amount == decimal(expectedRow.signed),
                    "withdrawal": actual.debitMoney?.amount == (debit == .zero ? nil : debit),
                    "deposit": actual.creditMoney?.amount == (credit == .zero ? nil : credit),
                    "balance": actual.runningBalanceMoney?.amount == decimal(expectedRow.balance),
                    "literal-balance": compact(actual.sourceProvenance.first?.literalRunningBalance ?? "") == compact(expectedRow.balance),
                    "narration": compact(actual.description) == compact(expectedRow.narration.joined(separator: " ")),
                    "reference": compact(actual.reference ?? "") == compact(reference ?? ""),
                    "source-page": actual.sourceProvenance.first?.sourcePage == expectedRow.page
                ]
                guard checks.values.allSatisfy({ $0 }) else {
                    Issue.record("Relationship source \(source.sha256.prefix(12)) section \(sectionIndex + 1) occurrence \(index + 1) mismatch: \(checks.filter { !$0.value }.keys.sorted().joined(separator: ", ")).")
                    throw Failure.sourceMismatch
                }
            }
        }
    }

    static func compareStored(_ sections: [BankStatementSectionPlanDTO],
                              transactions: [TransactionDTO], source: Source,
                              requiresFirstSource: Bool = true) throws {
        let sections = sections.sorted { $0.sectionOrdinal < $1.sectionOrdinal }
        guard sections.count == source.sections.count else { throw Failure.sourceMismatch }
        let byID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        for (index, pair) in zip(sections, source.sections).enumerated() {
            let (actual, expected) = pair
            let closing = expected.closing ?? expected.summary?.closing
            let headerMatches = actual.sectionOrdinal == index + 1 &&
                actual.identityPatterns.map(\.pattern) == [expected.account] &&
                compact(actual.productLabel) == compact(expected.product) &&
                actual.nativeCurrency == expected.currency &&
                actual.sourceEvidence.statementStartDateISO == canonicalDate(expected.start) &&
                actual.sourceEvidence.statementEndDateISO == canonicalDate(expected.end) &&
                actual.sourceEvidence.openingBalanceDecimal.map(decimal) == decimal(expected.opening) &&
                actual.sourceEvidence.closingBalanceDecimal.map(decimal) == closing.map(decimal) &&
                actual.sourceDetails?.firstPage == expected.pages.first &&
                actual.sourceDetails?.lastPage == (expected.lastPage ?? expected.pages.last) &&
                actual.sourceDetails?.recognizedRowCount == expected.rows.count &&
                actual.rows.count == expected.rows.count
            guard headerMatches else {
                Issue.record("Stored relationship source \(source.sha256.prefix(12)) section \(index + 1) envelope differs from its independent oracle.")
                throw Failure.sourceMismatch
            }
            for (ordinal, pair) in zip(actual.rows, expected.rows).enumerated() {
                let (row, expectedRow) = pair
                let canonical = try #require(byID[row.source.incomingTransactionId])
                let reference = source.family == "axis" ? expectedRow.cheque?.joined(separator: " ") : expectedRow.reference
                let money = try Money(canonicalDecimal: expectedRow.signed, currency: expected.currency)
                let balance = try Money(amount: decimal(expectedRow.balance), currency: CurrencyCode(expected.currency))
                let amountMinor = try money.minorUnits(), balanceMinor = try balance.minorUnits()
                let sourceMatches = row.source.postingDateISO == canonicalDate(expectedRow.date) &&
                    row.valueDateISO == expectedRow.valueDate.map(canonicalDate) &&
                    row.source.nativeCurrency == expected.currency &&
                    decimal(row.source.signedAmountDecimal) == money.amount &&
                    row.source.signedAmountMinor == amountMinor &&
                    decimal(row.source.runningBalanceDecimal) == balance.amount &&
                    row.source.runningBalanceMinor == balanceMinor &&
                    compact(row.literalNarration) == compact(expectedRow.narration.joined(separator: " ")) &&
                    compact(row.literalReference ?? "") == compact(reference ?? "") &&
                    compact(row.literalBalance) == compact(expectedRow.balance)
                let canonicalMatches = canonical.accountId == actual.accountId &&
                    canonical.postedDateISO == row.source.postingDateISO &&
                    canonical.valueDateISO == row.valueDateISO &&
                    canonical.financialDateRole == FinancialDateRole.transactionDate.rawValue &&
                    canonical.amountMinor == row.source.signedAmountMinor &&
                    canonical.nativeCurrency == row.source.nativeCurrency &&
                    (canonical.documentId != actual.documentId || canonical.runningBalanceMinor == row.source.runningBalanceMinor)
                let firstSourceMatches = !requiresFirstSource ||
                    (canonical.documentId == actual.documentId && canonical.importSessionId == actual.importSessionId &&
                     canonical.description == row.literalNarration && canonical.reference == row.literalReference &&
                     canonical.rawRows.first?.normalizedRowId == row.normalizedRowId &&
                     canonical.rawRows.first?.sourceOrdinal == row.sourceOrdinal)
                guard sourceMatches && canonicalMatches && firstSourceMatches else {
                    Issue.record("Stored relationship source \(source.sha256.prefix(12)) section \(index + 1) occurrence \(ordinal + 1) differs from its independent oracle.")
                    throw Failure.sourceMismatch
                }
            }
        }
    }

    /// Independently extracted rows/closings supply the expected runtime balance.
    /// Production DTOs supply only the already-compared section/account linkage.
    static func compareRuntimeBalances(_ snapshot: RepositoryRuntimeSnapshot, sections: [BankStatementSectionPlanDTO],
                                       sourcesBySessionID: [String: Source]) throws {
        let positions = DashboardPositionProjection.make(accounts: snapshot.accounts,
            transactions: snapshot.transactions, cardSnapshot: snapshot.cardSnapshot).flatMap(\.banks)
        for account in snapshot.accounts {
            var candidates: [(date: String, balance: Decimal, closing: Bool)] = []
            for section in sections where section.accountId == account.repositoryAccountId {
                let source = try #require(sourcesBySessionID[section.importSessionId])
                guard source.sections.indices.contains(section.sectionOrdinal - 1) else { throw Failure.sourceMismatch }
                let expected = source.sections[section.sectionOrdinal - 1]
                guard expected.currency == account.currencyCode else { throw Failure.sourceMismatch }
                if expected.rows.isEmpty {
                    if let closing = expected.closing ?? expected.summary?.closing {
                        candidates.append((canonicalDate(expected.end), decimal(closing), true))
                    }
                } else if let last = expected.rows.enumerated().max(by: {
                    (canonicalDate($0.element.date), $0.offset) < (canonicalDate($1.element.date), $1.offset)
                }) {
                    candidates.append((canonicalDate(last.element.date), decimal(last.element.balance), false))
                }
            }
            let latestDate = candidates.map(\.date).max()
            let latest = candidates.filter { $0.date == latestDate }
            let expected: Decimal?
            let expectedDate: String?
            if let first = latest.first, latest.filter({ !$0.closing }).count <= 1,
               latest.allSatisfy({ $0.balance == first.balance }) {
                expected = first.balance
                expectedDate = first.date
            } else {
                // Existing account presentation uses zero when no dated authority
                // can be selected. This does not create a source observation.
                expected = nil
                expectedDate = nil
            }
            let position = try #require(positions.first { $0.id == account.repositoryAccountId })
            let matches = account.currentBalance == (expected ?? .zero) && account.currentBalanceAsOfISO == expectedDate &&
                position.amount?.amount == expected && position.asOf?.canonical == expectedDate
            #expect(matches, "Account balance differs from independently extracted dated rows/zero-section closing.")
        }
    }

    private static func compact(_ value: String) -> String { value.filter { !$0.isWhitespace } }
    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")) ?? .nan
    }
    private static func canonicalDate(_ value: String) -> String {
        let parts = value.split(whereSeparator: { $0 == "/" || $0 == "-" })
        guard parts.count == 3 else { return "invalid" }
        return "\(parts[2])-\(parts[1])-\(parts[0])"
    }
}
