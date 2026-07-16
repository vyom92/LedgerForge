import Foundation
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct AmericanExpressCardStatementFixtureEvidenceTests {
    private static let fixtures = [
        Fixture(name: "amex_card_statement_20260424_to_20260523", transactions: 61, pages: 7, transactionPages: 5, originalCurrencyRows: 49),
        Fixture(name: "amex_card_statement_20260524_to_20260623", transactions: 34, pages: 5, transactionPages: 3, originalCurrencyRows: 10)
    ]

    @Test func completeInventoryExistsAndSchemaV2MetadataDecodes() throws {
        let urls = Self.fixtures.flatMap { fixture in
            [
                FixtureLocator.americanExpressCardStatementPDF("\(fixture.name).pdf"),
                FixtureLocator.americanExpressCardStatementExpected("\(fixture.name).expected.json"),
                FixtureLocator.americanExpressCardStatementManifest("\(fixture.name).manifest.json")
            ]
        }
        #expect(urls.count == 6)
        #expect(urls.allSatisfy(FixtureLocator.fileExists))
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
            #expect(expected.documentFamily == "card_statement")
            #expect(expected.layoutVersion == "AMEX-CARD-PDF-CLEANROOM-v1")
            #expect(expected.layoutRelationship == "same observed layout version across both periods")
            #expect(expected.sourceFormats == ["pdf"])
            #expect(manifest.sourceFormats == ["pdf"])
            #expect(expected.productionSupportBoundary.contains("fixture evidence only"))
            #expect(!manifest.productionSupport.productionParserSupport)
            #expect(!manifest.productionSupport.productionPDFSupport)
            #expect(!manifest.productionSupport.cardDomainSemanticsFinalized)
            #expect(!manifest.productionSupport.productionSupportClaimed)
            #expect(manifest.productionSupport.classification == "fixture_evidence_only")
        }
    }

    @Test func canonicalFinancialEvidenceReconcilesWithoutProductionSemantics() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            #expect(expected.transactionCount == fixture.transactions)
            #expect(expected.transactions.count == fixture.transactions)
            #expect(expected.transactions.map(\.sourceOrder) == Array(1...fixture.transactions))
            #expect(expected.transactions.allSatisfy { $0.statementCurrency == "QAR" })
            #expect(expected.summary.reconciles)
            let previous = try Self.decimal(expected.summary.previousBalance)
            let credits = try Self.decimal(expected.summary.paymentsAndCreditsTotal)
            let debits = try Self.decimal(expected.summary.newDebitsTotal)
            let closing = try Self.decimal(expected.summary.statementClosingBalance)
            #expect(previous - credits + debits == closing)
            #expect(expected.validationExpectation.contains("no production card semantics implied"))
        }
    }

    @Test func periodsAreContiguousAndBalanceContinuous() throws {
        let earlier = try Self.expected(Self.fixtures[0])
        let later = try Self.expected(Self.fixtures[1])
        #expect(earlier.statementPeriod.start == "2026-04-24")
        #expect(earlier.statementPeriod.end == "2026-05-23")
        #expect(later.statementPeriod.start == "2026-05-24")
        #expect(later.statementPeriod.end == "2026-06-23")
        let calendar = Calendar(identifier: .gregorian)
        let earlierEnd = try #require(Self.isoDate(earlier.statementPeriod.end))
        let laterStart = try #require(Self.isoDate(later.statementPeriod.start))
        #expect(calendar.date(byAdding: .day, value: 1, to: earlierEnd) == laterStart)
        #expect(earlier.statementPeriod.end < later.statementPeriod.start)
        #expect(earlier.summary.statementClosingBalance == later.summary.previousBalance)
        #expect(earlier.periodRelationship.chronology == "R1 then R2")
        #expect(earlier.periodRelationship.overlap == "none")
        #expect(earlier.periodRelationship.calendarRelationship == "contiguous")
        #expect(later.periodRelationship == earlier.periodRelationship)
    }

    @Test func fictionalIdentityAndRowScopeRelationshipsRemainExplicit() throws {
        let evidence = try Self.fixtures.map(Self.expected)
        #expect(Set(evidence.map(\.fictionalCustomerIdentity)).count == 1)
        #expect(Set(evidence.map(\.fictionalAccountIdentity)).count == 1)
        #expect(Set(evidence.flatMap(\.fictionalInstrumentIdentities)).count == 1)
        let accountID = try #require(evidence.first?.fictionalAccountIdentity)
        let instrumentID = try #require(evidence.first?.fictionalInstrumentIdentities.first)
        #expect(accountID != instrumentID)
        for expected in evidence {
            #expect(expected.instrumentSectionCount == 1)
            let accountRows = expected.transactions.filter { $0.section == "account_level" }
            let instrumentRows = expected.transactions.filter { $0.section == "instrument_001" }
            #expect(accountRows.count == 1)
            #expect(accountRows.allSatisfy { $0.sourceClassification == "payment" && $0.fictionalInstrumentIdentity == nil })
            #expect(instrumentRows.count == expected.transactionCount - 1)
            #expect(instrumentRows.allSatisfy { $0.fictionalInstrumentIdentity == instrumentID })
            #expect(expected.accountRelationship.contains("same fictional account"))
            #expect(expected.instrumentRelationship.contains("same fictional instrument"))
        }
    }

    @Test func originalCurrencyEvidenceRemainsSeparateAndNoMissingValuesAreDerived() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            let originalCurrencyRows = expected.transactions.filter {
                $0.originalMerchantAmount != nil || $0.originalMerchantCurrency != nil
            }
            #expect(originalCurrencyRows.count == fixture.originalCurrencyRows)
            #expect(originalCurrencyRows.allSatisfy { $0.originalMerchantAmount != nil && $0.originalMerchantCurrency != nil })
            #expect(originalCurrencyRows.allSatisfy { $0.statementCurrency == "QAR" && $0.postedAmount.isEmpty == false })
            #expect(expected.transactions.allSatisfy { $0.sourceConversionRate == nil })
            #expect(expected.transactions.allSatisfy { $0.fee == nil && $0.markup == nil && $0.tax == nil })
            let manifest = try Self.manifest(fixture)
            #expect(manifest.fxAssertions.postedStatementCurrency == "QAR")
            #expect(manifest.fxAssertions.originalCurrencyEvidencePreservedSeparately)
            #expect(manifest.fxAssertions.missingRatesNotCalculated)
            #expect(manifest.fxAssertions.markupNotInvented)
        }
    }

    @Test func summariesPreserveOnlyObservedEvidenceAndRewardsRemainNonCashMetadata() throws {
        for fixture in Self.fixtures {
            let summary = try Self.expected(fixture).summary
            #expect(summary.minimumPaymentDue == nil)
            #expect(summary.fullPaymentDue == nil)
            #expect(summary.cashAdvanceTotal == nil)
            #expect(summary.feesTotal == nil)
            #expect(summary.interestOrFinanceChargeTotal == nil)
            #expect(summary.creditOrSpendingLimit == nil)
            #expect(summary.availableCredit == nil)
            #expect(summary.rewardsSummary.opening + summary.rewardsSummary.new == summary.rewardsSummary.closing)
            #expect(summary.rewardsSummary.period.isEmpty == false)
        }
    }

    @Test func cleanRoomAndSourceFidelityDeclarationsRemainBounded() throws {
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
            #expect(manifest.sourceFidelity.tableGeometry == "measured transaction column and row geometry preserved")
            #expect(manifest.sourceFidelity.pageBreakRelationships == "preserved")
            #expect(manifest.sourceFidelity.multilineNarrationRelationships == "preserved")
            #expect(manifest.sourceFidelity.instrumentSectionRelationships == "preserved")
            #expect(manifest.sourceFidelity.fxEvidenceRelationships == "preserved_when_present")
            #expect(manifest.sourceFidelity.privateTextualValues == "replaced")
            #expect(manifest.sourceFidelity.sourceObjectIdentity == "not_preserved")
            #expect(manifest.sourceFidelity.repeatedHeaders == "preserved_when_present")
            #expect(manifest.pagination.rewardsPagePreserved)
            #expect(manifest.pagination.legalPagePreserved)
            #expect(manifest.pagination.pageAssignmentsPreserved)
            #expect(manifest.privacy.usesFictionalCustomerMetadata)
            #expect(manifest.privacy.usesFictionalAccountIdentifier)
            #expect(manifest.privacy.usesFictionalInstrumentIdentifiers)
            #expect(manifest.privacy.containsNoOriginalCardIdentifier)
            #expect(manifest.privacy.containsNoOriginalTransactionReference)
            #expect(manifest.privacy.containsNoOriginalMerchantIdentity)
            #expect(manifest.privacy.containsNoPrivateMapping)
            #expect(manifest.privacy.containsNoPrivateSourcePathOrFilename)
            #expect(manifest.privacy.containsNoSourcePDFObject)
        }
    }

    @Test func nativePDFTextDimensionsAndInteractiveSurfacesMatchManifests() throws {
        for fixture in Self.fixtures {
            let url = FixtureLocator.americanExpressCardStatementPDF("\(fixture.name).pdf")
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
            #expect(manifest.ocrBoundary == .approvedFixtureBoundary)

            let objectText = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            for forbidden in ["/EmbeddedFiles", "/AcroForm", "/Annots", "/XObject", "/Subtype /Image", "/ActualText", "/Alt"] {
                #expect(!objectText.contains(forbidden))
            }
        }
    }

    @Test func paginationAndTransactionPageAssignmentsRemainExact() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            let manifest = try Self.manifest(fixture)
            #expect(manifest.pagination.transactionPageCount == fixture.transactionPages)
            #expect(expected.transactions.allSatisfy { (1...fixture.transactionPages).contains($0.page) })
            #expect(Set(expected.transactions.map(\.page)) == Set(1...fixture.transactionPages))
            #expect(manifest.instrumentAssertions.instrumentSectionCount == 1)
            #expect(manifest.instrumentAssertions.sectionOrderPreserved)
            #expect(manifest.instrumentAssertions.accountLevelPaymentDistinguished)
        }
    }

    @Test func fixtureSurfacesContainNoPrivateWorkbenchEvidence() throws {
        let forbidden = [
            ["", "Users", "vyom", ""].joined(separator: "/"),
            "Ledger Forge Sanitization Workbench", "AmericanExpress-CleanRoom",
            "redaction-map", "source-verification", "sanitization-report", "layout-model",
            "generated-text-allowlist"
        ]
        for fixture in Self.fixtures {
            let urls = [
                FixtureLocator.americanExpressCardStatementExpected("\(fixture.name).expected.json"),
                FixtureLocator.americanExpressCardStatementManifest("\(fixture.name).manifest.json")
            ]
            let metadata = try urls.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
            let pdfURL = FixtureLocator.americanExpressCardStatementPDF("\(fixture.name).pdf")
            let document = try #require(PDFDocument(url: pdfURL))
            let pdfText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
            let attributes = String(describing: document.documentAttributes)
            let repositorySurface = ([pdfURL] + urls).map {
                $0.path.replacingOccurrences(of: FixtureLocator.fixturesRoot.path, with: "LedgerForgeTests/Fixtures")
            }.joined(separator: "\n")
            for value in forbidden {
                #expect(!metadata.contains(value))
                #expect(!pdfText.contains(value))
                #expect(!attributes.contains(value))
                #expect(!repositorySurface.contains(value))
            }
        }
    }

    private static func expected(_ fixture: Fixture) throws -> ExpectedEvidence {
        try JSONDecoder().decode(ExpectedEvidence.self, from: Data(contentsOf: FixtureLocator.americanExpressCardStatementExpected("\(fixture.name).expected.json")))
    }

    private static func manifest(_ fixture: Fixture) throws -> ManifestEvidence {
        try JSONDecoder().decode(ManifestEvidence.self, from: Data(contentsOf: FixtureLocator.americanExpressCardStatementManifest("\(fixture.name).manifest.json")))
    }

    private static func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }

    private static func isoDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private struct Fixture {
    let name: String
    let transactions: Int
    let pages: Int
    let transactionPages: Int
    let originalCurrencyRows: Int
}

