import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisPartialOverlapOracleTests {

    @Test func sanitisedPairMatchesIndependentExpectedOracleAndOverlapShape() throws {
        let expected = try PartialOverlapExpectation.load()
        let oracles = try expected.statements.map {
            try IndependentPartialOverlapOracle.load(fileName: $0.fixture)
        }

        #expect(expected.profileID == "axis.bank-account.csv")
        #expect(expected.profileVersion == "1")
        #expect(oracles.map(\.header) == [expected.physicalHeaderOrder, expected.physicalHeaderOrder])
        #expect(Set(oracles.map(\.accountIdentifier)).count == 1)
        #expect(expected.sameAccount)

        for (oracle, statement) in zip(oracles, expected.statements) {
            #expect(
                oracle.rows.map(\.financialProjection) ==
                statement.oracleRows.map(\.financialProjection)
            )
            #expect(oracle.rows.count == statement.transactionCount)
            #expect(oracle.statementStartDate == statement.statementStartDate)
            #expect(oracle.statementEndDate == statement.statementEndDate)
            #expect(oracle.rawSourceDRTotal == statement.rawSourceDRTotalDecimal)
            #expect(oracle.rawSourceCRTotal == statement.rawSourceCRTotalDecimal)
            #expect(oracle.canonicalDebitTotal == statement.canonicalDebitTotalDecimal)
            #expect(oracle.canonicalCreditTotal == statement.canonicalCreditTotalDecimal)
            #expect(oracle.openingBalance == statement.openingBalanceDecimal)
            #expect(oracle.closingBalance == statement.closingBalanceDecimal)
            #expect(oracle.completeReconciliation)
            #expect(statement.completeReconciliation)
            #expect(oracle.repeatedEventReferences.isEmpty)
        }

        let firstEvents = Dictionary(uniqueKeysWithValues: oracles[0].rows.map {
            ($0.eventReference, $0)
        })
        let secondEvents = Dictionary(uniqueKeysWithValues: oracles[1].rows.map {
            ($0.eventReference, $0)
        })
        let sharedReferences = Set(firstEvents.keys).intersection(secondEvents.keys)
        let laterOnlyReferences = Set(secondEvents.keys).subtracting(firstEvents.keys)
        let expectedSharedReferences = Set(
            expected.statements.flatMap(\.rows)
                .filter { $0.eventDisposition == "shared" }
                .map(\.eventReference)
        )
        let expectedLaterOnlyReferences = Set(
            expected.statements[1].rows
                .filter { $0.eventDisposition == "later-only" }
                .map(\.eventReference)
        )

        #expect(sharedReferences.count == expected.sharedEventCount)
        #expect(laterOnlyReferences.count == expected.uniqueLaterEventCount)
        #expect(sharedReferences == expectedSharedReferences)
        #expect(laterOnlyReferences == expectedLaterOnlyReferences)
        #expect(sharedReferences.allSatisfy {
            firstEvents[$0]?.eventFinancialProjection ==
            secondEvents[$0]?.eventFinancialProjection
        })
        #expect(oracles[1].rows.allSatisfy { row in row.isSupportedEvent })
        #expect(expected.sharedEventsFinanciallyAgree)
        #expect(expected.noRepeatedEventWithinStatement)
        #expect(expected.laterStatementContainsOnlySupportedEvents)
    }

    @Test func productionParserProjectionMatchesIndependentOracle() throws {
        let expected = try PartialOverlapExpectation.load()

        for statement in expected.statements {
            let oracle = try IndependentPartialOverlapOracle.load(fileName: statement.fixture)
            let parsed = try parseProductionFixture(fileName: statement.fixture)
            let productionRows = parsed.financialDocument.transactions.map {
                PartialOverlapOracleRow(
                    sourceOrdinal: $0.sourceProvenance[0].sourceOrdinal,
                    transactionDate: Self.dateString($0.statementDate!),
                    sourceColumn: $0.credit != nil ? "DR" : "CR",
                    rawSourceAmount: $0.credit ?? $0.debit!,
                    canonicalDirection: $0.credit != nil ? "credit" : "debit",
                    signedCanonicalAmount: $0.money.amount,
                    runningBalance: $0.balance!,
                    eventOperation: $0.verifiedAxisUPIEventEvidence!.operation.rawValue,
                    eventSubtype: $0.verifiedAxisUPIEventEvidence!.subtype.rawValue,
                    eventReference: $0.verifiedAxisUPIEventEvidence!.reference,
                    eventDisposition: ""
                )
            }

            #expect(productionRows.map(\.financialProjection) == oracle.rows.map(\.financialProjection))
            #expect(parsed.validation.passed)
            #expect(parsed.validation.debitTotal == oracle.canonicalDebitTotal)
            #expect(parsed.validation.creditTotal == oracle.canonicalCreditTotal)
            #expect(parsed.validation.openingBalance == oracle.openingBalance)
            #expect(parsed.validation.closingBalance == oracle.closingBalance)
            #expect(parsed.financialDocument.transactions.allSatisfy {
                $0.sourceProvenance[0].parserProfileID == "axis.bank-account.csv" &&
                $0.sourceProvenance[0].parserProfileVersion == "1"
            })
        }
    }

    @Test func declaredPeriodCanExtendBeyondTransactionBoundaries() throws {
        let text = """
        AXIS BANK
        Statement of Account No - 930000000000001 for the period (From : 01-01-2026 To : 31-01-2026)
        Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL
        05-01-2026,,UPI/P2A/100000000001/SYNTHETIC,100.00,,1100.00,001
        25-01-2026,,UPI/P2M/100000000002/SYNTHETIC,,50.00,1050.00,001
        """
        let oracle = try IndependentPartialOverlapOracle.load(text: text)

        #expect(oracle.statementStartDate == "01-01-2026")
        #expect(oracle.statementEndDate == "31-01-2026")
        #expect(oracle.rows.first?.transactionDate == "05-01-2026")
        #expect(oracle.rows.last?.transactionDate == "25-01-2026")
    }

    @Test func invalidPeriodEvidenceFailsClosed() {
        let validRows = """
        Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL
        05-01-2026,,UPI/P2A/100000000001/SYNTHETIC,100.00,,1100.00,001
        """
        let invalidPreambles = [
            "",
            "Statement of Account No - 930000000000001 for the period (From : 99-01-2026 To : 31-01-2026)",
            """
            Statement of Account No - 930000000000001 for the period (From : 01-01-2026 To : 31-01-2026)
            Statement of Account No - 930000000000001 for the period (From : 01-01-2026 To : 31-01-2026)
            """,
            """
            Statement of Account No - 930000000000001 for the period (From : 01-01-2026 To : 31-01-2026)
            Statement of Account No - 930000000000001 for the period (From : 02-01-2026 To : 31-01-2026)
            """
        ]

        for preamble in invalidPreambles {
            #expect(throws: PartialOverlapOracleError.invalidStatementPeriod) {
                try IndependentPartialOverlapOracle.load(
                    text: ["AXIS BANK", preamble, validRows].joined(separator: "\n")
                )
            }
        }
    }

    private func parseProductionFixture(fileName: String) throws -> ParsedPartialOverlapFixture {
        let url = FixtureLocator.axisCSV(fileName)
        let text = try CSVReader().read(from: url)
        let document = CSVAnalyzer().analyze(text: text, fileURL: url)
        let metadata = InstitutionDetector().detect(from: text)
        let normalization = CSVNormalizer().normalizeWithSourceContext(
            text: text,
            document: document
        )
        let parser = try #require(
            StatementParserRegistry.shared.parser(for: document, metadata: metadata)
        )
        let financialDocument = try parser.parse(
            document: NormalizedDocument(
                document: document,
                metadata: metadata,
                rows: normalization.rows,
                header: normalization.header,
                sourceContext: normalization.sourceContext
            )
        )
        return ParsedPartialOverlapFixture(
            financialDocument: financialDocument,
            validation: ImportValidator.validate(financialDocument: financialDocument)
        )
    }

    private static func dateString(_ date: StatementDate) -> String {
        String(format: "%02d-%02d-%04d", date.day, date.month, date.year)
    }
}

