import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct AxisNROFixtureEvidenceTests {
    private static let r1CSV = "axis_bank_nro_account_statement_baseline_csv_source_truth.csv"
    private static let r2CSV = "axis_bank_nro_account_statement_extended.csv"
    private static let r1PairExpected = "axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.expected.json"

    @Test func sourceFaithfulFixturesExistAndStructuredEvidenceDecodes() throws {
        let urls = [
            FixtureLocator.axisCSV(Self.r1CSV), FixtureLocator.axisCSV(Self.r2CSV),
            FixtureLocator.axisPDF("axis_bank_nro_account_statement_baseline.pdf"), FixtureLocator.axisPDF("axis_bank_nro_account_statement_extended.pdf"),
            FixtureLocator.axisXLS("axis_bank_nro_account_statement_baseline.xls"), FixtureLocator.axisXLS("axis_bank_nro_account_statement_extended.xls"),
            FixtureLocator.axisExpected("axis_bank_nro_account_statement_baseline_csv_source_truth.expected.json"), FixtureLocator.axisExpected(Self.r1PairExpected), FixtureLocator.axisExpected("axis_bank_nro_account_statement_extended.expected.json"),
            FixtureLocator.axisManifest("axis_bank_nro_account_statement_baseline_csv_source_truth.manifest.json"), FixtureLocator.axisManifest("axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.manifest.json"), FixtureLocator.axisManifest("axis_bank_nro_account_statement_extended.manifest.json")
        ]
        #expect(urls.allSatisfy(FixtureLocator.fileExists))
        let csv = try Self.expected("axis_bank_nro_account_statement_baseline_csv_source_truth.expected.json")
        let pair = try Self.expected(Self.r1PairExpected)
        let extended = try Self.expected("axis_bank_nro_account_statement_extended.expected.json")
        #expect(csv.transactionCount == 17)
        #expect(pair.transactionCount == 16)
        #expect(extended.transactionCount == 20)
        for name in ["axis_bank_nro_account_statement_baseline_csv_source_truth.manifest.json", "axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.manifest.json", "axis_bank_nro_account_statement_extended.manifest.json"] {
            let manifest = try Self.manifest(name)
            #expect(manifest.fixtureClass == "source-faithful sanitized fixture")
            #expect(manifest.candidateStatus == "validated")
            #expect(manifest.provenance.origin == "institution_supplied" && manifest.provenance.acquisition == "user_downloaded" && manifest.provenance.verification == "owner_attested")
            #expect(manifest.privacy.allTrue)
            #expect(manifest.overlapBasis.classification == "financial_projection" && !manifest.overlapBasis.textualEqualityRequired)
        }
    }

    @Test func sourceFaithfulCSVOverlapPreservesDivergenceWithoutSyntheticAlignment() throws {
        let r1 = try Self.rows(Self.r1CSV)
        let r2 = try Self.rows(Self.r2CSV)
        #expect(r1.allSatisfy { $0.count == 7 && !$0[1].isEmpty && !$0[2].isEmpty })
        #expect(r2.allSatisfy { $0.count == 7 && !$0[1].isEmpty && !$0[2].isEmpty })
        let r1Financial = r1.map(Self.financialProjection)
        let r2Financial = r2.map(Self.financialProjection)
        let shared = Set(r1Financial).intersection(Set(r2Financial))
        #expect(r1.count == 17, "Range 1 CSV must retain its legitimate CSV-only interest credit.")
        #expect(r2.count == 20)
        #expect(shared.count == 17)
        #expect(Set(r1Financial).subtracting(Set(r2Financial)).isEmpty)
        #expect(Set(r2Financial).subtracting(Set(r1Financial)).count == 3)
        #expect(r1Financial == r2Financial.filter { shared.contains($0) })
        #expect(Set(r1Financial).isStrictSubset(of: Set(r2Financial)))
        let csv = try Self.expected("axis_bank_nro_account_statement_baseline_csv_source_truth.expected.json")
        let pair = try Self.expected(Self.r1PairExpected)
        #expect(csv.transactionCount == 17 && pair.transactionCount == 16, "Range 1 CSV/PDF/XLS divergence must never be silently aligned.")
    }

    @Test func pairManifestsRecordIndependentPDFAndXLSEvidenceAndPrivacyBoundary() throws {
        let manifest = try Self.manifest("axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.manifest.json")
        #expect(manifest.sourceFormats == ["pdf", "xls"])
        #expect(manifest.crossFormatBoundary.contains("do not establish financial equivalence"))
        #expect(manifest.overlapVerification["pdf"]?.shared == 16)
        #expect(manifest.overlapVerification["pdf"]?.range2Only == 4)
        #expect(manifest.overlapVerification["xls"]?.shared == 16)
        #expect(manifest.overlapVerification["xls"]?.range2Only == 4)
        let texts = try [
            FixtureLocator.axisCSV(Self.r1CSV), FixtureLocator.axisCSV(Self.r2CSV),
            FixtureLocator.axisExpected("axis_bank_nro_account_statement_baseline_csv_source_truth.expected.json"),
            FixtureLocator.axisExpected(Self.r1PairExpected),
            FixtureLocator.axisExpected("axis_bank_nro_account_statement_extended.expected.json"),
            FixtureLocator.axisManifest("axis_bank_nro_account_statement_baseline_csv_source_truth.manifest.json"),
            FixtureLocator.axisManifest("axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.manifest.json"),
            FixtureLocator.axisManifest("axis_bank_nro_account_statement_extended.manifest.json")
        ].map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        for forbidden in ["/Users/vyom/", "Ledger Forge Sanitization Workbench", "redaction-map", "source-verification", "sanitization-report"] { #expect(!texts.contains(forbidden)) }
    }

    private static func rows(_ name: String) throws -> [[String]] {
        let url = FixtureLocator.axisCSV(name)
        let text = try CSVReader().read(from: url)
        let document = CSVAnalyzer().analyze(text: text, fileURL: url)
        let normalized = CSVNormalizer().normalize(text: text, document: document)
        let formatter = DateFormatter(); formatter.dateFormat = "dd-MM-yyyy"; formatter.locale = Locale(identifier: "en_US_POSIX")
        return normalized.compactMap { row in guard let date = row.values.first, formatter.date(from: date) != nil else { return nil }; return row.values }
    }

    private static func financialProjection(_ row: [String]) -> [String] { [row[0], row[3], row[4], row[5], row[6]] }

    private static func expected(_ name: String) throws -> Expected { try JSONDecoder().decode(Expected.self, from: Data(contentsOf: FixtureLocator.axisExpected(name))) }
    private static func manifest(_ name: String) throws -> Manifest { try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: FixtureLocator.axisManifest(name))) }
}

