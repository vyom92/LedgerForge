import Combine
import Foundation

/// Observes the same instances used by the Mac UI. It never opens a repository,
/// requests hydration/network work, saves a plan, or manufactures financial data.
@MainActor
final class FinancialMCPPresentation {
  static let shared = FinancialMCPPresentation()
  private weak var dashboard: DashboardViewModel?
  private weak var planner: SalaryWorkspaceViewModel?
  private weak var prices: InvestmentPriceSession?
  private weak var rates: AlDarReferenceSession?
  private var subscriptions = Set<AnyCancellable>()
  private var generation: ProviderGenerationToken?
  private var providerIdentity = UUID().uuidString
  private var revision: UInt64 = 0
  private var dirty = true
  private var queued = false
  private var selectedSection = "Dashboard"
  private var showsZeroBalances = false

  func attach(
    dashboard: DashboardViewModel, planner: SalaryWorkspaceViewModel,
    prices: InvestmentPriceSession, rates: AlDarReferenceSession
  ) {
    guard self.dashboard !== dashboard else { return }
    self.dashboard = dashboard
    self.planner = planner
    self.prices = prices
    self.rates = rates
    subscriptions.removeAll()
    let publishers: [ObservableObjectPublisher] = [
      dashboard.objectWillChange, planner.objectWillChange,
      planner.planningAnalysis.objectWillChange, prices.objectWillChange, rates.objectWillChange,
      ApplicationAvailability.shared.objectWillChange, AccountStore.shared.objectWillChange,
      CardStore.shared.objectWillChange, InvestmentStore.shared.objectWillChange,
      FundingPlanStore.shared.objectWillChange, FinancialIntelligenceStore.shared.objectWillChange,
      CategoryStore.shared.objectWillChange, NetWorthMembershipStore.shared.objectWillChange,
      ReportingCurrencyPreferences.shared.objectWillChange,
      BackgroundUpdatesSession.shared.objectWillChange,
    ]
    for publisher in publishers {
      publisher.sink { [weak self] in self?.changed() }.store(in: &subscriptions)
    }
    FinancialMCPController.shared.$allowed.removeDuplicates().sink { [weak self] _ in
      self?.changed()
    }.store(in: &subscriptions)
    changed()
  }

  func select(section: String, showsZeroBalances: Bool) {
    guard selectedSection != section || self.showsZeroBalances != showsZeroBalances else { return }
    selectedSection = section
    self.showsZeroBalances = showsZeroBalances
    changed()
  }

