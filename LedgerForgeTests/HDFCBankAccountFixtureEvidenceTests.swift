import Foundation
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct HDFCBankAccountFixtureEvidenceTests {
    private static let fixtures = [
        Fixture(name: "hdfc_bank_nre_account_statement_annual", accountType: "NRE", transactions: 62, pages: 5, rows: 110, multilineContinuations: 15),
        Fixture(name: "hdfc_bank_nre_account_statement_recent", accountType: "NRE", transactions: 16, pages: 2, rows: 64, multilineContinuations: 3),
        Fixture(name: "hdfc_bank_nro_account_statement_annual", accountType: "NRO", transactions: 76, pages: 7, rows: 124, multilineContinuations: 7),
        Fixture(name: "hdfc_bank_nro_account_statement_recent", accountType: "NRO", transactions: 7, pages: 1, rows: 55, multilineContinuations: 0)
    ]

    @Test func completeInventoryExistsAndStructuredMetadataDecodes() throws {
        let urls = Self.fixtures.flatMap { fixture in
            [
                FixtureLocator.hdfcBankAccountPDF("\(fixture.name).pdf"),
                FixtureLocator.hdfcBankAccountXLS("\(fixture.name).xls"),
                FixtureLocator.hdfcBankAccountExpected("\(fixture.name).expected.json"),
                FixtureLocator.hdfcBankAccountManifest("\(fixture.name).manifest.json")
            ]
        }
        #expect(urls.count == 16)
        #expect(urls.allSatisfy { FixtureLocator.fileExists(at: $0) })
        #expect(try urls.allSatisfy { try Data(contentsOf: $0).isEmpty == false })

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
            #expect(expected.sourceFormats == ["pdf", "xls"])
            #expect(try !Self.metadataText(fixture).contains("production_support"))
        }
    }

    @Test func financialTruthAndFictionalIdentityRelationshipsAreExplicit() throws {
        let expected = try Self.fixtures.map { try Self.expected($0) }
        for (fixture, evidence) in zip(Self.fixtures, expected) {
            #expect(evidence.transactionCount == fixture.transactions)
            #expect(evidence.canonicalTransactions.count == fixture.transactions)
            #expect(evidence.computedFinalBalance == evidence.closingBalance)
            #expect(evidence.pdfXLSFinancialEquivalence.matches)
            #expect(evidence.pdfXLSFinancialEquivalence.basis == "ordered_financial_projection")
            #expect(evidence.pdfXLSFinancialEquivalence.fields == ["transaction_date", "value_date", "debit", "credit", "running_balance"])
            #expect(evidence.validationExpectation == "expected valid")
        }

        let customerIDs = Set(expected.map(\.fictionalIdentity.customerIdentityID))
        let nreAccountIDs = Set(expected.filter { $0.accountType == "NRE" }.map(\.fictionalIdentity.accountIdentityID))
        let nroAccountIDs = Set(expected.filter { $0.accountType == "NRO" }.map(\.fictionalIdentity.accountIdentityID))
        #expect(customerIDs == ["hdfc-fixture-customer-001"])
        #expect(nreAccountIDs == ["hdfc-fixture-nre-account-001"])
        #expect(nroAccountIDs == ["hdfc-fixture-nro-account-001"])
        #expect(nreAccountIDs.isDisjoint(with: nroAccountIDs))
        #expect(expected.allSatisfy { $0.fictionalIdentity.accountType == $0.accountType })
    }

    @Test func cleanRoomOCRAndFidelityDeclarationsRemainBounded() throws {
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
            #expect(manifest.sourceFidelity.tableGeometry == "preserved")
            #expect(manifest.sourceFidelity.pageBreakRelationships == "preserved")
            #expect(manifest.sourceFidelity.multilineNarrationRelationships == "preserved")
            #expect(manifest.sourceFidelity.textualPrivateValues == "replaced")
            #expect(manifest.sourceFidelity.sourceObjectIdentity == "not_preserved")
            #expect(manifest.ocrBoundary == OCRBoundary.approvedFixtureBoundary)
            #expect(manifest.privacy.allTrue)
        }
    }

    @Test func nativePDFTextGeometryAndObjectSurfacesMatchManifests() throws {
        for fixture in Self.fixtures {
            let url = FixtureLocator.hdfcBankAccountPDF("\(fixture.name).pdf")
            let manifest = try Self.manifest(fixture)
            let document = try #require(PDFDocument(url: url))
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

            let bytes = try Data(contentsOf: url)
            let objectText = String(decoding: bytes, as: UTF8.self)
            for forbidden in ["/EmbeddedFiles", "/AcroForm", "/Annots", "/Users/vyom/", "Ledger Forge Sanitization Workbench", "HDFC-CleanRoom"] {
                #expect(!objectText.contains(forbidden))
            }
        }
    }

    @Test func multilineRelationshipsMatchCleanRoomContinuationEvidence() throws {
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            let document = try #require(PDFDocument(url: FixtureLocator.hdfcBankAccountPDF("\(fixture.name).pdf")))
            let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
            #expect(text.components(separatedBy: "FIXTURE DETAIL GROUP").count - 1 == fixture.multilineContinuations)
            #expect(manifest.sourceFidelity.multilineNarrationRelationships == "preserved")
        }
    }

    @Test func legacyXLSContainersAndDimensionsMatchManifests() throws {
        let ole2Signature = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        for fixture in Self.fixtures {
            let url = FixtureLocator.hdfcBankAccountXLS("\(fixture.name).xls")
            let data = try Data(contentsOf: url)
            let manifest = try Self.manifest(fixture)
            let workbook = manifest.workbookAssertions
            #expect(url.pathExtension.lowercased() == "xls")
            #expect(data.prefix(ole2Signature.count) == ole2Signature)
            #expect(data.prefix(2) != Data([0x50, 0x4B]))
            #expect(workbook.containerFormat == "OLE2")
            #expect(workbook.workbookFormat == "BIFF8")
            #expect(workbook.sheetCount == 1)
            #expect(workbook.dimensionDefinition == "one-based maximum used row and column")
            #expect(workbook.sheets == [WorkbookSheetAssertion(sheetIndex: 0, maxUsedRow: fixture.rows, maxUsedColumn: 7, hidden: false, hiddenRowCount: 0, hiddenColumnCount: 0, mergedRangeCount: 0)])
            #expect(workbook.formulaCount == 0)
            #expect(workbook.definedNameCount == 0)
            #expect(workbook.externalLinkCount == 0)
        }
    }

    @Test func repositoryVisibleFixtureSurfacesRemainPrivacySafe() throws {
        let fixtureRoot = FixtureLocator.fixturesRoot.appendingPathComponent("HDFC").appendingPathComponent("BankAccount")
        let enumerator = try #require(FileManager.default.enumerator(at: fixtureRoot, includingPropertiesForKeys: nil))
        let urls = enumerator.compactMap { $0 as? URL }
        for url in urls {
            let lower = url.lastPathComponent.lowercased()
            for forbidden in [".synthetic", "redaction", "verification", "sanitization-report", "layout-model", "allowlist"] {
                #expect(!lower.contains(forbidden))
            }
        }

        let forbiddenText = ["/Users/vyom/", "Ledger Forge Sanitization Workbench", "HDFC-CleanRoom", "redaction-map", "source-verification", "sanitization-report", "layout-model", "generated-text-allowlist"]
        for fixture in Self.fixtures {
            let metadata = try Self.metadataText(fixture)
            let document = try #require(PDFDocument(url: FixtureLocator.hdfcBankAccountPDF("\(fixture.name).pdf")))
            let pdfText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
            let attributes = String(describing: document.documentAttributes)
            for forbidden in forbiddenText {
                #expect(!metadata.contains(forbidden))
                #expect(!pdfText.contains(forbidden))
                #expect(!attributes.contains(forbidden))
            }
        }
    }

    private static func expected(_ fixture: Fixture) throws -> HDFCExpected {
        try JSONDecoder().decode(HDFCExpected.self, from: Data(contentsOf: FixtureLocator.hdfcBankAccountExpected("\(fixture.name).expected.json")))
    }

    private static func manifest(_ fixture: Fixture) throws -> HDFCManifest {
        try JSONDecoder().decode(HDFCManifest.self, from: Data(contentsOf: FixtureLocator.hdfcBankAccountManifest("\(fixture.name).manifest.json")))
    }

    private static func metadataText(_ fixture: Fixture) throws -> String {
        try String(contentsOf: FixtureLocator.hdfcBankAccountExpected("\(fixture.name).expected.json"), encoding: .utf8)
            + String(contentsOf: FixtureLocator.hdfcBankAccountManifest("\(fixture.name).manifest.json"), encoding: .utf8)
    }
}

