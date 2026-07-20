// Shared privacy-safe fixtures for confirmed-import contract tests.

import Foundation
@testable import LedgerForge

func confirmedImportIdentifier(
    kind: FinancialIdentifierKind = .institutionAccountId,
    value: String = "AXIS-CONTRACT-001"
) throws -> FinancialIdentifier {
    try FinancialIdentifier(
        kind: kind,
        rawValue: value,
        verificationState: .verified,
        provenance: .institutionStructuredField
    )
}
