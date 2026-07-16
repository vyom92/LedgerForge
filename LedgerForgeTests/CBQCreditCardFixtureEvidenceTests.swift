import Foundation
import PDFKit
import Testing

@MainActor
struct CBQCreditCardFixtureEvidenceTests {
    private static let fixtures = [
        Fixture(name: "cbq_credit_card_statement_v1_earlier", layout: "v1", transactions: 28, originalCurrencyRows: 9),
        Fixture(name: "cbq_credit_card_statement_v1_later", layout: "v1", transactions: 14, originalCurrencyRows: 1),
        Fixture(name: "cbq_credit_card_statement_v2_earlier", layout: "v2", transactions: 11, originalCurrencyRows: 2),
        Fixture(name: "cbq_credit_card_statement_v2_later", layout: "v2", transactions: 23, originalCurrencyRows: 16)
    ]

    @Test func completeInventoryAndSchemaV2MetadataDecode() throws {
        let urls = Self.fixtures.flatMap { fixture in
            [Self.pdfURL(fixture), Self.expectedURL(fixture), Self.manifestURL(fixture)]
        }
        #expect(urls.count == 12)
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
            #expect(manifest.fixtureClass == expected.fixtureClass)
            #expect(expected.documentFamily == "card_statement")
            #expect(expected.sourceFormats == ["pdf"])
            #expect(expected.productionSupport.classification == "fixture_evidence_only")
            #expect(!expected.productionSupport.productionParserSupport)
            #expect(!expected.productionSupport.cardDomainSemanticsFinalized)
            #expect(!expected.productionSupport.ledgerForgeImportSupportClaimed)
            #expect(expected.productionSupport.fwP109Status == "blocked")
        }
    }

    @Test func canonicalFinancialEvidenceRemainsOrderedAndReconciled() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            #expect(expected.transactionCount == fixture.transactions)
            #expect(expected.transactions.count == fixture.transactions)
            #expect(expected.transactions.map(\.sourceOrder) == Array(1...fixture.transactions))
            #expect(expected.transactions.allSatisfy { !$0.transactionDate.isEmpty && !$0.postedAmount.isEmpty })
            #expect(expected.transactions.allSatisfy { $0.statementCurrency == "QAR" })
            #expect(expected.statementCurrency == "QAR")
            #expect(expected.validation.financialReconciliation == "expected_pass")
            #expect(expected.validation.transactionOrder == "exact_source_order")
            #expect(expected.validation.pageAssignment == "exact")
            #expect(expected.validation.instrumentAssignment == "exact")
            #expect(expected.validation.transactionCount == fixture.transactions)
        }
    }

    @Test func periodsAreConsecutiveNonOverlappingAndBalanceContinuous() throws {
        let evidence = try Self.fixtures.map(Self.expected)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        #expect(evidence.map(\.periodRelationships.chronologicalPosition) == [1, 2, 3, 4])
        #expect(evidence.allSatisfy { $0.periodRelationships.periodsConsecutive && !$0.periodRelationships.periodsOverlap })
        #expect(evidence.allSatisfy { $0.periodRelationships.closingToNextContinuitySourceSupported })
        #expect(evidence.allSatisfy { !$0.periodRelationships.continuityValueManufactured })
        for (earlier, later) in zip(evidence, evidence.dropFirst()) {
            let end = try #require(formatter.date(from: earlier.statementPeriod.end))
            let start = try #require(formatter.date(from: later.statementPeriod.start))
            #expect(Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: end) == start)
            #expect(earlier.summary.closingBalance == later.summary.previousBalance)
            #expect(earlier.periodRelationships.nextFixtureID == later.fixtureID)
            #expect(later.periodRelationships.previousFixtureID == earlier.fixtureID)
        }
    }

    @Test func fictionalCustomerAccountAndInstrumentRelationshipsRemainExact() throws {
        let evidence = try Self.fixtures.map(Self.expected)
        #expect(Set(evidence.map(\.customer.customerID)).count == 1)
        #expect(Set(evidence.map(\.account.accountID)).count == 1)
        #expect(Set(evidence.flatMap { $0.instruments.map(\.instrumentID) }).count == 2)
        for expected in evidence {
            let identity = expected.identityRelationships
            #expect(identity.customerContinuous && identity.accountContinuous && identity.instrumentsContinuous)
            #expect(identity.primaryAndSupplementaryDistinct && identity.instrumentsDistinctFromAccount)
            #expect(identity.continuityAcrossLayoutTransition)
            #expect(identity.accountID != identity.primaryInstrumentID)
            #expect(identity.accountID != identity.supplementaryInstrumentID)
            #expect(Set(expected.instruments.map(\.relationship)) == ["primary", "supplementary"])
            #expect(expected.instrumentRelationships.accountID == expected.account.accountID)
            #expect(expected.instrumentRelationships.instruments.allSatisfy { $0.accountRelationship == "belongs_to_fictional_account" })
            #expect(expected.transactions.allSatisfy { transaction in
                expected.instruments.contains { $0.instrumentID == transaction.instrumentID }
                    && transaction.instrumentID == transaction.instrumentSectionID
            })
        }
    }

    @Test func layoutTransitionAndSummaryMembershipRemainExplicit() throws {
        let evidence = try Self.fixtures.map(Self.expected)
        #expect(evidence.prefix(2).allSatisfy { $0.layoutVersion.hasSuffix("-v1") && $0.summary.layoutFamily == "v1_legacy_summary" })
        #expect(evidence.suffix(2).allSatisfy { $0.layoutVersion.hasSuffix("-v2") && $0.summary.layoutFamily == "v2_equation_summary" })
        for expected in evidence {
            #expect(expected.layout.layoutVersion == expected.layoutVersion)
            #expect(expected.layout.instrumentSpecificTransactionSections)
            #expect(expected.layout.page2ContinuationSupported)
            #expect(expected.layout.repeatedHeadersControlContinuation)
            #expect(expected.layout.informationalRegionsDoNotTerminateTransactions)
            #expect(expected.layout.page3Classification == "replaced_non_transactional_promotional_region")
            #expect(expected.layout.sameAccountAcrossTransition)
            if expected.summary.layoutFamily == "v1_legacy_summary" {
                #expect(expected.summary.amountBilled != nil && expected.summary.paymentReceived != nil && expected.summary.availableLimit != nil)
                #expect(expected.summary.payments == nil && expected.summary.creditsOrReversals == nil && expected.summary.purchases == nil)
            } else {
                #expect(expected.summary.payments != nil && expected.summary.creditsOrReversals != nil && expected.summary.purchases != nil)
                #expect(expected.summary.installments != nil && expected.summary.feesOrCharges != nil)
                #expect(expected.summary.amountBilled == nil && expected.summary.paymentReceived == nil && expected.summary.availableLimit == nil)
            }
        }
    }

    @Test func originalCurrencyEvidenceStaysSeparateWithoutDerivedValues() throws {
        for fixture in Self.fixtures {
            let expected = try Self.expected(fixture)
            let originalRows = expected.transactions.filter { $0.originalMerchantAmount != nil || $0.originalMerchantCurrency != nil }
            #expect(originalRows.count == fixture.originalCurrencyRows)
            #expect(originalRows.allSatisfy { $0.originalMerchantAmount != nil && $0.originalMerchantCurrency != nil })
            #expect(originalRows.allSatisfy { $0.statementCurrency == "QAR" && $0.originalMerchantCurrency != "QAR" })
            #expect(expected.fxEvidence.postedStatementCurrency == "QAR")
            #expect(expected.fxEvidence.postedAmountDistinctFromOriginalMerchantAmount)
            #expect(!expected.fxEvidence.printedFXRateEvidencePresent)
            #expect(!expected.fxEvidence.missingFXRatesCalculated)
            #expect(!expected.fxEvidence.missingMarkupCalculated)
            #expect(expected.transactions.allSatisfy { $0.statementFXRate == nil })
            #expect(expected.transactions.allSatisfy { $0.markup == nil && $0.tax == nil })
            #expect(expected.transactions.allSatisfy { transaction in
                transaction.fee == nil || (transaction.sourceClassification == "fee" && transaction.fee == transaction.postedAmount)
            })
        }
    }

    @Test func geometryEvidencePreservesQualifiedToleranceClaims() throws {
        for (index, fixture) in Self.fixtures.enumerated() {
            let geometry = try Self.manifest(fixture).geometry
            #expect(geometry.coordinateSystem == .pdfTopLeft)
            #expect(geometry.tolerances == .approved)
            #expect(geometry.maximum.pageDimensions == 0 && geometry.maximum.tableRegionBounds == 0)
            #expect(geometry.maximum.summaryRegionBounds == 0 && geometry.maximum.columnAnchors == 0)
            #expect(geometry.maximum.headerBaselines == 0.346 && geometry.maximum.transactionBaselines == 0.957)
            #expect(geometry.maximum.amountAlignmentAnchors == 0 && geometry.maximum.sectionBounds == 0 && geometry.maximum.footerRegionBounds == 0)
            #expect(geometry.exactRelationships.allTrue)
            #expect(geometry.independentComparatorPassed)
            if index < 3 {
                #expect(geometry.observationCounts.multilineIndentation == 0 && geometry.observationCounts.multilineSpacing == 0)
                #expect(geometry.maximum.multilineIndentation == nil && geometry.maximum.multilineSpacing == nil)
                #expect(geometry.measurementStatus.multilineIndentation == "not_applicable")
                #expect(geometry.measurementStatus.multilineSpacing == "not_applicable")
            } else {
                #expect(geometry.observationCounts.multilineIndentation == 4 && geometry.observationCounts.multilineSpacing == 4)
                #expect(geometry.maximum.multilineIndentation == 0 && geometry.maximum.multilineSpacing == 1.047)
                #expect(geometry.measurementStatus.multilineIndentation == "measured")
                #expect(geometry.measurementStatus.multilineSpacing == "measured")
            }
        }
    }

    @Test func cleanRoomAndProductionBoundariesRemainExplicit() throws {
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            #expect(manifest.sanitization.classification == "clean_room_pdf_reconstruction")
            #expect(manifest.sanitization.noSourceSurfacesReused)
            #expect(manifest.sourceFidelity.privateTextualValues == "replaced")
            #expect(manifest.sourceFidelity.sourceObjectIdentity == "not_preserved")
            #expect(manifest.sourceFidelity.financialTruth == "exact")
            #expect(manifest.sourceFidelity.transactionOrder == "exact")
            #expect(manifest.privacy.allTrue)
            #expect(manifest.productionSupport.classification == "fixture_evidence_only")
            #expect(!manifest.productionSupport.productionParserSupport)
            #expect(!manifest.productionSupport.cardDomainSemanticsFinalized)
            #expect(!manifest.productionSupport.ledgerForgeImportSupportClaimed)
        }
    }

    @Test func nativePDFTextAndObjectSurfacesMatchDeclarations() throws {
        for fixture in Self.fixtures {
            let manifest = try Self.manifest(fixture)
            let document = try #require(PDFDocument(url: Self.pdfURL(fixture)))
            #expect(!document.isEncrypted && !document.isLocked)
            #expect(document.pageCount == 3 && document.pageCount == manifest.pdfAssertions.pageCount)
            #expect(manifest.pdfAssertions.pages.count == 3)
            for index in 0..<3 {
                let page = try #require(document.page(at: index))
                let assertion = manifest.pdfAssertions.pages[index]
                let bounds = page.bounds(for: .mediaBox)
                #expect(assertion.pageIndex == index)
                #expect(abs(bounds.width - assertion.widthPoints) <= manifest.pdfAssertions.dimensionTolerancePoints)
                #expect(abs(bounds.height - assertion.heightPoints) <= manifest.pdfAssertions.dimensionTolerancePoints)
                #expect(!(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(page.annotations.isEmpty)
            }
            #expect(manifest.ocrBoundary == .approvedFixtureBoundary)
            #expect(manifest.pdfAssertions.nativeSelectableText)
            #expect(!manifest.pdfAssertions.annotationsPresent && !manifest.pdfAssertions.formsPresent && !manifest.pdfAssertions.attachmentsPresent)
            let objectText = String(decoding: try Data(contentsOf: Self.pdfURL(fixture)), as: UTF8.self)
            for forbidden in ["/EmbeddedFiles", "/AcroForm", "/Annots", "/Filespec", "/Subtype /Link", "/Users/vyom/"] {
                #expect(!objectText.contains(forbidden))
            }
        }
    }

    @Test func repositoryVisibleSurfacesRemainPrivacySafe() throws {
        let root = FixtureLocator.fixturesRoot.appendingPathComponent("CBQ/CreditCard")
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]))
        let urls = enumerator.compactMap { $0 as? URL }
        #expect(urls.filter { !$0.hasDirectoryPath }.count == 12)
        let forbidden = ["/Users/vyom/", "Ledger Forge Sanitization Workbench", "CBQ-CreditCard-CleanRoom", "redaction-map", "source-verification", "sanitization-report", "geometry-validation-report", "geometry-comparison", "layout-model", "generated-text-allowlist", "metadata-audit", "VisualValidation"]
        for url in urls {
            let repositoryRelativePath = url.path.replacingOccurrences(of: FixtureLocator.fixturesRoot.path + "/", with: "")
            #expect(forbidden.allSatisfy { !repositoryRelativePath.contains($0) })
        }
        for fixture in Self.fixtures {
            let document = try #require(PDFDocument(url: Self.pdfURL(fixture)))
            let surfaces = try String(contentsOf: Self.expectedURL(fixture), encoding: .utf8)
                + String(contentsOf: Self.manifestURL(fixture), encoding: .utf8)
                + (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
                + String(describing: document.documentAttributes)
            #expect(forbidden.allSatisfy { !surfaces.contains($0) })
        }
    }

    private static func expected(_ fixture: Fixture) throws -> ExpectedEvidence {
        try JSONDecoder().decode(ExpectedEvidence.self, from: Data(contentsOf: expectedURL(fixture)))
    }
    private static func manifest(_ fixture: Fixture) throws -> ManifestEvidence {
        try JSONDecoder().decode(ManifestEvidence.self, from: Data(contentsOf: manifestURL(fixture)))
    }
    private static func pdfURL(_ fixture: Fixture) -> URL { FixtureLocator.cbqCreditCardPDF("\(fixture.name).pdf", layoutVersion: fixture.layout) }
    private static func expectedURL(_ fixture: Fixture) -> URL { FixtureLocator.cbqCreditCardExpected("\(fixture.name).expected.json") }
    private static func manifestURL(_ fixture: Fixture) -> URL { FixtureLocator.cbqCreditCardManifest("\(fixture.name).manifest.json") }
}

