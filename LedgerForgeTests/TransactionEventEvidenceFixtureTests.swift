import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct TransactionEventEvidenceFixtureTests {

    @Test func sanitizedOverlapFixturePreservesFinancialTruthAndAccountIdentity() throws {
        let fixture = try Self.loadFixture(
            csv: "axis_bank_nre_account_statement_overlap.csv",
            expected: "axis_bank_nre_account_statement_overlap.expected.json"
        )
        let baseline = try Self.parseFixture("axis_bank_nre_account_statement_baseline.csv")
        let overlap = try Self.parseFixture("axis_bank_nre_account_statement_overlap.csv")

        #expect(overlap.metadata.institution.rawValue == fixture.institution)
        #expect(overlap.metadata.documentType.rawValue == fixture.documentClassification)
        #expect(String(describing: type(of: overlap.parser)) == fixture.expectedParser)
        #expect(overlap.financialDocument.transactions.count == fixture.transactionCount)
        #expect(overlap.financialDocument.transactions.first?.currency == fixture.currency)
        #expect(overlap.validation.debitTotal == fixture.debitTotal)
        #expect(overlap.validation.creditTotal == fixture.creditTotal)
        #expect(overlap.validation.openingBalance == fixture.openingBalance)
        #expect(overlap.validation.closingBalance == fixture.closingBalance)
        #expect(fixture.computedFinalBalance == fixture.closingBalance)
        #expect(overlap.validation.passed)

        let baselineIdentifier = try #require(baseline.financialDocument.financialIdentifiers.first)
        let overlapIdentifier = try #require(overlap.financialDocument.financialIdentifiers.first)
        #expect(overlap.financialDocument.financialIdentifiers.count == fixture.verifiedAccountIdentifier.count)
        #expect(overlapIdentifier.kind.rawValue == fixture.verifiedAccountIdentifier.kind)
        #expect(overlapIdentifier.strength.rawValue == fixture.verifiedAccountIdentifier.strength)
        #expect(overlapIdentifier.verificationState.rawValue == fixture.verifiedAccountIdentifier.verificationState)
        #expect(overlapIdentifier.provenance.rawValue == fixture.verifiedAccountIdentifier.provenance)
        #expect(overlapIdentifier.normalizedValue == baselineIdentifier.normalizedValue)
        #expect(fixture.verifiedAccountIdentifier.matchesSanitizedBaseline)
    }

    @Test func sanitizedFixturesPreserveVerifiedOverlapAndNewEventRelationships() throws {
        let fixture = try Self.loadFixture(
            csv: "axis_bank_nre_account_statement_overlap.csv",
            expected: "axis_bank_nre_account_statement_overlap.expected.json"
        )
        let baselineRows = try Self.transactionRows("axis_bank_nre_account_statement_baseline.csv")
        let overlapRows = try Self.transactionRows("axis_bank_nre_account_statement_overlap.csv")
        let baselineSet = Set(baselineRows)
        let overlapSet = Set(overlapRows)
        let shared = baselineSet.intersection(overlapSet)

        #expect(baselineRows.count == 81)
        #expect(overlapRows.count == fixture.transactionCount)
        #expect(shared.count == fixture.crossFixtureRelationships.completeRowsShared)
        #expect(baselineSet.subtracting(overlapSet).count == fixture.crossFixtureRelationships.rowsUniqueToBaseline)
        #expect(overlapSet.subtracting(baselineSet).count == fixture.crossFixtureRelationships.rowsUniqueToOverlap)
        #expect(fixture.crossFixtureRelationships.newEventSymbolicLabels.count == 1)

        let sharedUPIReferences = Set(shared.compactMap(Self.upiReference))
        let acceptedUPI = try #require(
            fixture.candidateReferenceFamilies.first { $0.family == "axis-upi-reference" }
        )
        #expect(acceptedUPI.acceptedForADR031)
        #expect(sharedUPIReferences.count == acceptedUPI.sharedEventCount)
        #expect(fixture.crossFixtureRelationships.sharedUPISymbolicLabels.count == sharedUPIReferences.count)
    }

    @Test func expectedEvidenceRecordsObservedUPIPostingAndCreditAdjustmentReuse() throws {
        let fixture = try Self.loadFixture(
            csv: "axis_bank_nre_account_statement_overlap.csv",
            expected: "axis_bank_nre_account_statement_overlap.expected.json"
        )
        #expect(fixture.crossFixtureRelationships.postingAdjustmentSharedReferenceGroups == 1)
        #expect(fixture.crossFixtureRelationships.postingAdjustmentIdentityOutcome ==
            "distinct events separated by deterministic source subtype")
        #expect(fixture.crossFixtureRelationships.postingAdjustmentFixtureRepresentation ==
            "symbolic relationship verified from original source evidence because the byte-frozen baseline does not encode the original token reuse")
    }

    @Test func sanitizedOverlapFixtureContainsOnlyApprovedPrivacySafeEvidence() throws {
        let fixture = try Self.loadFixture(
            csv: "axis_bank_nre_account_statement_overlap.csv",
            expected: "axis_bank_nre_account_statement_overlap.expected.json"
        )
        let text = try CSVReader().read(from: fixture.csvURL)

        #expect(text.contains("Name :- TEST CUSTOMER"))
        #expect(text.contains("Statement of Account No - 920000000000000"))
        #expect(text.contains("TEST-INSTRUMENT-NEW-001"))
        #expect(!text.contains("AcctStatement_"))
        #expect(fixture.privacyAssertions.usesFictionalAccountIdentifier)
        #expect(fixture.privacyAssertions.usesFictionalCustomerMetadata)
        #expect(fixture.privacyAssertions.containsNoOriginalTransactionReference)
        #expect(fixture.privacyAssertions.containsNoOriginalCounterpartyIdentity)
        #expect(fixture.privacyAssertions.containsNoPrivateMapping)
    }

    private static func parseFixture(_ fileName: String) throws -> ParsedEvidenceFixture {
        let url = FixtureLocator.axisCSV(fileName)
        let text = try CSVReader().read(from: url)
        let document = CSVAnalyzer().analyze(text: text, fileURL: url)
        let metadata = InstitutionDetector().detect(from: text)
        let normalization = CSVNormalizer().normalizeWithSourceContext(text: text, document: document)
        let parser = try #require(StatementParserRegistry.shared.parser(for: document, metadata: metadata))
        let financialDocument = try parser.parse(
            document: NormalizedDocument(
                document: document,
                metadata: metadata,
                rows: normalization.rows,
                sourceContext: normalization.sourceContext
            )
        )
        return ParsedEvidenceFixture(
            metadata: metadata,
            parser: parser,
            financialDocument: financialDocument,
            validation: ImportValidator.validate(financialDocument: financialDocument)
        )
    }

    private static func transactionRows(_ fileName: String) throws -> [[String]] {
        let url = FixtureLocator.axisCSV(fileName)
        let text = try CSVReader().read(from: url)
        let document = CSVAnalyzer().analyze(text: text, fileURL: url)
        let rows = CSVNormalizer().normalize(text: text, document: document)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return rows.compactMap { row in
            guard let date = row.values.first, formatter.date(from: date) != nil else {
                return nil
            }
            return row.values
        }
    }

    private static func upiReference(_ row: [String]) -> String? {
        guard row.count >= 3 else { return nil }
        let components = row[2].split(separator: "/", omittingEmptySubsequences: false)
        guard components.count > 2, components[0] == "UPI" else { return nil }
        let candidate = String(components[2])
        guard candidate.count == 12, candidate.allSatisfy(\.isNumber) else { return nil }
        return candidate
    }

    private static func loadFixture(csv: String, expected: String) throws -> Sprint40AxisOverlapExpectation {
        let url = FixtureLocator.axisExpected(expected)
        let data = try Data(contentsOf: url)
        var result = try JSONDecoder().decode(Sprint40AxisOverlapExpectation.self, from: data)
        result.csvURL = FixtureLocator.axisCSV(csv)
        return result
    }
}

