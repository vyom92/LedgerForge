import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CBQCreditCardPDFParserTests {
    @Test
    func v1KeepsAccountPaymentInPhysicalSectionAndRetainsSourceOrder() throws {
        let normalized = try normalize(version: "v1")
        let document = try CBQCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalized.document,
            metadata: metadata,
            rows: normalized.rows,
            header: normalized.header,
            sourceContext: normalized.sourceContext
        ))
        let evidence = try #require(document.cardStatementEvidence)
        #expect(document.financialIdentifiers.count == 1)
        #expect(document.financialIdentifiers[0].kind == .institutionIssuedIdentifier)
        #expect(document.financialIdentifiers[0].verificationState == .verified)
        #expect(document.transactions.count == 5)
        #expect(document.transactions[0].cardLiabilityEffect == .decreasesAmountOwed)
        #expect(document.transactions[0].money.amount == -20)
        #expect(document.transactions[1].description.hasPrefix("DUPLICATE ROW"))
        #expect(document.transactions[2].description.contains("continuation date-looking narration"))
        #expect(document.transactions[2].description.contains("follow-up narration"))
        #expect(document.transactions[1].sourceProvenance[0].sourceOrdinal < document.transactions[2].sourceProvenance[0].sourceOrdinal)
        let payment = try #require(evidence.annotation(for: document.transactions[0]))
        #expect(payment.financialScope == .accountLevel)
        #expect(payment.documentScopedSectionID != nil)
        #expect(payment.summaryMembership == .cbqV1PaymentReceived)
        #expect(evidence.reconciliationRuleIdentifier == CardStatementEvidence.cbqV1QARReconciliationRule)
        #expect(evidence.summary(code: "source_section_net_total")?.money?.amount == 8)
    }

    @Test
    func v2UsesPositiveCreditComponentsAndPreservesForeignCreditMoney() throws {
        let normalized = try normalize(version: "v2")
        let document = try CBQCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalized.document,
            metadata: metadata,
            rows: normalized.rows,
            header: normalized.header,
            sourceContext: normalized.sourceContext
        ))
        let evidence = try #require(document.cardStatementEvidence)
        let foreign = try #require(document.transactions.first { $0.description.hasPrefix("MERCHANT") })
        #expect(foreign.money.amount == -9)
        let annotation = try #require(evidence.annotation(for: foreign))
        #expect(annotation.originalMerchantMoney?.currency.code == "EUR")
        #expect(annotation.originalMerchantMoney?.amount == -10)
        #expect(annotation.summaryMembership == .cbqV2CreditReversal)
        #expect(evidence.summary(code: "total_payment")?.money?.amount == 20)
        #expect(evidence.summary(code: "credit_reversal")?.money?.amount == 9)
        #expect(evidence.summary(code: "fees_charges")?.money?.amount == 3)
        #expect(evidence.reconciliationRuleIdentifier == CardStatementEvidence.cbqV2QARReconciliationRule)
    }

    @Test
    func nearMatchTransactionHeaderRejectsClosedGrammar() throws {
        let pages = fixturePages(version: "v1").map { $0.replacingOccurrences(of: "Referance", with: "Reference") }
        #expect(throws: CBQCreditCardPDFNormalizationError.self) {
            _ = try CBQCreditCardPDFNormalizer().normalize(
                text: pages.joined(separator: "\n"), pageTexts: pages,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-fictional.pdf")
            )
        }
    }

    @Test
    func approvedPostTerminationLayoutFamiliesAreAccepted() throws {
        for variant in ["v1", "v2", "v2-extended"] {
            let pages = fixturePages(version: variant == "v1" ? "v1" : "v2", tailVariant: variant)
            let normalized = try CBQCreditCardPDFNormalizer().normalize(
                text: pages.joined(separator: "\n"), pageTexts: pages,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-tail-\(variant).pdf")
            )
            #expect(!normalized.rows.isEmpty)
        }
    }

    @Test
    func arbitraryFinancialAndChangedPostTerminationTailsReject() throws {
        let approved = fixturePages(version: "v1")
        let arbitrary = [approved[0], approved[1], "unapproved boilerplate text"]
        let financial = [approved[0], approved[1], "01/01/25 02/01/25 1.00"]
        let changed = [approved[0], approved[1], approved[2].replacingOccurrences(of: "commercial", with: "altered", options: .caseInsensitive, range: nil)]
        var categoryShift = approved[2].split(separator: " ").map(String.init)
        let urlIndex = try #require(categoryShift.firstIndex(where: { $0.hasPrefix("https://") }))
        let fillerIndex = try #require(categoryShift.firstIndex(of: "boilerplate"))
        categoryShift.swapAt(urlIndex, fillerIndex)
        let changedCategory = [approved[0], approved[1], categoryShift.joined(separator: " ")]

        for pages in [arbitrary, financial, changed, changedCategory] {
            #expect(throws: CBQCreditCardPDFNormalizationError.self) {
                _ = try CBQCreditCardPDFNormalizer().normalize(
                    text: pages.joined(separator: "\n"), pageTexts: pages,
                    fileURL: URL(fileURLWithPath: "/tmp/cbq-card-tail-rejection.pdf")
                )
            }
        }
    }

    @Test
    func conflictingDuplicatePreambleEvidenceFailsClosed() throws {
        var pages = fixturePages(version: "v1")
        pages[0] = pages[0].replacingOccurrences(
            of: "Statement Date 30/11/25",
            with: "Statement Date 30/11/25\nStatement Date 31/12/25"
        )
        #expect(throws: CBQCreditCardPDFNormalizationError.malformedPreamble) {
            _ = try CBQCreditCardPDFNormalizer().normalize(
                text: pages.joined(separator: "\n"), pageTexts: pages,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-fictional-duplicate-preamble.pdf")
            )
        }
    }

    private let metadata = DocumentMetadata(
        institution: .cbq, documentType: .creditCard, fileFormat: .pdf, confidence: 1
    )

    private func normalize(version: String) throws -> CBQCreditCardPDFNormalizationResult {
        let pages = fixturePages(version: version)
        return try CBQCreditCardPDFNormalizer().normalize(
            text: pages.joined(separator: "\n"), pageTexts: pages,
            fileURL: URL(fileURLWithPath: "/tmp/cbq-card-fictional-\(version).pdf")
        )
    }

    private func fixturePages(version: String, tailVariant: String? = nil) -> [String] {
        let summary: String
        if version == "v1" {
            summary = "Previous Outstanding Balance 100.00 Amount Billed 12.00 Payment Received CR 20.00 Current Outstanding Balance 92.00"
        } else {
            summary = "Reversal Purchases Billed Installment Fees/\n80.00 = 6.00 + 0.00 + 3.00 + 100.00 - 20.00 - )9.00("
        }
        let page1 = """
        Card Account Reference
        470012345678901
        Statement Date 30/11/25
        Statement Period 01/11/25 to 30/11/25
        Payment Due Date 15/12/25
        """ + "\n" + summary + "\n" + """
        Diners Club
        Card Number Card Holder Name Product Card Limit
        1234XXXXXXXX5678 HOLDER DINERS CLUB 5000
        Post Date Purchase
        Date Description & Referance Foreign Currency Amount in QAR
        01/11/25 02/11/25 Paid using bankDirect CR 20.00
        Reference: PAYMENT-001
        03/11/25 04/11/25 DUPLICATE ROW 1.00
        03/11/25 04/11/25 DUPLICATE ROW 1.00
        05/11/25 06/11/25 continuation date-looking narration
        follow-up narration
        Continued on next page...
        """
        let page2 = """
        Diners Club
        Card Number Card Holder Name Product Card Limit
        1234XXXXXXXX5678 HOLDER DINERS CLUB 5000
        Post Date Purchase
        Date Description & Referance Foreign Currency Amount in QAR
        07/11/25 08/11/25 MERCHANT EUR 10.00 CR 9.00
        Total Diners Club 8.00
        Mastercard Platinum
        Card Number Card Holder Name Product Card Limit
        4321XXXXXXXX8765 HOLDER MASTERCARD PLATINUM 7000
        09/11/25 10/11/25 CASH ADVANCE FEE 3.00
        Total Mastercard Platinum CR 0.00
        XXXX End of Statement
        """
        let page3 = fictionalCBQApprovedTail(version: tailVariant ?? version)
        return [page1, page2, page3]
    }
}