private struct ExpectedEvidence: Decodable {
    let metadataSchemaVersion: Int
    let fixtureID: String
    let fixtureClass: String
    let documentFamily: String
    let layoutVersion: String
    let layoutRelationship: String
    let sourceFormats: [String]
    let statementPeriod: StatementPeriod
    let statementCurrency: String
    let transactionCount: Int
    let transactions: [ExpectedTransaction]
    let fictionalCustomerIdentity: String
    let fictionalAccountIdentity: String
    let fictionalInstrumentIdentities: [String]
    let accountRelationship: String
    let instrumentRelationship: String
    let instrumentSectionCount: Int
    let summary: StatementSummary
    let periodRelationship: PeriodRelationship
    let validationExpectation: String
    let productionSupportBoundary: String

    enum CodingKeys: String, CodingKey {
        case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", documentFamily = "document_family", layoutVersion = "layout_version", layoutRelationship = "layout_relationship", sourceFormats = "source_formats", statementPeriod = "statement_period", statementCurrency = "statement_currency", transactionCount = "transaction_count", transactions = "canonical_ordered_transactions", fictionalCustomerIdentity = "fictional_customer_identity", fictionalAccountIdentity = "fictional_account_identity", fictionalInstrumentIdentities = "fictional_instrument_identities", accountRelationship = "account_relationship", instrumentRelationship = "instrument_relationship", instrumentSectionCount = "instrument_section_count", summary = "observed_statement_summary", periodRelationship = "period_relationship", validationExpectation = "validation_expectation", productionSupportBoundary = "production_support_boundary"
    }
}