private struct Fixture { let name: String; let layout: String; let transactions: Int; let originalCurrencyRows: Int }

private struct ExpectedEvidence: Decodable {
    let metadataSchemaVersion: Int; let fixtureID: String; let fixtureClass: String; let documentFamily: String; let sourceFormats: [String]
    let layoutVersion: String; let transactionCount: Int; let statementCurrency: String; let statementPeriod: StatementPeriod
    let customer: CustomerIdentity; let account: AccountIdentity; let instruments: [InstrumentIdentity]
    let identityRelationships: IdentityRelationships; let instrumentRelationships: InstrumentRelationships
    let periodRelationships: PeriodRelationships; let layout: LayoutRelationships; let fxEvidence: FXEvidence
    let summary: SummaryEvidence; let transactions: [TransactionEvidence]; let validation: ValidationExpectations
    let productionSupport: ProductionSupport
    enum CodingKeys: String, CodingKey {
        case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", documentFamily = "document_family", sourceFormats = "source_formats", layoutVersion = "layout_version", transactionCount = "transaction_count", statementCurrency = "statement_currency", statementPeriod = "statement_period", customer = "fictional_customer_identity", account = "fictional_account_identity", instruments = "fictional_instrument_identities", identityRelationships = "fictional_identity_relationships", instrumentRelationships = "instrument_relationships", periodRelationships = "period_relationships", layout = "layout_relationships", fxEvidence = "original_currency_and_fx_evidence", summary = "statement_summary_evidence", transactions = "canonical_ordered_transactions", validation = "validation_expectations", productionSupport = "production_support_boundary"
    }
}

