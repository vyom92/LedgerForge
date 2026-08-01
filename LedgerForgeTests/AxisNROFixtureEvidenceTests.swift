import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct AxisNROFixtureEvidenceTests {
    private static let r1CSV = "axis_bank_nro_account_statement_baseline_csv_source_truth.csv"
    private static let r2CSV = "axis_bank_nro_account_statement_extended.csv"
    private static let r1PairExpected = "axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.expected.json"
    private static let pdfFixtures = [
        PDFEvidenceFixture(
            pdf: "axis_bank_nro_account_statement_baseline.pdf",
            expected: Self.r1PairExpected,
            manifest: "axis_bank_nro_account_statement_baseline_pdf_xls_source_truth.manifest.json"
        ),
        PDFEvidenceFixture(
            pdf: "axis_bank_nro_account_statement_extended.pdf",
            expected: "axis_bank_nro_account_statement_extended.expected.json",
            manifest: "axis_bank_nro_account_statement_extended.manifest.json"
        )
    ]

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

    @Test func sanitizedPDFGrammarAndFinancialProjectionMatchIndependentEvidence() throws {
        for fixture in Self.pdfFixtures {
            let url = FixtureLocator.axisPDF(fixture.pdf)
            let data = try Data(contentsOf: url)
            let document = try #require(PDFDocument(data: data))
            let expected = try Self.expected(fixture.expected)
            let manifest = try Self.manifest(fixture.manifest)
            let artifactDigests = try #require(manifest.artifactDigests)
            let pagination = try #require(manifest.paginationAssertions)

            #expect(!document.isLocked)
            #expect(document.pageCount == pagination.pdfPageCount)
            #expect(Self.sha256(data) == artifactDigests.pdfSHA256)

            let pageTexts = try (0..<document.pageCount).map { index in
                try #require(document.page(at: index)?.string)
            }
            #expect(pageTexts.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

            let normalizedPages = pageTexts.map(Self.normalizedWhitespace)
            let tableHeader = "Tran Date Chq No Particulars Debit Credit Balance Init. Br"
            let tableHeaderPages = normalizedPages.enumerated().compactMap { index, text in
                text.contains(tableHeader) ? index + 1 : nil
            }
            #expect(tableHeaderPages == pagination.tableHeaderPages)
            #expect(!pagination.repeatedHeadersPresent)

            let normalizedText = normalizedPages.joined(separator: " ")
            #expect(normalizedText.localizedCaseInsensitiveContains("Axis Bank"))
            #expect(normalizedText.contains(
                "Statement of Axis Account No : \(expected.verifiedAccountIdentifier.value) "
                    + "for the period (From : \(expected.statementStartDate) To : \(expected.statementEndDate))"
            ))
            #expect(normalizedText.contains(tableHeader))
            #expect(Self.containsAmount(expected.openingBalance, after: "OPENING BALANCE", in: normalizedText))
            #expect(normalizedText.contains("TRANSACTION TOTAL \(expected.debitTotal) \(expected.creditTotal)"))
            #expect(Self.containsAmount(expected.closingBalance, after: "CLOSING BALANCE", in: normalizedText))

            try Self.verifyFinancialProjection(expected, in: pageTexts.joined(separator: "\n"))
            try Self.verifyPDFKitColumnGeometry(expected, in: document)
        }
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

    private static func verifyFinancialProjection(_ expected: Expected, in text: String) throws {
        #expect(expected.transactions.count == expected.transactionCount)
        var cursor = text.startIndex
        var runningBalance = try Self.decimal(expected.openingBalance)

        for (index, transaction) in expected.transactions.enumerated() {
            #expect(transaction.ordinal == index + 1)
            let dateRange = try #require(text.range(
                of: transaction.transactionDate,
                range: cursor..<text.endIndex
            ))
            let boundary: String.Index
            if index + 1 < expected.transactions.count {
                boundary = try #require(text.range(
                    of: expected.transactions[index + 1].transactionDate,
                    range: dateRange.upperBound..<text.endIndex
                )).lowerBound
            } else {
                boundary = try #require(text.range(
                    of: "TRANSACTION TOTAL",
                    range: dateRange.upperBound..<text.endIndex
                )).lowerBound
            }

            let rowText = String(text[dateRange.lowerBound..<boundary])
            let debit = try Self.decimal(transaction.debit)
            let credit = try Self.decimal(transaction.credit)
            let resultingBalance = try Self.decimal(transaction.runningBalance)
            #expect((debit == 0) != (credit == 0))
            #expect(rowText.contains(debit == 0 ? transaction.credit : transaction.debit))
            #expect(Self.amountRepresentations(transaction.runningBalance).contains { rowText.contains($0) })
            #expect(runningBalance - debit + credit == resultingBalance)

            runningBalance = resultingBalance
            cursor = boundary
        }

        let closingBalance = try Self.decimal(expected.closingBalance)
        #expect(runningBalance == closingBalance)
    }

    private static func verifyPDFKitColumnGeometry(
        _ expected: Expected,
        in document: PDFDocument
    ) throws {
        let page = try #require(document.page(at: 0))
        let pageText = try #require(page.string)
        let text = pageText as NSString
        let dateExpression = try NSRegularExpression(
            pattern: #"(?m)^\s*\d{2}-\d{2}-\d{4}(?:\s|$)"#
        )
        #expect(dateExpression.numberOfMatches(
            in: pageText,
            range: NSRange(location: 0, length: text.length)
        ) == expected.transactionCount)

        try Self.expectColumn(
            "Debit",
            edge: .minX,
            sourcePosition: 339.3,
            in: text,
            on: page
        )
        try Self.expectColumn(
            "Credit",
            edge: .minX,
            sourcePosition: 400.1,
            in: text,
            on: page
        )
        try Self.expectColumn(
            "Balance",
            edge: .minX,
            sourcePosition: 473.1,
            in: text,
            on: page
        )

        var cursor = 0
        for transaction in expected.transactions {
            let line = try #require(pageText.components(separatedBy: .newlines).first {
                $0.trimmingCharacters(in: .whitespaces)
                    .hasPrefix(transaction.transactionDate + " ")
                    && $0.contains(transaction.description)
            })
            let lineRange = text.range(
                of: line,
                range: NSRange(location: cursor, length: text.length - cursor)
            )
            try #require(lineRange.location != NSNotFound)
            cursor = NSMaxRange(lineRange)

            let lineText = line as NSString
            let descriptionRange = lineText.range(of: transaction.description)
            try #require(descriptionRange.location != NSNotFound)
            let isCredit = try Self.decimal(transaction.debit) == 0
            let amount = isCredit
                ? transaction.credit
                : transaction.debit
            let amountRange = lineText.range(
                of: amount,
                range: NSRange(
                    location: NSMaxRange(descriptionRange),
                    length: lineText.length - NSMaxRange(descriptionRange)
                )
            )
            try #require(amountRange.location != NSNotFound)
            let balanceRange = lineText.range(
                of: transaction.runningBalance,
                range: NSRange(
                    location: NSMaxRange(amountRange),
                    length: lineText.length - NSMaxRange(amountRange)
                )
            )
            try #require(balanceRange.location != NSNotFound)
            let branchRange = lineText.range(
                of: "4437",
                range: NSRange(
                    location: NSMaxRange(balanceRange),
                    length: lineText.length - NSMaxRange(balanceRange)
                )
            )
            try #require(branchRange.location != NSNotFound)

            let dateRange = lineText.range(of: transaction.transactionDate)
            let dateBounds = try Self.bounds(
                for: dateRange,
                offsetBy: lineRange.location,
                on: page
            )
            let descriptionBounds = try Self.bounds(
                for: descriptionRange,
                offsetBy: lineRange.location,
                on: page
            )
            let amountBounds = try Self.bounds(
                for: amountRange,
                offsetBy: lineRange.location,
                on: page
            )
            let balanceBounds = try Self.bounds(
                for: balanceRange,
                offsetBy: lineRange.location,
                on: page
            )
            let branchBounds = try Self.bounds(
                for: branchRange,
                offsetBy: lineRange.location,
                on: page
            )

            #expect(abs(dateBounds.minX - 38.5) <= 2)
            #expect(abs(descriptionBounds.minX - 132.1) <= 2)
            #expect(abs(amountBounds.maxX - (isCredit ? 441.9 : 379.2)) <= 2)
            #expect(abs(balanceBounds.maxX - 530.9) <= 2)
            #expect(abs(branchBounds.minX - 536.9) <= 2)
        }
    }

    private enum ColumnEdge { case minX, maxX }

    private static func expectColumn(
        _ value: String,
        edge: ColumnEdge,
        sourcePosition: CGFloat,
        in text: NSString,
        on page: PDFPage
    ) throws {
        let range = text.range(of: value)
        try #require(range.location != NSNotFound)
        let bounds = try Self.bounds(for: range, offsetBy: 0, on: page)
        let position: CGFloat
        switch edge {
        case .minX: position = bounds.minX
        case .maxX: position = bounds.maxX
        }
        #expect(abs(position - sourcePosition) <= 2)
    }

    private static func bounds(
        for range: NSRange,
        offsetBy offset: Int,
        on page: PDFPage
    ) throws -> CGRect {
        let selection = try #require(page.selection(for: NSRange(
            location: offset + range.location,
            length: range.length
        )))
        return selection.bounds(for: page)
    }

    private static func normalizedWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func containsAmount(_ amount: String, after label: String, in text: String) -> Bool {
        Self.amountRepresentations(amount).contains { text.contains("\(label) \($0)") }
    }

    private static func amountRepresentations(_ amount: String) -> [String] {
        amount.hasPrefix("0.") ? [amount, String(amount.dropFirst())] : [amount]
    }

    private static func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func expected(_ name: String) throws -> Expected { try JSONDecoder().decode(Expected.self, from: Data(contentsOf: FixtureLocator.axisExpected(name))) }
    private static func manifest(_ name: String) throws -> Manifest { try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: FixtureLocator.axisManifest(name))) }
}

