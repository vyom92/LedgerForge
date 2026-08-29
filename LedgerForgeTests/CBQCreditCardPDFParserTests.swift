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
    func nonFinancialPostTerminationVariationIsAcceptedButFinancialOrStructuralReentryRejects() throws {
        let approved = fixturePages(version: "v1")
        let harmless = [approved[0], approved[1], "unapproved boilerplate text mentioning the next statement and card"]
        let changed = [approved[0], approved[1], approved[2].replacingOccurrences(of: "commercial", with: "altered", options: .caseInsensitive, range: nil)]

        for pages in [harmless, changed] {
            let normalized = try CBQCreditCardPDFNormalizer().normalize(
                text: pages.joined(separator: "\n"), pageTexts: pages,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-tail-non-financial.pdf")
            )
            #expect(!normalized.rows.isEmpty)
        }

        let financial = [approved[0], approved[1], "01/01/25 02/01/25 1.00"]
        let structural = [approved[0], approved[1], "Card Account Reference"]
        let secondTermination = [approved[0], approved[1], "XXXX End of Statement"]
        let continuation = [approved[0], approved[1], "Continued on next page..."]
        for pages in [financial, structural, secondTermination, continuation] {
            #expect(throws: CBQCreditCardPDFNormalizationError.self) {
                _ = try CBQCreditCardPDFNormalizer().normalize(
                    text: pages.joined(separator: "\n"), pageTexts: pages,
                    fileURL: URL(fileURLWithPath: "/tmp/cbq-card-tail-rejection.pdf")
                )
            }
        }
    }

    @Test
    func v1SummaryIgnoresExplanatoryLabelReuseButRejectsDuplicateFinancialField() throws {
        var explanatory = fixturePages(version: "v1")
        explanatory[0] = explanatory[0].replacingOccurrences(
            of: "Current Outstanding Balance 92.00",
            with: "Current Outstanding Balance 92.00\nAmount billed includes purchases and reversals posted in the statement"
        )
        let normalized = try CBQCreditCardPDFNormalizer().normalize(
            text: explanatory.joined(separator: "\n"), pageTexts: explanatory,
            fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v1-explanatory-label.pdf")
        )
        #expect(!normalized.rows.isEmpty)

        var duplicate = fixturePages(version: "v1")
        duplicate[0] = duplicate[0].replacingOccurrences(
            of: "Amount Billed 12.00",
            with: "Amount Billed 12.00\nAmount Billed 13.00"
        )
        #expect(throws: CBQCreditCardPDFNormalizationError.malformedSummary) {
            _ = try CBQCreditCardPDFNormalizer().normalize(
                text: duplicate.joined(separator: "\n"), pageTexts: duplicate,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v1-duplicate-summary.pdf")
            )
        }
    }

    @Test
    func v2StatementBalanceRequiresMatchingCreditSignAndMagnitude() throws {
        var credit = fixturePages(version: "v2")
        credit[0] = credit[0]
            .replacingOccurrences(of: "Total Statement Balance QAR 80.00", with: "Total Statement Balance QAR CR 80.00")
            .replacingOccurrences(of: "80.00 =", with: ")80.00( =")
        let accepted = try CBQCreditCardPDFNormalizer().normalize(
            text: credit.joined(separator: "\n"), pageTexts: credit,
            fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v2-credit-balance.pdf")
        )
        #expect(!accepted.rows.isEmpty)

        var signMismatch = credit
        signMismatch[0] = signMismatch[0].replacingOccurrences(
            of: "Total Statement Balance QAR CR 80.00",
            with: "Total Statement Balance QAR 80.00"
        )
        #expect(throws: CBQCreditCardPDFNormalizationError.malformedSummary) {
            _ = try CBQCreditCardPDFNormalizer().normalize(
                text: signMismatch.joined(separator: "\n"), pageTexts: signMismatch,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v2-sign-mismatch.pdf")
            )
        }

        var magnitudeMismatch = credit
        magnitudeMismatch[0] = magnitudeMismatch[0].replacingOccurrences(
            of: "Total Statement Balance QAR CR 80.00",
            with: "Total Statement Balance QAR CR 81.00"
        )
        #expect(throws: CBQCreditCardPDFNormalizationError.malformedSummary) {
            _ = try CBQCreditCardPDFNormalizer().normalize(
                text: magnitudeMismatch.joined(separator: "\n"), pageTexts: magnitudeMismatch,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v2-magnitude-mismatch.pdf")
            )
        }
    }

    @Test
    func continuationPageMayRepeatTableHeaderWithoutRepeatingProductLabel() throws {
        var pages = fixturePages(version: "v2")
        var lines = pages[1].components(separatedBy: .newlines)
        if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "Diners Club" }) {
            lines.remove(at: index)
        }
        pages[1] = lines.joined(separator: "\n")
        let normalized = try CBQCreditCardPDFNormalizer().normalize(
            text: pages.joined(separator: "\n"), pageTexts: pages,
            fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v2-continuation.pdf")
        )
        #expect(!normalized.rows.isEmpty)
    }

    @Test
    func wrappedMoneyTailCreatesItsOwnTransaction() throws {
        var pages = fixturePages(version: "v2")
        pages[0] = pages[0].replacingOccurrences(
            of: "05/11/25 06/11/25 continuation date-looking narration\nfollow-up narration",
            with: "05/11/25 06/11/25 WRAPPED MERCHANT\nEUR 10.00 37.50"
        )
        let normalized = try CBQCreditCardPDFNormalizer().normalize(
            text: pages.joined(separator: "\n"), pageTexts: pages,
            fileURL: URL(fileURLWithPath: "/tmp/cbq-card-v2-wrapped-money.pdf")
        )
        #expect(normalized.rows.count == 6)
        let wrapped = try #require(normalized.rows.first { $0.values[2] == "WRAPPED MERCHANT" })
        #expect(wrapped.values[4] == "10.00")
        #expect(wrapped.values[5] == "EUR")
        #expect(wrapped.values[6] == "37.50")
        #expect(wrapped.values[7] == CardLiabilityEffect.increasesAmountOwed.rawValue)
    }

    @Test
    func conflictingDuplicatePreambleEvidenceFailsClosed() throws {
        var pages = fixturePages(version: "v1")
        pages[0] = pages[0].replacingOccurrences(
            of: "Statement Date 30 November, 2025",
            with: "Statement Date 30 November, 2025\nStatement Date 31 December, 2025"
        )
        #expect(throws: CBQCreditCardPDFNormalizationError.malformedPreamble) {
            _ = try CBQCreditCardPDFNormalizer().normalize(
                text: pages.joined(separator: "\n"), pageTexts: pages,
                fileURL: URL(fileURLWithPath: "/tmp/cbq-card-fictional-duplicate-preamble.pdf")
            )
        }
    }

    @Test
    func authenticFourDigitAndFullMonthPreambleCanonicalizesToExistingParserContract() throws {
        let normalized = try normalize(version: "v1")
        let fragments = normalized.sourceContext.preTransactionFragments.map(\.text)
        #expect(fragments.contains("STATEMENT_DATE\t30/11/25"))
        #expect(fragments.contains("PERIOD\t01/11/25\t30/11/25"))
        #expect(fragments.contains("DUE_DATE\t15/12/25"))
    }

    @Test
    func legacyShortPreambleRemainsAccepted() throws {
        var pages = fixturePages(version: "v1")
        pages[0] = pages[0]
            .replacingOccurrences(of: "Statement Date 30 November, 2025", with: "Statement Date 30/11/25")
            .replacingOccurrences(of: "Statement Period 01/11/2025 - 30/11/2025", with: "Statement Period 01/11/25 to 30/11/25")
            .replacingOccurrences(of: "Payment Due Date 15 December, 2025", with: "Payment Due Date 15/12/25")
        let normalized = try CBQCreditCardPDFNormalizer().normalize(
            text: pages.joined(separator: "\n"), pageTexts: pages,
            fileURL: URL(fileURLWithPath: "/tmp/cbq-card-fictional-legacy-preamble.pdf")
        )
        #expect(!normalized.rows.isEmpty)
    }

    @Test
    func mixedInvalidAndConflictingPeriodEvidenceFailsClosed() throws {
        let replacements = [
            "Statement Period 01/11/25 - 30/11/2025",
            "Statement Period 01/11/202 - 30/11/202",
            "Statement Period 31/02/2025 - 30/11/2025",
            "Statement Period 30/11/2025 - 01/11/2025",
            "Statement Period 01/11/2025 - 30/11/2025\nStatement Period 01/12/2025 - 31/12/2025"
        ]
        for replacement in replacements {
            var pages = fixturePages(version: "v1")
            pages[0] = pages[0].replacingOccurrences(
                of: "Statement Period 01/11/2025 - 30/11/2025",
                with: replacement
            )
            #expect(throws: CBQCreditCardPDFNormalizationError.malformedPreamble) {
                _ = try CBQCreditCardPDFNormalizer().normalize(
                    text: pages.joined(separator: "\n"), pageTexts: pages,
                    fileURL: URL(fileURLWithPath: "/tmp/cbq-card-fictional-invalid-period.pdf")
                )
            }
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
            summary = "Previous Outstanding Balance 100.00\nAmount Billed 12.00\nPayment Received CR 20.00\nCurrent Outstanding Balance 92.00"
        } else {
            summary = "Reversal Purchases Billed Installment Fees/\nTotal Statement Balance QAR 80.00\n80.00 = 3.00 + 0.00 + 6.00 + 9.00 - 20.00 - 100.00"
        }
        let page1 = """
        Card Account Reference
        470012345678901
        Statement Date 30 November, 2025
        Statement Period 01/11/2025 - 30/11/2025
        Payment Due Date 15 December, 2025
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
    switch version {
    case "v1":
        return "For your next statement visit www.example.test for card and commercial bank information."
    case "v2-extended":
        return "Important card statement information. Please visit www.example.test and the bank website.\nReward and mobile app information may change on the next statement."
    default:
        return "Important card statement information. Reward details and commercial bank notices are available at www.example.test."
    }
}