private struct StatementPeriod: Decodable { let start: String; let end: String }
private struct CustomerIdentity: Decodable { let customerID: String; enum CodingKeys: String, CodingKey { case customerID = "customer_id" } }
private struct AccountIdentity: Decodable { let accountID: String; enum CodingKeys: String, CodingKey { case accountID = "account_id" } }
private struct InstrumentIdentity: Decodable { let instrumentID: String; let relationship: String; enum CodingKeys: String, CodingKey { case instrumentID = "instrument_id", relationship } }
private struct InstrumentRelationships: Decodable { let accountID: String; let instruments: [InstrumentRelationship]; enum CodingKeys: String, CodingKey { case accountID = "account_id", instruments } }
private struct InstrumentRelationship: Decodable { let instrumentID: String; let role: String; let accountRelationship: String; enum CodingKeys: String, CodingKey { case instrumentID = "instrument_id", role, accountRelationship = "account_relationship" } }

private struct IdentityRelationships: Decodable {
    let accountID: String; let primaryInstrumentID: String; let supplementaryInstrumentID: String
    let customerContinuous: Bool; let accountContinuous: Bool; let instrumentsContinuous: Bool; let primaryAndSupplementaryDistinct: Bool; let instrumentsDistinctFromAccount: Bool; let continuityAcrossLayoutTransition: Bool
    enum CodingKeys: String, CodingKey { case accountID = "account_id", primaryInstrumentID = "primary_instrument_id", supplementaryInstrumentID = "supplementary_instrument_id", customerContinuous = "customer_continuous_across_all_fixtures", accountContinuous = "account_continuous_across_all_fixtures", instrumentsContinuous = "instrument_identities_continuous_across_all_fixtures", primaryAndSupplementaryDistinct = "primary_and_supplementary_distinct", instrumentsDistinctFromAccount = "instruments_distinct_from_account", continuityAcrossLayoutTransition = "continuity_preserved_across_v1_to_v2_transition" }
}