private struct ParsedEvidenceFixture {
    let metadata: DocumentMetadata
    let parser: any StatementParser
    let financialDocument: FinancialDocument
    let validation: ImportValidationResult
}

private struct Sprint40AxisOverlapExpectation: Decodable {
    var csvURL: URL!
    let institution: String
    let documentClassification: String
    let currency: String
    let expectedParser: String
    let transactionCount: Int
    let openingBalance: Decimal
    let closingBalance: Decimal
    let debitTotal: Decimal
    let creditTotal: Decimal
    let computedFinalBalance: Decimal
    let verifiedAccountIdentifier: VerifiedAccountIdentifier
    let candidateReferenceFamilies: [CandidateReferenceFamily]
    let crossFixtureRelationships: CrossFixtureRelationships
    let privacyAssertions: PrivacyAssertions

    struct VerifiedAccountIdentifier: Decodable {
        let count: Int
        let kind: String
        let strength: String
        let verificationState: String
        let provenance: String
        let matchesSanitizedBaseline: Bool
    }

    struct CandidateReferenceFamily: Decodable {
        let family: String
        let sharedEventCount: Int
        let acceptedForADR031: Bool
    }

    struct CrossFixtureRelationships: Decodable {
        let completeRowsShared: Int
        let rowsUniqueToBaseline: Int
        let rowsUniqueToOverlap: Int
        let sharedUPISymbolicLabels: [String]
        let newEventSymbolicLabels: [String]
        let postingAdjustmentSharedReferenceGroups: Int
        let postingAdjustmentIdentityOutcome: String
        let postingAdjustmentFixtureRepresentation: String
    }