private struct StatementPeriod: Decodable { let start: String; let end: String }
private struct PeriodRelationship: Decodable, Equatable {
    let chronology: String
    let overlap: String
    let calendarRelationship: String
    enum CodingKeys: String, CodingKey { case chronology, overlap, calendarRelationship = "calendar_relationship" }
}

private struct ExpectedTransaction: Decodable {
    let sourceOrder: Int
    let transactionDate: String
    let postingDate: String?
    let sanitizedNarration: String
    let sourceClassification: String
    let financialEffect: String
    let postedAmount: String
    let statementCurrency: String
    let originalMerchantAmount: String?
    let originalMerchantCurrency: String?
    let sourceConversionRate: String?
    let markup: String?
    let fee: String?
    let tax: String?
    let page: Int
    let section: String
    let fictionalInstrumentIdentity: String?
    enum CodingKeys: String, CodingKey { case sourceOrder = "source_order", transactionDate = "transaction_date", postingDate = "posting_date", sanitizedNarration = "sanitized_narration", sourceClassification = "source_classification", financialEffect = "financial_effect", postedAmount = "posted_amount", statementCurrency = "statement_currency", originalMerchantAmount = "original_merchant_amount", originalMerchantCurrency = "original_merchant_currency", sourceConversionRate = "source_conversion_rate", markup, fee, tax, page, section, fictionalInstrumentIdentity = "fictional_instrument_identity" }
}