private struct PeriodRelationships: Decodable {
    let chronologicalPosition: Int; let previousFixtureID: String?; let nextFixtureID: String?; let periodsConsecutive: Bool; let periodsOverlap: Bool; let closingToNextContinuitySourceSupported: Bool; let continuityValueManufactured: Bool
    enum CodingKeys: String, CodingKey { case chronologicalPosition = "chronological_position", previousFixtureID = "previous_fixture_id", nextFixtureID = "next_fixture_id", periodsConsecutive = "periods_consecutive", periodsOverlap = "periods_overlap", closingToNextContinuitySourceSupported = "closing_to_next_previous_balance_continuity_source_supported", continuityValueManufactured = "continuity_value_manufactured" }
}

private struct LayoutRelationships: Decodable {
    let layoutVersion: String; let instrumentSpecificTransactionSections: Bool; let page2ContinuationSupported: Bool; let repeatedHeadersControlContinuation: Bool; let informationalRegionsDoNotTerminateTransactions: Bool; let page3Classification: String; let sameAccountAcrossTransition: Bool
    enum CodingKeys: String, CodingKey { case layoutVersion = "layout_version", instrumentSpecificTransactionSections = "instrument_specific_transaction_sections", page2ContinuationSupported = "page_2_continuation_supported_when_observed", repeatedHeadersControlContinuation = "repeated_transaction_headers_control_continuation", informationalRegionsDoNotTerminateTransactions = "informational_or_apparent_end_regions_are_not_termination_when_transactions_continue", page3Classification = "page_3_classification", sameAccountAcrossTransition = "same_account_across_layout_transition" }
}

