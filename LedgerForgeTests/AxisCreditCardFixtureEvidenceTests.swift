import Foundation
import PDFKit
import Testing

@MainActor
struct AxisCreditCardFixtureEvidenceTests {
    private static let fixtures = [
        Fixture(name: "axis_credit_card_statement_20260417_to_20260517", pdfRows: 140, xlsxRows: 143, usedRows: 151, mergedRanges: 300),
        Fixture(name: "axis_credit_card_statement_20260518_to_20260617", pdfRows: 151, xlsxRows: 154, usedRows: 162, mergedRanges: 322)
    ]

    @Test func completeInventoryAndSchemaV2MetadataDecode() throws {
        let urls = Self.fixtures.flatMap { [Self.pdfURL($0), Self.xlsxURL($0), Self.expectedURL($0), Self.manifestURL($0)] }
        #expect(urls.count == 8)
        #expect(urls.allSatisfy(FixtureLocator.fileExists))
        #expect(try urls.allSatisfy { try !Data(contentsOf: $0).isEmpty })
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            let manifest = try Self.manifest(fixture)
            #expect(expected.metadataSchemaVersion == 2 && manifest.metadataSchemaVersion == 2)
            #expect(expected.fixtureID == fixture.name && manifest.fixtureID == fixture.name)
            #expect(expected.fixtureClass == "source-faithful sanitized fixture")
            #expect(manifest.fixtureClass == expected.fixtureClass && manifest.candidateStatus == "validated")
            #expect(expected.documentFamily == "card_statement" && manifest.documentFamily == "card_statement")
            #expect(expected.sourceFormats == ["pdf", "xlsx"] && manifest.sourceFormats == ["pdf", "xlsx"])
            #expect(expected.productionSupport.fixtureOnlyAndUnsupported)
            #expect(manifest.productionSupport.fixtureOnlyAndUnsupported)
        }
    }

    @Test func crossFormatFinancialProjectionAndFormatOnlyRowsRemainExact() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            #expect(expected.counts.pdf == fixture.pdfRows && expected.counts.xlsx == fixture.xlsxRows)
            #expect(expected.projection.count == fixture.pdfRows)
            #expect(expected.projection.map(\.sharedOrdinal) == Array(1...fixture.pdfRows))
            #expect(expected.projection.allSatisfy { !$0.transactionDate.isEmpty && !$0.postedAmount.isEmpty })
            #expect(expected.projection.allSatisfy { $0.statementCurrency == "INR" })
            #expect(expected.projection.allSatisfy { ["debit", "credit"].contains($0.sourceMarker) })
            #expect(expected.crossFormat.sharedOrderedRowCount == fixture.pdfRows)
            #expect(expected.crossFormat.sharedOrderPreserved && expected.crossFormat.reconciledWithFormatOnlyRows)
            #expect(!expected.crossFormat.textualEqualityRequired && !expected.crossFormat.narrationIdentityCompared)
            #expect(expected.formatOnly.pdfOnly.isEmpty && expected.formatOnly.pdfOnlyCount == 0)
            #expect(expected.formatOnly.xlsxOnly.count == 3 && expected.formatOnly.xlsxOnlyCount == 3)
            #expect(expected.formatOnly.xlsxOnly.allSatisfy { $0.classification == "legitimate_xlsx_only_source_format_evidence" && $0.statementCurrency == "INR" })
            #expect(expected.formatOnly.xlsxOnly.map(\.xlsxSourceOrder) == expected.formatOnly.xlsxOnly.map(\.xlsxSourceOrder).sorted())
            #expect(expected.formatOnly.allExclusionsTrue)
        }
    }

    @Test func consecutivePeriodsAndFictionalIdentityRemainBounded() throws {
        let evidence = try Self.fixtures.map(Self.expected)
        let calendar = Calendar(identifier: .gregorian)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let earlierEnd = try #require(formatter.date(from: evidence[0].period.end))
        let laterStart = try #require(formatter.date(from: evidence[1].period.start))
        #expect(calendar.date(byAdding: .day, value: 1, to: earlierEnd) == laterStart)
        #expect(evidence.allSatisfy { $0.periodRelationship.consecutive && !$0.periodRelationship.overlaps })
        #expect(evidence.allSatisfy { !$0.periodRelationship.balanceContinuityAsserted && !$0.periodRelationship.manufacturedContinuityValue })
        #expect(Set(evidence.map(\.identity.customerID)).count == 1)
        #expect(Set(evidence.map(\.identity.accountID)).count == 1)
        #expect(Set(evidence.flatMap(\.identity.instrumentIDs)).count == 1)
        #expect(evidence.allSatisfy { $0.identity.accountID != $0.identity.instrumentIDs.first })
        #expect(evidence.allSatisfy { !$0.identity.supplementaryInstrumentPresent })
        #expect(evidence.allSatisfy { $0.identity.customerShared && $0.identity.accountShared && $0.identity.instrumentShared })
    }

    @Test func debitCreditSummaryAndFXBoundariesRemainSourceOnly() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            #expect(expected.statementCurrency == "INR")
            #expect(expected.markerBoundary.retainedAsSourceEvidence)
            #expect(!expected.markerBoundary.universalCardEffectContract)
            #expect(!expected.markerBoundary.amountOwedNamingFinalized)
            #expect(!expected.markerBoundary.bankInterpretationAuthorized)
            #expect(!expected.markerBoundary.productionSemanticsFinalized)
            #expect(expected.summary.supportedFieldsPresent)
            #expect(expected.summary.absentFieldsRemainAbsent)
            #expect(expected.summary.unobservedFieldsAreNotInvented)
            #expect(expected.fx.allAbsentAndINROnly)
        }
    }

    @Test func PDFGeometryNativeTextAndObjectSurfacesMatchManifest() throws {
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            let document = try #require(PDFDocument(url: Self.pdfURL(fixture)))
            #expect(!document.isEncrypted && !document.isLocked)
            #expect(document.pageCount == 6 && manifest.pdf.pageCount == 6 && manifest.pdf.pages.count == 6)
            for index in 0..<6 {
                let page = try #require(document.page(at: index))
                let assertion = manifest.pdf.pages[index]
                let bounds = page.bounds(for: .mediaBox)
                #expect(assertion.pageIndex == index)
                #expect(abs(bounds.width - assertion.widthPoints) <= manifest.pdf.dimensionTolerancePoints)
                #expect(abs(bounds.height - assertion.heightPoints) <= manifest.pdf.dimensionTolerancePoints)
                #expect(!(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(page.annotations.isEmpty)
            }
            #expect(manifest.geometry.coordinateSystem == .pdfTopLeft)
            #expect(manifest.geometry.tolerances == .approved)
            #expect(manifest.geometry.maximum == .approvedObservedMaximum)
            #expect(manifest.geometry.exactRelationships.allTrue)
            #expect(manifest.geometry.comparator.used && manifest.geometry.comparator.passed && !manifest.geometry.comparator.generatorHelpersReused)
            #expect(manifest.pdf.nativeSelectableText && !manifest.pdf.hasInteractiveOrImageSurfaces)
            #expect(manifest.ocr == .approvedFixtureBoundary)
            let objectText = String(decoding: try Data(contentsOf: Self.pdfURL(fixture)), as: UTF8.self)
            #expect(["/EmbeddedFiles", "/AcroForm", "/Annots", "/Filespec", "/Subtype /Link"].allSatisfy { !objectText.contains($0) })
        }
    }

    @Test func XLSXWorkbookStructureAndCleanRoomPackageMatchManifest() throws {
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            let workbook = manifest.workbook
            #expect(workbook.sheetCount == 1 && workbook.visibleSheetCount == 1 && workbook.hiddenSheetCount == 0)
            let sheet = try #require(workbook.sheets.first)
            #expect(sheet.maxUsedRow == fixture.usedRows && sheet.maxUsedColumn == 6)
            #expect(sheet.mergedRangeCount == fixture.mergedRanges && !sheet.hidden)
            #expect(sheet.hiddenRowCount == 0 && sheet.hiddenColumnCount == 0)
            #expect(!sheet.filterPresent && !sheet.frozenPanesPresent)
            #expect(workbook.emptySurfaceCounts && workbook.relationshipPartCount == 2)
            #expect(workbook.reusedSourceIdentityPartCount == 0)
            #expect(manifest.xlsxCleanRoom.allTrue)

            let entries = try Self.zipEntries(Self.xlsxURL(fixture))
            #expect(entries.count == 8)
            #expect(entries.filter { $0.hasSuffix(".rels") }.count == 2)
            #expect(entries.allSatisfy { entry in
                !entry.hasPrefix("customXml/") && !entry.hasPrefix("xl/externalLinks/") && !entry.hasPrefix("xl/drawings/") && !entry.hasPrefix("xl/embeddings/") && !entry.hasPrefix("xl/comments")
            })
            #expect(!entries.contains("xl/vbaProject.bin"))
            let worksheet = try Self.zipText(Self.xlsxURL(fixture), entry: "xl/worksheets/sheet1.xml")
            let workbookXML = try Self.zipText(Self.xlsxURL(fixture), entry: "xl/workbook.xml")
            #expect(Self.maximumUsedCell(in: worksheet) == (fixture.usedRows, 6))
            #expect(Self.occurrences(of: ":mergeCell ", in: worksheet) == fixture.mergedRanges)
            #expect(!worksheet.contains(":f>") && !worksheet.contains(" hidden=\"1\"") && !worksheet.contains(":autoFilter") && !worksheet.contains(":pane"))
            #expect(!workbookXML.contains("<definedNames") && !workbookXML.contains("state=\"hidden\""))
        }
    }

    @Test func cleanRoomAndPrivacyBoundariesRemainExplicit() throws {
        let root = FixtureLocator.fixturesRoot.appendingPathComponent("Axis/CreditCard")
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let urls = enumerator.compactMap { $0 as? URL }
        #expect(urls.filter { !$0.hasDirectoryPath }.count == 8)
        let forbidden = ["/Users/vyom/", "Ledger Forge Sanitization Workbench", "Axis-CreditCard-CleanRoom", "redaction-map", "source-verification", "sanitization-report", "geometry-report", "metadata-audit", "visual-validation"]
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            #expect(manifest.sanitization.noSourceSurfacesReused)
            #expect(manifest.sourceFidelity.privateTextualValues == "replaced")
            #expect(manifest.sourceFidelity.sourcePDFObjectIdentity == "not_preserved")
            #expect(manifest.sourceFidelity.sourceXLSXPackageIdentity == "not_preserved")
            #expect(manifest.privacy.allTrue)
            let document = try #require(PDFDocument(url: Self.pdfURL(fixture)))
            let surfaces = try String(contentsOf: Self.expectedURL(fixture), encoding: .utf8)
                + String(contentsOf: Self.manifestURL(fixture), encoding: .utf8)
                + (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
                + String(describing: document.documentAttributes)
                + Self.zipEntries(Self.xlsxURL(fixture)).joined(separator: "\n")
                + Self.zipText(Self.xlsxURL(fixture), entry: "xl/workbook.xml")
                + Self.zipText(Self.xlsxURL(fixture), entry: "xl/worksheets/sheet1.xml")
                + Self.zipText(Self.xlsxURL(fixture), entry: "xl/sharedStrings.xml")
                + Self.zipText(Self.xlsxURL(fixture), entry: "xl/_rels/workbook.xml.rels")
            #expect(forbidden.allSatisfy { !surfaces.contains($0) })
        }
        for url in urls {
            let relativePath = url.path.replacingOccurrences(of: FixtureLocator.fixturesRoot.path + "/", with: "")
            #expect(forbidden.allSatisfy { !relativePath.contains($0) })
        }
    }

    private static func expected(_ fixture: Fixture) throws -> ExpectedEvidence { try JSONDecoder().decode(ExpectedEvidence.self, from: Data(contentsOf: expectedURL(fixture))) }
    private static func manifest(_ fixture: Fixture) throws -> ManifestEvidence { try JSONDecoder().decode(ManifestEvidence.self, from: Data(contentsOf: manifestURL(fixture))) }
    private static func pdfURL(_ fixture: Fixture) -> URL { FixtureLocator.axisCreditCardPDF("\(fixture.name).pdf") }
    private static func xlsxURL(_ fixture: Fixture) -> URL { FixtureLocator.axisCreditCardXLSX("\(fixture.name).xlsx") }
    private static func expectedURL(_ fixture: Fixture) -> URL { FixtureLocator.axisCreditCardExpected("\(fixture.name).expected.json") }
    private static func manifestURL(_ fixture: Fixture) -> URL { FixtureLocator.axisCreditCardManifest("\(fixture.name).manifest.json") }

    private static func unzip(_ arguments: [String]) throws -> String {
        let process = Process(); let output = Pipe(); process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); process.arguments = arguments; process.standardOutput = output; process.standardError = Pipe(); try process.run(); process.waitUntilExit(); #expect(process.terminationStatus == 0); return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
    private static func zipEntries(_ url: URL) throws -> [String] { try unzip(["-Z1", url.path]).split(separator: "\n").map(String.init) }
    private static func zipText(_ url: URL, entry: String) throws -> String { try unzip(["-p", url.path, entry]) }
    private static func occurrences(of needle: String, in text: String) -> Int { text.components(separatedBy: needle).count - 1 }
    private static func maximumUsedCell(in worksheet: String) -> (Int, Int) {
        let regex = try! NSRegularExpression(pattern: #"<(?:[A-Za-z]+:)?c [^>]*r="([A-Z]+)([0-9]+)""#)
        var maxRow = 0, maxColumn = 0
        for match in regex.matches(in: worksheet, range: NSRange(worksheet.startIndex..., in: worksheet)) {
            let columnText = String(worksheet[Range(match.range(at: 1), in: worksheet)!]); let row = Int(worksheet[Range(match.range(at: 2), in: worksheet)!])!
            let column = columnText.reduce(0) { $0 * 26 + Int($1.asciiValue! - Character("A").asciiValue! + 1) }
            maxRow = max(maxRow, row); maxColumn = max(maxColumn, column)
        }
        return (maxRow, maxColumn)
    }
}

