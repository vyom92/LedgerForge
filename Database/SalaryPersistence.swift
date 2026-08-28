import Foundation

public struct SalaryComponentDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let salaryStatementId: String
    public let sideCode: String
    public let sourceOrdinal: Int
    public let sourceLabel: String
    public let amountCurrency: String
    public let amountMinor: Int64
    public let amountDecimal: String
}

public struct SalaryStatementDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let documentId: String
    public let importSessionId: String
    public let normalizedDocumentId: String
    public let sourceFingerprintAlgorithm: String
    public let sourceFingerprintDigest: String
    public let sourceAuthorityCode: String
    public let parserProfileId: String
    public let parserProfileVersion: String
    public let financialPeriodISO: String
    public let printDateISO: String?
    public let documentKindCode: String
    public let nativeCurrency: String
    public let printedEarningsMinor: Int64
    public let printedEarningsDecimal: String
    public let printedDeductionsMinor: Int64?
    public let printedDeductionsDecimal: String?
    public let printedNetMinor: Int64
    public let printedNetDecimal: String
    public let printedPaymentMinor: Int64
    public let printedPaymentDecimal: String
    public let createdAtISO: String
    public let components: [SalaryComponentDTO]
}

public struct SalaryImportPlanDTO: nonisolated Equatable, Sendable {
    public let providerGeneration: ProviderGenerationToken
    public let workspace: WorkspaceDTO
    public let history: ConfirmedImportHistoryTemplateDTO
    public let statement: SalaryStatementDTO
}

public enum SalaryImportRepositoryResult: nonisolated Equatable {
    case committed(statementId: String, importSessionId: String, documentId: String)
    case exactSourceDuplicate(PriorImportedStatementDTO)
    case staleProviderGeneration
    case retryableContention
    case repositoryIntegrityConflict
    case persistenceUnavailable
}

public struct SalaryRepositorySnapshotDTO: nonisolated Equatable, Sendable {
    public let statements: [SalaryStatementDTO]
    public init(statements: [SalaryStatementDTO]) { self.statements = statements }
}

public protocol SalaryRepository {
    func commitImportedSalary(_ plan: SalaryImportPlanDTO) -> SalaryImportRepositoryResult
    func snapshot(workspaceId: String) throws -> SalaryRepositorySnapshotDTO
}

public struct FundingPlanBalanceDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let planId: String
    public let sourceOrdinal: Int
    public let accountId: String
    public let nativeCurrency: String
    public let included: Bool
    public let amountCurrency: String?
    public let amountMinor: Int64?
    public let amountDecimal: String?
    public let provenanceCode: String
    public let carriedSourcePlanId: String?
    public let capturedAtISO: String?
}

public struct FundingPlanCommitmentDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let planId: String
    public let regionCode: String
    public let sourceOrdinal: Int
    public let label: String
    public let amountCurrency: String
    public let amountMinor: Int64
    public let amountDecimal: String
    public let included: Bool
    public let fundingAccountId: String?
    public let provenanceCode: String
    public let carriedSourcePlanId: String?
}

public struct FundingPlanDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let planMonthISO: String
    public let rolloverSourcePlanId: String?
    public let expectedFixedMinor: Int64
    public let expectedFixedDecimal: String
    public let expectedFixedProvenance: String
    public let expectedVariableMinor: Int64
    public let expectedVariableDecimal: String
    public let expectedVariableProvenance: String
    public let expectedDeductionsMinor: Int64
    public let expectedDeductionsDecimal: String
    public let expectedDeductionsProvenance: String
    public let configuredFeeMinor: Int64
    public let configuredFeeDecimal: String
    public let configuredFeeProvenance: String
    public let fxINRPerQARDecimal: String?
    public let fxObservationDateISO: String?
    public let plannedInvestmentMinor: Int64
    public let plannedInvestmentDecimal: String
    public let plannedInvestmentProvenance: String
    public let updatedAtISO: String
    public let balances: [FundingPlanBalanceDTO]
    public let commitments: [FundingPlanCommitmentDTO]
}

public protocol FundingPlanRepository {
    func plans(workspaceId: String) throws -> [FundingPlanDTO]
    @discardableResult func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO
}

