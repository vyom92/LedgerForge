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
    public var recurs: Bool = true
    public var temporaryCarryBasisMinor: Int64? = nil
    public var temporaryCarryBasisDecimal: String? = nil
    public var carriedSourceRowId: String? = nil
    public var remark: String = ""
    public var dueDateISO: String? = nil
}

public struct FundingPlanDeductionDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let planId: String
    public let sourceOrdinal: Int
    public let label: String
    public let amountMinor: Int64
    public let amountDecimal: String
    public let recurs: Bool
    public let carriedSourceRowId: String?
}

public struct FundingPlanEffectiveReferenceDTO: nonisolated Equatable, Sendable {
    public let planId: String
    public let rawINR: String
    public let fetchedAtISO: String

    nonisolated func quote() throws -> AlDarReferenceQuote {
        try AlDarReferenceQuote(submittedQAR: Money(canonicalDecimal: "1.00", currency: "QAR"),
            returnedINR: AlDarReturnedINRDecimal(rawToken: rawINR), fetchedAtISO: fetchedAtISO)
    }
}

nonisolated public struct FundingPlanAlDarReferenceDTO: Equatable, Sendable {
    public let fundingPlanId: String
    public let providerCode: String
    public let sourceContractCode: String
    public let directionCode: String
    public let submittedQARMinor: Int64
    public let submittedQARDecimal: String
    public let returnedINRRawDecimal: String
    public let boundShortfallINRMinor: Int64
    public let boundShortfallINRDecimal: String
    public let fetchedAtISO: String
    public let classificationCode: String

    func evidence() throws -> AlDarReferenceEvidence {
        guard providerCode == "al_dar", sourceContractCode == "public_home_get_rate_v1",
              directionCode == "qar_to_inr", classificationCode == "indicative_reference" else {
            throw AlDarReferenceError.invalidBinding
        }
        let submitted = try Money(canonicalDecimal: submittedQARDecimal, currency: "QAR")
        let shortfall = try Money(canonicalDecimal: boundShortfallINRDecimal, currency: "INR")
        guard try submitted.minorUnits() == submittedQARMinor,
              try shortfall.minorUnits() == boundShortfallINRMinor else { throw AlDarReferenceError.invalidBinding }
        return try AlDarReferenceEvidence(quote: AlDarReferenceQuote(
            submittedQAR: submitted, returnedINR: AlDarReturnedINRDecimal(rawToken: returnedINRRawDecimal),
            fetchedAtISO: fetchedAtISO), boundShortfallINR: shortfall)
    }

    init(planID: String, evidence: AlDarReferenceEvidence) throws {
        fundingPlanId = planID
        providerCode = "al_dar"; sourceContractCode = "public_home_get_rate_v1"
        directionCode = "qar_to_inr"; classificationCode = "indicative_reference"
        submittedQARMinor = try evidence.quote.submittedQAR.minorUnits()
        submittedQARDecimal = try evidence.quote.submittedQAR.canonicalDecimalString()
        returnedINRRawDecimal = evidence.quote.returnedINR.rawToken
        boundShortfallINRMinor = try evidence.boundShortfallINR.minorUnits()
        boundShortfallINRDecimal = try evidence.boundShortfallINR.canonicalDecimalString()
        fetchedAtISO = evidence.quote.fetchedAtISO
    }

    init(fundingPlanId: String, providerCode: String, sourceContractCode: String, directionCode: String,
         submittedQARMinor: Int64, submittedQARDecimal: String, returnedINRRawDecimal: String,
         boundShortfallINRMinor: Int64, boundShortfallINRDecimal: String, fetchedAtISO: String, classificationCode: String) {
        self.fundingPlanId = fundingPlanId; self.providerCode = providerCode
        self.sourceContractCode = sourceContractCode; self.directionCode = directionCode
        self.submittedQARMinor = submittedQARMinor; self.submittedQARDecimal = submittedQARDecimal
        self.returnedINRRawDecimal = returnedINRRawDecimal
        self.boundShortfallINRMinor = boundShortfallINRMinor; self.boundShortfallINRDecimal = boundShortfallINRDecimal
        self.fetchedAtISO = fetchedAtISO; self.classificationCode = classificationCode
    }
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
    public var alDarReference: FundingPlanAlDarReferenceDTO? = nil
    public var calculationVersion: String = "legacy"
    public var keepInCBQMinor: Int64? = nil
    public var keepInCBQDecimal: String? = nil
    public var referenceMode: String? = nil
    public var deductions: [FundingPlanDeductionDTO] = []
    public var effectiveReference: FundingPlanEffectiveReferenceDTO? = nil
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
        guard ["legacy", "budgetV1"].contains(plan.calculationVersion) else {
            throw RepositoryError.relationshipViolation("Unknown planning calculation version.")
        }
        if plan.calculationVersion == "budgetV1" {
            guard let minor = plan.keepInCBQMinor, let decimal = plan.keepInCBQDecimal, minor >= 0,
                  ["alDar", "manual"].contains(plan.referenceMode ?? ""),
                  plan.expectedDeductionsMinor == 0, plan.plannedInvestmentMinor == 0,
                  plan.alDarReference == nil else {
                throw RepositoryError.relationshipViolation("Budget Planning inputs are incomplete or conflict with legacy inputs.")
            }
            _ = try money(decimal, minor, "QAR")
            guard plan.deductions.map(\.sourceOrdinal) == (plan.deductions.isEmpty ? [] : Array(1...plan.deductions.count)),
                  Set(plan.deductions.map(\.id)).count == plan.deductions.count else {
                throw RepositoryError.relationshipViolation("Deduction identity or order is invalid.")
            }
            for row in plan.deductions {
                guard row.planId == plan.id, !row.id.isEmpty,
                      !row.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      row.label.count <= 240, row.amountMinor >= 0,
                      row.carriedSourceRowId == nil || plan.rolloverSourcePlanId != nil else {
                    throw RepositoryError.relationshipViolation("Deduction rows require a name and nonnegative amount.")
                }
                _ = try money(row.amountDecimal, row.amountMinor, "QAR")
            }
            if plan.referenceMode == "alDar" {
                guard plan.fxINRPerQARDecimal == nil, plan.fxObservationDateISO == nil else {
                    throw RepositoryError.relationshipViolation("Only one planning reference may be selected.")
                }
                if let reference = plan.effectiveReference {
                    guard reference.planId == plan.id else { throw RepositoryError.relationshipViolation("Reference plan mismatch.") }
                    _ = try reference.quote()
                }
            } else {
                guard plan.effectiveReference == nil, plan.fxINRPerQARDecimal != nil,
                      plan.fxObservationDateISO != nil else { throw RepositoryError.relationshipViolation("Manual reference is incomplete.") }
            }
        } else if plan.keepInCBQMinor != nil || plan.keepInCBQDecimal != nil || plan.referenceMode != nil || !plan.deductions.isEmpty || plan.effectiveReference != nil {
            throw RepositoryError.relationshipViolation("Legacy plan contains new calculation inputs.")
        }
        for value in [
            (plan.expectedFixedDecimal, plan.expectedFixedMinor),
            (plan.expectedVariableDecimal, plan.expectedVariableMinor),
            (plan.expectedDeductionsDecimal, plan.expectedDeductionsMinor),
            (plan.configuredFeeDecimal, plan.configuredFeeMinor),
            (plan.plannedInvestmentDecimal, plan.plannedInvestmentMinor)
        ] { _ = try money(value.0, value.1, "QAR") }
        guard plan.configuredFeeMinor >= 0 else {
            throw RepositoryError.relationshipViolation("Transfer fee must be zero or greater.")
        }
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
            if plan.calculationVersion == "legacy",
               (!commitment.recurs || commitment.temporaryCarryBasisMinor != nil || commitment.temporaryCarryBasisDecimal != nil || commitment.carriedSourceRowId != nil || !commitment.remark.isEmpty || commitment.dueDateISO != nil) {
                throw RepositoryError.relationshipViolation("Legacy commitment contains Budget Planning metadata.")
            }
            if plan.calculationVersion == "budgetV1" {
                if let date = commitment.dueDateISO {
                    _ = try StatementDate(canonical: date)
                }
                guard commitment.amountMinor >= 0, commitment.remark.count <= 240,
                      commitment.carriedSourceRowId == nil || plan.rolloverSourcePlanId != nil else {
                    throw RepositoryError.relationshipViolation("Commitment amount or lineage is invalid.")
                }
                switch (commitment.temporaryCarryBasisMinor, commitment.temporaryCarryBasisDecimal) {
                case (nil, nil): break
                case let (minor?, decimal?):
                    guard commitment.recurs, minor >= commitment.amountMinor else { throw RepositoryError.relationshipViolation("Temporary remaining amount must not exceed its carry basis.") }
                    _ = try money(decimal, minor, commitment.amountCurrency)
                default: throw RepositoryError.relationshipViolation("Temporary remaining amount has no complete carry basis.")
                }
            }
            guard amount.currency == expectedCurrency else {
                throw RepositoryError.relationshipViolation("Funding commitment currency is invalid.")
            }
        }
        if let reference = plan.alDarReference {
            guard reference.fundingPlanId == plan.id, plan.fxINRPerQARDecimal == nil,
                  plan.fxObservationDateISO == nil else {
                throw RepositoryError.relationshipViolation("Only one planning reference may be selected.")
            }
            let evidence = try reference.evidence()
            let zero = PersistedMoney(currency: "INR", minorUnits: 0)
            let balances = try plan.balances.filter { $0.included && $0.nativeCurrency == "INR" }.map { row in
                guard let decimal = row.amountDecimal, let minor = row.amountMinor else {
                    throw RepositoryError.relationshipViolation("Reference requires a complete INR shortfall.")
                }
                return try money(decimal, minor, "INR")
            }
            let commitments = try plan.commitments.filter { $0.included && $0.regionCode == "india" }
                .map { try money($0.amountDecimal, $0.amountMinor, "INR") }
            let shortfall = try subtract(aggregate([zero] + commitments), aggregate([zero] + balances))
            guard max(0, shortfall.minorUnits) == (try evidence.boundShortfallINR.minorUnits()) else {
                throw RepositoryError.relationshipViolation("Planning reference no longer matches the INR shortfall.")
            }
        }
    }

    static func validateRowLineage(plan: FundingPlanDTO, existing: [FundingPlanDTO]) throws {
        let otherPlans = existing.filter { $0.id != plan.id }
        let balanceIDs = Set(otherPlans.flatMap { $0.balances.map(\.id) })
        let commitmentIDs = Set(otherPlans.flatMap { $0.commitments.map(\.id) })
        let deductionIDs = Set(otherPlans.flatMap { $0.deductions.map(\.id) })
        guard !plan.balances.contains(where: { balanceIDs.contains($0.id) }),
              !plan.commitments.contains(where: { commitmentIDs.contains($0.id) }),
              !plan.deductions.contains(where: { deductionIDs.contains($0.id) }) else {
            throw RepositoryError.relationshipViolation("New months require unique row identities.")
        }
        let source = existing.first { $0.id == plan.rolloverSourcePlanId && $0.workspaceId == plan.workspaceId && $0.planMonthISO < plan.planMonthISO }
        let saved = existing.first { $0.id == plan.id && $0.workspaceId == plan.workspaceId && $0.rolloverSourcePlanId == plan.rolloverSourcePlanId }
        for row in plan.commitments {
            if let sourceID = row.carriedSourceRowId {
                let retained = saved?.commitments.contains { $0.id == row.id && $0.carriedSourceRowId == sourceID && $0.regionCode == row.regionCode && $0.amountCurrency == row.amountCurrency } == true
                guard retained || source?.commitments.contains(where: { $0.id == sourceID && $0.regionCode == row.regionCode && $0.amountCurrency == row.amountCurrency }) == true else {
                    throw RepositoryError.relationshipViolation("Recurring bill lineage is invalid.")
                }
            }
        }
        for row in plan.deductions {
            if let sourceID = row.carriedSourceRowId {
                let retained = saved?.deductions.contains { $0.id == row.id && $0.carriedSourceRowId == sourceID } == true
                guard retained || source?.deductions.contains(where: { $0.id == sourceID }) == true else { throw RepositoryError.relationshipViolation("Deduction lineage is invalid.") }
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