private struct ParsedPartialOverlapFixture {
    let financialDocument: FinancialDocument
    let validation: ImportValidationResult
}

private struct IndependentPartialOverlapOracle {
    let header: [String]
    let accountIdentifier: String
    let statementStartDate: String
    let statementEndDate: String
    let rows: [PartialOverlapOracleRow]
    let rawSourceDRTotal: Decimal
    let rawSourceCRTotal: Decimal
    let canonicalDebitTotal: Decimal
    let canonicalCreditTotal: Decimal
    let openingBalance: Decimal
    let closingBalance: Decimal
    let completeReconciliation: Bool
    let repeatedEventReferences: Set<String>

    static func load(fileName: String) throws -> Self {
        let text = try String(
            contentsOf: FixtureLocator.axisCSV(fileName),
            encoding: .utf8
        )
        return try load(text: text)
    }

    static func load(text: String) throws -> Self {
        let lines = text.components(separatedBy: .newlines)
        let headerOffset = try #require(lines.firstIndex {
            $0.split(separator: ",").map(String.init) == [
                "Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"
            ]
        })
        let header = lines[headerOffset].split(
            separator: ",",
            omittingEmptySubsequences: false
        ).map(String.init)
        let accountPrefix = "Statement of Account No - "
        let periodMarker = " for the period ("
        let accountLines = lines.filter { $0.hasPrefix(accountPrefix) }
        guard accountLines.count == 1 else {
            throw PartialOverlapOracleError.invalidStatementPeriod
        }
        let accountLine = accountLines[0]
        let accountRemainder = accountLine.dropFirst(accountPrefix.count)
        guard let periodRange = accountRemainder.range(of: periodMarker) else {
            throw PartialOverlapOracleError.invalidStatementPeriod
        }
        let accountIdentifier = String(accountRemainder[..<periodRange.lowerBound])
        let periodText = accountRemainder[periodRange.upperBound...]
        let periodPattern = try NSRegularExpression(
            pattern: #"^From\s*:\s*(\d{2}-\d{2}-\d{4})\s+To\s*:\s*(\d{2}-\d{2}-\d{4})\)\s*$"#
        )
        let periodString = String(periodText)
        let periodNSRange = NSRange(periodString.startIndex..., in: periodString)
        guard let periodMatch = periodPattern.firstMatch(
            in: periodString,
            range: periodNSRange
        ), periodMatch.numberOfRanges == 3,
              let startRange = Range(periodMatch.range(at: 1), in: periodString),
              let endRange = Range(periodMatch.range(at: 2), in: periodString) else {
            throw PartialOverlapOracleError.invalidStatementPeriod
        }
        let statementStartDate = String(periodString[startRange])
        let statementEndDate = String(periodString[endRange])
        guard let startDate = Self.gregorianDate(statementStartDate),
              let endDate = Self.gregorianDate(statementEndDate),
              startDate <= endDate else {
            throw PartialOverlapOracleError.invalidStatementPeriod
        }
        let datePattern = try NSRegularExpression(pattern: #"^\d{2}-\d{2}-\d{4}$"#)
        var rows: [PartialOverlapOracleRow] = []

        for (offset, line) in lines.dropFirst(headerOffset + 1).enumerated() {
            let cells = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            guard cells.count == 7 else { continue }
            let dateRange = NSRange(cells[0].startIndex..., in: cells[0])
            guard datePattern.firstMatch(in: cells[0], range: dateRange) != nil else { continue }
            let sourceDR = Self.decimal(cells[3])
            let sourceCR = Self.decimal(cells[4])
            guard (sourceDR == nil) != (sourceCR == nil) else {
                throw PartialOverlapOracleError.invalidDirectionOccupancy
            }
            let sourceColumn = sourceDR != nil ? "DR" : "CR"
            let rawAmount = try #require(sourceDR ?? sourceCR)
            let canonicalDirection = sourceDR != nil ? "credit" : "debit"
            let signedAmount = sourceDR != nil ? rawAmount : -rawAmount
            let components = cells[2].split(
                separator: "/",
                omittingEmptySubsequences: false
            ).map(String.init)
            guard components.count >= 4,
                  components[0] == "UPI",
                  ["P2A", "P2M"].contains(components[1]),
                  components[2].count == 12,
                  components[2].allSatisfy(\.isNumber) else {
                throw PartialOverlapOracleError.unsupportedEvent
            }
            rows.append(
                PartialOverlapOracleRow(
                    sourceOrdinal: headerOffset + offset + 2,
                    transactionDate: cells[0],
                    sourceColumn: sourceColumn,
                    rawSourceAmount: rawAmount,
                    canonicalDirection: canonicalDirection,
                    signedCanonicalAmount: signedAmount,
                    runningBalance: try #require(Self.decimal(cells[5])),
                    eventOperation: components[1].lowercased(),
                    eventSubtype: sourceDR != nil ? "credit-adjustment" : "posting",
                    eventReference: components[2],
                    eventDisposition: ""
                )
            )
        }

        let first = try #require(rows.first)
        let openingBalance = first.runningBalance - first.signedCanonicalAmount
        var priorBalance = openingBalance
        var reconciles = true
        for row in rows {
            reconciles = reconciles &&
                priorBalance + row.signedCanonicalAmount == row.runningBalance
            priorBalance = row.runningBalance
        }
        let references = rows.map(\.eventReference)
        let repeatedReferences = Set(references.filter {
            reference in references.filter { $0 == reference }.count > 1
        })

        return Self(
            header: header,
            accountIdentifier: accountIdentifier,
            statementStartDate: statementStartDate,
            statementEndDate: statementEndDate,
            rows: rows,
            rawSourceDRTotal: rows.filter { $0.sourceColumn == "DR" }
                .reduce(0) { $0 + $1.rawSourceAmount },
            rawSourceCRTotal: rows.filter { $0.sourceColumn == "CR" }
                .reduce(0) { $0 + $1.rawSourceAmount },
            canonicalDebitTotal: rows.filter { $0.canonicalDirection == "debit" }
                .reduce(0) { $0 + $1.rawSourceAmount },
            canonicalCreditTotal: rows.filter { $0.canonicalDirection == "credit" }
                .reduce(0) { $0 + $1.rawSourceAmount },
            openingBalance: openingBalance,
            closingBalance: try #require(rows.last?.runningBalance),
            completeReconciliation: reconciles,
            repeatedEventReferences: repeatedReferences
        )
    }

    private static func decimal(_ value: String) -> Decimal? {
        guard !value.isEmpty else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func gregorianDate(_ value: String) -> Date? {
        let components = value.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: components[2],
            month: components[1],
            day: components[0]
        )
        guard let date = calendar.date(from: dateComponents),
              calendar.dateComponents([.year, .month, .day], from: date) ==
              DateComponents(year: components[2], month: components[1], day: components[0]) else {
            return nil
        }
        return date
    }
}