  private func changed() {
    dirty = true
    guard !queued else { return }
    queued = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.queued = false
      let current = ApplicationAvailability.shared.generation
      if self.generation != current {
        self.providerIdentity = UUID().uuidString
        self.generation = current
      }
      self.revision &+= 1
      self.dirty = false
      // Keep the existing shared UI analysis current while sharing it.
      // This is observation-driven, never invoked from an MCP read.
      let permissions = FinancialMCPController.shared.allowed
      if let planner = self.planner, planner.canEdit, planner.hasValidCalculation,
        permissions.contains(FinancialMCPProtocol.Tool.reserveStatus.rawValue)
          || permissions.contains(FinancialMCPProtocol.Tool.planningContext.rawValue)
      {
        planner.planningAnalysis.refresh(
          plan: planner.plan, scenario: planner.insightSelection.scenario,
          selectedHistoryAccountIDs: planner.selectedHistoryAccountIDs,
          retainedRecurringOccurrenceIDs: planner.retainedRecurringOccurrenceIDs,
          excludedRecurringOccurrenceIDs: planner.recurringOccurrenceExclusions)
      }
    }
  }

  func read(_ tool: FinancialMCPProtocol.Tool, arguments: [String: String]) -> [String: Any] {
    let availability = ApplicationAvailability.shared
    guard let current = availability.generation, current == DatabaseProvider.shared.generationToken,
      availability.state == .current || availability.state == .empty,
      !DatabaseActivityGate.shared.hasExclusiveOperation, !DatabaseActivityGate.shared.isUnavailable
    else {
      return FinancialMCPProtocol.error(
        "provider_unavailable",
        "Current LedgerForge presentation is unavailable; retained values are not current evidence."
      )
    }
    guard !dirty, generation == current, let dashboard, !dashboard.financialMCPRefreshPending,
      let planner, planner.generation == current,
      let prices, let rates,
      InvestmentStore.shared.generation == current, FundingPlanStore.shared.generation == current,
      FinancialIntelligenceStore.shared.generation == current,
      NetWorthMembershipStore.shared.generation == current,
      prices.financialMCPMatches(
        generation: current, snapshot: InvestmentStore.shared.snapshot, legs: rates.legs)
    else {
      return FinancialMCPProtocol.error(
        "presentation_changing",
        "The presentation is updating or belongs to a different provider. Retry after the app finishes updating."
      )
    }
    let snapshot = providerIdentity + ":" + String(revision)
    if let expected = arguments["expected_snapshot"], expected != snapshot {
      return FinancialMCPProtocol.error(
        "snapshot_changed",
        "The financial presentation changed. Read a new snapshot before combining results.")
    }
    var result: [String: Any] = [
      "schema_version": 1, "snapshot_id": snapshot,
      "provider_generation": providerIdentity, "presentation_revision": String(revision),
      "captured_at": ISO8601DateFormatter().string(from: Date()),
      "state": availability.state == .empty ? "empty" : "available", "read_only": true,
      "selected_section": selectedSection, "selected_month": planner.month.canonical,
      "basis":
        "Existing LedgerForge presentation; exact amounts are decimal strings or exact numerator/denominator pairs. Display strings preserve the app's rounding.",
    ]
    do {
      switch tool {
      case .financialStatus, .portfolioOverview:
        result["observations"] = [
          "investment_status": BackgroundUpdatesSession.shared.observationStatus(
            identities: Set(prices.overview.total.quotes.map(\.mapping.identity))),
          "fx_status": rates.observationStatus,
          "investment_refresh_in_progress": !prices.refreshing.isEmpty,
          "fx_refresh_in_progress": !rates.refreshing.isEmpty,
          "basis": "Current native observation status; cached values retain their source dates and are not a successful fresh fetch.",
        ]
        let value = try CompanionMacProjectionBuilder.make(
          ledgerLineage: providerIdentity,
          publicationID: snapshot, generation: revision, publishedAt: Date(),
          report: dashboard.netWorthReport,
          positions: dashboard.positions, investmentSnapshot: InvestmentStore.shared.snapshot,
          overview: prices.overview, valuations: prices.valuations, investmentsAvailable: true)
        if tool == .financialStatus {
          result["dashboard"] = try FinancialMCPProtocol.encoded(value.dashboard)
          result["display_filters"] = [
            "show_zero_balances": showsZeroBalances,
            "reporting_currencies": ReportingCurrencyPreferences.shared.currencies.map(\.rawValue),
            "visible_member_ids": dashboard.netWorthReport.members.filter {
              showsZeroBalances || !$0.isIncludedZeroBalanceAccount
            }.map { $0.id.stableKey },
          ]
          result["net_worth_basis"] = [
            "meaning": "Current holdings and qualified prices. Policy totals, vested values, cost, salary and planned savings are not added. Balances and holdings retain different source dates.",
            "targets": dashboard.netWorthReport.targets.map { target -> [String: Any] in
              [
                "currency": target.currency.rawValue, "qualification": target.label,
                "partial": target.isPartial, "stale": target.isStale,
                "missing_positions": target.missingCount,
                "arithmetic_failure": target.arithmeticFailure,
                "fx_fetched_at": Set(target.contributions.flatMap(\.fxDates)).sorted().map {
                  ISO8601DateFormatter().string(from: $0)
                },
              ]
            },
            "fx_references": rates.legs.keys.sorted { $0.rawValue < $1.rawValue }.compactMap {
              currency -> [String: String]? in
              guard let leg = rates.legs[currency] else { return nil }
              return ["base_currency": "QAR", "base_amount": "1", "currency": currency.rawValue,
                "amount": leg.returned.rawToken, "fetched_at": leg.fetchedAtISO]
            },
          ]
          result["monthly_summary"] = [
            "month": planner.month.canonical, "title": dashboard.fundingMonthTitle,
            "state": String(describing: dashboard.fundingState),
            "message": dashboard.fundingMessage as Any? ?? NSNull(),
            "rate_detail": dashboard.fundingRateDetail as Any? ?? NSNull(),
            "metrics": Self.calculation(dashboard.fundingCalculation),
          ]
        } else {
          result["portfolio"] = try FinancialMCPProtocol.encoded(value.investments)
          result["price_revision"] = prices.revision
          result["qualification"] = [
            "priced_holdings": prices.overview.total.priceCount,
            "holdings": prices.overview.total.holdingCount,
            "cost_covered": prices.overview.total.costCount,
            "gain_covered": prices.overview.total.gainCount,
            "missing_fx": prices.overview.total.fxMissing,
            "oldest_valuation_age_days": prices.overview.total.oldestAge(at: Date()),
            "oldest_freshness_age_days": prices.overview.total.oldestFreshnessAge(at: Date()),
          ]
        }
      case .reserveStatus:
        guard let projection = planner.planningAnalysis.financialMCPProjection(for: planner) else {
          return FinancialMCPProtocol.error(
            "planning_presentation_unavailable",
            "The selected plan's reserve analysis is updating, incomplete, or not available. No earlier calculation is substituted."
          )
        }
        result["reserves"] = Self.reserves(projection, planner: planner)
      case .planningContext:
        if let monthText = arguments["month"] {
          guard let month = try? SelectedStatementMonth(canonical: monthText),
            SalaryWorkspaceViewModel.planningMonths.contains(month)
          else {
            return FinancialMCPProtocol.error(
              "invalid_month", "Use a supported planning month in YYYY-MM format.")
          }
          let saved = FundingPlanStore.shared.plan(
            for: month, workspaceID: planner.plan.workspaceID)
          let retained = FundingPlanStore.shared.scratchpads.first {
            $0.plan.month == month && $0.plan.workspaceID == planner.plan.workspaceID
          }
          result["requested_month"] = monthText
          result["selection_basis"] =
            "Hydrated saved and retained records for the explicit month; this does not select or edit a UI month."
          result["saved"] = try saved.map(Self.plan) ?? NSNull()
          result["retained"] = try retained.map(Self.scratchpad) ?? NSNull()
          result["calculated_outputs"] =
            "Unavailable for an explicitly requested record. Omit month to read the actual displayed calculation."
        } else {
          result["selection_basis"] =
            "Actual selected Budget Planning workspace, including uncommitted input and unsaved scenario."
          result["editor"] = try Self.editor(planner)
          result["saved"] =
            try FundingPlanStore.shared.plan(
              for: planner.month, workspaceID: planner.plan.workspaceID
            ).map(Self.plan) ?? NSNull()
          result["retained"] =
            try planner.financialMCPRetainedEntries.map(Self.scratchpad) ?? NSNull()
          if let projection = planner.planningAnalysis.financialMCPProjection(for: planner) {
            result["insights"] = Self.insights(projection, planner: planner)
          } else {
            result["insights"] = FinancialMCPProtocol.error(
              "planning_presentation_unavailable",
              "No current completed insight calculation for this draft and scenario.")
          }
        }
      }
    } catch {
      return FinancialMCPProtocol.error(
        "presentation_encoding_failed", "The current presentation could not be represented exactly."
      )
    }
    // Capture is synchronous on the UI actor: no suspension can interleave
    // a provider replacement, quote change or draft edit within this value.
    return result
  }

  static func metric(_ label: String, _ money: Money?) -> [String: Any] {
    [
      "label": label, "display": money.map { MoneyFormatting.display($0) } ?? "Unavailable",
      "amount": money.flatMap { try? $0.canonicalDecimalString() } as Any? ?? NSNull(),
      "currency": money?.currency.code as Any? ?? NSNull(),
    ]
  }
  static func decimal(
    _ label: String, _ amount: Decimal?, currency: String, missingDisplay: String = "Unavailable"
  ) -> [String: Any] {
    let money = amount.flatMap { try? Money(amount: $0, currency: currency) }
    return [
      "label": label, "display": money.map { MoneyFormatting.display($0) } ?? missingDisplay,
      "amount": amount.map(InvestmentArithmetic.text) as Any? ?? NSNull(), "currency": currency,
    ]
  }
  static func calculation(_ value: FundingPlanCalculation?) -> [String: Any] {
    guard let value else { return ["state": "unavailable"] }
    let metrics: [(String, Money?)] = [
      ("Expected net pay", value.expectedNet), ("Qatar starting cash", value.selectedQARLiquidity),
      ("India starting cash", value.selectedINRLiquidity),
      ("Qatar commitments", value.qatarCommitments),
      ("India commitments", value.indiaCommitments),
      ("India funding shortfall", value.indiaFundingShortfall),
      ("Required QAR principal", value.requiredQARPrincipal),
      ("Effective transfer fee", value.effectiveTransferFee),
      ("QAR before investment", value.qarBeforeInvestment),
      ("Available for investment", value.availableForInvestment),
      ("Final QAR buffer", value.finalQARBuffer), ("Total deductions", value.totalDeductions),
      ("Position before transfer", value.positionBeforeTransfer),
      ("Signed potential capacity", value.signedPotentialCapacity),
      ("Transferable principal", value.transferablePrincipal),
      ("Estimated INR", value.estimatedINR),
      ("Qatar obligation shortfall", value.qatarObligationShortfall),
      ("Qatar reserve gap", value.qatarReserveGap),
    ]
    return [
      "state": value.incompleteReasons.isEmpty ? "complete" : "partial",
      "incomplete_reasons": value.incompleteReasons.map(\.rawValue).sorted(),
      "values": metrics.map { metric($0.0, $0.1) },
    ]
  }
  static func plan(_ value: FundingPlan) throws -> [String: Any] {
    var result = try FinancialMCPProtocol.encoded(value) as? [String: Any] ?? [:]
    // Explicit exact FX survives consumers which parse JSON numbers as Double.
    result["exact_manual_inr_per_qar"] =
      value.planningFX.map { InvestmentArithmetic.text($0.inrPerQAR) } as Any? ?? NSNull()
    result["displayed_inputs"] = [
      metric("Fixed earnings", value.expectedFixedEarnings),
      metric("Variable earnings", value.expectedVariableEarnings),
      metric("Deductions", value.expectedDeductions),
      metric("Transfer fee", value.configuredTransferFee), metric("Keep in CBQ", value.keepInCBQ),
    ]
    return result
  }
  static func scratchpad(_ value: MonthlyPlanScratchpad) throws -> [String: Any] {
    [
      "state": value.fieldErrors.isEmpty ? "retained" : "retained_incomplete",
      "plan": try plan(value.plan),
      "canonical_at_retention": try value.canonical.map(plan) ?? NSNull(),
      "raw_input": value.rawText, "field_errors": value.fieldErrors,
      "unavailable_balance_accounts": value.unavailableBalanceAccountIDs.sorted(),
      "meaning":
        "Retained entries are distinct from a validated saved plan. Incomplete input is text, not an accepted financial amount.",
    ]
  }
  static func editor(_ value: SalaryWorkspaceViewModel) throws -> [String: Any] {
    [
      "month": value.month.canonical, "plan": try plan(value.plan), "status": value.statusText,
      "save_state": String(describing: value.saveState), "dirty": value.isDirty,
      "retention_pending": value.retentionPending, "raw_input": value.rawText,
      "field_errors": value.fieldErrors,
      "has_valid_calculation": value.hasValidCalculation,
      "calculation": calculation(value.hasValidCalculation ? value.calculation : nil),
      "inr_buffer_estimate": metric(
        "Final buffer INR estimate", value.hasValidCalculation ? value.finalBufferINREstimate : nil),
      "selected_history_accounts": value.selectedHistoryAccountIDs.sorted(),
      "excluded_planning_accounts": value.excludedPlanningAccountIDs.sorted(),
      "scenario": scenario(value),
    ]
  }
  static func scenario(_ planner: SalaryWorkspaceViewModel) -> [String: Any] {
    let value = planner.insightSelection.scenario
    return [
      "state": value.isActive ? "unsaved_scenario" : "inactive", "account_id": value.accountID,
      "extra_income": InvestmentArithmetic.text(value.extraIncome),
      "extra_cost": InvestmentArithmetic.text(value.extraCost),
      "contribution_change": InvestmentArithmetic.text(value.contributionChange),
      "payment_delay_days": value.paymentDelayDays,
      "raw_income": planner.insightSelection.scenarioIncome,
      "raw_cost": planner.insightSelection.scenarioCost,
      "raw_contribution": planner.insightSelection.scenarioContribution,
      "currency": AccountStore.shared.accounts.first { $0.repositoryAccountId == value.accountID }?
        .currencyCode as Any? ?? NSNull(),
    ]
  }
  static func reserves(_ projection: PlanningProjection, planner: SalaryWorkspaceViewModel)
    -> [String: Any]
  {
    let contributions = planner.plan.assistance?.contributions ?? []
    let sources = projection.reserves.map { reserve -> (String, Set<String>) in
      (
        reserve.id,
        Set(contributions.filter { $0.designationID == reserve.id }.map(\.fundingAccountID))
          .union(reserve.designation.accountID.map { [$0] } ?? [])
      )
    }
    let overlaps = sources.enumerated().flatMap { index, first in
      sources.dropFirst(index + 1).compactMap { second -> [String: Any]? in
        let shared = first.1.intersection(second.1)
        return shared.isEmpty
          ? nil
          : [
            "reserve_ids": [first.0, second.0], "shared_funding_accounts": shared.sorted(),
            "qualification":
              "Shared funding sources can overlap. These conditional figures are not a globally reconciled allocation.",
          ]
      }
    }
    let currency = planner.insightSelection.currency
    return [
      "month": projection.month.canonical, "currency_filter": currency,
      "scenario": scenario(planner),
      "start": projection.start.canonical, "end": projection.end.canonical,
      "globally_reconciled": false, "overlapping_allocations": overlaps,
      "basis":
        "Per-reserve conditional funding after bills. Targets, monthly contributions and funded amounts are separate; no aggregate funded total is established.",
      "values": projection.reserves.filter { $0.designation.target.currency == currency }.map {
        value -> [String: Any] in
        [
          "id": value.id, "title": value.designation.title, "kind": value.designation.kind.rawValue,
          "account_id": value.designation.accountID as Any? ?? NSNull(), "basis": value.basis,
          "target": decimal("Target", value.target, currency: currency),
          "conditional_funding": decimal(
            "Conditional funding", value.fundedAfterBills, currency: currency,
            missingDisplay: "Funding unknown"),
          "gap": decimal("Gap", value.gap, currency: currency),
          "monthly_contribution": decimal(
            "Planned this month",
            contributions.contains { $0.designationID == value.id }
              ? value.proposedContribution : nil, currency: currency,
            missingDisplay: "Not selected"),
          "contribution_selected": contributions.contains { $0.designationID == value.id },
          "contributions": contributions.filter { $0.designationID == value.id }.map {
            contribution -> [String: Any] in
            [
              "funding_account_id": contribution.fundingAccountID,
              "due_date": contribution.dueDate,
              "amount": metric("Monthly contribution", try? contribution.amount.money()),
            ]
          },
          "available_on": value.designation.availableOn as Any? ?? NSNull(),
          "balance_date": value.designation.planningBalanceDate as Any? ?? NSNull(),
        ]
      },
    ]
  }
  static func insights(_ projection: PlanningProjection, planner: SalaryWorkspaceViewModel)
    -> [String: Any]
  {
    let selected = projection.runways.first { $0.id == planner.insightSelection.accountID }
      ?? projection.runways.first
    return [
      "month": projection.month.canonical, "start": projection.start.canonical,
      "end": projection.end.canonical,
      "scenario_is_active": projection.scenarioIsActive,
      "selected_account": selected?.id as Any? ?? NSNull(),
      "unmatched_spending_count": projection.unmatchedSpendingCount,
      "card_needs": projection.cardNeeds,
      "accounts": projection.runways.map { value -> [String: Any] in
        let capacity = projection.investmentCapacity(
          accountID: value.id, assistance: planner.plan.assistance)
        return [
          "id": value.id, "title": value.anchor.title, "currency": value.anchor.currency,
          "balance_date": value.anchor.date?.canonical as Any? ?? NSNull(),
          "limitations": value.limitations,
          "investment_capacity": decimal(
            "Additional investment capacity", capacity.0, currency: value.anchor.currency),
          "investment_capacity_reasons": capacity.1,
          "values": [
            decimal("Starting balance", value.anchor.amount, currency: value.anchor.currency),
            decimal(
              "Lowest conditional balance", value.lowestBalance, currency: value.anchor.currency),
            decimal(
              "Ending conditional balance", value.endingBalance, currency: value.anchor.currency),
            decimal("Protected balance", value.reserveFloor, currency: value.anchor.currency),
            decimal(
              "Conditional headroom", value.conditionalHeadroom, currency: value.anchor.currency),
          ],
        ]
      },
    ]
  }
}