private struct FXEvidence: Decodable {
    let postedStatementCurrency: String; let postedAmountDistinctFromOriginalMerchantAmount: Bool; let printedFXRateEvidencePresent: Bool; let missingFXRatesCalculated: Bool; let missingMarkupCalculated: Bool
    enum CodingKeys: String, CodingKey { case postedStatementCurrency = "posted_statement_amount_currency", postedAmountDistinctFromOriginalMerchantAmount = "posted_statement_amount_kept_distinct_from_original_merchant_amount", printedFXRateEvidencePresent = "printed_fx_rate_evidence_present", missingFXRatesCalculated = "missing_fx_rates_calculated", missingMarkupCalculated = "missing_markup_calculated" }
}

private struct SummaryEvidence: Decodable {
    let layoutFamily: String; let previousBalance: String; let closingBalance: String; let amountBilled: String?; let paymentReceived: String?; let availableLimit: String?; let payments: String?; let creditsOrReversals: String?; let purchases: String?; let installments: String?; let feesOrCharges: String?
    enum CodingKeys: String, CodingKey { case layoutFamily = "layout_family", previousBalance = "previous_balance", closingBalance = "closing_balance", amountBilled = "amount_billed", paymentReceived = "payment_received", availableLimit = "available_limit", payments, creditsOrReversals = "credits_or_reversals", purchases, installments, feesOrCharges = "fees_or_charges" }
}

