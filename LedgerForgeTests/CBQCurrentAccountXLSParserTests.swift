import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CBQCurrentAccountXLSParserTests {
    @Test func exactProfilePreservesSignedQARRowsIdentityAndAbsentFields() async throws {
        let normalized = try await CBQXLSFixtureTestSupport.normalized()
        let document = try CBQCurrentAccountXLSParser().parse(document: normalized)

        #expect(document.parserName == "CBQ Current Account XLS")
        #expect(document.metadata.institution == .cbq)
        #expect(document.metadata.documentType == .bankAccount)
        #expect(document.metadata.fileFormat == .xls)
        #expect(document.bookedCurrency?.code == "QAR")
        #expect(document.declaredStatementPeriod == nil)
        #expect(document.transactions.count == 4)
        #expect(document.transactions.map(\.amount) == [2500, -125.50, -50, 25.25])
        #expect(document.transactions.map(\.balance) == [9100, 6725.50, 6851, 6901])
        #expect(document.transactions.map { $0.sourceProvenance[0].sourceOrdinal } == [8, 9, 10, 11])
        #expect(document.transactions.allSatisfy { $0.currency == "QAR" })
        #expect(document.transactions.allSatisfy { $0.valueDate == nil && $0.reference == nil })
        #expect(document.transactions.allSatisfy {
            $0.financialDateRole == .transactionDate
                && $0.statementTimezoneEvidence == .iana("Asia/Qatar")
                && $0.sourceProvenance[0].parserProfileID == CBQCurrentAccountXLSParser.profileID
                && $0.sourceProvenance[0].parserProfileVersion == CBQCurrentAccountXLSParser.profileVersion
        })
        #expect(document.transactions[0].credit == 2500 && document.transactions[0].debit == nil)
        #expect(document.transactions[1].debit == 125.50 && document.transactions[1].credit == nil)
        #expect(document.transactions.map(\.description) == [
            "Invented Salary Credit", "Invented Utility Debit",
            "Invented Transfer Debit", "Invented Refund Credit"
        ])
        #expect(document.financialIdentifiers.count == 1)
        #expect(document.financialIdentifiers[0].kind == .institutionAccountId)
        #expect(document.financialIdentifiers[0].verificationState == .verified)
        #expect(document.financialIdentifiers[0].provenance == .institutionStructuredField)
        #expect(document.financialIdentifiers[0].normalizedValue == "7000000000001")
    }

    @Test func rowAssociatedBalancesDoNotImposeSourceOrderRecurrenceOrInventSummary() async throws {
        let document = try CBQCurrentAccountXLSParser().parse(
            document: await CBQXLSFixtureTestSupport.normalized()
        )
        let validation = ImportValidator.validate(financialDocument: document)

        #expect(validation.passed)
        #expect(validation.issues.isEmpty)
        #expect(validation.openingBalanceMoney == nil)
        #expect(validation.closingBalanceMoney == nil)
        #expect(validation.debitTotal == 175.50)
        #expect(validation.creditTotal == 2525.25)
        #expect(document.transactions[0].statementDate == document.transactions[1].statementDate)
        #expect(document.transactions[0].balance != document.transactions[1].balance)
    }

    @Test func accountEvidenceIsExclusiveIdentityAndMalformedEvidenceFailsClosed() async throws {
        let normalized = try await CBQXLSFixtureTestSupport.normalized()
        let parsed = try CBQCurrentAccountXLSParser().parse(document: normalized)
        #expect(!parsed.financialIdentifiers.map(\.normalizedValue).contains("INVENTEDHOLDER"))

        let missing = CBQXLSFixtureTestSupport.replacingFragment(
            in: normalized,
            sourceRow: 4,
            with: "\t\t\t\t\t\t"
        )
        #expect(
            throws: CBQCurrentAccountXLSParserError.missingAccountNumber(sourceOrdinal: 4)
        ) {
            try CBQCurrentAccountXLSParser().parse(document: missing)
        }
        let malformed = CBQXLSFixtureTestSupport.replacingFragment(
            in: normalized,
            sourceRow: 4,
            with: "INVALID\t\t\t\t\t\t"
        )
        #expect(
            throws: CBQCurrentAccountXLSParserError.malformedAccountNumber(sourceOrdinal: 4)
        ) {
            try CBQCurrentAccountXLSParser().parse(document: malformed)
        }
        let changedHolder = CBQXLSFixtureTestSupport.replacingFragment(
            in: normalized,
            sourceRow: 5,
            with: "CURRENT ACCOUNT-RETAIL ANOTHER INVENTED HOLDER\t\t\t\t\t\t"
        )
        let changedParsed = try CBQCurrentAccountXLSParser().parse(document: changedHolder)
        #expect(changedParsed.financialIdentifiers == parsed.financialIdentifiers)
    }

    @Test func malformedZeroAndAscendingRowsFailClosed() async throws {
        let normalized = try await CBQXLSFixtureTestSupport.normalized()
        let malformed = changing(normalized, sourceRow: 8, column: 2, to: "amount")
        #expect(
            throws: CBQCurrentAccountXLSParserError.malformedMonetaryValue(sourceOrdinal: 8)
        ) {
            try CBQCurrentAccountXLSParser().parse(document: malformed)
        }
        let zero = changing(normalized, sourceRow: 8, column: 2, to: "0.00")
        #expect(throws: CBQCurrentAccountXLSParserError.zeroAmount(sourceOrdinal: 8)) {
            try CBQCurrentAccountXLSParser().parse(document: zero)
        }
        let badDate = changing(normalized, sourceRow: 8, column: 0, to: "31/02/2026")
        #expect(throws: CBQCurrentAccountXLSParserError.malformedDate(sourceOrdinal: 8)) {
            try CBQCurrentAccountXLSParser().parse(document: badDate)
        }
        let ascending = changing(normalized, sourceRow: 10, column: 0, to: "18/08/2026")
        #expect(throws: CBQCurrentAccountXLSParserError.ascendingDateOrder(sourceOrdinal: 10)) {
            try CBQCurrentAccountXLSParser().parse(document: ascending)
        }
    }

    @Test func detectorClassifierAndRegistryRequireTheExactCBQFamily() async throws {
        let raw = try await CBQXLSFixtureTestSupport.read()
        let result = try CBQCurrentAccountXLSNormalizer().normalize(rawDocument: raw)
        let detector = SignatureInstitutionDetector()
        let institution = try await detector.detectInstitution(in: raw)
        let classification = try await StatementClassificationDetector().classify(
            document: raw,
            institution: institution
        )
        let selection = StatementParserSelector().selectParser(
            for: result.document,
            institution: institution,
            classification: classification
        )

        #expect(institution.institutionCode == Institution.cbq.rawValue)
        #expect(institution.reasons.count == 3)
        #expect(classification.documentType == .bankStatement)
        #expect(selection.parser is CBQCurrentAccountXLSParser)
        #expect(selection.legacyMetadata.fileFormat == .xls)

        let insufficient = detector.detect(from: "Commercial Bank Transaction History")
        #expect(insufficient.metadata.institution == .unknown)
        let nearMatch = CBQXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 7,
            sourceColumn: 2,
            with: "Description"
        )
        let rejected = try await detector.detectInstitution(in: nearMatch)
        #expect(rejected.institutionCode == nil)
    }

    private func changing(
        _ document: NormalizedDocument,
        sourceRow: Int,
        column: Int,
        to value: String
    ) -> NormalizedDocument {
        CBQXLSFixtureTestSupport.replacingNormalizedRow(
            in: document,
            sourceRow: sourceRow
        ) { values in
            var values = values
            values[column] = value
            return values
        }
    }
}
