import Foundation
import Testing

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
            #expect(try Self.manifest(name).fixtureClass == "source-faithful sanitized fixture")
        }
    }

    @Test func sourceFaithfulCSVOverlapPreservesDivergenceWithoutSyntheticAlignment() throws {
        let r1 = try Self.rows(Self.r1CSV)
        let r2 = try Self.rows(Self.r2CSV)
        let shared = Set(r1).intersection(Set(r2))
        #expect(r1.count == 17, "Range 1 CSV must retain its legitimate CSV-only interest credit.")
        #expect(r2.count == 20)
        #expect(shared.count == 17)
        #expect(Set(r1).subtracting(Set(r2)).isEmpty)
        #expect(Set(r2).subtracting(Set(r1)).count == 3)
        #expect(r1 == r2.filter { shared.contains($0) })
        #expect(Set(r1).isStrictSubset(of: Set(r2)))
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
            FixtureLocator.axisExpected("axis_bank_nro_account_statement_baseline_csv_source_truth.expected.json"),
            FixtureLocator.axisExpected(Self.r1PairExpected),
            FixtureLocator.axisManifest("axis_bank_nro_account_statement_baseline_csv_source_truth.manifest.json"),
            FixtureLocator.axisManifest("axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.manifest.json")
        ].map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        for forbidden in ["/Users/vyom/", "Ledger Forge Sanitization Workbench", "redaction-map", "source-verification", "sanitization-report"] { #expect(!texts.contains(forbidden)) }
    }

    private static func rows(_ name: String) throws -> [[String]] {
        let text = try String(contentsOf: FixtureLocator.axisCSV(name), encoding: .utf8)
        let rows = text.split(whereSeparator: \.isNewline).map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        let header = try #require(rows.firstIndex { $0.prefix(7) == ["Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"] })
        return rows[(header + 1)...].filter { $0.count == 7 && $0[0].count == 10 && $0[0].contains("-") }.map { [$0[0], $0[3], $0[4], $0[5]] }
    }

    private static func expected(_ name: String) throws -> Expected { try JSONDecoder().decode(Expected.self, from: Data(contentsOf: FixtureLocator.axisExpected(name))) }
    private static func manifest(_ name: String) throws -> Manifest { try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: FixtureLocator.axisManifest(name))) }
}

private struct Expected: Decodable { let transactionCount: Int; enum CodingKeys: String, CodingKey { case transactionCount = "transaction_count" } }
private struct Manifest: Decodable {
    let fixtureClass: String; let sourceFormats: [String]; let crossFormatBoundary: String; let overlapVerification: [String: Overlap]
    enum CodingKeys: String, CodingKey { case fixtureClass = "fixture_class", sourceFormats = "source_formats", crossFormatBoundary = "cross_format_boundary", overlapVerification = "overlap_verification" }
}
private struct Overlap: Decodable { let shared: Int; let range2Only: Int; enum CodingKeys: String, CodingKey { case shared = "shared_complete_transaction_rows", range2Only = "range_2_only_rows" } }