private struct Expected: Decodable { let transactionCount: Int; enum CodingKeys: String, CodingKey { case transactionCount = "transaction_count" } }
private struct Manifest: Decodable {
    let fixtureID: String; let fixtureClass: String; let institution: String; let family: String; let sourceFormats: [String]; let candidateStatus: String; let provenance: Provenance; let privacy: Privacy; let crossFormatBoundary: String; let overlapBasis: OverlapBasis; let overlapVerification: [String: Overlap]
    enum CodingKeys: String, CodingKey { case fixtureID = "fixture_id", fixtureClass = "fixture_class", institution, family, sourceFormats = "source_formats", candidateStatus = "candidate_status", provenance = "source_provenance", privacy = "privacy_assertions", crossFormatBoundary = "cross_format_boundary", overlapBasis = "overlap_basis", overlapVerification = "overlap_verification" }
}
private struct OverlapBasis: Decodable { let classification: String; let textualEqualityRequired: Bool; enum CodingKeys: String, CodingKey { case classification, textualEqualityRequired = "textual_equality_required" } }
private struct Provenance: Decodable { let origin: String; let acquisition: String; let verification: String }
private struct Privacy: Decodable { let usesFictionalCustomerMetadata: Bool; let usesFictionalAccountIdentifier: Bool; let containsNoOriginalTransactionReference: Bool; let containsNoOriginalCounterpartyIdentity: Bool; let containsNoPrivateMapping: Bool; let containsNoPrivateSourcePathOrFilename: Bool; var allTrue: Bool { usesFictionalCustomerMetadata && usesFictionalAccountIdentifier && containsNoOriginalTransactionReference && containsNoOriginalCounterpartyIdentity && containsNoPrivateMapping && containsNoPrivateSourcePathOrFilename }; enum CodingKeys: String, CodingKey { case usesFictionalCustomerMetadata = "uses_fictional_customer_metadata", usesFictionalAccountIdentifier = "uses_fictional_account_identifier", containsNoOriginalTransactionReference = "contains_no_original_transaction_reference", containsNoOriginalCounterpartyIdentity = "contains_no_original_counterparty_identity", containsNoPrivateMapping = "contains_no_private_mapping", containsNoPrivateSourcePathOrFilename = "contains_no_private_source_path_or_filename" } }
private struct Overlap: Decodable { let shared: Int; let range2Only: Int; enum CodingKeys: String, CodingKey { case shared = "shared_financial_transaction_rows", range2Only = "range_2_only_rows" } }