private struct Fixture {
    let name: String
    let accountType: String
    let transactions: Int
    let pages: Int
    let rows: Int
    let multilineContinuations: Int
}

private struct HDFCExpected: Decodable {
    let metadataSchemaVersion: Int
    let fixtureID: String
    let fixtureClass: String
    let accountType: String
    let sourceFormats: [String]
    let transactionCount: Int
    let closingBalance: String
    let computedFinalBalance: String
    let canonicalTransactions: [FinancialTransaction]
    let fictionalIdentity: FictionalIdentity
    let pdfXLSFinancialEquivalence: FinancialEquivalence
    let validationExpectation: String
    enum CodingKeys: String, CodingKey {
        case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", accountType = "account_type", sourceFormats = "source_formats", transactionCount = "transaction_count", closingBalance = "closing_balance", computedFinalBalance = "computed_final_balance", canonicalTransactions = "canonical_ordered_financial_transactions", fictionalIdentity = "fictional_identity", pdfXLSFinancialEquivalence = "pdf_xls_financial_equivalence", validationExpectation = "validation_expectation"
    }
}

private struct FinancialTransaction: Decodable {}
private struct FictionalIdentity: Decodable {
    let customerIdentityID: String
    let accountIdentityID: String
    let accountType: String
    enum CodingKeys: String, CodingKey { case customerIdentityID = "customer_identity_id", accountIdentityID = "account_identity_id", accountType = "account_type" }
}
private struct FinancialEquivalence: Decodable {
    let basis: String
    let fields: [String]
    let matches: Bool
}