private enum PartialOverlapOracleError: Error, Equatable {
    case invalidDirectionOccupancy
    case invalidStatementPeriod
    case unsupportedEvent
}

private struct PartialOverlapOracleRow: Equatable {
    let sourceOrdinal: Int
    let transactionDate: String
    let sourceColumn: String
    let rawSourceAmount: Decimal
    let canonicalDirection: String
    let signedCanonicalAmount: Decimal
    let runningBalance: Decimal
    let eventOperation: String
    let eventSubtype: String
    let eventReference: String
    let eventDisposition: String

    var isSupportedEvent: Bool {
        ["p2a", "p2m"].contains(eventOperation) &&
        eventReference.count == 12 &&
        ["posting", "credit-adjustment"].contains(eventSubtype)
    }

    var financialProjection: PartialOverlapFinancialProjection {
        PartialOverlapFinancialProjection(
            sourceOrdinal: sourceOrdinal,
            transactionDate: transactionDate,
            sourceColumn: sourceColumn,
            rawSourceAmount: rawSourceAmount,
            canonicalDirection: canonicalDirection,
            signedCanonicalAmount: signedCanonicalAmount,
            runningBalance: runningBalance,
            eventOperation: eventOperation,
            eventSubtype: eventSubtype,
            eventReference: eventReference
        )
    }

