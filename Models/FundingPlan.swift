import Foundation
import CryptoKit

/// One current editor state per month. Incomplete text is intentionally separate
/// from the validated plan used by financial projections; there is no edit log.

extension FundingPlan {
    /// Versioned content identity for a later plan-specific compare-and-save.
    /// This is a review token, not a write authorization or an edit history.
    nonisolated func planningRevision() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return "monthly-plan-v1:" + SHA256.hash(data: try encoder.encode(self)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated func persistenceDTO() throws -> FundingPlanDTO {
        let plan = self
        func provenance(_ value: FundingPlanValueProvenance) -> (code: String, carried: String?, captured: String?) {
            switch value {
            case .manual: return ("manual", nil, nil)
            case .carried(let source): return ("carried", source, nil)
            case .capturedAccountBalance(let time): return ("captured_account_balance", nil, time)
            }
        }
        func amount(_ money: Money) throws -> (Int64, String) { (try money.minorUnits(), try money.canonicalDecimalString()) }
        let fixed = try amount(plan.expectedFixedEarnings), variable = try amount(plan.expectedVariableEarnings)
        let deductions = try amount(plan.expectedDeductions), fee = try amount(plan.configuredTransferFee)
        let investment = try amount(plan.plannedInvestment)
        let balances = try plan.balances.enumerated().map { index, value -> FundingPlanBalanceDTO in
            let p = provenance(value.provenance)
            return FundingPlanBalanceDTO(id: value.id, planId: plan.id, sourceOrdinal: index + 1, accountId: value.accountID, nativeCurrency: value.nativeCurrency.code, included: value.included,
                                         amountCurrency: value.money?.currency.code, amountMinor: try value.money?.minorUnits(), amountDecimal: try value.money?.canonicalDecimalString(),
                                         provenanceCode: p.code, carriedSourcePlanId: p.carried, capturedAtISO: p.captured, financialBalanceDateISO: value.financialBalanceDate?.canonical)
        }
        func commitmentDTOs(_ values: [FundingPlanCommitment], region: String) throws -> [FundingPlanCommitmentDTO] {
            try values.enumerated().map { index, value in
                let p = provenance(value.provenance), money = try amount(value.money)
                return FundingPlanCommitmentDTO(id: value.id, planId: plan.id, regionCode: region, sourceOrdinal: index + 1, label: value.label,
                                                amountCurrency: value.money.currency.code, amountMinor: money.0, amountDecimal: money.1,
                                                included: value.included, fundingAccountId: value.fundingAccountID,
                                                provenanceCode: p.code, carriedSourcePlanId: p.carried,
                                                recurs: value.recurs, temporaryCarryBasisMinor: try value.temporaryCarryBasis?.minorUnits(),
                                                temporaryCarryBasisDecimal: try value.temporaryCarryBasis?.canonicalDecimalString(),
                                                carriedSourceRowId: value.carriedSourceRowID, remark: value.remark, dueDateISO: value.dueDate?.canonical)
            }
        }
        return FundingPlanDTO(
            id: plan.id, workspaceId: plan.workspaceID, planMonthISO: plan.month.canonical, rolloverSourcePlanId: plan.rolloverSourcePlanID,
            expectedFixedMinor: fixed.0, expectedFixedDecimal: fixed.1, expectedFixedProvenance: provenance(plan.expectedFixedProvenance).code,
            expectedVariableMinor: variable.0, expectedVariableDecimal: variable.1, expectedVariableProvenance: provenance(plan.expectedVariableProvenance).code,
            expectedDeductionsMinor: deductions.0, expectedDeductionsDecimal: deductions.1, expectedDeductionsProvenance: provenance(plan.expectedDeductionsProvenance).code,
            configuredFeeMinor: fee.0, configuredFeeDecimal: fee.1, configuredFeeProvenance: provenance(plan.configuredTransferFeeProvenance).code,
            fxINRPerQARDecimal: plan.planningFX.map { NSDecimalNumber(decimal: $0.inrPerQAR).stringValue }, fxObservationDateISO: plan.planningFX?.observationDate.canonical,
            plannedInvestmentMinor: investment.0, plannedInvestmentDecimal: investment.1, plannedInvestmentProvenance: provenance(plan.plannedInvestmentProvenance).code,
            updatedAtISO: plan.updatedAtISO, balances: balances,
            commitments: try commitmentDTOs(plan.qatarCommitments, region: "qatar") + commitmentDTOs(plan.indiaCommitments, region: "india"),
            alDarReference: try plan.alDarReference.map { try FundingPlanAlDarReferenceDTO(planID: plan.id, evidence: $0) },
            calculationVersion: plan.calculationVersion.rawValue,
            keepInCBQMinor: try plan.keepInCBQ?.minorUnits(), keepInCBQDecimal: try plan.keepInCBQ?.canonicalDecimalString(),
            referenceMode: plan.calculationVersion == .budgetV1 ? plan.referenceMode.rawValue : nil,
            deductions: try plan.deductions.enumerated().map { index, row in
                FundingPlanDeductionDTO(id: row.id, planId: plan.id, sourceOrdinal: index + 1, label: row.label,
                    amountMinor: try row.money.minorUnits(), amountDecimal: try row.money.canonicalDecimalString(),
                    recurs: row.recurs, carriedSourceRowId: row.carriedSourceRowID)
            },
            effectiveReference: try plan.effectiveAlDarReference.map {
                guard $0.submittedQAR.currency.code == "QAR", $0.submittedQAR.amount == 1 else { throw AlDarReferenceError.invalidBinding }
                return FundingPlanEffectiveReferenceDTO(planId: plan.id, rawINR: $0.returnedINR.rawToken, fetchedAtISO: $0.fetchedAtISO)
            },
            assistance: plan.assistance
        )
    }
}

extension FundingPlanDTO {
    /// Ephemeral input to the one worksheet calculator, after ordinary DTO
    /// validation. This never hydrates stores or supplies a second formula.
    nonisolated func allocationCalculationInput() throws -> FundingPlan {
        try SalaryPersistenceDTOValidator.validate(plan: self)
        guard let version = FundingPlanCalculationVersion(rawValue: calculationVersion),
              let mode = FundingPlanReferenceMode(rawValue: referenceMode ?? "alDar") else { throw SurplusAllocationError.invalidRecord }
        func money(_ decimal: String, _ currency: String = "QAR") throws -> Money {
            try Money(canonicalDecimal: decimal, currency: currency)
        }
        func provenance(_ code: String, source: String? = nil, captured: String? = nil) throws -> FundingPlanValueProvenance {
            switch code {
            case "manual": return .manual
            case "carried":
                guard let source = source ?? rolloverSourcePlanId else { throw SurplusAllocationError.invalidRecord }
                return .carried(sourcePlanID: source)
            case "captured_account_balance":
                guard let captured else { throw SurplusAllocationError.invalidRecord }
                return .capturedAccountBalance(capturedAtISO: captured)
            default: throw SurplusAllocationError.invalidRecord
            }
        }
        func bills(_ region: String) throws -> [FundingPlanCommitment] {
            try commitments.filter { $0.regionCode == region }.map {
                .init(id: $0.id, label: $0.label, money: try money($0.amountDecimal, $0.amountCurrency), included: $0.included,
                      fundingAccountID: $0.fundingAccountId, provenance: try provenance($0.provenanceCode, source: $0.carriedSourcePlanId),
                      recurs: $0.recurs, temporaryCarryBasis: try $0.temporaryCarryBasisDecimal.map { try money($0, region == "india" ? "INR" : "QAR") },
                      carriedSourceRowID: $0.carriedSourceRowId, remark: $0.remark,
                      dueDate: try $0.dueDateISO.map { try StatementDate(canonical: $0) })
            }
        }
        return try FundingPlan(id: id, workspaceID: workspaceId, month: SelectedStatementMonth(canonical: planMonthISO),
            rolloverSourcePlanID: rolloverSourcePlanId,
            expectedFixedEarnings: money(expectedFixedDecimal), expectedFixedProvenance: provenance(expectedFixedProvenance),
            expectedVariableEarnings: money(expectedVariableDecimal), expectedVariableProvenance: provenance(expectedVariableProvenance),
            expectedDeductions: money(expectedDeductionsDecimal), expectedDeductionsProvenance: provenance(expectedDeductionsProvenance),
            balances: balances.map { row in
                .init(id: row.id, accountID: row.accountId, nativeCurrency: try CurrencyCode(row.nativeCurrency), included: row.included,
                      money: try row.amountDecimal.map { try money($0, row.nativeCurrency) }, provenance: try provenance(row.provenanceCode, source: row.carriedSourcePlanId, captured: row.capturedAtISO),
                      financialBalanceDate: try row.financialBalanceDateISO.map { try StatementDate(canonical: $0) })
            }, qatarCommitments: bills("qatar"), indiaCommitments: bills("india"),
            configuredTransferFee: money(configuredFeeDecimal), configuredTransferFeeProvenance: provenance(configuredFeeProvenance),
            planningFX: try fxINRPerQARDecimal.map {
                guard let rate = Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")), let date = fxObservationDateISO else {
                    throw SurplusAllocationError.incompletePlan
                }
                return try FundingPlanFX(inrPerQAR: rate, observationDate: StatementDate(canonical: date))
            }, alDarReference: try alDarReference?.evidence(),
            plannedInvestment: money(plannedInvestmentDecimal), plannedInvestmentProvenance: provenance(plannedInvestmentProvenance), updatedAtISO: updatedAtISO,
            calculationVersion: version,
            keepInCBQ: try keepInCBQDecimal.map { try money($0) },
            deductions: deductions.map { .init(id: $0.id, label: $0.label, money: try money($0.amountDecimal), recurs: $0.recurs, carriedSourceRowID: $0.carriedSourceRowId) },
            referenceMode: mode,
            effectiveAlDarReference: try effectiveReference?.quote(), assistance: assistance)
    }
}