private struct TransactionEvidence: Decodable {
    let transactionDate: String; let postedAmount: String; let statementCurrency: String; let sourceClassification: String; let instrumentID: String; let originalMerchantAmount: String?; let originalMerchantCurrency: String?; let statementFXRate: String?; let markup: String?; let fee: String?; let tax: String?; let page: Int; let sourceOrder: Int; let instrumentSectionID: String
    enum CodingKeys: String, CodingKey { case transactionDate = "transaction_date", postedAmount = "posted_amount", statementCurrency = "statement_currency", sourceClassification = "source_classification", instrumentID = "instrument_id", originalMerchantAmount = "original_merchant_amount", originalMerchantCurrency = "original_merchant_currency", statementFXRate = "statement_fx_rate", markup, fee, tax, page, sourceOrder = "source_order", instrumentSectionID = "instrument_section_id" }
}

private struct ValidationExpectations: Decodable {
    let financialReconciliation: String; let transactionCount: Int; let transactionOrder: String; let pageAssignment: String; let instrumentAssignment: String
    enum CodingKeys: String, CodingKey { case financialReconciliation = "financial_reconciliation", transactionCount = "transaction_count", transactionOrder = "transaction_order", pageAssignment = "page_assignment", instrumentAssignment = "instrument_assignment" }
}

private struct ManifestEvidence: Decodable {
    let metadataSchemaVersion: Int; let fixtureID: String; let fixtureClass: String; let sanitization: SanitizationMethod; let sourceFidelity: SourceFidelity; let geometry: GeometryAssertions; let pdfAssertions: PDFAssertions; let ocrBoundary: OCRBoundary; let privacy: PrivacyAssertions; let productionSupport: ProductionSupport
    enum CodingKeys: String, CodingKey { case metadataSchemaVersion = "metadata_schema_version", fixtureID = "fixture_id", fixtureClass = "fixture_class", sanitization = "sanitization_method", sourceFidelity = "source_fidelity", geometry = "geometry_assertions", pdfAssertions = "pdf_assertions", ocrBoundary = "ocr_boundary", privacy = "privacy_assertions", productionSupport = "production_support_boundary" }
}

private struct SanitizationMethod: Decodable {
    let classification: String; let sourcePageObjectsReused: Bool; let sourceContentStreamsReused: Bool; let sourceImagesReused: Bool; let sourceFontsReused: Bool; let sourceMetadataReused: Bool; let sourceAnnotationsReused: Bool; let sourceXObjectsReused: Bool; let sourceFontObjectsOrSubsetsReused: Bool; let sourceFormsReused: Bool; let sourceAttachmentsReused: Bool; let sourceLinksReused: Bool; let rasterizedSourceBackgroundsReused: Bool
    var noSourceSurfacesReused: Bool { !sourcePageObjectsReused && !sourceContentStreamsReused && !sourceImagesReused && !sourceFontsReused && !sourceMetadataReused && !sourceAnnotationsReused && !sourceXObjectsReused && !sourceFontObjectsOrSubsetsReused && !sourceFormsReused && !sourceAttachmentsReused && !sourceLinksReused && !rasterizedSourceBackgroundsReused }
    enum CodingKeys: String, CodingKey { case classification, sourcePageObjectsReused = "source_page_objects_reused", sourceContentStreamsReused = "source_content_streams_reused", sourceImagesReused = "source_images_reused", sourceFontsReused = "source_fonts_reused", sourceMetadataReused = "source_metadata_reused", sourceAnnotationsReused = "source_annotations_reused", sourceXObjectsReused = "source_xobjects_reused", sourceFontObjectsOrSubsetsReused = "source_font_objects_or_subsets_reused", sourceFormsReused = "source_forms_reused", sourceAttachmentsReused = "source_attachments_reused", sourceLinksReused = "source_links_reused", rasterizedSourceBackgroundsReused = "rasterized_source_backgrounds_reused" }
}