    struct PrivacyAssertions: Decodable {
        let usesFictionalAccountIdentifier: Bool
        let usesFictionalCustomerMetadata: Bool
        let containsNoOriginalTransactionReference: Bool
        let containsNoOriginalCounterpartyIdentity: Bool
        let containsNoPrivateMapping: Bool
    }

    private enum CodingKeys: String, CodingKey {
        case institution
        case documentClassification = "document_classification"
        case currency
        case expectedParser = "expected_parser"
        case transactionCount = "transaction_count"
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case debitTotal = "debit_total"
        case creditTotal = "credit_total"
        case computedFinalBalance = "computed_final_balance"
        case verifiedAccountIdentifier = "verified_account_identifier"
        case candidateReferenceFamilies = "candidate_reference_families"
        case crossFixtureRelationships = "cross_fixture_relationships"
        case privacyAssertions = "privacy_assertions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        institution = try container.decode(String.self, forKey: .institution)
        documentClassification = try container.decode(String.self, forKey: .documentClassification)
        currency = try container.decode(String.self, forKey: .currency)
        expectedParser = try container.decode(String.self, forKey: .expectedParser)
        transactionCount = try container.decode(Int.self, forKey: .transactionCount)
        openingBalance = try Self.decimal(container, .openingBalance)
        closingBalance = try Self.decimal(container, .closingBalance)
        debitTotal = try Self.decimal(container, .debitTotal)
        creditTotal = try Self.decimal(container, .creditTotal)
        computedFinalBalance = try Self.decimal(container, .computedFinalBalance)
        verifiedAccountIdentifier = try container.decode(VerifiedAccountIdentifier.self, forKey: .verifiedAccountIdentifier)
        candidateReferenceFamilies = try container.decode([CandidateReferenceFamily].self, forKey: .candidateReferenceFamilies)
        crossFixtureRelationships = try container.decode(CrossFixtureRelationships.self, forKey: .crossFixtureRelationships)
        privacyAssertions = try container.decode(PrivacyAssertions.self, forKey: .privacyAssertions)
    }

    private static func decimal(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) throws -> Decimal {
        let value = try container.decode(String.self, forKey: key)
        return try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}

private extension Sprint40AxisOverlapExpectation.VerifiedAccountIdentifier {
    enum CodingKeys: String, CodingKey {
        case count
        case kind
        case strength
        case verificationState = "verification_state"
        case provenance
        case matchesSanitizedBaseline = "matches_sanitized_baseline"
    }
}

private extension Sprint40AxisOverlapExpectation.CandidateReferenceFamily {
    enum CodingKeys: String, CodingKey {
        case family
        case sharedEventCount = "shared_event_count"
        case acceptedForADR031 = "accepted_for_adr_031"
    }
}

private extension Sprint40AxisOverlapExpectation.CrossFixtureRelationships {
    enum CodingKeys: String, CodingKey {
        case completeRowsShared = "complete_rows_shared"
        case rowsUniqueToBaseline = "rows_unique_to_baseline"
        case rowsUniqueToOverlap = "rows_unique_to_overlap"
        case sharedUPISymbolicLabels = "shared_upi_symbolic_labels"
        case newEventSymbolicLabels = "new_event_symbolic_labels"
        case postingAdjustmentSharedReferenceGroups = "posting_adjustment_shared_reference_groups"
        case postingAdjustmentIdentityOutcome = "posting_adjustment_identity_outcome"
        case postingAdjustmentFixtureRepresentation = "posting_adjustment_fixture_representation"
    }
}

private extension Sprint40AxisOverlapExpectation.PrivacyAssertions {
    enum CodingKeys: String, CodingKey {
        case usesFictionalAccountIdentifier = "uses_fictional_account_identifier"
        case usesFictionalCustomerMetadata = "uses_fictional_customer_metadata"
        case containsNoOriginalTransactionReference = "contains_no_original_transaction_reference"
        case containsNoOriginalCounterpartyIdentity = "contains_no_original_counterparty_identity"
        case containsNoPrivateMapping = "contains_no_private_mapping"
    }
}
