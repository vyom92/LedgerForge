import Foundation
import Testing
@testable import LedgerForge

/// Source-independent decimal mechanics only; these are not statement substitutes.
struct InvestmentDecimalTests {
    @Test func preservesTextScaleAndExactValue() throws {
        let number = try InvestmentDecimal(" 1,234.0000012300 ")
        #expect(number.sourceText == " 1,234.0000012300 ")
        #expect(number.canonical == "1234.0000012300")
        #expect(number.scale == 10)
        #expect(number.value == Decimal(string: "1234.0000012300"))
        #expect(try JSONDecoder().decode(InvestmentDecimal.self, from: JSONEncoder().encode(number)) == number)
    }

    @Test func rejectsRoundingAndMalformedGrouping() {
        for text in ["1e4", "NaN", "12,34.0", "1.2.3", "", ".1", "1.", "12345678901234567890123456789012345", "0." + String(repeating: "0", count: 28) + "1"] {
            #expect(throws: InvestmentError.self) { try InvestmentDecimal(text) }
        }
    }

    @Test func retainsDistinctPrintedScalesAndGrouping() throws {
        let shorter = try InvestmentDecimal("12.34"), longer = try InvestmentDecimal("12.340")
        #expect(shorter.value == longer.value && shorter != longer)
        #expect(try InvestmentDecimal("1,23,456.00").canonical == "123456.00")
        #expect(try InvestmentDecimal("-0.000").canonical == "0.000")
    }
}