private struct SourceFidelity: Decodable { let financialTruth: String; let transactionOrder: String; let privateTextualValues: String; let sourceObjectIdentity: String; enum CodingKeys: String, CodingKey { case financialTruth = "financial_truth", transactionOrder = "transaction_order", privateTextualValues = "private_textual_values", sourceObjectIdentity = "source_object_identity" } }
private struct CoordinateSystem: Decodable, Equatable { let origin: String; let xDirection: String; let yDirection: String; let unit: String; static let pdfTopLeft = Self(origin: "top_left", xDirection: "right", yDirection: "down", unit: "pdf_point"); enum CodingKeys: String, CodingKey { case origin, xDirection = "x_direction", yDirection = "y_direction", unit } }
private struct GeometryValues: Decodable, Equatable { let pageDimensions: Double; let tableRegionBounds: Double; let summaryRegionBounds: Double; let columnAnchors: Double; let headerBaselines: Double; let transactionBaselines: Double; let amountAlignmentAnchors: Double; let multilineIndentation: Double?; let multilineSpacing: Double?; let sectionBounds: Double; let footerRegionBounds: Double; static let approved = Self(pageDimensions: 0.25, tableRegionBounds: 2, summaryRegionBounds: 2, columnAnchors: 1.5, headerBaselines: 1.5, transactionBaselines: 2, amountAlignmentAnchors: 1.5, multilineIndentation: 2, multilineSpacing: 2, sectionBounds: 2, footerRegionBounds: 3); enum CodingKeys: String, CodingKey { case pageDimensions = "page_dimensions", tableRegionBounds = "table_region_bounds", summaryRegionBounds = "summary_region_bounds", columnAnchors = "column_anchors", headerBaselines = "header_baselines", transactionBaselines = "transaction_baselines", amountAlignmentAnchors = "amount_alignment_anchors", multilineIndentation = "multiline_indentation", multilineSpacing = "multiline_spacing", sectionBounds = "section_bounds", footerRegionBounds = "footer_region_bounds" } }
private struct ObservationCounts: Decodable { let multilineIndentation: Int; let multilineSpacing: Int; enum CodingKeys: String, CodingKey { case multilineIndentation = "multiline_indentation", multilineSpacing = "multiline_spacing" } }
private struct MeasurementStatus: Decodable { let multilineIndentation: String; let multilineSpacing: String; enum CodingKeys: String, CodingKey { case multilineIndentation = "multiline_indentation", multilineSpacing = "multiline_spacing" } }
private struct ExactRelationships: Decodable { let pageAssignment: Bool; let transactionOrder: Bool; let instrumentSectionAssignment: Bool; let pageBreakRelationships: Bool; let repeatedHeaders: Bool; let continuationClassification: Bool; let transactionCount: Bool; let summaryFieldMembership: Bool; let transactionVsIgnoredRegionClassification: Bool; var allTrue: Bool { pageAssignment && transactionOrder && instrumentSectionAssignment && pageBreakRelationships && repeatedHeaders && continuationClassification && transactionCount && summaryFieldMembership && transactionVsIgnoredRegionClassification }; enum CodingKeys: String, CodingKey { case pageAssignment = "page_assignment", transactionOrder = "transaction_order", instrumentSectionAssignment = "instrument_section_assignment", pageBreakRelationships = "page_break_relationships", repeatedHeaders = "repeated_headers", continuationClassification = "continuation_classification", transactionCount = "transaction_count", summaryFieldMembership = "summary_field_membership", transactionVsIgnoredRegionClassification = "transaction_vs_ignored_region_classification" } }
private struct GeometryAssertions: Decodable { let coordinateSystem: CoordinateSystem; let tolerances: GeometryValues; let maximum: GeometryValues; let observationCounts: ObservationCounts; let exactRelationships: ExactRelationships; let independentComparatorPassed: Bool; let measurementStatus: MeasurementStatus; enum CodingKeys: String, CodingKey { case coordinateSystem = "coordinate_system", tolerances = "tolerances_points", maximum = "maximum_observed_deviation_points", observationCounts = "observation_counts", exactRelationships = "exact_relationships", independentComparatorPassed = "independent_comparator_passed", measurementStatus = "measurement_status" } }
private struct PDFAssertions: Decodable { let pageCount: Int; let dimensionTolerancePoints: Double; let pages: [PDFPageAssertion]; let nativeSelectableText: Bool; let annotationsPresent: Bool; let formsPresent: Bool; let attachmentsPresent: Bool; enum CodingKeys: String, CodingKey { case pageCount = "page_count", dimensionTolerancePoints = "dimension_tolerance_points", pages, nativeSelectableText = "native_selectable_text", annotationsPresent = "annotations_present", formsPresent = "forms_present", attachmentsPresent = "attachments_present" } }
private struct PDFPageAssertion: Decodable { let pageIndex: Int; let widthPoints: Double; let heightPoints: Double; enum CodingKeys: String, CodingKey { case pageIndex = "page_index", widthPoints = "width_points", heightPoints = "height_points" } }
private struct OCRBoundary: Decodable, Equatable { let nativeTextAvailable: Bool; let pdfkitExtractionUsable: Bool; let pymupdfExtractionUsable: Bool; let ocrUsed: Bool; let ocrRequiredForFixture: Bool; let scope: String; static let approvedFixtureBoundary = Self(nativeTextAvailable: true, pdfkitExtractionUsable: true, pymupdfExtractionUsable: true, ocrUsed: false, ocrRequiredForFixture: false, scope: "approved_fixture_layout_only"); enum CodingKeys: String, CodingKey { case nativeTextAvailable = "native_text_available", pdfkitExtractionUsable = "pdfkit_extraction_usable", pymupdfExtractionUsable = "pymupdf_extraction_usable", ocrUsed = "ocr_used", ocrRequiredForFixture = "ocr_required_for_fixture", scope } }
private struct PrivacyAssertions: Decodable { let usesFictionalCustomerMetadata: Bool; let usesFictionalAccountIdentifier: Bool; let containsNoOriginalCardIdentifier: Bool; let containsNoOriginalTransactionReference: Bool; let containsNoOriginalMerchantIdentity: Bool; let containsNoPrivateMapping: Bool; let containsNoPrivateSourcePathOrFilename: Bool; let containsNoSourcePDFObject: Bool; let usesFictionalInstrumentIdentities: Bool; var allTrue: Bool { usesFictionalCustomerMetadata && usesFictionalAccountIdentifier && containsNoOriginalCardIdentifier && containsNoOriginalTransactionReference && containsNoOriginalMerchantIdentity && containsNoPrivateMapping && containsNoPrivateSourcePathOrFilename && containsNoSourcePDFObject && usesFictionalInstrumentIdentities }; enum CodingKeys: String, CodingKey { case usesFictionalCustomerMetadata = "uses_fictional_customer_metadata", usesFictionalAccountIdentifier = "uses_fictional_account_identifier", containsNoOriginalCardIdentifier = "contains_no_original_card_identifier", containsNoOriginalTransactionReference = "contains_no_original_transaction_reference", containsNoOriginalMerchantIdentity = "contains_no_original_merchant_identity", containsNoPrivateMapping = "contains_no_private_mapping", containsNoPrivateSourcePathOrFilename = "contains_no_private_source_path_or_filename", containsNoSourcePDFObject = "contains_no_source_pdf_object", usesFictionalInstrumentIdentities = "uses_fictional_instrument_identities" } }
private struct ProductionSupport: Decodable { let classification: String; let productionParserSupport: Bool; let cardDomainSemanticsFinalized: Bool; let ledgerForgeImportSupportClaimed: Bool; let fwP109Status: String; enum CodingKeys: String, CodingKey { case classification, productionParserSupport = "production_parser_support", cardDomainSemanticsFinalized = "card_domain_semantics_finalized", ledgerForgeImportSupportClaimed = "ledgerforge_import_support_claimed", fwP109Status = "fw_p1_09_status" } }