extension PayslipReceiptState {
    /// Fresh repository facts use exactly the same receipt decision as native
    /// projections. No receipt, payroll amount or category is inferred here.
    nonisolated static func resolve(plan: FundingPlan, receiptDTOs: [TransactionDTO], excludedAccounts: Set<String> = []) throws -> Self? {
        guard let link = plan.assistance?.payslipFunding else { return nil }
        let rows = receiptDTOs.filter { $0.isTrusted && $0.workspaceId == plan.workspaceID && $0.accountId == link.accountID && String($0.postedDateISO.prefix(7)) == plan.month.canonical }
        let evidence = try rows.map { row -> PayslipReceiptEvidence in
            guard row.nativeCurrency == link.net.currency, ["debit", "credit"].contains(row.direction),
                  FinancialDateRole(rawValue: row.financialDateRole) != nil,
                  !row.rawRows.isEmpty, Set(row.rawRows.map(\.normalizedRowId)).count == row.rawRows.count,
                  row.rawRows.allSatisfy({ !$0.normalizedRowId.isEmpty && !($0.normalizedDocumentId ?? "").isEmpty &&
                      ($0.sourceOrdinal ?? 0) > 0 && !($0.normalizedRecordDigest ?? "").isEmpty &&
                      !($0.parserProfileId ?? "").isEmpty && !($0.parserProfileVersion ?? "").isEmpty }) else { throw FinancialIntelligenceError.invalidRecord }
            let documents = Dictionary(grouping: row.rawRows, by: \.normalizedDocumentId)
            guard documents.values.allSatisfy({ Set($0.map(\.sourceOrdinal)).count == $0.count }),
                  documents.values.allSatisfy({ Set($0.map { ($0.parserProfileId ?? "") + "|" + ($0.parserProfileVersion ?? "") }).count == 1 }) else { throw FinancialIntelligenceError.invalidRecord }
            _ = try StatementTimezoneEvidence(validatingPersistenceCode: row.statementTimezoneEvidence)
            return try .init(id: row.id, accountID: row.accountId, date: StatementDate(canonical: row.postedDateISO),
                money: MovementValidation.Fact(row).money(), isCredit: row.direction == "credit", narration: row.description ?? "",
                hasCBQSource: row.rawRows.contains { $0.parserProfileId?.hasPrefix("cbq.") == true })
        }
        return resolve(plan: plan, evidence: evidence, excludedAccounts: excludedAccounts)
    }
}

extension MonthlyPlanScratchpad {
    nonisolated func dto() throws -> MonthlyPlanScratchpadDTO {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try .init(workspaceID: plan.workspaceID, month: plan.month.canonical,
                         stateJSON: String(decoding: encoder.encode(self), as: UTF8.self))
    }

    nonisolated static func decode(_ dto: MonthlyPlanScratchpadDTO) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: Data(dto.stateJSON.utf8))
        guard value.hasIdentity(workspaceID: dto.workspaceID, month: dto.month) else {
            throw RepositoryError.relationshipViolation("Monthly scratchpad identity is invalid.")
        }
        return value
    }
}
