import Foundation

/// A source number, not currency-rounded Money. Text and scale survive a round trip.
/// The bound keeps every accepted coefficient exactly representable by Decimal.
nonisolated public struct InvestmentDecimal: Equatable, Hashable, Codable, Sendable {
    public let sourceText: String
    public let canonical: String
    public let scale: Int
    public let value: Decimal

    public init(_ sourceText: String) throws {
        let token = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let unsigned = token.first == "-" || token.first == "+" ? String(token.dropFirst()) : token
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty else { throw InvestmentError.invalidNumber }
        let groups = parts[0].split(separator: ",", omittingEmptySubsequences: false)
        guard groups.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else {
            throw InvestmentError.invalidNumber
        }
        if groups.count > 1 {
            let western = (1...3).contains(groups[0].count) && groups.dropFirst().allSatisfy { $0.count == 3 }
            let indian = (1...2).contains(groups[0].count) && groups.last?.count == 3
                && groups.dropFirst().dropLast().allSatisfy { $0.count == 2 }
            guard western || indian else { throw InvestmentError.invalidNumber }
        }
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard (parts.count == 1 || !fraction.isEmpty), fraction.utf8.allSatisfy({ (48...57).contains($0) }),
              fraction.count <= 28 else { throw InvestmentError.invalidNumber }
        let integer = groups.joined()
        let significant = (integer + fraction).drop(while: { $0 == "0" })
        guard significant.count <= 32, integer.count + fraction.count <= 64 else { throw InvestmentError.invalidNumber }
        let normalizedInteger = String(integer.drop(while: { $0 == "0" }))
        let sign = token.first == "-" && !significant.isEmpty ? "-" : ""
        let canonical = sign + (normalizedInteger.isEmpty ? "0" : normalizedInteger)
            + (parts.count == 2 ? "." + fraction : "")
        guard let value = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
            throw InvestmentError.invalidNumber
        }
        self.sourceText = sourceText
        self.canonical = canonical
        self.scale = fraction.count
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(sourceText)
    }

}

nonisolated public enum InvestmentError: Error, LocalizedError, Equatable, Sendable {
    case invalidNumber, invalidEvidence, invalidPersistedState, olderSnapshot, staleReview
    case missingSourceField(String)
    case identityChoiceRequired, sameDateConflict, unsupportedSource

    public var errorDescription: String? {
        switch self {
        case .invalidNumber: "An investment quantity or cost cannot be preserved exactly."
        case .missingSourceField: "The statement’s required holdings fields are missing or ambiguous."
        case .invalidEvidence: "The statement does not establish a complete, consistent holdings update."
        case .invalidPersistedState: "Stored investment evidence is inconsistent. Holdings were not replaced."
        case .olderSnapshot: "This statement is older than the current holdings. No positions were changed."
        case .staleReview: "Holdings changed after this preview. Review the statement again."
        case .identityChoiceRequired: "Confirm which portfolio or investment this statement updates."
        case .sameDateConflict: "This statement disagrees with holdings for the same date. Choose which source to use."
        case .unsupportedSource: "This statement does not supply supported current fund holdings."
        }
    }
}

nonisolated public struct InvestmentPriceMapping: Equatable, Hashable, Codable, Sendable {
    public let provider: String
    public let code: String
    public let currency: String
    // Optional additions preserve decoding of the original V21 JSON records.
    public var priceKind: String? = nil
    public var instrumentReference: String? = nil
    public var listing: String? = nil
    public var evidence: String? = nil

    var identity: String {
        [provider, code, currency, priceKind ?? "", instrumentReference ?? "", listing ?? ""].joined(separator: "|")
    }
}

nonisolated public struct InvestmentContainer: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let workspaceID: String
    public var institution: String
    public let identityKind: String
    public let identity: String
    public var aliases: [String]
    public var displayName: String
    public var holdingsDate: String
    public var completeAtHoldingsDate: Bool
    public var documentID: String?
    public var importSessionID: String?
    public var zioSource: ZurichISPPolicyObservation? = nil
    /// One complete latest account receipt, anchored to the first policy. CSV
    /// fallback changes current positions without erasing the successful sync.
    public var lastZioAccount: ZurichISPAccountSnapshot? = nil
}

