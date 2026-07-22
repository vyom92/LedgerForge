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
