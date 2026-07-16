import Foundation
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct CBQCurrentAccountFixtureEvidenceTests {
    private static let fixtures = [
        Fixture(name: "cbq_current_account_statement_baseline", transactions: 10, pages: 3),
        Fixture(name: "cbq_current_account_statement_middle", transactions: 7, pages: 2),
        Fixture(name: "cbq_current_account_statement_recent", transactions: 9, pages: 2)
    ]

    @Test func completeInventoryExistsAndSchemaV2EvidenceDecodes() throws {
        let urls = Self.fixtures.flatMap { fixture in
            [
                FixtureLocator.cbqBankAccountPDF("\(fixture.name).pdf"),
                FixtureLocator.cbqBankAccountExpected("\(fixture.name).expected.json"),
                FixtureLocator.cbqBankAccountManifest("\(fixture.name).manifest.json")
            ]
        }
        #expect(urls.count == 9)
        #expect(urls.allSatisfy { FixtureLocator.fileExists(at: $0) })
        #expect(try urls.allSatisfy { try !Data(contentsOf: $0).isEmpty })

        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            let manifest = try Self.manifest(fixture)
            #expect(expected.metadataSchemaVersion == 2)
            #expect(manifest.metadataSchemaVersion == 2)
            #expect(expected.fixtureID == fixture.name)
            #expect(manifest.fixtureID == fixture.name)
            #expect(expected.fixtureClass == "source-faithful sanitized fixture")
            #expect(manifest.fixtureClass == "source-faithful sanitized fixture")
            #expect(manifest.candidateStatus == "validated")
            #expect(expected.sourceFormats == ["pdf"])
            #expect(!manifest.productionSupport.productionParserSupport)
            #expect(!manifest.productionSupport.productionPDFSupport)
            #expect(!manifest.productionSupport.productionSupportClaimed)
            #expect(expected.productionSupportBoundary.contains("no production CBQ PDF parser"))
        }
    }

    @Test func canonicalFinancialTruthReconcilesInSourceOrder() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            #expect(expected.transactionCount == fixture.transactions)
            #expect(expected.transactions.count == fixture.transactions)
            #expect(expected.transactions.map(\.ordinal) == Array(1...fixture.transactions))
            #expect(expected.transactions.allSatisfy { !$0.postingDate.isEmpty && !$0.valueDate.isEmpty })
            #expect(expected.transactions.allSatisfy { $0.sourceRowRelationship == "preserved" })
            #expect(expected.nativeCurrency == "QAR")
            #expect(expected.computedClosingBalance == expected.closingBalance)

            let opening = try Self.decimal(expected.openingBalance)
            let debit = try Self.decimal(expected.debitTotal)
            let credit = try Self.decimal(expected.creditTotal)
            let closing = try Self.decimal(expected.closingBalance)
            #expect(opening - debit + credit == closing)

            for transaction in expected.transactions {
                _ = try Self.decimal(transaction.debit)
                _ = try Self.decimal(transaction.credit)
                _ = try Self.decimal(transaction.runningBalance)
            }
        }
    }

    @Test func periodsAreChronologicalContiguousAndFinanciallyDisjoint() throws {
        let expected = try Self.fixtures.map(Self.expected)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        for evidence in expected {
            #expect(evidence.periodRelationship.chronology == "R1 then R2 then R3")
            #expect(evidence.periodRelationship.overlap == "none")
            #expect(evidence.periodRelationship.calendarRelationship == "contiguous")
            #expect(evidence.periodRelationship.duplicateFinancialRows == 0)
        }

        for (earlier, later) in zip(expected, expected.dropFirst()) {
            let earlierEnd = try #require(formatter.date(from: earlier.statementEndDate))
            let laterStart = try #require(formatter.date(from: later.statementStartDate))
            let nextDay = try #require(Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: earlierEnd))
            #expect(nextDay == laterStart)
            #expect(earlier.closingBalance == later.openingBalance)
            #expect(Set(earlier.transactions.map(\.financialProjection)).isDisjoint(with: Set(later.transactions.map(\.financialProjection))))
        }

        #expect(expected[0].periodRelationship.closingMatchesNextPeriodOpening == true)
        #expect(expected[1].periodRelationship.previousPeriodClosingMatchesOpening == true)
        #expect(expected[1].periodRelationship.closingMatchesNextPeriodOpening == true)
        #expect(expected[2].periodRelationship.previousPeriodClosingMatchesOpening == true)
    }

    @Test func fictionalCustomerAndCurrentAccountRelationshipsAreStable() throws {
        let expected = try Self.fixtures.map(Self.expected)
        #expect(Set(expected.map(\.fictionalCustomerIdentity)) == ["cbq-current-fixture-customer-001"])
        #expect(Set(expected.map(\.fictionalAccountIdentity)) == ["cbq-current-fixture-account-001"])
        #expect(expected.allSatisfy { $0.accountRelationship == "same fictional current account across all three contiguous periods" })
        #expect(expected.allSatisfy { $0.accountType == "current account" })
    }

    @Test func cleanRoomOCRAndQualifiedFidelityDeclarationsRemainBounded() throws {
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            #expect(manifest.sanitizationMethod.classification == "clean_room_pdf_reconstruction")
            #expect(!manifest.sanitizationMethod.sourcePageObjectsReused)
            #expect(!manifest.sanitizationMethod.sourceContentStreamsReused)
            #expect(!manifest.sanitizationMethod.sourceImagesReused)
            #expect(!manifest.sanitizationMethod.sourceFontsReused)
            #expect(!manifest.sanitizationMethod.sourceMetadataReused)
            #expect(!manifest.sanitizationMethod.sourceAnnotationsReused)
            #expect(manifest.sourceFidelity.financialTruth == "exact")
            #expect(manifest.sourceFidelity.transactionOrder == "exact")
            #expect(manifest.sourceFidelity.pageCount == "preserved")
            #expect(manifest.sourceFidelity.pageDimensions == "preserved")
            #expect(manifest.sourceFidelity.tableGeometry == "measured column and row geometry preserved")
            #expect(manifest.sourceFidelity.pageBreakRelationships == "preserved")
            #expect(manifest.sourceFidelity.repeatedHeaders == "preserved_when_present")
            #expect(manifest.sourceFidelity.multilineNarrationRelationships == "preserved")
            #expect(manifest.sourceFidelity.privateTextualValues == "replaced")
            #expect(manifest.sourceFidelity.sourceObjectIdentity == "not_preserved")
            #expect(manifest.ocrBoundary == .approvedFixtureBoundary)
            #expect(manifest.pagination.repeatedTransactionHeadersPreserved)
            #expect(manifest.pagination.pageBreaksPreserved)
            #expect(manifest.extractionOrder.multilineNarrationRelationshipsPreserved)
            #expect(manifest.privacy.allTrue)
        }
    }

    @Test func nativePDFTextGeometryAndObjectSurfacesMatchManifests() throws {
        for fixture in Self.fixtures {
            let url = FixtureLocator.cbqBankAccountPDF("\(fixture.name).pdf")
            let manifest = try Self.manifest(fixture)
            let document = try #require(PDFDocument(url: url))
            #expect(!document.isEncrypted)
            #expect(!document.isLocked)
            #expect(document.pageCount == fixture.pages)
            #expect(document.pageCount == manifest.pdfAssertions.pageCount)
            #expect(manifest.pdfAssertions.pages.count == fixture.pages)
            #expect(manifest.pdfAssertions.dimensionTolerancePoints == 0.25)

            for index in 0..<fixture.pages {
                let page = try #require(document.page(at: index))
                let assertion = manifest.pdfAssertions.pages[index]
                let bounds = page.bounds(for: .mediaBox)
                #expect(assertion.pageIndex == index)
                #expect(abs(bounds.width - assertion.widthPoints) <= manifest.pdfAssertions.dimensionTolerancePoints)
                #expect(abs(bounds.height - assertion.heightPoints) <= manifest.pdfAssertions.dimensionTolerancePoints)
                #expect(!(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(page.annotations.isEmpty)
            }

            #expect(manifest.pdfAssertions.nativeSelectableText)
            #expect(!manifest.pdfAssertions.annotationsPresent)
            #expect(!manifest.pdfAssertions.formsPresent)
            #expect(!manifest.pdfAssertions.attachmentsPresent)

            let objectText = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            for forbidden in ["/EmbeddedFiles", "/AcroForm", "/Annots", "/Users/vyom/", "Ledger Forge Sanitization Workbench", "CBQ-Current-CleanRoom"] {
                #expect(!objectText.contains(forbidden))
            }
        }
    }

    @Test func repositoryVisibleFixtureSurfacesRemainPrivacySafe() throws {
        let root = FixtureLocator.fixturesRoot.appendingPathComponent("CBQ").appendingPathComponent("BankAccount")
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let urls = enumerator.compactMap { $0 as? URL }
        #expect(urls.filter { !$0.hasDirectoryPath }.count == 9)

        let forbiddenNames = ["redaction", "verification", "sanitization-report", "layout-model", "allowlist", "originals"]
        for url in urls {
            let lower = url.lastPathComponent.lowercased()
            #expect(forbiddenNames.allSatisfy { !lower.contains($0) })
        }

        let forbiddenText = ["/Users/vyom/", "Ledger Forge Sanitization Workbench", "CBQ-Current-CleanRoom", "redaction-map", "source-verification", "sanitization-report", "layout-model", "generated-text-allowlist"]
        for fixture in Self.fixtures {
            let metadata = try Self.metadataText(fixture)
            let document = try #require(PDFDocument(url: FixtureLocator.cbqBankAccountPDF("\(fixture.name).pdf")))
            let pdfText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
            let attributes = String(describing: document.documentAttributes)
            for forbidden in forbiddenText {
                #expect(!metadata.contains(forbidden))
                #expect(!pdfText.contains(forbidden))
                #expect(!attributes.contains(forbidden))
            }
        }
    }

    private static func expected(_ fixture: Fixture) throws -> CBQExpected {
        try JSONDecoder().decode(CBQExpected.self, from: Data(contentsOf: FixtureLocator.cbqBankAccountExpected("\(fixture.name).expected.json")))
    }

    private static func manifest(_ fixture: Fixture) throws -> CBQManifest {
        try JSONDecoder().decode(CBQManifest.self, from: Data(contentsOf: FixtureLocator.cbqBankAccountManifest("\(fixture.name).manifest.json")))
    }

    private static func metadataText(_ fixture: Fixture) throws -> String {
        try String(contentsOf: FixtureLocator.cbqBankAccountExpected("\(fixture.name).expected.json"), encoding: .utf8)
            + String(contentsOf: FixtureLocator.cbqBankAccountManifest("\(fixture.name).manifest.json"), encoding: .utf8)
    }

    private static func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}