private struct HDFCManifest: Decodable {
    let metadataSchemaVersion: Int
    let fixtureID: String
    let fixtureClass: String
    let candidateStatus: String
    let sanitizationMethod: SanitizationMethod
    let sourceFidelity: SourceFidelity
    let ocrBoundary: OCRBoundary
    let privacy: PrivacyAssertions
    let pdfAssertions: PDFAssertions
    let workbookAssertions: WorkbookAssertions
    enum CodingKeys: String, CodingKey { case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", candidateStatus = "candidate_status", sanitizationMethod = "sanitization_method", sourceFidelity = "source_fidelity", ocrBoundary = "ocr_boundary", privacy = "privacy_assertions", pdfAssertions = "pdf_assertions", workbookAssertions = "workbook_assertions" }
}

private struct SanitizationMethod: Decodable {
    let classification: String
    let sourceAnnotationsReused: Bool
    let sourceContentStreamsReused: Bool
    let sourceFontsReused: Bool
    let sourceImagesReused: Bool
    let sourceMetadataReused: Bool
    let sourcePageObjectsReused: Bool
    enum CodingKeys: String, CodingKey { case classification, sourceAnnotationsReused = "source_annotations_reused", sourceContentStreamsReused = "source_content_streams_reused", sourceFontsReused = "source_fonts_reused", sourceImagesReused = "source_images_reused", sourceMetadataReused = "source_metadata_reused", sourcePageObjectsReused = "source_page_objects_reused" }
}

private struct SourceFidelity: Decodable {
    let financialTruth: String
    let multilineNarrationRelationships: String
    let pageBreakRelationships: String
    let pageCount: String
    let pageDimensions: String
    let sourceObjectIdentity: String
    let tableGeometry: String
    let textualPrivateValues: String
    let transactionOrder: String
    enum CodingKeys: String, CodingKey { case financialTruth = "financial_truth", multilineNarrationRelationships = "multiline_narration_relationships", pageBreakRelationships = "page_break_relationships", pageCount = "page_count", pageDimensions = "page_dimensions", sourceObjectIdentity = "source_object_identity", tableGeometry = "table_geometry", textualPrivateValues = "textual_private_values", transactionOrder = "transaction_order" }
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
private struct PDFPageAssertion: Decodable { let pageIndex: Int; let widthPoints: Double; let heightPoints: Double; enum CodingKeys: String, CodingKey { case pageIndex = "page_index", widthPoints = "width_points", heightPoints = "height_points" } }

private struct WorkbookAssertions: Decodable {
    let containerFormat: String
    let workbookFormat: String
    let sheetCount: Int
    let dimensionDefinition: String
    let sheets: [WorkbookSheetAssertion]
    let formulaCount: Int
    let definedNameCount: Int
    let externalLinkCount: Int
    enum CodingKeys: String, CodingKey { case containerFormat = "container_format", workbookFormat = "workbook_format", sheetCount = "sheet_count", dimensionDefinition = "dimension_definition", sheets, formulaCount = "formula_count", definedNameCount = "defined_name_count", externalLinkCount = "external_link_count" }
}
private struct WorkbookSheetAssertion: Decodable, Equatable {
    let sheetIndex: Int
    let maxUsedRow: Int
    let maxUsedColumn: Int
    let hidden: Bool
    let hiddenRowCount: Int
    let hiddenColumnCount: Int
    let mergedRangeCount: Int
    enum CodingKeys: String, CodingKey { case sheetIndex = "sheet_index", maxUsedRow = "max_used_row", maxUsedColumn = "max_used_column", hidden, hiddenRowCount = "hidden_row_count", hiddenColumnCount = "hidden_column_count", mergedRangeCount = "merged_range_count" }
}