nonisolated enum SalaryPersistenceDTOValidator {
    private struct PersistedMoney: nonisolated Equatable {
        let currency: String
        let minorUnits: Int64
    }

    static func validate(statement: SalaryStatementDTO) throws {
        guard statement.sourceAuthorityCode == "qatar_airways",
              statement.parserProfileId == "qatar-airways.salary.pdf",
              statement.parserProfileVersion == "1",
              statement.nativeCurrency == "QAR",
              ["regular_salary", "adhoc_payment", "annual_discretionary_bonus"].contains(statement.documentKindCode),
              Set(statement.components.map(\.id)).count == statement.components.count else {
            throw RepositoryError.relationshipViolation("Salary statement source identity is invalid.")
        }
        try month(statement.financialPeriodISO)
        if let printDateISO = statement.printDateISO {
            try date(printDateISO)
        }
        let earnings = try components(statement.components.filter { $0.sideCode == "earning" })
        let deductions = try components(statement.components.filter { $0.sideCode == "deduction" })
        guard earnings.count + deductions.count == statement.components.count else {
            throw RepositoryError.relationshipViolation("Salary component side or kind is invalid.")
        }
        let printedEarnings = try money(statement.printedEarningsDecimal, statement.printedEarningsMinor, "QAR")
        let printedDeductions = try optionalMoney(statement.printedDeductionsDecimal, statement.printedDeductionsMinor, statement.printedDeductionsDecimal == nil ? nil : "QAR")
        let printedNet = try money(statement.printedNetDecimal, statement.printedNetMinor, "QAR")
        let printedPayment = try money(statement.printedPaymentDecimal, statement.printedPaymentMinor, "QAR")
        guard !earnings.isEmpty else {
            throw RepositoryError.relationshipViolation("Salary totals do not reconcile.")
        }
        let aggregatedEarnings = try aggregate(earnings)
        let aggregatedDeductions = deductions.isEmpty ? nil : try aggregate(deductions)
        let net = try subtract(
            printedEarnings,
            printedDeductions ?? PersistedMoney(currency: "QAR", minorUnits: 0)
        )
        guard aggregatedEarnings == printedEarnings,
              aggregatedDeductions == printedDeductions,
              net == printedNet,
              printedNet == printedPayment else {
            throw RepositoryError.relationshipViolation("Salary totals do not reconcile.")
        }
    }

    static func validate(plan: FundingPlanDTO) throws {
        _ = try month(plan.planMonthISO)
        for value in [
            (plan.expectedFixedDecimal, plan.expectedFixedMinor),
            (plan.expectedVariableDecimal, plan.expectedVariableMinor),
            (plan.expectedDeductionsDecimal, plan.expectedDeductionsMinor),
            (plan.configuredFeeDecimal, plan.configuredFeeMinor),
            (plan.plannedInvestmentDecimal, plan.plannedInvestmentMinor)
        ] { _ = try money(value.0, value.1, "QAR") }
        let inputProvenances = [plan.expectedFixedProvenance, plan.expectedVariableProvenance,
                                plan.expectedDeductionsProvenance, plan.configuredFeeProvenance,
                                plan.plannedInvestmentProvenance]
        guard inputProvenances.allSatisfy({ $0 == "manual" || $0 == "carried" }),
              (inputProvenances.contains("carried") ? plan.rolloverSourcePlanId != nil : true),
              Set(plan.balances.map(\.id)).count == plan.balances.count,
              Set(plan.balances.map(\.accountId)).count == plan.balances.count,
              Set(plan.commitments.map(\.id)).count == plan.commitments.count else {
            throw RepositoryError.relationshipViolation("Funding plan provenance or identity is invalid.")
        }
        switch (plan.fxINRPerQARDecimal, plan.fxObservationDateISO) {
        case (nil, nil): break
        case let (.some(rate), .some(observation)):
            guard let decimal = Decimal(string: rate, locale: Locale(identifier: "en_US_POSIX")), decimal > 0 else {
                throw RepositoryError.relationshipViolation("Funding plan FX is invalid.")
            }
            try date(observation)
        default:
            throw RepositoryError.relationshipViolation("Funding plan FX evidence is incomplete.")
        }
        guard plan.balances.map(\.sourceOrdinal).sorted() == (plan.balances.isEmpty ? [] : Array(1...plan.balances.count)) else {
            throw RepositoryError.relationshipViolation("Funding plan balance order is invalid.")
        }
        for balance in plan.balances {
            guard balance.planId == plan.id, balance.nativeCurrency == "QAR" || balance.nativeCurrency == "INR" else {
                throw RepositoryError.relationshipViolation("Funding plan balance relationship is invalid.")
            }
            _ = try optionalMoney(balance.amountDecimal, balance.amountMinor, balance.amountCurrency, expectedCurrency: balance.nativeCurrency)
            let provenanceValid = (balance.provenanceCode == "manual" && balance.carriedSourcePlanId == nil && balance.capturedAtISO == nil)
                || (balance.provenanceCode == "carried" && plan.rolloverSourcePlanId != nil && balance.carriedSourcePlanId == plan.rolloverSourcePlanId && balance.capturedAtISO == nil)
                || (balance.provenanceCode == "captured_account_balance" && balance.carriedSourcePlanId == nil && balance.capturedAtISO != nil)
            guard provenanceValid else { throw RepositoryError.relationshipViolation("Funding plan balance provenance is invalid.") }
        }
        for region in ["qatar", "india"] {
            let rows = plan.commitments.filter { $0.regionCode == region }
            let expectedOrdinals = rows.isEmpty ? [] : Array(1...rows.count)
            guard rows.map(\.sourceOrdinal).sorted() == expectedOrdinals else {
                throw RepositoryError.relationshipViolation("Funding commitment order is invalid.")
            }
        }
        for commitment in plan.commitments {
            let expectedCurrency = commitment.regionCode == "qatar" ? "QAR" : (commitment.regionCode == "india" ? "INR" : "")
            guard commitment.planId == plan.id, !commitment.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (commitment.provenanceCode == "manual" && commitment.carriedSourcePlanId == nil)
                    || (commitment.provenanceCode == "carried" && plan.rolloverSourcePlanId != nil && commitment.carriedSourcePlanId == plan.rolloverSourcePlanId) else {
                throw RepositoryError.relationshipViolation("Funding commitment provenance is invalid.")
            }
            let amount = try money(commitment.amountDecimal, commitment.amountMinor, commitment.amountCurrency)
            guard amount.currency == expectedCurrency else {
                throw RepositoryError.relationshipViolation("Funding commitment currency is invalid.")
            }
        }
    }

    private static func components(_ values: [SalaryComponentDTO]) throws -> [PersistedMoney] {
        let ordered = values.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        let expectedOrdinals = ordered.isEmpty ? [] : Array(1...ordered.count)
        guard ordered.map(\.sourceOrdinal) == expectedOrdinals else {
            throw RepositoryError.relationshipViolation("Salary component order is invalid.")
        }
        return try ordered.map {
            guard !$0.sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RepositoryError.relationshipViolation("Salary component label is invalid.")
            }
            let value = try money($0.amountDecimal, $0.amountMinor, $0.amountCurrency)
            guard value.minorUnits > 0 else { throw RepositoryError.relationshipViolation("Salary component amount is invalid.") }
            return value
        }
    }

    private static func aggregate(_ values: [PersistedMoney]) throws -> PersistedMoney {
        guard var total = values.first else {
            throw RepositoryError.relationshipViolation("Salary Money aggregation is empty.")
        }
        for value in values.dropFirst() {
            guard value.currency == total.currency else {
                throw RepositoryError.relationshipViolation("Salary Money currencies disagree.")
            }
            let (sum, overflow) = total.minorUnits.addingReportingOverflow(value.minorUnits)
            guard !overflow else {
                throw RepositoryError.relationshipViolation("Salary Money aggregation overflows.")
            }
            total = PersistedMoney(currency: total.currency, minorUnits: sum)
        }
        return total
    }

    private static func subtract(_ lhs: PersistedMoney, _ rhs: PersistedMoney) throws -> PersistedMoney {
        guard lhs.currency == rhs.currency else {
            throw RepositoryError.relationshipViolation("Salary Money currencies disagree.")
        }
        let (difference, overflow) = lhs.minorUnits.subtractingReportingOverflow(rhs.minorUnits)
        guard !overflow else {
            throw RepositoryError.relationshipViolation("Salary Money subtraction overflows.")
        }
        return PersistedMoney(currency: lhs.currency, minorUnits: difference)
    }

    private static func money(_ decimal: String, _ minor: Int64, _ currency: String) throws -> PersistedMoney {
        let normalizedCurrency = currency.uppercased()
        guard normalizedCurrency == "QAR" || normalizedCurrency == "INR",
              isCanonicalTwoFractionDecimal(decimal),
              let amount = Decimal(string: decimal, locale: Locale(identifier: "en_US_POSIX")) else {
            throw RepositoryError.relationshipViolation("Money decimal or currency is invalid.")
        }
        var scaled = amount * Decimal(100)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded == scaled,
              let exactMinor = Int64(NSDecimalNumber(decimal: rounded).stringValue),
              exactMinor == minor else {
            throw RepositoryError.relationshipViolation("Money decimal and minor units disagree.")
        }
        return PersistedMoney(currency: normalizedCurrency, minorUnits: exactMinor)
    }

    private static func optionalMoney(_ decimal: String?, _ minor: Int64?, _ currency: String?, expectedCurrency: String? = nil) throws -> PersistedMoney? {
        guard decimal != nil || minor != nil || currency != nil else { return nil }
        guard let decimal, let minor, let currency, expectedCurrency.map({ $0 == currency }) ?? true else {
            throw RepositoryError.relationshipViolation("Optional Money evidence is incomplete.")
        }
        return try money(decimal, minor, currency)
    }

    private static func isCanonicalTwoFractionDecimal(_ value: String) -> Bool {
        let isNegative = value.first == "-"
        let magnitude = isNegative ? value.dropFirst() : value[...]
        let parts = magnitude.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].count == 2,
              (parts[0] == "0" || parts[0].first != "0"),
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
              parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              !(isNegative && parts[0] == "0" && parts[1] == "00") else {
            return false
        }
        return true
    }

    private static func month(_ value: String) throws {
        let parts = value.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            throw RepositoryError.relationshipViolation("Plan month is invalid.")
        }
        guard year >= 1, (1...12).contains(month), String(format: "%04d-%02d", year, month) == value else {
            throw RepositoryError.relationshipViolation("Plan month is invalid.")
        }
    }

    private static func date(_ value: String) throws {
        let parts = value.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            throw RepositoryError.relationshipViolation("Date evidence is invalid.")
        }
        var components = DateComponents(); components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0); components.year = year; components.month = month; components.day = day
        guard components.date != nil, String(format: "%04d-%02d-%02d", year, month, day) == value else {
            throw RepositoryError.relationshipViolation("Date evidence is invalid.")
        }
    }
}

public struct PlaceholderSalaryRepo: SalaryRepository {
    public init() {}
    public func commitImportedSalary(_ plan: SalaryImportPlanDTO) -> SalaryImportRepositoryResult { .persistenceUnavailable }
    public func snapshot(workspaceId: String) throws -> SalaryRepositorySnapshotDTO { throw RepositoryError.persistenceUnavailable }
}

public struct PlaceholderFundingPlanRepo: FundingPlanRepository {
    public init() {}
    public func plans(workspaceId: String) throws -> [FundingPlanDTO] { throw RepositoryError.persistenceUnavailable }
    public func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO { throw RepositoryError.persistenceUnavailable }
}

struct EmptySalaryRepo: SalaryRepository {
    func commitImportedSalary(_ plan: SalaryImportPlanDTO) -> SalaryImportRepositoryResult { .persistenceUnavailable }
    func snapshot(workspaceId: String) throws -> SalaryRepositorySnapshotDTO { SalaryRepositorySnapshotDTO(statements: []) }
}

struct EmptyFundingPlanRepo: FundingPlanRepository {
    func plans(workspaceId: String) throws -> [FundingPlanDTO] { [] }
    func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO { throw RepositoryError.persistenceUnavailable }
}
