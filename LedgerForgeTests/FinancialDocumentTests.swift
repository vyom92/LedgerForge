// LedgerForgeTests/FinancialDocumentTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct FinancialDocumentTests {

    @Test func statementDateUsesInvariantCalendarPresentationWithoutFoundationDate() throws {
        let date = try StatementDate(canonical: "2026-06-06")

        #expect(date.canonical == "2026-06-06")
        #expect(date.presentation == "6 Jun 26")
        #expect(try StatementDate.axisNRE("06-06-2026") == date)
    }

}
