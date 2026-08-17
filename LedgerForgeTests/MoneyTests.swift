import Foundation
import Testing
@testable import LedgerForge

struct MoneyTests {

    @Test func canonicalINRMoneyEncodesFixedScaleDecimalAndMinorUnits() throws {
        let money = try Money(amount: Decimal(string: "100.5")!, currency: "inr")

        #expect(money.currency.code == "INR")
        #expect(try money.canonicalDecimalString() == "100.50")
        #expect(try money.minorUnits() == 10_050)
    }

    @Test func persistedINRTextRequiresCanonicalScale() throws {
        do {
            _ = try Money(canonicalDecimal: "100.5", currency: "INR")
            Issue.record("Expected malformed canonical INR text to fail")
        } catch let error as MoneyError {
            #expect(error == .malformedCanonicalDecimal(currency: "INR"))
        } catch {
            Issue.record("Expected MoneyError, got \(error)")
        }

        let money = try Money(canonicalDecimal: "100.50", currency: "INR")
        #expect(money.amount == Decimal(string: "100.50")!)
    }

    @Test func catalogUsesReviewedFractionScales() throws {
        #expect(try CurrencyCatalog.shared.definition(for: "KRW").fractionDigits == 0)
        #expect(try CurrencyCatalog.shared.definition(for: "QAR").fractionDigits == 2)
        #expect(try CurrencyCatalog.shared.definition(for: "KWD").fractionDigits == 3)
    }

    @Test func catalogIsVersionedAtV2() {
        #expect(CurrencyCatalog.version == "ledgerforge.currency-catalog.v2")
    }

    @Test func catalogContainsExactly155DeterministicSortedUniqueDefinitions() {
        let definitions = CurrencyCatalog.shared.definitions
        let codes = definitions.map { $0.code.code }

        #expect(definitions.count == 155)
        #expect(codes == codes.sorted())
        #expect(Set(codes).count == definitions.count)
        #expect(definitions == definitions.sorted { $0.code < $1.code })
    }

    @Test func catalogIncludesRequiredOrdinaryCurrenciesAndScales() throws {
        let expectedScales = [
            "KRW": 0,
            "QAR": 2,
            "BHD": 3,
            "KWD": 3,
            "AUD": 2,
            "CHF": 2,
            "EUR": 2,
            "GBP": 2,
            "ZAR": 2,
            "XAF": 0,
            "XCD": 2,
            "XCG": 2,
            "XOF": 0,
            "XPF": 0
        ]

        for (code, scale) in expectedScales {
            #expect(try CurrencyCatalog.shared.definition(for: code).fractionDigits == scale)
        }
    }

    @Test func catalogRejectsNonCurrencyAndFundCodesWithTypedErrors() {
        let excludedCodes = [
            // ISO 4217 List One entries whose minor unit is N.A.
            "XAU", "XAG", "XPD", "XPT", "XBA", "XBB", "XBC", "XBD",
            "XDR", "XSU", "XUA", "XTS", "XXX",
            // Current ISO 4217 List Two fund codes.
            "XAD", "BOV", "CLF", "COU", "MXV", "CHW", "CHE", "USN", "UYI", "UYW",
            "ZZZ"
        ]

        for code in excludedCodes {
            do {
                _ = try CurrencyCatalog.shared.definition(for: code)
                Issue.record("Expected \(code) to be unsupported")
            } catch let error as MoneyError {
                #expect(error == .unsupportedCurrency(code))
            } catch {
                Issue.record("Expected typed unsupported-currency error for \(code), got \(error)")
            }
        }
    }

    @Test func exactScaleRejectsFractionalKRWFourthDecimalBHDAndThirdDecimalTwoScale() {
        let cases = [("1.1", "KRW"), ("1.2345", "BHD"), ("1.001", "EUR")]

        for (amount, currency) in cases {
            do {
                _ = try Money(amount: Decimal(string: amount)!, currency: currency)
                Issue.record("Expected \(currency) amount \(amount) to fail without rounding")
            } catch let error as MoneyError {
                #expect(error == .excessPrecision(currency: currency))
            } catch {
                Issue.record("Expected excess-precision error for \(currency), got \(error)")
            }
        }
    }

    @Test func canonicalScaleRoundTripsForZeroTwoAndThreeDecimalCurrencies() throws {
        let values = [
            ("0", "KRW", "0", Int64(0)),
            ("12.34", "QAR", "12.34", Int64(1_234)),
            ("-1.234", "BHD", "-1.234", Int64(-1_234))
        ]

        for (amount, currency, canonical, minorUnits) in values {
            let money = try Money(amount: Decimal(string: amount)!, currency: currency)
            #expect(try money.canonicalDecimalString() == canonical)
            #expect(try money.minorUnits() == minorUnits)

            let decoded = try Money(canonicalDecimal: canonical, currency: currency)
            #expect(decoded == money)
            #expect(try Money.fromMinorUnits(minorUnits, currency: currency) == money)
        }
    }

    @Test func excessPrecisionFailsWithoutRounding() {
        do {
            _ = try Money(amount: Decimal(string: "1.001")!, currency: "INR")
            Issue.record("Expected excess precision to fail")
        } catch let error as MoneyError {
            #expect(error == .excessPrecision(currency: "INR"))
        } catch {
            Issue.record("Expected MoneyError, got \(error)")
        }
    }

    @Test func transactionPreviewPresentationUsesTransactionNativeMoneyAndDirection() throws {
        let transaction = Transaction(
            statementDate: nil,
            description: "Kuwaiti debit",
            debit: Decimal(string: "4.125")!,
            credit: nil,
            amount: Decimal(string: "-4.125")!,
            balance: nil,
            currency: "KWD",
            account: "Account",
            sourceBank: "Bank",
            sourceFile: "Preview"
        )

        #expect(transaction.signedAmountDisplay == "-KWD 4.125")
    }
}
