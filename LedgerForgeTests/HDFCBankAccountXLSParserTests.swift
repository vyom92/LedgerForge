import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct HDFCBankAccountXLSParserTests {
    @Test func oneProfileParsesBothSyntheticSourcesWithDistinctStrongIdentity() async throws {
        let annual = try HDFCBankAccountXLSParser().parse(
            document: await HDFCXLSFixtureTestSupport.normalized(
                HDFCXLSFixtureTestSupport.annualFixture
            )
        )
        let recent = try HDFCBankAccountXLSParser().parse(
            document: await HDFCXLSFixtureTestSupport.normalized(
                HDFCXLSFixtureTestSupport.recentFixture
            )
        )

        for document in [annual, recent] {
            #expect(document.parserName == "HDFC Bank Account XLS")
            #expect(document.metadata.institution == .hdfc)
            #expect(document.metadata.documentType == .bankAccount)
            #expect(document.metadata.fileFormat == .xls)
            #expect(document.bookedCurrency?.code == "INR")
            #expect(document.transactions.count == 4)
            #expect(document.financialIdentifiers.count == 1)
            #expect(document.financialIdentifiers[0].kind == .institutionAccountId)
            #expect(document.financialIdentifiers[0].verificationState == .verified)
            #expect(
                document.financialIdentifiers[0].provenance
                    == .institutionStructuredField
            )
            #expect(document.financialIdentifiers[0].normalizedValue.count == 14)
            #expect(document.transactions.allSatisfy {
                $0.sourceProvenance.first?.parserProfileID
                    == HDFCBankAccountXLSParser.profileID
                    && $0.sourceProvenance.first?.parserProfileVersion
                    == HDFCBankAccountXLSParser.profileVersion
            })
            #expect(document.transactions.map {
                $0.sourceProvenance.first?.sourceOrdinal
            } == [23, 24, 25, 26])
            #expect(document.transactions.contains { $0.statementDate != $0.valueDate })
            #expect(document.transactions.contains { $0.debit != nil })
            #expect(document.transactions.contains { $0.credit != nil })
            #expect(document.transactions.contains {
                ($0.debit?.exponent ?? 0) < 0 || ($0.credit?.exponent ?? 0) < 0
            })
            let references = document.transactions.compactMap(\.reference)
            #expect(Set(references).count < references.count)
            #expect(ImportValidator.validate(financialDocument: document).passed)
        }
        #expect(
            annual.financialIdentifiers[0].normalizedValue
                != recent.financialIdentifiers[0].normalizedValue
        )
        #expect(
            Set((annual.financialIdentifiers + recent.financialIdentifiers).map(
                \.normalizedValue
            )).count == 2
        )
    }

    @Test func missingMalformedAccountEvidenceFailsAndCustomerEvidenceIsNeverIdentity() async throws {
        let normalized = try await HDFCXLSFixtureTestSupport.normalized()
        let missing = HDFCXLSFixtureTestSupport.replacingFragment(
            in: normalized,
            sourceRow: 15
        ) { values in
            var values = values
            values[4] = "Account No :  NR Others"
            return values
        }
        #expect(
            throws: HDFCBankAccountXLSParserError.missingAccountNumber(sourceOrdinal: 15)
        ) {
            try HDFCBankAccountXLSParser().parse(document: missing)
        }

        let malformed = HDFCXLSFixtureTestSupport.replacingFragment(
            in: normalized,
            sourceRow: 15
        ) { values in
            var values = values
            values[4] = "Account No : INVALID NR Others"
            return values
        }
        #expect(
            throws: HDFCBankAccountXLSParserError.malformedAccountNumber(sourceOrdinal: 15)
        ) {
            try HDFCBankAccountXLSParser().parse(document: malformed)
        }

        let parsed = try HDFCBankAccountXLSParser().parse(document: normalized)
        let customerFragment = try #require(
            normalized.sourceContext.preTransactionFragments.first {
                $0.sourceOrdinal == 14
            }
        )
        let customerDigits = customerFragment.text.filter(\.isNumber)
        #expect(!customerDigits.isEmpty)
        #expect(!parsed.financialIdentifiers.map(\.normalizedValue).contains(customerDigits))
    }

    @Test func amountDirectionDatesAndRunningBalancesFailClosed() async throws {
        let normalized = try await HDFCXLSFixtureTestSupport.normalized()

        let both = HDFCXLSFixtureTestSupport.replacingNormalizedRow(
            in: normalized,
            sourceRow: 23
        ) { values in
            var values = values
            values[4] = "1.00"
            values[5] = "1.00"
            return values
        }
        #expect(
            throws: HDFCBankAccountXLSParserError.ambiguousDirection(sourceOrdinal: 23)
        ) {
            try HDFCBankAccountXLSParser().parse(document: both)
        }

        let neither = HDFCXLSFixtureTestSupport.replacingNormalizedRow(
            in: normalized,
            sourceRow: 23
        ) { values in
            var values = values
            values[4] = ""
            values[5] = ""
            return values
        }
        #expect(
            throws: HDFCBankAccountXLSParserError.missingDirection(sourceOrdinal: 23)
        ) {
            try HDFCBankAccountXLSParser().parse(document: neither)
        }

        let badDate = changingRow(normalized, column: 0, to: "31/02/26")
        #expect(
            throws: HDFCBankAccountXLSParserError.malformedDate(sourceOrdinal: 23)
        ) {
            try HDFCBankAccountXLSParser().parse(document: badDate)
        }

        let badValueDate = changingRow(normalized, column: 3, to: "31/02/26")
        #expect(
            throws: HDFCBankAccountXLSParserError.malformedValueDate(sourceOrdinal: 23)
        ) {
            try HDFCBankAccountXLSParser().parse(document: badValueDate)
        }

        let badBalance = changingRow(normalized, column: 6, to: "999999.00")
        #expect(
            throws: HDFCBankAccountXLSParserError.openingBalanceMismatch(sourceOrdinal: 23)
        ) {
            try HDFCBankAccountXLSParser().parse(document: badBalance)
        }
    }

    @Test func printedSummaryCountsTotalsAndClosingBalanceMustReconcile() async throws {
        let normalized = try await HDFCXLSFixtureTestSupport.normalized()
        let title = try #require(
            normalized.sourceContext.postTransactionFragments.first {
                $0.text.contains("STATEMENT SUMMARY  :-")
            }
        )

        let countMismatch = changingPostFragment(
            normalized,
            sourceRow: title.sourceOrdinal + 5,
            column: 4,
            to: "99"
        )
        #expect(throws: HDFCBankAccountXLSParserError.debitCountMismatch) {
            try HDFCBankAccountXLSParser().parse(document: countMismatch)
        }

        let totalMismatch = changingPostFragment(
            normalized,
            sourceRow: title.sourceOrdinal + 2,
            column: 4,
            to: "999999.00"
        )
        #expect(throws: HDFCBankAccountXLSParserError.debitTotalMismatch) {
            try HDFCBankAccountXLSParser().parse(document: totalMismatch)
        }

        let closingMismatch = changingPostFragment(
            normalized,
            sourceRow: title.sourceOrdinal + 2,
            column: 6,
            to: "999999.00"
        )
        #expect(throws: HDFCBankAccountXLSParserError.closingBalanceMismatch) {
            try HDFCBankAccountXLSParser().parse(document: closingMismatch)
        }
    }

    @Test func ordinaryDetectorClassifierAndRegistrySelectOnlyTheExactHDFCProfile() async throws {
        let raw = try await HDFCXLSFixtureTestSupport.read()
        let normalization = try HDFCBankAccountXLSNormalizer().normalize(rawDocument: raw)
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: raw)
        let classification = try await StatementClassificationDetector().classify(
            document: raw,
            institution: institution
        )
        let selection = StatementParserSelector().selectParser(
            for: normalization.document,
            institution: institution,
            classification: classification
        )

        #expect(institution.institutionCode == Institution.hdfc.rawValue)
        #expect(institution.reasons.count == 3)
        #expect(classification.documentType == .bankStatement)
        #expect(selection.parser is HDFCBankAccountXLSParser)
        #expect(selection.legacyMetadata.fileFormat == .xls)

        let nearMatch = HDFCXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 21,
            sourceColumn: 2,
            with: "Description"
        )
        let rejected = try await SignatureInstitutionDetector().detectInstitution(in: nearMatch)
        #expect(rejected.institutionCode == nil)
    }

    private func changingRow(
        _ document: NormalizedDocument,
        column: Int,
        to value: String
    ) -> NormalizedDocument {
        HDFCXLSFixtureTestSupport.replacingNormalizedRow(
            in: document,
            sourceRow: 23
        ) { values in
            var values = values
            values[column] = value
            return values
        }
    }

    private func changingPostFragment(
        _ document: NormalizedDocument,
        sourceRow: Int,
        column: Int,
        to value: String
    ) -> NormalizedDocument {
        HDFCXLSFixtureTestSupport.replacingFragment(
            in: document,
            sourceRow: sourceRow,
            postTransaction: true
        ) { values in
            var values = values
            values[column] = value
            return values
        }
    }
}
