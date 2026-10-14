import Foundation

/// One current editor state per month. Incomplete text is intentionally separate
/// from the validated plan used by financial projections; there is no edit log.

extension FundingPlan {
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
