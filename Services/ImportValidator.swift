//
//  ImportValidator.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

/// Performs validation on imported transactions before they are trusted by the application.
nonisolated final class ImportValidator {

    static func validate(financialDocument: FinancialDocument) -> ImportValidationResult {
        if let bank = financialDocument.bankStatementEvidence, bank.isAccountRelationshipStatement {
            return validateBankSections(financialDocument, evidence: bank)
        }
        if let investment = financialDocument.investmentStatementEvidence {
            var issues: [ValidationIssue] = []
            do {
                try investment.validate()
                guard financialDocument.metadata.documentType == .investment,
                      financialDocument.transactions.isEmpty, financialDocument.financialIdentifiers.isEmpty,
                      financialDocument.salaryStatementEvidence == nil, financialDocument.cardStatementEvidence == nil,
                      financialDocument.parserProfileID == investment.parserProfile,
                      financialDocument.parserProfileVersion == "1" else { throw InvestmentError.invalidEvidence }
            } catch {
                issues.append(.init(severity: .error, rowNumber: nil, message: "Current holdings evidence is incomplete or inconsistent."))
            }
            return ImportValidationResult(rowsRead: investment.scopes.reduce(0) { $0 + $1.positions.count },
                transactionsParsed: 0, statementCurrency: nil, debitTotalMoney: nil, creditTotalMoney: nil,
                openingBalanceMoney: nil, closingBalanceMoney: nil, passed: issues.isEmpty, issues: issues)
        }
        if let salaryEvidence = financialDocument.salaryStatementEvidence {
            return validateSalaryStatement(financialDocument: financialDocument, evidence: salaryEvidence)
        }
        if let cardEvidence = financialDocument.cardStatementEvidence {
            return validateCardStatement(
                financialDocument: financialDocument,
                evidence: cardEvidence
            )
        }
        return validate(
            transactions: financialDocument.transactions,
            statementCurrency: financialDocument.bookedCurrency,
            zeroActivityEvidence: financialDocument.zeroActivityEvidence,
            financialDocument: financialDocument
        )
    }

    private static func validateBankSections(_ document: FinancialDocument, evidence: BankStatementEvidence) -> ImportValidationResult {
        var issues: [ValidationIssue] = []
        let sections = evidence.sections
        let transactions = document.transactions
        let expectedProfile: String?
        switch document.metadata.institution {
        case .axis: expectedProfile = BankRelationshipFamily.axis.profileID
        case .hdfc: expectedProfile = BankRelationshipFamily.hdfc.profileID
        default: expectedProfile = nil
        }
        let complete = !sections.isEmpty && document.metadata.documentType == .bankAccount &&
            document.metadata.fileFormat == .pdf && expectedProfile != nil && document.parserProfileID == expectedProfile &&
            document.parserProfileVersion == "1" && document.bookedCurrency?.code == "INR" &&
            document.financialIdentifiers.isEmpty && sections.map(\.ordinal) == Array(1...sections.count) &&
            Set(sections.map(\.id)).count == sections.count &&
            Set(sections.map { $0.sourceIdentity.literal }).count == sections.count &&
            sections.flatMap(\.transactionIDs) == transactions.map(\.id) &&
            Set(transactions.map(\.id)).count == transactions.count
        if !complete {
            issues.append(.init(severity: .error, rowNumber: nil, message: "Bank section ownership is incomplete or contradictory."))
        }
        let byID = Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for section in sections {
            let rows = section.transactionIDs.compactMap { byID[$0] }
            let ordinals = rows.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
            let valid = section.nativeCurrency == document.bookedCurrency && !section.productLabel.isEmpty &&
                section.exhaustedRegion.matches(normalizedFinancialRowCount: rows.count) &&
                rows.count == section.transactionIDs.count && ordinals.count == rows.count &&
                ordinals == ordinals.sorted() && Set(ordinals).count == ordinals.count &&
                rows.allSatisfy { row in
                    row.statementDate != nil && row.financialDateRole == .transactionDate &&
                    row.money.currency == section.nativeCurrency && row.money.amount != .zero &&
                    row.runningBalanceMoney?.currency == section.nativeCurrency && row.sourceProvenance.count == 1 &&
                    row.sourceProvenance.first?.parserProfileID == document.parserProfileID &&
                    row.sourceProvenance.first?.literalRunningBalance != nil &&
                    (document.metadata.institution == .hdfc ? row.valueDate != nil : row.valueDate == nil) &&
                    (row.money.amount < .zero ? row.debitMoney?.amount == -row.money.amount && row.creditMoney == nil
                                             : row.creditMoney?.amount == row.money.amount && row.debitMoney == nil)
                }
            if !valid {
                issues.append(.init(severity: .error, rowNumber: section.firstSourceOrdinal,
                                    message: "A bank account section has incomplete transaction evidence."))
            }
        }
        // The owner selected complete transactions mapped to separate accounts.
        // Printed account/cross-account controls remain observations; neither
        // recurrence nor aggregate totals rewrite or veto these extracted rows.
        return .init(rowsRead: transactions.count, transactionsParsed: transactions.count,
            statementCurrency: document.bookedCurrency, debitTotalMoney: nil, creditTotalMoney: nil,
            openingBalanceMoney: nil, closingBalanceMoney: nil, passed: issues.isEmpty, issues: issues)
    }

    private static func validateSalaryStatement(
        financialDocument: FinancialDocument,
        evidence: SalaryStatementEvidence
    ) -> ImportValidationResult {
        var issues: [ValidationIssue] = []
        if financialDocument.metadata.institution != .unknown ||
            financialDocument.metadata.documentType != .salarySlip ||
            financialDocument.metadata.fileFormat != .pdf ||
            financialDocument.bookedCurrency != evidence.nativeCurrency ||
            !financialDocument.transactions.isEmpty ||
            !financialDocument.financialIdentifiers.isEmpty ||
            evidence.sourceAuthority != .qatarAirways ||
            evidence.profileID != SalaryStatementEvidence.profileID ||
            evidence.profileVersion != SalaryStatementEvidence.profileVersion {
            issues.append(ValidationIssue(
                severity: .error,
                rowNumber: nil,
                message: "Salary source metadata conflicts with the exact profile."
            ))
        }
        let allComponents = evidence.earnings + evidence.deductions
        if allComponents.contains(where: { $0.money.currency != evidence.nativeCurrency || $0.money.amount <= 0 }) {
            issues.append(ValidationIssue(
                severity: .error,
                rowNumber: nil,
                message: "Salary component Money is invalid."
            ))
        }
        if evidence.earnings.map(\.sourceOrdinal) != evidence.earnings.indices.map({ $0 + 1 }) ||
            evidence.deductions.map(\.sourceOrdinal) != evidence.deductions.indices.map({ $0 + 1 }) {
            issues.append(ValidationIssue(
                severity: .error,
                rowNumber: nil,
                message: "Salary component source order is incomplete."
            ))
        }
        return ImportValidationResult(
            rowsRead: allComponents.count,
            transactionsParsed: 0,
            statementCurrency: evidence.nativeCurrency,
            debitTotalMoney: evidence.printedDeductionsTotal,
            creditTotalMoney: evidence.printedEarningsTotal,
            openingBalanceMoney: nil,
            closingBalanceMoney: evidence.printedNet,
            passed: issues.isEmpty,
            issues: issues
        )
    }

    private static func validateCardStatement(
        financialDocument: FinancialDocument,
        evidence: CardStatementEvidence
    ) -> ImportValidationResult {
        let transactions = financialDocument.transactions
        var issues: [ValidationIssue] = []
        let currency = evidence.nativeCurrency
        // Empty cards still traverse this entire profile validator.  Typed
        // zero evidence is an additional admission predicate; it never
        // replaces summary, section, source-order, or reconciliation checks.
        let zeroValidation = transactions.isEmpty
            ? ZeroActivityStatementValidator.validate(financialDocument: financialDocument)
            : nil
        guard let contract = CardStatementProfileContract(reconciliationRuleIdentifier: evidence.reconciliationRuleIdentifier),
              contract.acceptsCurrentReconciliationRule(evidence.reconciliationRuleIdentifier) else {
            return ImportValidationResult(
                rowsRead: transactions.count,
                transactionsParsed: transactions.count,
                statementCurrency: currency,
                debitTotalMoney: nil,
                creditTotalMoney: nil,
                openingBalanceMoney: nil,
                closingBalanceMoney: nil,
                passed: false,
                issues: [ValidationIssue(severity: .error, rowNumber: nil, message: "Card reconciliation contract is unsupported.")]
            )
        }
        let sectionIDs = Set(evidence.instrumentSections.map(\.documentScopedSectionID))
        let annotationsByID = Dictionary(
            uniqueKeysWithValues: evidence.transactionAnnotations.map { ($0.parserTransactionID, $0) }
        )
        let sourceOrdinals = transactions.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
        let axisSourceOrderIsValid = sourceOrdinals.count == transactions.count
            && sourceOrdinals.allSatisfy { $0 > 0 }
            && sourceOrdinals == sourceOrdinals.sorted()
            && Set(sourceOrdinals).count == sourceOrdinals.count

        let temporalEvidenceValid: Bool
        if contract == .axis {
            switch financialDocument.metadata.fileFormat {
            case .pdf:
                temporalEvidenceValid =
                    (evidence.declaredStatementPeriod != nil && evidence.selectedStatementMonth == nil) ||
                    (evidence.statementDate == nil && evidence.declaredStatementPeriod == nil &&
                        evidence.selectedStatementMonth != nil)
            case .xlsx:
                temporalEvidenceValid = evidence.statementDate == nil &&
                    evidence.declaredStatementPeriod == nil &&
                    evidence.selectedStatementMonth != nil
            default:
                temporalEvidenceValid = false
            }
        } else {
            temporalEvidenceValid = evidence.statementDate != nil && evidence.declaredStatementPeriod != nil &&
                evidence.statementDate == evidence.declaredStatementPeriod?.end && evidence.selectedStatementMonth == nil
        }
        if financialDocument.metadata.institution.rawValue != contract.institutionCode ||
            financialDocument.metadata.documentType != .creditCard ||
            !((contract == .axis && [.pdf, .xlsx].contains(financialDocument.metadata.fileFormat)) ||
              (contract != .axis && financialDocument.metadata.fileFormat == .pdf)) ||
            financialDocument.bookedCurrency != currency ||
            currency.code != contract.nativeCurrency ||
            (contract == .amexUSDZero && (!transactions.isEmpty || !evidence.instrumentSections.isEmpty)) ||
            financialDocument.declaredStatementPeriod != evidence.declaredStatementPeriod ||
            !temporalEvidenceValid {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card statement metadata conflicts with parser evidence."))
        }
        if (transactions.isEmpty && zeroValidation?.passed != true) ||
            annotationsByID.count != transactions.count ||
            Set(transactions.map(\.id)) != Set(annotationsByID.keys) {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Every card financial row requires exactly one transaction annotation."))
        }
        if let zeroValidation, !zeroValidation.passed {
            issues.append(contentsOf: zeroValidation.issues)
        }
        if contract == .axis && !axisSourceOrderIsValid {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Axis source physical order is incomplete or contradictory."))
        }

        var increaseValues: [Money] = []
        var decreaseValues: [Money] = []
        var instrumentValues: [Money] = []
        var allValues: [Money] = []
        var membershipValues: [CardTransactionSummaryMembership: [Money]] = [:]
        var sectionValues = Dictionary(uniqueKeysWithValues: sectionIDs.map { ($0, [Money]()) })

        for (index, transaction) in transactions.enumerated() {
            let row = transaction.sourceProvenance.first?.sourceOrdinal ?? index + 1
            guard let postingDate = transaction.statementDate,
                  let annotation = annotationsByID[transaction.id] else {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card row is missing posting-date or annotation evidence."))
                continue
            }
            let isCBQV1PrecedingBoundaryRepayment =
                contract == .cbqV1 &&
                annotation.financialScope == .accountLevel &&
                annotation.summaryMembership == .cbqV1PaymentReceived &&
                annotation.liabilityEffect == .decreasesAmountOwed &&
                annotation.sourceTransactionDate == postingDate &&
                Self.immediatelyPrecedes(postingDate, periodStart: evidence.declaredStatementPeriod?.start)
            if contract != .axis, let period = evidence.declaredStatementPeriod,
               (postingDate > period.end || (postingDate < period.start && !isCBQV1PrecedingBoundaryRepayment)) {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card financial date is outside the source-proven statement period."))
            }
            if transaction.financialDateRole != (contract == .axis ? .transactionDate : .postingDate) ||
                transaction.money.currency != currency ||
                transaction.debitMoney != nil || transaction.creditMoney != nil ||
                transaction.runningBalanceMoney != nil ||
                transaction.cardLiabilityEffect != annotation.liabilityEffect ||
                transaction.sourceProvenance.count != 1 ||
                transaction.sourceProvenance[0].sourceTransactionDate != annotation.sourceTransactionDate ||
                (contract != .axis && transaction.sourceProvenance[0].sourceOrdinal != index + 1) ||
                !contract.accepts(profileID: transaction.sourceProvenance[0].parserProfileID) ||
                transaction.sourceProvenance[0].parserProfileVersion != contract.profileVersion {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card row semantics or provenance are incomplete."))
            }
            if let original = annotation.originalMerchantMoney,
               original.currency == currency ||
                (annotation.liabilityEffect == .increasesAmountOwed && original.amount <= 0) ||
                (annotation.liabilityEffect == .decreasesAmountOwed && original.amount >= 0) {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Original merchant Money is invalid for the card liability effect."))
            }
            let minor = try? transaction.money.minorUnits()
            switch annotation.liabilityEffect {
            case .increasesAmountOwed:
                if minor.map({ $0 <= 0 }) ?? true {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "A card charge must increase amount owed with positive signed Money."))
                }
                increaseValues.append(transaction.money)
            case .decreasesAmountOwed:
                if minor.map({ $0 >= 0 }) ?? true {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "A card payment or credit must decrease amount owed with negative signed Money."))
                }
                if let positive = try? Money(amount: -transaction.money.amount, currency: currency) {
                    decreaseValues.append(positive)
                }
            }
            allValues.append(transaction.money)
            if let membership = annotation.summaryMembership {
                membershipValues[membership, default: []].append(transaction.money)
            }
            if let sectionID = annotation.documentScopedSectionID {
                if !sectionIDs.contains(sectionID) {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card row references an unknown structural source section."))
                } else {
                    sectionValues[sectionID, default: []].append(transaction.money)
                }
            }
            switch annotation.financialScope {
            case .accountLevel:
                if contract.requiresCBQSummaryMembership,
                   annotation.summaryMembership.map(contract.accountLevelMemberships.contains) != true {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "CBQ account-level activity has invalid summary membership."))
                }
            case .instrument:
                guard annotation.documentScopedSectionID != nil else {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card instrument activity is missing structural source membership."))
                    continue
                }
                instrumentValues.append(transaction.money)
                if contract.requiresCBQSummaryMembership,
                   annotation.summaryMembership.map(contract.instrumentMemberships.contains) != true {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "CBQ instrument activity has invalid summary membership."))
                }
            }
        }

        let previous = evidence.summary(code: "previous_balance")?.money
        let newBalance = contract == .axis
            ? evidence.summary(code: "axis_total_payment_due")?.money
            : evidence.summary(code: "new_balance")?.money
        let dueDate = evidence.summary(code: "due_date")?.date
        let summaryCodes = Set(evidence.summaryComponents.map(\.persistenceCode))
        let summaryContractInvalid = contract == .axis
            ? !summaryCodes.isSubset(of: contract.allowedSummaryCodes)
            : dueDate == nil || previous == nil || newBalance == nil ||
                summaryCodes != contract.requiredSummaryCodes(
                    reconciliationRuleIdentifier: evidence.reconciliationRuleIdentifier,
                    sourceFormatCode: financialDocument.metadata.fileFormat.rawValue
                )
        if summaryContractInvalid ||
            evidence.summaryComponents.compactMap(\.money).contains(where: { $0.currency != currency }) {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card summary components are incomplete or contradictory."))
        }
        let structuralIdentityIsInvalid: Bool
        if contract == .axis {
            structuralIdentityIsInvalid = evidence.accountSourceIdentityObservations.count > 1 ||
                evidence.accountSourceIdentityObservations.contains {
                    $0.kind != .axisPrimaryMaskedCardNumber || $0.subject != .liabilityAccount
                } ||
                !evidence.instrumentSections.isEmpty ||
                evidence.transactionAnnotations.contains {
                    $0.financialScope != .accountLevel || $0.documentScopedSectionID != nil
                }
        } else if let accountKind = contract.accountObservationKindCode,
                  let instrumentKind = contract.instrumentObservationKindCode,
                  let sectionRule = contract.sectionRule {
            let permitsAccountOnlyZero = contract.isAmex &&
                transactions.isEmpty && zeroValidation?.passed == true
            structuralIdentityIsInvalid = evidence.accountSourceIdentityObservations.count != 1 ||
                evidence.accountSourceIdentityObservations.first?.kind.rawValue != accountKind ||
                evidence.accountSourceIdentityObservations.first?.subject != .liabilityAccount ||
                (evidence.instrumentSections.isEmpty && !permitsAccountOnlyZero) ||
                evidence.instrumentSections.contains(where: { section in
                    section.reconciliationRuleIdentifier != sectionRule ||
                        section.signedNetTotal.currency != currency ||
                        section.sourceIdentityObservations.count != 1 ||
                        section.sourceIdentityObservations.first?.kind.rawValue != instrumentKind ||
                        section.sourceIdentityObservations.first?.subject != .instrument
                })
        } else {
            structuralIdentityIsInvalid = true
        }
        if structuralIdentityIsInvalid {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card source identity or section evidence is incompatible with its exact profile."))
        }

        let increaseTotal = try? moneySum(increaseValues, currency: currency)
        let decreaseTotal = try? moneySum(decreaseValues, currency: currency)
        let instrumentTotal = try? moneySum(instrumentValues, currency: currency)
        let allRowsTotal = try? moneySum(allValues, currency: currency)
        // Source totals and section balances cannot veto nonempty, fully
        // accounted occurrences. Empty statements still require every
        // existing summary, section and independent zero-activity check.
        if transactions.isEmpty {
            validateSummary(
                contract: contract,
                evidence: evidence,
                previous: previous,
                newBalance: newBalance,
                increaseTotal: increaseTotal,
                decreaseTotal: decreaseTotal,
                instrumentTotal: instrumentTotal,
                allRowsTotal: allRowsTotal,
                membershipValues: membershipValues,
                currency: currency,
                issues: &issues
            )
            if contract != .axis {
                for section in evidence.instrumentSections {
                    let sectionValues = sectionValues[section.documentScopedSectionID] ?? []
                    let sectionReconciles: Bool
                    if sectionValues.isEmpty {
                        // An empty card may still contain source-proven structural
                        // sections.  Empty section activity is valid only when
                        // the section's printed signed total is exactly zero and
                        // the independent zero-control admission succeeded.  The
                        // summary, identity and profile checks above still run.
                        sectionReconciles = zeroValidation?.passed == true &&
                            (try? section.signedNetTotal.minorUnits()) == 0
                    } else {
                        sectionReconciles = (try? moneySum(sectionValues, currency: currency)) == section.signedNetTotal
                    }
                    guard sectionReconciles else {
                        issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card instrument section does not equal its printed signed total."))
                        continue
                    }
                }
                let sectionsTotal = try? moneySum(evidence.instrumentSections.map(\.signedNetTotal), currency: currency)
                let expectedSectionCoverage = contract.isAmex ? instrumentTotal : allRowsTotal
                if sectionsTotal != expectedSectionCoverage {
                    issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card structural sections do not cover the exact source financial rows."))
                }
            }
        }

        return ImportValidationResult(
            rowsRead: transactions.count,
            transactionsParsed: transactions.count,
            statementCurrency: currency,
            debitTotalMoney: increaseTotal,
            creditTotalMoney: decreaseTotal,
            openingBalanceMoney: previous,
            closingBalanceMoney: newBalance,
            passed: issues.isEmpty,
            issues: issues
        )
    }

    private static func validateSummary(
        contract: CardStatementProfileContract,
        evidence: CardStatementEvidence,
        previous: Money?,
        newBalance: Money?,
        increaseTotal: Money?,
        decreaseTotal: Money?,
        instrumentTotal: Money?,
        allRowsTotal: Money?,
        membershipValues: [CardTransactionSummaryMembership: [Money]],
        currency: CurrencyCode,
        issues: inout [ValidationIssue]
    ) {
        func component(_ code: String) -> Money? { evidence.summary(code: code)?.money }
        func total(_ membership: CardTransactionSummaryMembership, magnitude: Bool = false) -> Money? {
            let values = membershipValues[membership, default: []]
            let normalized = magnitude ? values.compactMap { try? Money(amount: abs($0.amount), currency: currency) } : values
            return try? moneySum(normalized, currency: currency)
        }
        let mismatch: Bool
        switch contract {
        case .amex, .amexUSDZero:
            let credits = component("new_credits")
            let debits = component("new_debits")
            let printedInstrument = component("instrument_net_total")
            let expected: Money?
            if let previous, let credits, let debits {
                expected = try? (try previous - credits) + debits
            } else {
                expected = nil
            }
            mismatch = expected != newBalance || increaseTotal != debits || decreaseTotal != credits || instrumentTotal != printedInstrument
        case .cbqV1:
            let billed = component("amount_billed")
            let payment = component("payment_received")
            let sectionNet = component("source_section_net_total")
            let expected: Money?
            if let previous, let billed, let payment {
                expected = try? (try previous + billed) - payment
            } else {
                expected = nil
            }
            mismatch = expected != newBalance || total(.cbqV1AmountBilled) != billed ||
                total(.cbqV1PaymentReceived, magnitude: true) != payment || allRowsTotal != sectionNet
        case .cbqV2:
            let payment = component("total_payment")
            let credit = component("credit_reversal")
            let purchases = component("purchases")
            let installment = component("billed_installment")
            let fees = component("fees_charges")
            let sectionNet = component("source_section_net_total")
            let expected: Money?
            if let previous, let payment, let credit, let purchases, let installment, let fees {
                expected = try? (try (try (try (try previous - payment) - credit) + purchases) + installment) + fees
            } else {
                expected = nil
            }
            mismatch = expected != newBalance || total(.cbqV2TotalPayment, magnitude: true) != payment ||
                total(.cbqV2CreditReversal, magnitude: true) != credit || total(.cbqV2Purchases) != purchases ||
                total(.cbqV2BilledInstallment) != installment || total(.cbqV2FeesCharges) != fees ||
                allRowsTotal != sectionNet
        case .axis:
            // Axis source formats expose only previous balance and total
            // payment due. For a source-proven empty ledger, those two actual
            // controls must reconcile without inventing intermediate totals.
            mismatch = evidence.transactionAnnotations.isEmpty &&
                (previous == nil || newBalance == nil || previous != newBalance)
        }
        if mismatch {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card statement summary does not reconcile under its exact profile contract."))
        }
    }

    private static func immediatelyPrecedes(_ date: StatementDate, periodStart: StatementDate?) -> Bool {
        guard let periodStart else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let start = calendar.date(from: DateComponents(year: periodStart.year, month: periodStart.month, day: periodStart.day)),
              let preceding = calendar.date(byAdding: .day, value: -1, to: start) else { return false }
        let parts = calendar.dateComponents([.year, .month, .day], from: preceding)
        return parts.year == date.year && parts.month == date.month && parts.day == date.day
    }

    static func validate(transactions: [Transaction]) -> ImportValidationResult {
        let currencies = Set(transactions.map(\.money.currency))
        return validate(
            transactions: transactions,
            statementCurrency: currencies.count == 1 ? currencies.first : nil
        )
    }

    private static func validate(
        transactions: [Transaction],
        statementCurrency: CurrencyCode?,
        zeroActivityEvidence: ZeroActivityStatementEvidence? = nil,
        financialDocument: FinancialDocument? = nil
    ) -> ImportValidationResult {

        var issues: [ValidationIssue] = []

        let zeroValidation: ImportValidationResult? = transactions.isEmpty
            ? financialDocument.map { ZeroActivityStatementValidator.validate(financialDocument: $0) }
            : nil
        if transactions.isEmpty && zeroValidation?.passed != true {
            issues.append(
                ValidationIssue(
                    severity: .error,
                    rowNumber: nil,
                    message: "No transactions were imported."
                )
            )
        }
        if let zeroValidation, !zeroValidation.passed {
            issues.append(contentsOf: zeroValidation.issues)
        }

        if !transactions.isEmpty, statementCurrency == nil {
            issues.append(ValidationIssue(
                severity: .error,
                rowNumber: nil,
                message: "Statement currency is missing or transactions use mixed currencies."
            ))
        }

        for (index, transaction) in transactions.enumerated() {
            if transaction.statementDate == nil {
                issues.append(ValidationIssue(
                    severity: .error,
                    rowNumber: transaction.sourceProvenance.first?.sourceOrdinal ?? index + 1,
                    message: "Transaction is missing a statement date."
                ))
            }
            if let statementCurrency, transaction.money.currency != statementCurrency {
                issues.append(ValidationIssue(
                    severity: .error,
                    rowNumber: nil,
                    message: "Transaction currency does not match statement currency."
                ))
            }
            if transaction.debitMoney?.currency != nil && transaction.debitMoney?.currency != transaction.money.currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Transaction debit currency does not match posted currency."))
            }
            if transaction.creditMoney?.currency != nil && transaction.creditMoney?.currency != transaction.money.currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Transaction credit currency does not match posted currency."))
            }
            if transaction.runningBalanceMoney?.currency != nil && transaction.runningBalanceMoney?.currency != transaction.money.currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Running-balance currency does not match posted currency."))
            }
            if transaction.debit == nil && transaction.credit == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        rowNumber: nil,
                        message: "Transaction '\(transaction.description)' has neither a debit nor a credit amount."
                    )
                )
            }

            if transaction.balance == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        rowNumber: nil,
                        message: "Transaction '\(transaction.description)' is missing a running balance."
                    )
                )
            }
        }

        let debitTotalMoney = transactions.isEmpty
            ? zeroActivityEvidence?.debitTotal
            : (try? moneySum(transactions.compactMap(\.debitMoney), currency: statementCurrency))
        let creditTotalMoney = transactions.isEmpty
            ? zeroActivityEvidence?.creditTotal
            : (try? moneySum(transactions.compactMap(\.creditMoney), currency: statementCurrency))

        // Opening/closing controls are source-owned observations. Row order
        // cannot supply missing statement controls or veto known occurrences.
        let openingBalanceMoney = transactions.isEmpty
            ? zeroActivityEvidence?.openingBalance
            : financialDocument?.sourceStatementEvidence?.openingBalance
        let closingBalanceMoney = transactions.isEmpty
            ? zeroActivityEvidence?.closingBalance
            : financialDocument?.sourceStatementEvidence?.closingBalance

        return ImportValidationResult(
            rowsRead: transactions.count,
            transactionsParsed: transactions.count,
            statementCurrency: statementCurrency,
            debitTotalMoney: debitTotalMoney,
            creditTotalMoney: creditTotalMoney,
            openingBalanceMoney: openingBalanceMoney,
            closingBalanceMoney: closingBalanceMoney,
            passed: issues.isEmpty,
            issues: issues
        )
    }

    private static func moneySum(_ values: [Money], currency: CurrencyCode?) throws -> Money? {
        guard let currency else { return nil }
        guard !values.isEmpty else { return try Money(amount: .zero, currency: currency) }
        return try Money.aggregate(values)
    }
}