private struct Fixture {
    let name: String
    let transactions: Int
    let pages: Int
}

private struct CBQExpected: Decodable {
    let metadataSchemaVersion: Int
    let fixtureID: String
    let fixtureClass: String
    let sourceFormats: [String]
    let accountType: String
    let statementStartDate: String
    let statementEndDate: String
    let nativeCurrency: String
    let transactionCount: Int
    let openingBalance: String
    let closingBalance: String
    let debitTotal: String
    let creditTotal: String
    let computedClosingBalance: String
    let transactions: [CBQTransaction]
    let fictionalCustomerIdentity: String
    let fictionalAccountIdentity: String
    let accountRelationship: String
    let periodRelationship: PeriodRelationship
    let productionSupportBoundary: String

    enum CodingKeys: String, CodingKey {
        case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", sourceFormats = "source_formats", accountType = "account_type", statementStartDate = "statement_start_date", statementEndDate = "statement_end_date", nativeCurrency = "native_currency", transactionCount = "transaction_count", openingBalance = "opening_balance", closingBalance = "closing_balance", debitTotal = "debit_total", creditTotal = "credit_total", computedClosingBalance = "computed_closing_balance", transactions = "canonical_ordered_financial_transactions", fictionalCustomerIdentity = "fictional_customer_identity", fictionalAccountIdentity = "fictional_account_identity", accountRelationship = "account_relationship", periodRelationship = "period_relationship", productionSupportBoundary = "production_support_boundary"
    }
}