@MainActor
func fictionalCBQApprovedTail(version: String) -> String {
        let keywordPositions: [(Int, [String])]
        let tokenCount: Int
        let numericPositions: [Int]
        let urlPositions: [Int]
        switch version {
        case "v1":
            keywordPositions = [
                (3, ["statement"]), (5, ["visit"]), (6, ["www"]), (10, ["card"]),
                (15, ["customer"]), (30, ["customer"]), (194, ["commercial"]), (195, ["bank"]),
                (200, ["card"]), (201, ["commercial"]), (202, ["bank"]), (207, ["card"])
            ]
            tokenCount = 255
            numericPositions = [17, 32, 75, 77, 149, 150, 158, 159, 228, 230, 235, 237, 254]
            urlPositions = [6]
        case "v2-extended":
            keywordPositions = [
                (3, ["statement"]), (5, ["visit"]), (6, ["www"]), (10, ["card"]),
                (15, ["customer"]), (30, ["customer"]), (78, ["important"]), (84, ["card"]),
                (85, ["statement"]), (137, ["statement"]), (140, ["mobile"]), (141, ["bank"]),
                (148, ["card"]), (154, ["commercial"]), (155, ["bank"]), (156, ["reward"]),
                (158, ["please"]), (163, ["mobile"]), (164, ["bank"]), (181, ["statement"]),
                (191, ["statement"]), (209, ["statement"]), (244, ["statement"]), (275, ["statement"]),
                (293, ["app"]), (321, ["statement"]), (329, ["app"]), (333, ["card"]),
                (358, ["card", "www"]), (366, ["please"]), (367, ["visit"]), (369, ["website"]),
                (374, ["visit"]), (375, ["www"]), (379, ["card"]), (384, ["customer"]),
                (399, ["customer"]), (563, ["commercial"]), (564, ["bank"]), (569, ["card"]),
                (570, ["commercial"]), (571, ["bank"]), (576, ["card"])
            ]
            tokenCount = 624
            numericPositions = [17, 32, 75, 77, 102, 115, 200, 238, 240, 291, 323, 386, 401, 444, 446, 518, 519, 527, 528, 597, 599, 604, 606, 623]
            urlPositions = [6, 358, 375]
        default:
            keywordPositions = [
                (3, ["statement"]), (5, ["important"]), (11, ["card"]), (12, ["statement"]),
                (64, ["statement"]), (67, ["mobile"]), (68, ["bank"]), (75, ["card"]),
                (81, ["commercial"]), (82, ["bank"]), (83, ["reward"]), (85, ["please"]),
                (90, ["mobile"]), (91, ["bank"]), (108, ["statement"]), (118, ["statement"]),
                (136, ["statement"]), (171, ["statement"]), (202, ["statement"]), (220, ["app"]),
                (248, ["statement"]), (256, ["app"]), (260, ["card"]), (285, ["card", "www"]),
                (293, ["please"]), (294, ["visit"]), (296, ["website"]), (301, ["visit"]),
                (302, ["www"]), (306, ["card"]), (311, ["customer"]), (326, ["customer"]),
                (490, ["commercial"]), (491, ["bank"]), (496, ["card"]), (497, ["commercial"]),
                (498, ["bank"]), (503, ["card"])
            ]
            tokenCount = 551
            numericPositions = [29, 42, 127, 165, 167, 218, 250, 313, 328, 371, 373, 445, 446, 454, 455, 524, 526, 531, 533, 550]
            urlPositions = [285, 302]
        }
        var tokens = Array(repeating: "boilerplate", count: tokenCount)
        tokens[0] = "XXXX"
        tokens[1] = "End"
        tokens[2] = "of"
        tokens[3] = "Statement"
        for (index, categories) in keywordPositions {
            let token = categories.contains("www")
                ? (categories.contains("card") ? "www.card.example.test" : "www.example.test")
                : categories.joined(separator: "-")
            tokens[index] = token
        }
        for index in numericPositions {
            tokens[index] = "1"
        }
        for index in urlPositions {
            tokens[index] = "https://" + tokens[index]
        }
        return tokens.dropFirst(4).joined(separator: " ")
}