nonisolated public struct InvestmentHolding: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let containerID: String
    public let instrumentIdentity: String
    public var sourceAliases: [String]
    public var displayName: String
    public var units: InvestmentDecimal
    public var currency: String
    public var averageCost: InvestmentDecimal?
    public var totalCost: InvestmentDecimal?
    public var averageCostLabel: String?
    public var totalCostLabel: String?
    public var costCurrency: String?
    public var holdingsDate: String
    public var documentID: String?
    public var importSessionID: String?
    public var normalizedDocumentID: String?
    public var sourceOrdinal: Int
    public var parserProfile: String
    public var issueDate: String?
    public var valuationDate: String?
    public var priceMapping: InvestmentPriceMapping?
    public var zioObservationID: String? = nil
    public var zioFundCode: String? = nil

    var sourceDateLabel: String { zioObservationID == nil ? "Holdings as of" : "Portal valuation date" }
}

/// Ephemeral parser evidence. Zero rows are meaningful for removal, never durable holdings.
nonisolated struct InvestmentPositionEvidence: Equatable, Sendable {
    let instrumentIdentity: String
    let sourceAliases: [String]
    let displayName: String
    let units: InvestmentDecimal
    let currency: String
    let averageCost: InvestmentDecimal?
    let totalCost: InvestmentDecimal?
    let averageCostLabel: String?
    let totalCostLabel: String?
    let costCurrency: String?
    let sourceOrdinal: Int
    let valuationDate: String?
}

nonisolated struct InvestmentScopeEvidence: Equatable, Sendable {
    let institution: String
    let identityKind: String
    let identity: String
    let aliases: [String]
    let displayName: String
    let holdingsDate: String
    let isComplete: Bool
    let positions: [InvestmentPositionEvidence]

    var key: String { [institution, identityKind, identity].joined(separator: "\u{1F}") }
}

nonisolated struct InvestmentStatementEvidence: Equatable, Sendable {
    let parserProfile: String
    let issueDate: String?
    let scopes: [InvestmentScopeEvidence]
    let excludedSectionDescription: String

    func validate() throws {
        guard !parserProfile.isEmpty, !scopes.isEmpty, Set(scopes.map(\.key)).count == scopes.count else {
            throw InvestmentError.invalidEvidence
        }
        if let issueDate { _ = try StatementDate(canonical: issueDate) }
        for scope in scopes {
            _ = try StatementDate(canonical: scope.holdingsDate)
            guard !scope.institution.isEmpty, !scope.identityKind.isEmpty, !scope.identity.isEmpty,
                  !scope.displayName.isEmpty, scope.isComplete || !scope.positions.isEmpty else {
                throw InvestmentError.invalidEvidence
            }
            let keys = scope.positions.map { $0.instrumentIdentity + "\u{1F}" + $0.currency }
            guard Set(keys).count == keys.count else { throw InvestmentError.identityChoiceRequired }
            for position in scope.positions {
                guard !position.instrumentIdentity.isEmpty, !position.displayName.isEmpty,
                      position.units.value >= 0, position.sourceOrdinal > 0 else { throw InvestmentError.invalidEvidence }
                _ = try CurrencyCatalog.shared.definition(for: position.currency)
                if let date = position.valuationDate { _ = try StatementDate(canonical: date) }
                let hasCost = position.averageCost != nil || position.totalCost != nil
                guard hasCost == (position.costCurrency != nil),
                      (position.averageCost != nil) == (position.averageCostLabel != nil),
                      (position.totalCost != nil) == (position.totalCostLabel != nil),
                      position.averageCost.map({ $0.value >= 0 }) ?? true,
                      position.totalCost.map({ $0.value >= 0 }) ?? true else { throw InvestmentError.invalidEvidence }
                if let currency = position.costCurrency { _ = try CurrencyCatalog.shared.definition(for: currency) }
            }
        }
    }
}