private struct PDFEvidenceFixture {
    let pdf: String
    let expected: String
    let manifest: String
}
private struct Expected: Decodable {
    let transactionCount: Int
    let openingBalance: String
    let closingBalance: String
    let debitTotal: String
    let creditTotal: String
    let transactions: [ExpectedTransaction]
    let statementStartDate: String
    let statementEndDate: String
    let verifiedAccountIdentifier: VerifiedAccountIdentifier
    enum CodingKeys: String, CodingKey {
        case transactionCount = "transaction_count", openingBalance = "opening_balance", closingBalance = "closing_balance", debitTotal = "debit_total", creditTotal = "credit_total", transactions = "canonical_ordered_transactions", statementStartDate = "statement_start_date", statementEndDate = "statement_end_date", verifiedAccountIdentifier = "verified_account_identifier"
    }
}
private struct ExpectedTransaction: Decodable {
    let ordinal: Int
    let transactionDate: String
    let description: String
    let debit: String
    let credit: String
    let runningBalance: String
    enum CodingKeys: String, CodingKey { case ordinal, transactionDate = "transaction_date", description, debit, credit, runningBalance = "running_balance" }
}
private struct VerifiedAccountIdentifier: Decodable { let value: String }
private struct Manifest: Decodable {
    let fixtureID: String; let fixtureClass: String; let institution: String; let family: String; let sourceFormats: [String]; let candidateStatus: String; let provenance: Provenance; let privacy: Privacy; let crossFormatBoundary: String; let overlapBasis: OverlapBasis; let overlapVerification: [String: Overlap]; let artifactDigests: ArtifactDigests?; let paginationAssertions: PaginationAssertions?
    enum CodingKeys: String, CodingKey { case fixtureID = "fixture_id", fixtureClass = "fixture_class", institution, family, sourceFormats = "source_formats", candidateStatus = "candidate_status", provenance = "source_provenance", privacy = "privacy_assertions", crossFormatBoundary = "cross_format_boundary", overlapBasis = "overlap_basis", overlapVerification = "overlap_verification", artifactDigests = "artifact_digests", paginationAssertions = "pagination_assertions" }
}
private struct ArtifactDigests: Decodable { let pdfSHA256: String; enum CodingKeys: String, CodingKey { case pdfSHA256 = "pdf_sha256" } }
private struct PaginationAssertions: Decodable { let pdfPageCount: Int; let repeatedHeadersPresent: Bool; let tableHeaderPages: [Int]; enum CodingKeys: String, CodingKey { case pdfPageCount = "pdf_page_count", repeatedHeadersPresent = "repeated_headers_present", tableHeaderPages = "table_header_pages" } }
private struct OverlapBasis: Decodable { let classification: String; let textualEqualityRequired: Bool; enum CodingKeys: String, CodingKey { case classification, textualEqualityRequired = "textual_equality_required" } }
private struct Provenance: Decodable { let origin: String; let acquisition: String; let verification: String }
private struct Privacy: Decodable { let usesFictionalCustomerMetadata: Bool; let usesFictionalAccountIdentifier: Bool; let containsNoOriginalTransactionReference: Bool; let containsNoOriginalCounterpartyIdentity: Bool; let containsNoPrivateMapping: Bool; let containsNoPrivateSourcePathOrFilename: Bool; var allTrue: Bool { usesFictionalCustomerMetadata && usesFictionalAccountIdentifier && containsNoOriginalTransactionReference && containsNoOriginalCounterpartyIdentity && containsNoPrivateMapping && containsNoPrivateSourcePathOrFilename }; enum CodingKeys: String, CodingKey { case usesFictionalCustomerMetadata = "uses_fictional_customer_metadata", usesFictionalAccountIdentifier = "uses_fictional_account_identifier", containsNoOriginalTransactionReference = "contains_no_original_transaction_reference", containsNoOriginalCounterpartyIdentity = "contains_no_original_counterparty_identity", containsNoPrivateMapping = "contains_no_private_mapping", containsNoPrivateSourcePathOrFilename = "contains_no_private_source_path_or_filename" } }
private struct Overlap: Decodable { let shared: Int; let range2Only: Int; enum CodingKeys: String, CodingKey { case shared = "shared_financial_transaction_rows", range2Only = "range_2_only_rows" } }