private struct CBQTransaction: Decodable {
    let ordinal: Int
    let postingDate: String
    let valueDate: String
    let debit: String
    let credit: String
    let runningBalance: String
    let sourceRowRelationship: String
    var financialProjection: [String] { [postingDate, valueDate, debit, credit, runningBalance] }
    enum CodingKeys: String, CodingKey { case ordinal, postingDate = "posting_date", valueDate = "value_date", debit, credit, runningBalance = "running_balance", sourceRowRelationship = "source_row_relationship" }
}

private struct PeriodRelationship: Decodable {
    let chronology: String
    let overlap: String
    let calendarRelationship: String
    let previousPeriodClosingMatchesOpening: Bool?
    let closingMatchesNextPeriodOpening: Bool?
    let duplicateFinancialRows: Int
    enum CodingKeys: String, CodingKey { case chronology, overlap, calendarRelationship = "calendar_relationship", previousPeriodClosingMatchesOpening = "previous_period_closing_matches_opening", closingMatchesNextPeriodOpening = "closing_matches_next_period_opening", duplicateFinancialRows = "duplicate_financial_rows" }
}

private struct CBQManifest: Decodable {
    let metadataSchemaVersion: Int
    let fixtureID: String
    let fixtureClass: String
    let candidateStatus: String
    let sanitizationMethod: SanitizationMethod
    let sourceFidelity: SourceFidelity
    let ocrBoundary: OCRBoundary
    let pagination: PaginationAssertions
    let extractionOrder: ExtractionOrderAssertions
    let privacy: PrivacyAssertions
    let pdfAssertions: PDFAssertions
    let productionSupport: ProductionSupportBoundary
    enum CodingKeys: String, CodingKey { case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", candidateStatus = "candidate_status", sanitizationMethod = "sanitization_method", sourceFidelity = "source_fidelity", ocrBoundary = "ocr_boundary", pagination = "pagination_assertions", extractionOrder = "extraction_order_assertions", privacy = "privacy_assertions", pdfAssertions = "pdf_assertions", productionSupport = "production_support_boundary" }
}

private struct SanitizationMethod: Decodable {
    let classification: String
    let sourcePageObjectsReused: Bool
    let sourceContentStreamsReused: Bool
    let sourceImagesReused: Bool
    let sourceFontsReused: Bool
    let sourceMetadataReused: Bool
    let sourceAnnotationsReused: Bool
    enum CodingKeys: String, CodingKey { case classification, sourcePageObjectsReused = "source_page_objects_reused", sourceContentStreamsReused = "source_content_streams_reused", sourceImagesReused = "source_images_reused", sourceFontsReused = "source_fonts_reused", sourceMetadataReused = "source_metadata_reused", sourceAnnotationsReused = "source_annotations_reused" }
}

private struct SourceFidelity: Decodable {
    let financialTruth: String
    let transactionOrder: String
    let pageCount: String
    let pageDimensions: String
    let tableGeometry: String
    let pageBreakRelationships: String
    let repeatedHeaders: String
    let multilineNarrationRelationships: String
    let privateTextualValues: String
    let sourceObjectIdentity: String
    enum CodingKeys: String, CodingKey { case financialTruth = "financial_truth", transactionOrder = "transaction_order", pageCount = "page_count", pageDimensions = "page_dimensions", tableGeometry = "table_geometry", pageBreakRelationships = "page_break_relationships", repeatedHeaders = "repeated_headers", multilineNarrationRelationships = "multiline_narration_relationships", privateTextualValues = "private_textual_values", sourceObjectIdentity = "source_object_identity" }
}

private struct OCRBoundary: Decodable, Equatable {
    let nativeTextAvailable: Bool
    let pdfkitExtractionUsable: Bool
    let pymupdfExtractionUsable: Bool
    let ocrUsed: Bool
    let ocrRequiredForFixture: Bool
    let scope: String
    static let approvedFixtureBoundary = Self(nativeTextAvailable: true, pdfkitExtractionUsable: true, pymupdfExtractionUsable: true, ocrUsed: false, ocrRequiredForFixture: false, scope: "approved_fixture_layout_only")
    enum CodingKeys: String, CodingKey { case nativeTextAvailable = "native_text_available", pdfkitExtractionUsable = "pdfkit_extraction_usable", pymupdfExtractionUsable = "pymupdf_extraction_usable", ocrUsed = "ocr_used", ocrRequiredForFixture = "ocr_required_for_fixture", scope }
}

private struct PaginationAssertions: Decodable {
    let repeatedTransactionHeadersPreserved: Bool
    let pageBreaksPreserved: Bool
    enum CodingKeys: String, CodingKey { case repeatedTransactionHeadersPreserved = "repeated_transaction_headers_preserved", pageBreaksPreserved = "page_breaks_preserved" }
}

private struct ExtractionOrderAssertions: Decodable {
    let multilineNarrationRelationshipsPreserved: Bool
    enum CodingKeys: String, CodingKey { case multilineNarrationRelationshipsPreserved = "multiline_narration_relationships_preserved" }
}

private struct PrivacyAssertions: Decodable {
    let usesFictionalCustomerMetadata: Bool
    let usesFictionalAccountIdentifier: Bool
    let containsNoOriginalTransactionReference: Bool
    let containsNoOriginalCounterpartyIdentity: Bool
    let containsNoPrivateMapping: Bool
    let containsNoPrivateSourcePathOrFilename: Bool
    let containsNoSourcePDFObject: Bool
    var allTrue: Bool { usesFictionalCustomerMetadata && usesFictionalAccountIdentifier && containsNoOriginalTransactionReference && containsNoOriginalCounterpartyIdentity && containsNoPrivateMapping && containsNoPrivateSourcePathOrFilename && containsNoSourcePDFObject }
    enum CodingKeys: String, CodingKey { case usesFictionalCustomerMetadata = "uses_fictional_customer_metadata", usesFictionalAccountIdentifier = "uses_fictional_account_identifier", containsNoOriginalTransactionReference = "contains_no_original_transaction_reference", containsNoOriginalCounterpartyIdentity = "contains_no_original_counterparty_identity", containsNoPrivateMapping = "contains_no_private_mapping", containsNoPrivateSourcePathOrFilename = "contains_no_private_source_path_or_filename", containsNoSourcePDFObject = "contains_no_source_pdf_object" }
}

private struct PDFAssertions: Decodable {
    let pageCount: Int
    let dimensionTolerancePoints: Double
    let pages: [PDFPageAssertion]
    let nativeSelectableText: Bool
    let annotationsPresent: Bool
    let formsPresent: Bool
    let attachmentsPresent: Bool
    enum CodingKeys: String, CodingKey { case pageCount = "page_count", dimensionTolerancePoints = "dimension_tolerance_points", pages, nativeSelectableText = "native_selectable_text", annotationsPresent = "annotations_present", formsPresent = "forms_present", attachmentsPresent = "attachments_present" }
}

private struct PDFPageAssertion: Decodable {
    let pageIndex: Int
    let widthPoints: Double
    let heightPoints: Double
    enum CodingKeys: String, CodingKey { case pageIndex = "page_index", widthPoints = "width_points", heightPoints = "height_points" }
}

private struct ProductionSupportBoundary: Decodable {
    let productionParserSupport: Bool
    let productionPDFSupport: Bool
    let productionSupportClaimed: Bool
    enum CodingKeys: String, CodingKey { case productionParserSupport = "production_parser_support", productionPDFSupport = "production_pdf_support", productionSupportClaimed = "production_support_claimed" }
}