    var eventFinancialProjection: PartialOverlapEventFinancialProjection {
        PartialOverlapEventFinancialProjection(
            transactionDate: transactionDate,
            sourceColumn: sourceColumn,
            rawSourceAmount: rawSourceAmount,
            canonicalDirection: canonicalDirection,
            signedCanonicalAmount: signedCanonicalAmount,
            runningBalance: runningBalance,
            eventOperation: eventOperation,
            eventSubtype: eventSubtype,
            eventReference: eventReference
        )
    }
}

private struct PartialOverlapFinancialProjection: Equatable {
    let sourceOrdinal: Int
    let transactionDate: String
    let sourceColumn: String
    let rawSourceAmount: Decimal
    let canonicalDirection: String
    let signedCanonicalAmount: Decimal
    let runningBalance: Decimal
    let eventOperation: String
    let eventSubtype: String
    let eventReference: String
}

private struct PartialOverlapEventFinancialProjection: Equatable {
    let transactionDate: String
    let sourceColumn: String
    let rawSourceAmount: Decimal
    let canonicalDirection: String
    let signedCanonicalAmount: Decimal
    let runningBalance: Decimal
    let eventOperation: String
    let eventSubtype: String
    let eventReference: String
}

private struct PartialOverlapExpectation: Decodable {
    let profileID: String
    let profileVersion: String
    let physicalHeaderOrder: [String]
    let sameAccount: Bool
    let sharedEventCount: Int
    let uniqueLaterEventCount: Int
    let sharedEventsFinanciallyAgree: Bool
    let noRepeatedEventWithinStatement: Bool
    let laterStatementContainsOnlySupportedEvents: Bool
    let statements: [Statement]