private struct StatementSummary: Decodable {
    let previousBalance: String
    let paymentsAndCreditsTotal: String
    let newDebitsTotal: String
    let statementClosingBalance: String
    let minimumPaymentDue: String?
    let fullPaymentDue: String?
    let cashAdvanceTotal: String?
    let feesTotal: String?
    let interestOrFinanceChargeTotal: String?
    let creditOrSpendingLimit: String?
    let availableCredit: String?
    let rewardsSummary: RewardsSummary
    let reconciles: Bool
    enum CodingKeys: String, CodingKey { case previousBalance = "previous_balance", paymentsAndCreditsTotal = "payments_and_credits_total", newDebitsTotal = "new_debits_total", statementClosingBalance = "statement_closing_balance", minimumPaymentDue = "minimum_payment_due", fullPaymentDue = "full_payment_due", cashAdvanceTotal = "cash_advance_total", feesTotal = "fees_total", interestOrFinanceChargeTotal = "interest_or_finance_charge_total", creditOrSpendingLimit = "credit_or_spending_limit", availableCredit = "available_credit", rewardsSummary = "rewards_summary", reconciles }
}

private struct RewardsSummary: Decodable { let period: String; let opening: Int; let new: Int; let closing: Int }

private struct ManifestEvidence: Decodable {
    let metadataSchemaVersion: Int
    let fixtureID: String
    let fixtureClass: String
    let sourceFormats: [String]
    let sanitizationMethod: SanitizationMethod
    let sourceFidelity: SourceFidelity
    let ocrBoundary: OCRBoundary
    let pagination: PaginationAssertions
    let instrumentAssertions: InstrumentAssertions
    let fxAssertions: FXAssertions
    let privacy: PrivacyAssertions
    let pdfAssertions: PDFAssertions
    let productionSupport: ProductionSupportBoundary
    enum CodingKeys: String, CodingKey { case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", sourceFormats = "source_formats", sanitizationMethod = "sanitization_method", sourceFidelity = "source_fidelity", ocrBoundary = "ocr_boundary", pagination = "pagination_assertions", instrumentAssertions = "instrument_assertions", fxAssertions = "fx_assertions", privacy = "privacy_assertions", pdfAssertions = "pdf_assertions", productionSupport = "production_support_boundary" }
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
    let multilineNarrationRelationships: String
    let instrumentSectionRelationships: String
    let fxEvidenceRelationships: String
    let privateTextualValues: String
    let sourceObjectIdentity: String
    let repeatedHeaders: String
    enum CodingKeys: String, CodingKey { case financialTruth = "financial_truth", transactionOrder = "transaction_order", pageCount = "page_count", pageDimensions = "page_dimensions", tableGeometry = "table_geometry", pageBreakRelationships = "page_break_relationships", multilineNarrationRelationships = "multiline_narration_relationships", instrumentSectionRelationships = "instrument_section_relationships", fxEvidenceRelationships = "fx_evidence_relationships", privateTextualValues = "private_textual_values", sourceObjectIdentity = "source_object_identity", repeatedHeaders = "repeated_headers" }
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
    let transactionPageCount: Int
    let rewardsPagePreserved: Bool
    let legalPagePreserved: Bool
    let pageAssignmentsPreserved: Bool
    enum CodingKeys: String, CodingKey { case transactionPageCount = "transaction_page_count", rewardsPagePreserved = "rewards_page_preserved", legalPagePreserved = "legal_page_preserved", pageAssignmentsPreserved = "page_assignments_preserved" }
}

private struct InstrumentAssertions: Decodable {
    let instrumentSectionCount: Int
    let sectionOrderPreserved: Bool
    let accountLevelPaymentDistinguished: Bool
    enum CodingKeys: String, CodingKey { case instrumentSectionCount = "instrument_section_count", sectionOrderPreserved = "section_order_preserved", accountLevelPaymentDistinguished = "account_level_payment_distinguished" }
}

private struct FXAssertions: Decodable {
    let postedStatementCurrency: String
    let originalCurrencyEvidencePreservedSeparately: Bool
    let missingRatesNotCalculated: Bool
    let markupNotInvented: Bool
    enum CodingKeys: String, CodingKey { case postedStatementCurrency = "posted_statement_currency", originalCurrencyEvidencePreservedSeparately = "original_currency_evidence_preserved_separately", missingRatesNotCalculated = "missing_rates_not_calculated", markupNotInvented = "markup_not_invented" }
}

private struct PrivacyAssertions: Decodable {
    let usesFictionalCustomerMetadata: Bool
    let usesFictionalAccountIdentifier: Bool
    let usesFictionalInstrumentIdentifiers: Bool
    let containsNoOriginalCardIdentifier: Bool
    let containsNoOriginalTransactionReference: Bool
    let containsNoOriginalMerchantIdentity: Bool
    let containsNoPrivateMapping: Bool
    let containsNoPrivateSourcePathOrFilename: Bool
    let containsNoSourcePDFObject: Bool
    enum CodingKeys: String, CodingKey { case usesFictionalCustomerMetadata = "uses_fictional_customer_metadata", usesFictionalAccountIdentifier = "uses_fictional_account_identifier", usesFictionalInstrumentIdentifiers = "uses_fictional_instrument_identifiers", containsNoOriginalCardIdentifier = "contains_no_original_card_identifier", containsNoOriginalTransactionReference = "contains_no_original_transaction_reference", containsNoOriginalMerchantIdentity = "contains_no_original_merchant_identity", containsNoPrivateMapping = "contains_no_private_mapping", containsNoPrivateSourcePathOrFilename = "contains_no_private_source_path_or_filename", containsNoSourcePDFObject = "contains_no_source_pdf_object" }
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
    let classification: String
    let productionParserSupport: Bool
    let productionPDFSupport: Bool
    let cardDomainSemanticsFinalized: Bool
    let productionSupportClaimed: Bool
    enum CodingKeys: String, CodingKey { case classification, productionParserSupport = "production_parser_support", productionPDFSupport = "production_pdf_support", cardDomainSemanticsFinalized = "card_domain_semantics_finalized", productionSupportClaimed = "production_support_claimed" }
}