private struct Fixture { let name: String; let pdfRows: Int; let xlsxRows: Int; let usedRows: Int; let mergedRanges: Int }
private struct ExpectedEvidence: Decodable {
    let metadataSchemaVersion: Int; let fixtureID: String; let fixtureClass: String; let documentFamily: String; let sourceFormats: [String]; let period: Period; let statementCurrency: String; let counts: FormatCounts; let crossFormat: CrossFormat; let projection: [Projection]; let formatOnly: FormatOnlyRows; let identity: FictionalIdentity; let periodRelationship: PeriodRelationship; let markerBoundary: MarkerBoundary; let summary: Summary; let fx: FXBoundary; let productionSupport: ProductionSupport
    enum CodingKeys: String, CodingKey { case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", documentFamily = "document_family", sourceFormats = "source_formats", period = "statement_period", statementCurrency = "statement_currency", counts = "source_format_transaction_counts", crossFormat = "cross_format_relationship", projection = "canonical_shared_ordered_projection", formatOnly = "format_only_rows", identity = "fictional_identity", periodRelationship = "period_relationship", markerBoundary = "debit_credit_source_marker_boundary", summary = "statement_summary_evidence", fx = "original_currency_and_fx_evidence", productionSupport = "production_support_boundary" }
}
private struct Period: Decodable { let start: String; let end: String }
private struct FormatCounts: Decodable { let pdf: Int; let xlsx: Int }
private struct CrossFormat: Decodable { let sharedOrderedRowCount: Int; let sharedOrderPreserved: Bool; let textualEqualityRequired: Bool; let narrationIdentityCompared: Bool; let reconciledWithFormatOnlyRows: Bool; enum CodingKeys: String, CodingKey { case sharedOrderedRowCount = "shared_ordered_row_count", sharedOrderPreserved = "shared_order_preserved", textualEqualityRequired = "textual_equality_required", narrationIdentityCompared = "narration_identity_compared", reconciledWithFormatOnlyRows = "reconciled_with_explicit_format_only_rows" } }
private struct Projection: Decodable { let sharedOrdinal: Int; let transactionDate: String; let postedAmount: String; let statementCurrency: String; let sourceMarker: String; enum CodingKeys: String, CodingKey { case sharedOrdinal = "shared_ordinal", transactionDate = "transaction_date", postedAmount = "posted_statement_amount", statementCurrency = "statement_currency", sourceMarker = "source_marker" } }
private struct FormatOnlyRow: Decodable { let classification: String; let xlsxSourceOrder: Int; let statementCurrency: String; enum CodingKeys: String, CodingKey { case classification, xlsxSourceOrder = "xlsx_source_order", statementCurrency = "statement_currency" } }
private struct FormatOnlyRows: Decodable { let pdfOnly: [FormatOnlyRow]; let xlsxOnly: [FormatOnlyRow]; let pdfOnlyCount: Int; let xlsxOnlyCount: Int; let notReconciliationFailure: Bool; let notDuplicate: Bool; let notPDFExtractionFailure: Bool; let notSanitizationOmission: Bool; let notParserError: Bool; var allExclusionsTrue: Bool { notReconciliationFailure && notDuplicate && notPDFExtractionFailure && notSanitizationOmission && notParserError }; enum CodingKeys: String, CodingKey { case pdfOnly = "pdf_only", xlsxOnly = "xlsx_only", pdfOnlyCount = "pdf_only_count", xlsxOnlyCount = "xlsx_only_count", notReconciliationFailure = "not_a_reconciliation_failure", notDuplicate = "not_a_duplicate_classification", notPDFExtractionFailure = "not_a_pdf_extraction_failure", notSanitizationOmission = "not_a_sanitization_omission", notParserError = "not_a_production_parser_error" } }
private struct FictionalIdentity: Decodable { let customerID: String; let accountID: String; let instrumentIDs: [String]; let customerShared: Bool; let accountShared: Bool; let instrumentShared: Bool; let supplementaryInstrumentPresent: Bool; enum CodingKeys: String, CodingKey { case customerID = "customer_identity_id", accountID = "account_identity_id", instrumentIDs = "instrument_identity_ids", customerShared = "customer_shared_across_periods", accountShared = "account_shared_across_periods", instrumentShared = "instrument_shared_across_periods", supplementaryInstrumentPresent = "supplementary_instrument_present" } }
private struct PeriodRelationship: Decodable { let consecutive: Bool; let overlaps: Bool; let balanceContinuityAsserted: Bool; let manufacturedContinuityValue: Bool; enum CodingKeys: String, CodingKey { case consecutive, overlaps, balanceContinuityAsserted = "balance_continuity_asserted", manufacturedContinuityValue = "manufactured_continuity_value" } }
private struct MarkerBoundary: Decodable { let retainedAsSourceEvidence: Bool; let universalCardEffectContract: Bool; let amountOwedNamingFinalized: Bool; let bankInterpretationAuthorized: Bool; let productionSemanticsFinalized: Bool; enum CodingKeys: String, CodingKey { case retainedAsSourceEvidence = "retained_as_observed_source_evidence", universalCardEffectContract = "universal_card_effect_contract", amountOwedNamingFinalized = "increase_decrease_amount_owed_naming_finalized", bankInterpretationAuthorized = "bank_account_income_expense_interpretation_authorized", productionSemanticsFinalized = "production_semantics_finalized" } }
private struct SummaryField: Decodable { let present: Bool; let sourceValue: String?; enum CodingKeys: String, CodingKey { case present, sourceValue = "source_value" } }
private struct Summary: Decodable { let totalPaymentDue: SummaryField; let minimumPaymentDue: SummaryField; let paymentDueDate: SummaryField; let creditLimit: SummaryField; let openingBalance: SummaryField; let cashAdvance: SummaryField; let installment: SummaryField; let financeCharge: SummaryField; let unobservedFieldsAreNotInvented: Bool; var supportedFieldsPresent: Bool { [totalPaymentDue, minimumPaymentDue, paymentDueDate, creditLimit, openingBalance].allSatisfy { $0.present && $0.sourceValue != nil } }; var absentFieldsRemainAbsent: Bool { [cashAdvance, installment, financeCharge].allSatisfy { !$0.present && $0.sourceValue == nil } }; enum CodingKeys: String, CodingKey { case totalPaymentDue = "total_payment_due", minimumPaymentDue = "minimum_payment_due", paymentDueDate = "payment_due_date", creditLimit = "credit_limit", openingBalance = "opening_balance", cashAdvance = "cash_advance_summary", installment = "installment_summary", financeCharge = "finance_charge_summary", unobservedFieldsAreNotInvented = "unobserved_fields_are_not_invented" } }
private struct FXBoundary: Decodable { let originalAmount: String?; let originalCurrency: String?; let conversionRate: String?; let markup: String?; let fee: String?; let tax: String?; let multiCurrencyPresent: Bool; let observedCurrencies: [String]; var allAbsentAndINROnly: Bool { originalAmount == nil && originalCurrency == nil && conversionRate == nil && markup == nil && fee == nil && tax == nil && !multiCurrencyPresent && observedCurrencies == ["INR"] }; enum CodingKeys: String, CodingKey { case originalAmount = "original_merchant_amount", originalCurrency = "original_merchant_currency", conversionRate = "printed_conversion_rate", markup = "fx_markup", fee = "transaction_level_fee_field", tax = "transaction_level_tax_field", multiCurrencyPresent = "multi_currency_transaction_evidence_present", observedCurrencies = "observed_statement_currencies" } }
private struct ProductionSupport: Decodable { let classification: String; let parser: Bool; let pdf: Bool; let xlsx: Bool; let importSupported: Bool; let semantics: Bool; let markerInterpretation: Bool; let fwBlocked: Bool; var fixtureOnlyAndUnsupported: Bool { classification == "fixture_evidence_only" && !parser && !pdf && !xlsx && !importSupported && !semantics && !markerInterpretation && fwBlocked }; enum CodingKeys: String, CodingKey { case classification, parser = "axis_card_production_parser_support", pdf = "pdf_production_support", xlsx = "xlsx_production_support", importSupported = "statement_import_supported", semantics = "card_semantics_finalized", markerInterpretation = "debit_credit_production_interpretation", fwBlocked = "fw_p1_09_remains_blocked" } }

private struct ManifestEvidence: Decodable { let metadataSchemaVersion: Int; let fixtureID: String; let fixtureClass: String; let candidateStatus: String; let documentFamily: String; let sourceFormats: [String]; let sanitization: Sanitization; let sourceFidelity: SourceFidelity; let geometry: Geometry; let pdf: PDFAssertions; let ocr: OCRBoundary; let workbook: WorkbookAssertions; let xlsxCleanRoom: XLSXCleanRoom; let privacy: PrivacyAssertions; let productionSupport: ProductionSupport; enum CodingKeys: String, CodingKey { case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", candidateStatus = "candidate_status", documentFamily = "document_family", sourceFormats = "source_formats", sanitization = "sanitization_method", sourceFidelity = "source_fidelity", geometry = "pdf_geometry_contract", pdf = "pdf_assertions", ocr = "ocr_boundary", workbook = "workbook_assertions", xlsxCleanRoom = "xlsx_clean_room_assertions", privacy = "privacy_assertions", productionSupport = "production_support_boundary" } }
private struct Sanitization: Decodable { let flags: [String: Bool]; init(from decoder: Decoder) throws { let container = try decoder.singleValueContainer(); let values = try container.decode([String: JSONValue].self); flags = values.compactMapValues { $0.boolValue } }; var noSourceSurfacesReused: Bool { flags.filter { $0.key.hasSuffix("_reused") }.values.allSatisfy { !$0 } } }
private enum JSONValue: Decodable { case bool(Bool), string(String); init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); if let value = try? c.decode(Bool.self) { self = .bool(value) } else { self = .string(try c.decode(String.self)) } }; var boolValue: Bool? { if case .bool(let value) = self { value } else { nil } } }
private struct SourceFidelity: Decodable { let privateTextualValues: String; let sourcePDFObjectIdentity: String; let sourceXLSXPackageIdentity: String; enum CodingKeys: String, CodingKey { case privateTextualValues = "private_textual_values", sourcePDFObjectIdentity = "source_pdf_object_identity", sourceXLSXPackageIdentity = "source_xlsx_package_identity" } }
private struct CoordinateSystem: Decodable, Equatable { let origin: String; let xDirection: String; let yDirection: String; let unit: String; static let pdfTopLeft = Self(origin: "top_left", xDirection: "right", yDirection: "down", unit: "pdf_point"); enum CodingKeys: String, CodingKey { case origin, xDirection = "x_direction", yDirection = "y_direction", unit } }
private struct GeometryTolerances: Decodable, Equatable { let pageDimensions: Double; let table: Double; let summary: Double; let columns: Double; let headers: Double; let transactions: Double; let amounts: Double; let indentation: Double; let spacing: Double; let sections: Double; let footer: Double; static let approved = Self(pageDimensions: 0.25, table: 2, summary: 2, columns: 1.5, headers: 1.5, transactions: 2, amounts: 1.5, indentation: 2, spacing: 2, sections: 2, footer: 3); enum CodingKeys: String, CodingKey { case pageDimensions = "page_dimensions", table = "table_region_bounds", summary = "summary_region_bounds", columns = "column_anchors", headers = "header_baselines", transactions = "transaction_baselines", amounts = "amount_alignment_anchors", indentation = "multiline_indentation", spacing = "multiline_spacing", sections = "section_bounds", footer = "footer_legal_bounds" } }
private struct GeometryMaximum: Decodable, Equatable { let table: Double; let summary: Double; let column: Double; let transaction: Double; let multiline: Double; static let approvedObservedMaximum = Self(table: 0.00006103515625, summary: 0.00006103515625, column: 0.00006103515625, transaction: 0.000030517578125, multiline: 0.000030517578125); enum CodingKeys: String, CodingKey { case table = "table_region", summary = "summary_region", column = "column_anchor", transaction = "transaction_baseline", multiline = "multiline_relationship" } }
private struct ExactRelationships: Decodable { let values: [String: Bool]; init(from decoder: Decoder) throws { values = try decoder.singleValueContainer().decode([String: Bool].self) }; var allTrue: Bool { values.count == 10 && values.values.allSatisfy { $0 } } }
private struct Comparator: Decodable { let used: Bool; let passed: Bool; let generatorHelpersReused: Bool; enum CodingKeys: String, CodingKey { case used, passed, generatorHelpersReused = "generator_helpers_reused" } }
private struct Geometry: Decodable { let coordinateSystem: CoordinateSystem; let tolerances: GeometryTolerances; let maximum: GeometryMaximum; let exactRelationships: ExactRelationships; let comparator: Comparator; enum CodingKeys: String, CodingKey { case coordinateSystem = "coordinate_system", tolerances = "declared_tolerances_points", maximum = "actual_maximum_deviations_points", exactRelationships = "exact_relationships", comparator = "independent_comparator" } }
private struct PDFAssertions: Decodable { let pageCount: Int; let dimensionTolerancePoints: Double; let pages: [PDFPage]; let nativeSelectableText: Bool; let annotations: Bool; let forms: Bool; let attachments: Bool; let links: Bool; let images: Bool; var hasInteractiveOrImageSurfaces: Bool { annotations || forms || attachments || links || images }; enum CodingKeys: String, CodingKey { case pageCount = "page_count", dimensionTolerancePoints = "dimension_tolerance_points", pages, nativeSelectableText = "native_selectable_text", annotations = "annotations_present", forms = "forms_present", attachments = "attachments_present", links = "links_present", images = "images_present" } }
private struct PDFPage: Decodable { let pageIndex: Int; let widthPoints: Double; let heightPoints: Double; enum CodingKeys: String, CodingKey { case pageIndex = "page_index", widthPoints = "width_points", heightPoints = "height_points" } }
private struct OCRBoundary: Decodable, Equatable { let nativeText: Bool; let pdfkit: Bool; let pymupdf: Bool; let ocrUsed: Bool; let ocrRequired: Bool; let scope: String; static let approvedFixtureBoundary = Self(nativeText: true, pdfkit: true, pymupdf: true, ocrUsed: false, ocrRequired: false, scope: "approved_fixture_layout_only"); enum CodingKeys: String, CodingKey { case nativeText = "native_text_available", pdfkit = "pdfkit_extraction_usable", pymupdf = "pymupdf_extraction_usable", ocrUsed = "ocr_used", ocrRequired = "ocr_required_for_fixture", scope } }
private struct WorkbookAssertions: Decodable { let sheetCount: Int; let sheets: [WorkbookSheet]; let formulaCount: Int; let definedNameCount: Int; let externalLinkCount: Int; let commentCount: Int; let drawingCount: Int; let embeddedObjectCount: Int; let customXMLCount: Int; let macroPresent: Bool; let visibleSheetCount: Int; let hiddenSheetCount: Int; let relationshipPartCount: Int; let reusedSourceIdentityPartCount: Int; var emptySurfaceCounts: Bool { formulaCount == 0 && definedNameCount == 0 && externalLinkCount == 0 && commentCount == 0 && drawingCount == 0 && embeddedObjectCount == 0 && customXMLCount == 0 && !macroPresent }; enum CodingKeys: String, CodingKey { case sheetCount = "sheet_count", sheets, formulaCount = "formula_count", definedNameCount = "defined_name_count", externalLinkCount = "external_link_count", commentCount = "comment_count", drawingCount = "drawing_count", embeddedObjectCount = "embedded_object_count", customXMLCount = "custom_xml_count", macroPresent = "macro_present", visibleSheetCount = "visible_sheet_count", hiddenSheetCount = "hidden_sheet_count", relationshipPartCount = "relationship_part_count", reusedSourceIdentityPartCount = "reused_source_identity_part_count" } }
private struct WorkbookSheet: Decodable { let maxUsedRow: Int; let maxUsedColumn: Int; let hidden: Bool; let hiddenRowCount: Int; let hiddenColumnCount: Int; let mergedRangeCount: Int; let filterPresent: Bool; let frozenPanesPresent: Bool; enum CodingKeys: String, CodingKey { case maxUsedRow = "max_used_row", maxUsedColumn = "max_used_column", hidden, hiddenRowCount = "hidden_row_count", hiddenColumnCount = "hidden_column_count", mergedRangeCount = "merged_range_count", filterPresent = "filter_present", frozenPanesPresent = "frozen_panes_present" } }
private struct XLSXCleanRoom: Decodable { let flags: [String: Bool]; init(from decoder: Decoder) throws { flags = try decoder.singleValueContainer().decode([String: Bool].self) }; var allTrue: Bool { flags["fresh_ooxml_reconstruction"] == true && flags.filter { $0.key.hasSuffix("_reused") }.values.allSatisfy { !$0 } } }
private struct PrivacyAssertions: Decodable { let flags: [String: Bool]; init(from decoder: Decoder) throws { flags = try decoder.singleValueContainer().decode([String: Bool].self) }; var allTrue: Bool { !flags.isEmpty && flags.values.allSatisfy { $0 } } }