    struct Statement: Decodable {
        let fixture: String
        let statementStartDate: String
        let statementEndDate: String
        let transactionCount: Int
        let rawSourceDRTotal: String
        let rawSourceCRTotal: String
        let canonicalDebitTotal: String
        let canonicalCreditTotal: String
        let openingBalance: String
        let closingBalance: String
        let completeReconciliation: Bool
        let rows: [Row]

        var rawSourceDRTotalDecimal: Decimal { Decimal(string: rawSourceDRTotal)! }
        var rawSourceCRTotalDecimal: Decimal { Decimal(string: rawSourceCRTotal)! }
        var canonicalDebitTotalDecimal: Decimal { Decimal(string: canonicalDebitTotal)! }
        var canonicalCreditTotalDecimal: Decimal { Decimal(string: canonicalCreditTotal)! }
        var openingBalanceDecimal: Decimal { Decimal(string: openingBalance)! }
        var closingBalanceDecimal: Decimal { Decimal(string: closingBalance)! }
        var oracleRows: [PartialOverlapOracleRow] { rows.map(\.oracleRow) }

        private enum CodingKeys: String, CodingKey {
            case fixture
            case statementStartDate = "statement_start_date"
            case statementEndDate = "statement_end_date"
            case transactionCount = "transaction_count"
            case rawSourceDRTotal = "raw_source_dr_total"
            case rawSourceCRTotal = "raw_source_cr_total"
            case canonicalDebitTotal = "canonical_debit_total"
            case canonicalCreditTotal = "canonical_credit_total"
            case openingBalance = "opening_balance"
            case closingBalance = "closing_balance"
            case completeReconciliation = "complete_reconciliation"
            case rows
        }
    }

    struct Row: Decodable {
        let sourceOrdinal: Int
        let transactionDate: String
        let sourceColumn: String
        let rawSourceAmount: String
        let canonicalDirection: String
        let signedCanonicalAmount: String
        let runningBalance: String
        let eventOperation: String
        let eventSubtype: String
        let eventReference: String
        let eventDisposition: String

        var oracleRow: PartialOverlapOracleRow {
            PartialOverlapOracleRow(
                sourceOrdinal: sourceOrdinal,
                transactionDate: transactionDate,
                sourceColumn: sourceColumn,
                rawSourceAmount: Decimal(string: rawSourceAmount)!,
                canonicalDirection: canonicalDirection,
                signedCanonicalAmount: Decimal(string: signedCanonicalAmount)!,
                runningBalance: Decimal(string: runningBalance)!,
                eventOperation: eventOperation,
                eventSubtype: eventSubtype,
                eventReference: eventReference,
                eventDisposition: eventDisposition
            )
        }

        private enum CodingKeys: String, CodingKey {
            case sourceOrdinal = "source_ordinal"
            case transactionDate = "transaction_date"
            case sourceColumn = "source_column"
            case rawSourceAmount = "raw_source_amount"
            case canonicalDirection = "canonical_direction"
            case signedCanonicalAmount = "signed_canonical_amount"
            case runningBalance = "running_balance"
            case eventOperation = "event_operation"
            case eventSubtype = "event_subtype"
            case eventReference = "event_reference"
            case eventDisposition = "event_disposition"
        }
    }

    static func load() throws -> Self {
        let data = try Data(
            contentsOf: FixtureLocator.axisExpected(
                "axis_bank_partial_overlap.expected.json"
            )
        )
        return try JSONDecoder().decode(Self.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case profileVersion = "profile_version"
        case physicalHeaderOrder = "physical_header_order"
        case sameAccount = "same_account"
        case sharedEventCount = "shared_event_count"
        case uniqueLaterEventCount = "unique_later_event_count"
        case sharedEventsFinanciallyAgree = "shared_events_financially_agree"
        case noRepeatedEventWithinStatement = "no_repeated_event_within_statement"
        case laterStatementContainsOnlySupportedEvents = "later_statement_contains_only_supported_events"
        case statements
    }
}
