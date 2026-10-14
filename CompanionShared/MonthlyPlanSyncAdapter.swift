import Foundation

/// Exact monthly owner-input grouping. Financial facts remain in Binding's Mac-owned
/// anchor. This codec does not fetch, seed a month, execute a merge or write storage.
nonisolated enum MonthlyPlanSyncAdapter {
    enum AdapterError: Error, Equatable {
        case identity, structure(String), sourceOwnedMutation(String), inconsistentInput(String)
        case unknownEditedLocale(String), ambiguousOccurrenceOwnership(String)
        case unsupportedRecurringInsertion(String), invalidOrder(String), bookkeeping
    }
    enum InputOrigin: Codable, Equatable, Sendable {
        case unknown
        case known(localeIdentifier: String)
        var locale: Locale? {
            if case let .known(identifier) = self { return Locale(identifier: identifier) }
            return nil
        }
    }
    struct OrderKey: Codable, Equatable, Sendable {
        let position: Int
        let stableRowID: String
    }
    struct Metadata: Codable, Equatable, Sendable {
        var origins: [String: InputOrigin] = [:]
        var order: [String: OrderKey] = [:]
    }
    struct Binding: Codable, Equatable, Sendable {
        let scope: CompanionMerge.SyncScope
        let baselineScratchpad: MonthlyPlanScratchpad
        let baselineMetadata: Metadata
        let baselineDocument: CompanionMerge.Document
        let bankCurrencies: [String: CurrencyCode]
        let availableAlDarQuote: AlDarReferenceQuote?
        let fundingAccountIDs: Set<String>
        let excludedHistoryAccountIDs: Set<String>
        /// Only this bound month's existing applied/excluded occurrence identities.
        let occurrenceRows: [String: String]
        let knownOccurrenceIDs: Set<String>
    }
    struct EncodedMonth: Equatable, Sendable {
        let document: CompanionMerge.Document
        let metadata: Metadata
    }
    struct DecodedMonth: Equatable, Sendable {
        let scratchpad: MonthlyPlanScratchpad
        let metadata: Metadata
        /// Unknown lexical provenance is not fabricated and is not a replacement zero.
        let uncertainInputKeys: Set<String>
    }
    private struct Identity: Codable, Equatable {
        let format: Int
        let scope: CompanionMerge.SyncScope
        let workspaceID: String
        let planID: String
        let month: String
        let calculationVersion: FundingPlanCalculationVersion
    }
    private struct NumericInput: Codable, Equatable {
        let raw: String?
        let error: String?
        let untouched: Bool
        let origin: InputOrigin
    }
    private struct TextInput: Codable, Equatable {
        let raw: String?
        let error: String?
    }
    private struct Scalar: Codable, Equatable {
        let money: Money?
        let provenance: FundingPlanValueProvenance?
        let input: NumericInput
    }
    private struct FX: Codable, Equatable {
        let mode: FundingPlanReferenceMode
        let manual: FundingPlanFX?
        let legacy: AlDarReferenceEvidence?
        let rate: NumericInput
        let date: TextInput
    }
    private struct RowIdentity: Codable, Equatable {
        let id: String
        let region: String?
        let carriedSourceRowID: String?
        let order: OrderKey
    }
    private struct Label: Codable, Equatable {
        let parsed: String
        let input: TextInput
    }
    private struct DeductionValue: Codable, Equatable {
        let money: Money
        let recurs: Bool
        let input: NumericInput
    }
    private struct BillValue: Codable, Equatable {
        let money: Money
        let included: Bool
        let fundingAccountID: String?
        let recurs: Bool
        let temporaryCarryBasis: Money?
        let dueDate: StatementDate?
        let preReductionBasis: Money?
        let carriedDate: String?
        let input: NumericInput
    }
    private struct BalanceValue: Codable, Equatable {
        let accountID: String
        let currency: CurrencyCode
        let row: FundingPlanBalance?
        let input: NumericInput
        let unavailable: Bool
        let order: OrderKey?
    }

    static func makeBinding(scope: CompanionMerge.SyncScope, scratchpad: MonthlyPlanScratchpad,
                            metadata: Metadata, bankCurrencies: [String: CurrencyCode],
                            fundingAccountIDs: Set<String>, excludedHistoryAccountIDs: Set<String>,
                            availableAlDarQuote: AlDarReferenceQuote? = nil) throws -> Binding {
        try scope.validate()
        guard scope.month == scratchpad.plan.month.canonical,
              scratchpad.hasIdentity(workspaceID: scratchpad.plan.workspaceID, month: scope.month) else { throw AdapterError.identity }
        let applications = scratchpad.plan.assistance?.appliedRecurringIDs ?? [:]
        var rowOwners: [String: String] = [:]
        for (occurrence, rowID) in applications {
            guard rowOwners.updateValue(occurrence, forKey: rowID) == nil else {
                throw AdapterError.ambiguousOccurrenceOwnership(rowID)
            }
            try validateOccurrenceID(occurrence)
        }
        for occurrence in scratchpad.excludedRecurringOccurrenceIDs { try validateOccurrenceID(occurrence) }
        guard Set(applications.keys).isDisjoint(with: scratchpad.excludedRecurringOccurrenceIDs) else {
            throw AdapterError.structure("An occurrence is both applied and excluded")
        }
        let projected = try project(scratchpad, metadata: metadata, authorityBankCurrencies: bankCurrencies)
        let binding = Binding(scope: scope, baselineScratchpad: scratchpad,
            baselineMetadata: projected.metadata, baselineDocument: try addingIdentity(to: projected.document, scope: scope, plan: scratchpad.plan),
            bankCurrencies: bankCurrencies, availableAlDarQuote: availableAlDarQuote, fundingAccountIDs: fundingAccountIDs,
            excludedHistoryAccountIDs: excludedHistoryAccountIDs, occurrenceRows: applications,
            knownOccurrenceIDs: Set(applications.keys).union(scratchpad.excludedRecurringOccurrenceIDs))
        // The binding is accepted only if the supported groups losslessly represent its anchor.
        let decoded = try decode(document: binding.baselineDocument, against: binding)
        guard intentEqual(decoded.scratchpad, scratchpad), decoded.metadata == projected.metadata else {
            throw AdapterError.structure("Unsupported retained scratchpad fields")
        }
        return binding
    }

    /// Captures absent order metadata once. Preserve returned metadata with pending state.
    static func encode(_ scratchpad: MonthlyPlanScratchpad, metadata: Metadata,
                       against binding: Binding) throws -> EncodedMonth {
        let projected = try project(scratchpad, metadata: metadata, base: binding)
        let document = try addingIdentity(to: projected.document, scope: binding.scope, plan: scratchpad.plan)
        let decoded = try decode(document: document, against: binding)
        guard intentEqual(decoded.scratchpad, scratchpad), decoded.metadata == projected.metadata else {
            throw AdapterError.sourceOwnedMutation("Unrepresented or source-owned plan state changed")
        }
        return EncodedMonth(document: document, metadata: projected.metadata)
    }

    /// Call only on a complete kernel result. Conflict previews intentionally omit rows.
    /// This returns a new value without changing the input document or normalizing intent.
    static func decode(document: CompanionMerge.Document, against binding: Binding) throws -> DecodedMonth {
        let header = try decodeIdentity(document: document, binding: binding)
        var state = DecodeState(result: binding.baselineScratchpad)
        prepareDecodeState(&state, binding: binding)
        try decodeScalars(document: document, binding: binding, state: &state)
        try decodeFX(document: document, binding: binding, state: &state)
        for (key, item) in document where !state.seen.contains(key) {
            if key.hasPrefix("deduction:") {
                try decodeDeduction(key: key, item: item, binding: binding, state: &state)
            } else if key.hasPrefix("bill:") || key.hasPrefix("recurring:") {
                try decodeBill(key: key, item: item, binding: binding, state: &state)
            } else if key.hasPrefix("balance:") {
                try decodeBalance(key: key, item: item, binding: binding, state: &state)
            } else { throw AdapterError.structure("Unknown item " + key) }
            state.seen.insert(key)
        }
        try reconcileDecodeState(&state, binding: binding)
        try finishDecodeState(&state, binding: binding, header: header)
        return DecodedMonth(scratchpad: state.result, metadata: state.metadata, uncertainInputKeys: state.uncertain)
    }

    // Separate Debug frames keep independent row decoders from reserving one
    // combined stack frame on iPhone. State remains local to this decode call.
    private struct DecodeState {
        var result: MonthlyPlanScratchpad
        var metadata = Metadata()
        var uncertain = Set<String>()
        var seen = Set(["identity", "fx"])
        var rowIDs = Set<String>()
        var bankIDs = Set<String>()
        var deductionIDs = Set<String>()
        var rowOrders: [String: OrderKey] = [:]
        var activeOccurrences = Set<String>()
    }

    private static func decodeIdentity(document: CompanionMerge.Document, binding: Binding) throws -> Identity {
        guard document["identity"] == binding.baselineDocument["identity"] else { throw AdapterError.identity }
        let header: Identity = try group(document["identity"], "binding", keys: ["binding"])
        guard header.format == 1, header.scope == binding.scope,
              header.workspaceID == binding.baselineScratchpad.plan.workspaceID,
              header.planID == binding.baselineScratchpad.plan.id,
              header.month == binding.scope.month,
              header.calculationVersion == binding.baselineScratchpad.plan.calculationVersion else { throw AdapterError.identity }
        return header
    }

    private static func prepareDecodeState(_ state: inout DecodeState, binding: Binding) {
        // Only modelled keys are cleared. Unsupported retained keys stay anchored and immutable.
        let allPlanRows = binding.baselineScratchpad.plan.qatarCommitments + binding.baselineScratchpad.plan.indiaCommitments
        for field in scalarKeys { clear(field, from: &state.result) }
        for key in ["fx.rate", "fx.date"] { clear(key, from: &state.result) }
        for row in binding.baselineScratchpad.plan.deductions { clear("deduction.label." + row.id, from: &state.result); clear("deduction.amount." + row.id, from: &state.result) }
        for row in allPlanRows { clear("label." + row.id, from: &state.result); clear("amount." + row.id, from: &state.result); state.result.preReductionBasis[row.id] = nil }
        for row in binding.baselineScratchpad.plan.balances { clear("balance." + row.accountID, from: &state.result); state.result.unavailableBalanceAccountIDs.remove(row.accountID) }
        state.result.plan.deductions = []; state.result.plan.qatarCommitments = []; state.result.plan.indiaCommitments = []; state.result.plan.balances = []
    }

    private static func decodeScalars(document: CompanionMerge.Document, binding: Binding, state: inout DecodeState) throws {
        for field in scalarKeys {
            let key = "scalar:" + field
            let value: Scalar = try group(document[key], "value", keys: ["value"])
            let old: Scalar = try group(binding.baselineDocument[key], "value", keys: ["value"])
            guard value.money?.currency.code == "QAR" || (field == "reserve" && value.money == nil) else { throw AdapterError.structure(key) }
            if field == "reserve" { guard value.provenance == nil else { throw AdapterError.structure(key) } }
            else { guard value.money != nil, value.provenance != nil else { throw AdapterError.structure(key) } }
            if binding.baselineScratchpad.plan.calculationVersion == .budgetV1 && ["deductions", "investment"].contains(field), value != old {
                throw AdapterError.sourceOwnedMutation(key + " is a legacy-only field")
            }
            if value.money != old.money, value.provenance != .manual && field != "reserve" { throw AdapterError.sourceOwnedMutation(key) }
            if value.provenance != old.provenance && value.provenance != .manual { throw AdapterError.sourceOwnedMutation(key) }
            try validateNumeric(value.input, amount: value.money, old: old.input, oldAmount: old.money,
                currency: "QAR", nonnegative: ["reserve", "fee"].contains(field), upperBound: nil, key: field)
            setScalar(value, field: field, plan: &state.result.plan)
            install(value.input, key: field, into: &state.result, metadata: &state.metadata, uncertain: &state.uncertain)
            state.seen.insert(key)
        }
    }

    private static func decodeFX(document: CompanionMerge.Document, binding: Binding, state: inout DecodeState) throws {
        let fx: FX = try group(document["fx"], "value", keys: ["value"])
        let oldFX: FX = try group(binding.baselineDocument["fx"], "value", keys: ["value"])
        try validateFX(fx, old: oldFX, key: "fx", version: binding.baselineScratchpad.plan.calculationVersion)
        state.result.plan.referenceMode = fx.mode; state.result.plan.planningFX = fx.manual
        state.result.plan.alDarReference = fx.legacy
        state.result.plan.effectiveAlDarReference = fx.mode == .manual ? nil
            : (oldFX.mode == .alDar ? binding.baselineScratchpad.plan.effectiveAlDarReference : binding.availableAlDarQuote)
        install(fx.rate, key: "fx.rate", into: &state.result, metadata: &state.metadata, uncertain: &state.uncertain)
        install(fx.date, key: "fx.date", into: &state.result)

    }

    private static func decodeDeduction(key: String, item: CompanionMerge.Item, binding: Binding, state: inout DecodeState) throws {
        try requireKeys(item, ["identity", "label", "value"])
        let identity: RowIdentity = try payload(item.groups["identity"])
        let label: Label = try payload(item.groups["label"])
        let value: DeductionValue = try payload(item.groups["value"])
        guard !identity.id.isEmpty, key == "deduction:" + identity.id, identity.region == nil,
              state.deductionIDs.insert(identity.id).inserted, value.money.currency.code == "QAR" else { throw AdapterError.structure(key) }
        let previous = binding.baselineDocument[key]
        let oldIdentity: RowIdentity? = try optionalGroup(previous, "identity")
        let oldLabel: Label? = try optionalGroup(previous, "label")
        let oldValue: DeductionValue? = try optionalGroup(previous, "value")
        try validateIdentity(identity, old: oldIdentity, collection: "deduction", binding: binding, key: key)
        try validateLabel(label, old: oldLabel, key: "deduction.label." + identity.id, alwaysStoresRaw: true)
        try validateNumeric(value.input, amount: value.money, old: oldValue?.input, oldAmount: oldValue?.money,
            currency: "QAR", nonnegative: true, upperBound: nil, key: "deduction.amount." + identity.id)
        state.result.plan.deductions.append(.init(id: identity.id, label: label.parsed, money: value.money,
            recurs: value.recurs, carriedSourceRowID: identity.carriedSourceRowID))
        install(label.input, key: "deduction.label." + identity.id, into: &state.result)
        install(value.input, key: "deduction.amount." + identity.id, into: &state.result, metadata: &state.metadata, uncertain: &state.uncertain)
        state.rowOrders[key] = identity.order; state.metadata.order[key] = identity.order
    }

    private static func decodeBill(key: String, item: CompanionMerge.Item, binding: Binding, state: inout DecodeState) throws {
        try requireKeys(item, ["identity", "label", "value", "provenance", "remark"])
        let identity: RowIdentity = try payload(item.groups["identity"])
        let label: Label = try payload(item.groups["label"])
        let value: BillValue = try payload(item.groups["value"])
        let provenance: FundingPlanValueProvenance = try payload(item.groups["provenance"])
        let remark: String = try payload(item.groups["remark"])
        guard !identity.id.isEmpty, state.rowIDs.insert(identity.id).inserted,
              let region = identity.region, ["qatar", "india"].contains(region),
              value.money.currency.code == (region == "qatar" ? "QAR" : "INR") else { throw AdapterError.structure(key) }
        let recurring = key.hasPrefix("recurring:") ? String(key.dropFirst("recurring:".count)) : nil
        if let recurring {
            guard binding.knownOccurrenceIDs.contains(recurring), binding.occurrenceRows[recurring] == identity.id else {
                throw AdapterError.unsupportedRecurringInsertion(recurring)
            }
            state.activeOccurrences.insert(recurring)
        } else { guard key == "bill:" + identity.id else { throw AdapterError.identity } }
        let previous = binding.baselineDocument[key]
        let oldIdentity: RowIdentity? = try optionalGroup(previous, "identity")
        let oldLabel: Label? = try optionalGroup(previous, "label")
        let oldValue: BillValue? = try optionalGroup(previous, "value")
        let oldProvenance: FundingPlanValueProvenance? = try optionalGroup(previous, "provenance")
        let oldRemark: String? = try optionalGroup(previous, "remark")
        try validateIdentity(identity, old: oldIdentity, collection: region, binding: binding, key: key)
        try validateLabel(label, old: oldLabel, key: "label." + identity.id, alwaysStoresRaw: false)
        try validateNumeric(value.input, amount: value.money, old: oldValue?.input, oldAmount: oldValue?.money,
            currency: value.money.currency.code, nonnegative: binding.baselineScratchpad.plan.calculationVersion == .budgetV1,
            upperBound: value.temporaryCarryBasis, key: "amount." + identity.id)
        try validateBill(value, old: oldValue, recurring: recurring != nil, binding: binding, key: key)
        if provenance != oldProvenance && provenance != .manual { throw AdapterError.sourceOwnedMutation(key + ":provenance") }
        let restoresCarry = value.temporaryCarryBasis == nil && oldValue?.temporaryCarryBasis == value.money
        if oldValue != nil, (label.parsed != oldLabel?.parsed || (value.money != oldValue?.money && !restoresCarry)), provenance != .manual {
            throw AdapterError.sourceOwnedMutation(key + ":editedValueProvenance")
        }
        if remark != oldRemark && remark.count > 240 { throw AdapterError.structure(key + ":remark") }
        let row = FundingPlanCommitment(id: identity.id, label: label.parsed, money: value.money,
            included: value.included, fundingAccountID: value.fundingAccountID, provenance: provenance,
            recurs: value.recurs, temporaryCarryBasis: value.temporaryCarryBasis,
            carriedSourceRowID: identity.carriedSourceRowID, remark: remark, dueDate: value.dueDate)
        if region == "qatar" { state.result.plan.qatarCommitments.append(row) } else { state.result.plan.indiaCommitments.append(row) }
        state.result.preReductionBasis[row.id] = value.preReductionBasis
        state.result.plan.assistance?.carriedBillDates?[row.id] = value.carriedDate
        install(label.input, key: "label." + row.id, into: &state.result)
        install(value.input, key: "amount." + row.id, into: &state.result, metadata: &state.metadata, uncertain: &state.uncertain)
        state.rowOrders[key] = identity.order; state.metadata.order[key] = identity.order
    }

    private static func decodeBalance(key: String, item: CompanionMerge.Item, binding: Binding, state: inout DecodeState) throws {
        let value: BalanceValue = try group(item, "value", keys: ["value"])
        let accountID = value.accountID
        guard key == "balance:" + accountID, binding.bankCurrencies[accountID] == value.currency else { throw AdapterError.structure(key) }
        let previous: BalanceValue? = try optionalGroup(binding.baselineDocument[key], "value")
        if let row = value.row {
            guard row.accountID == accountID, !row.id.isEmpty, state.bankIDs.insert(accountID).inserted,
                  row.nativeCurrency == value.currency,
                  row.money == nil || row.money?.currency == row.nativeCurrency,
                  let order = value.order else { throw AdapterError.structure(key) }
            if let previousRow = previous?.row {
                guard previousRow.id == row.id, previousRow.accountID == row.accountID,
                      previousRow.nativeCurrency == row.nativeCurrency, previous?.order == order else { throw AdapterError.identity }
            } else {
                guard row.provenance == .manual, row.financialBalanceDate == nil else { throw AdapterError.sourceOwnedMutation(key) }
                try validateOrder(order, rowID: row.id, collection: "balance", binding: binding, key: key)
            }
            if row.money != previous?.row?.money || row.provenance != previous?.row?.provenance || row.financialBalanceDate != previous?.row?.financialBalanceDate {
                guard row.provenance == .manual, row.financialBalanceDate == nil else { throw AdapterError.sourceOwnedMutation(key) }
            }
            if !(previous?.row == nil && row.money == nil && value.input.raw == nil && value.input.error == nil) {
                try validateNumeric(value.input, amount: row.money, old: previous?.input, oldAmount: previous?.row?.money,
                    currency: row.nativeCurrency.code, nonnegative: false, upperBound: nil, key: "balance." + accountID)
            }
            state.result.plan.balances.append(row); state.rowOrders[key] = order; state.metadata.order[key] = order
        } else {
            guard previous?.row == nil, value.order == nil else { throw AdapterError.structure(key) }
            try validateNumeric(value.input, amount: nil, old: previous?.input, oldAmount: nil,
                currency: value.currency.code, nonnegative: false, upperBound: nil, key: "balance." + accountID)
        }
        install(value.input, key: "balance." + accountID, into: &state.result, metadata: &state.metadata, uncertain: &state.uncertain)
        if value.unavailable { state.result.unavailableBalanceAccountIDs.insert(accountID) }
        else { state.result.unavailableBalanceAccountIDs.remove(accountID) }
    }

    private static func reconcileDecodeState(_ state: inout DecodeState, binding: Binding) throws {
        let allPlanRows = binding.baselineScratchpad.plan.qatarCommitments + binding.baselineScratchpad.plan.indiaCommitments
        // No UI action deletes planning-balance records. Inclusion is the existing control.
        guard Set(binding.baselineScratchpad.plan.balances.map(\.accountID)).isSubset(of: state.bankIDs) else { throw AdapterError.structure("A balance was deleted instead of excluded") }
        let removedBills = Set(allPlanRows.map(\.id)).subtracting(state.rowIDs)
        for id in removedBills {
            state.result.plan.assistance?.billFundingAccounts?[id] = nil
            state.result.plan.assistance?.carriedBillDates?[id] = nil
            for index in state.result.plan.assistance?.datedAdjustments.indices ?? 0..<0 {
                if state.result.plan.assistance?.datedAdjustments[index].replacesCommitmentID == id {
                    state.result.plan.assistance?.datedAdjustments[index].replacesCommitmentID = nil
                }
            }
        }
        // Absence is the one delete authority. There is no racing aggregate exclusion group.
        for occurrence in binding.knownOccurrenceIDs {
            if state.activeOccurrences.contains(occurrence) {
                state.result.excludedRecurringOccurrenceIDs.remove(occurrence)
            } else {
                state.result.excludedRecurringOccurrenceIDs.insert(occurrence)
                state.result.plan.assistance?.appliedRecurringIDs[occurrence] = nil
                state.result.plan.assistance?.appliedRecurringPaid?[occurrence] = nil
            }
        }
    }

    private static func finishDecodeState(_ state: inout DecodeState, binding: Binding, header: Identity) throws {
        let rowOrders = state.rowOrders
        func less(_ a: String, _ b: String) -> Bool {
            let left = rowOrders[a]!, right = rowOrders[b]!
            return left.position == right.position ? left.stableRowID < right.stableRowID : left.position < right.position
        }
        state.result.plan.deductions.sort { less("deduction:" + $0.id, "deduction:" + $1.id) }
        state.result.plan.balances.sort { less("balance:" + $0.accountID, "balance:" + $1.accountID) }
        let reverse = Dictionary(uniqueKeysWithValues: binding.occurrenceRows.map { ($0.value, $0.key) })
        func billKey(_ id: String) -> String { reverse[id].map { "recurring:" + $0 } ?? "bill:" + id }
        state.result.plan.qatarCommitments.sort { less(billKey($0.id), billKey($1.id)) }
        state.result.plan.indiaCommitments.sort { less(billKey($0.id), billKey($1.id)) }
        let allIDs = state.result.plan.deductions.map(\.id) + state.result.plan.qatarCommitments.map(\.id)
            + state.result.plan.indiaCommitments.map(\.id) + state.result.plan.balances.map(\.id)
        guard Set(allIDs).count == allIDs.count,
              state.result.hasIdentity(workspaceID: header.workspaceID, month: header.month) else { throw AdapterError.identity }
    }

    /// Concrete repository check, inside the same transaction as the kernel transition.
    /// Raw-only retention leaves canonical unchanged. Canonical publication must be the
    /// identical decoded plan, with only its explicitly supplied update instant changed.
    static func validateCommit(document: CompanionMerge.Document, against binding: Binding,
                               editor: MonthlyPlanScratchpad, metadata: Metadata,
                               canonical: FundingPlan?) throws {
        let decoded = try decode(document: document, against: binding)
        guard intentEqual(decoded.scratchpad, editor), decoded.metadata == metadata else {
            throw AdapterError.inconsistentInput("Stored editor does not match the exact merged document")
        }
        if let canonical {
            guard editor.canonical == canonical, editor.plan == canonical,
                  PlannerInputValidity.hasValidCalculation(plan: editor.plan, fieldErrors: editor.fieldErrors,
                    excludedHistoryAccountIDs: binding.excludedHistoryAccountIDs) else { throw AdapterError.bookkeeping }
        } else {
            guard editor.canonical == binding.baselineScratchpad.canonical,
                  editor.plan.updatedAtISO == binding.baselineScratchpad.plan.updatedAtISO else { throw AdapterError.bookkeeping }
        }
        let formatter = ISO8601DateFormatter()
        guard let updated = formatter.date(from: editor.plan.updatedAtISO),
              formatter.string(from: updated) == editor.plan.updatedAtISO else { throw AdapterError.bookkeeping }
        let reencoded = try encode(editor, metadata: metadata, against: binding)
        guard reencoded.document == document else { throw AdapterError.inconsistentInput("Round-trip changed merge intent") }
    }

    private static let scalarKeys = ["fixed", "variable", "deductions", "fee", "investment", "reserve"]
    private static func project(_ scratch: MonthlyPlanScratchpad, metadata: Metadata,
                                base: Binding? = nil, authorityBankCurrencies: [String: CurrencyCode]? = nil) throws -> EncodedMonth {
        var document: CompanionMerge.Document = [:], nextMetadata = Metadata()
        let applications = scratch.plan.assistance?.appliedRecurringIDs ?? [:]
        var owners: [String: String] = [:]
        for (occurrence, rowID) in applications {
            guard owners.updateValue(occurrence, forKey: rowID) == nil else { throw AdapterError.ambiguousOccurrenceOwnership(rowID) }
        }
        func numeric(_ key: String) -> NumericInput {
            let origin = metadata.origins[key] ?? .unknown
            nextMetadata.origins[key] = origin
            return NumericInput(raw: scratch.rawText[key], error: scratch.fieldErrors[key],
                untouched: scratch.untouchedZeroFields.contains(key), origin: origin)
        }
        func text(_ key: String) -> TextInput { .init(raw: scratch.rawText[key], error: scratch.fieldErrors[key]) }
        var nextPositions: [String: Int] = [:]
        if let base {
            for (key, order) in base.baselineMetadata.order {
                let collection = try collectionName(key: key, item: base.baselineDocument[key])
                guard order.position < Int.max else { throw AdapterError.invalidOrder(key) }
                nextPositions[collection] = max(nextPositions[collection] ?? 0, order.position + 1)
            }
        }
        func order(_ key: String, id: String, collection: String, index: Int) throws -> OrderKey {
            if let retained = metadata.order[key] ?? base?.baselineMetadata.order[key] {
                guard retained.position >= 0, retained.stableRowID == id else { throw AdapterError.invalidOrder(key) }
                nextMetadata.order[key] = retained
                guard retained.position < Int.max else { throw AdapterError.invalidOrder(key) }
                nextPositions[collection] = max(nextPositions[collection] ?? 0, retained.position + 1)
                return retained
            }
            let position = base == nil ? index : nextPositions[collection] ?? 0
            guard position < Int.max else { throw AdapterError.invalidOrder(key) }
            let result = OrderKey(position: position, stableRowID: id)
            nextMetadata.order[key] = result; nextPositions[collection] = position + 1
            return result
        }
        for field in scalarKeys {
            let value = scalar(field, in: scratch.plan, input: numeric(field))
            document["scalar:" + field] = CompanionMerge.Item(["value": try json(value)])
        }
        let fx = FX(mode: scratch.plan.referenceMode, manual: scratch.plan.planningFX,
            legacy: scratch.plan.alDarReference,
            rate: numeric("fx.rate"), date: text("fx.date"))
        document["fx"] = CompanionMerge.Item(["value": try json(fx)])
        for (index, row) in scratch.plan.deductions.enumerated() {
            let key = "deduction:" + row.id
            guard document[key] == nil else { throw AdapterError.structure("Duplicate " + key) }
            document[key] = CompanionMerge.Item([
                "identity": try json(RowIdentity(id: row.id, region: nil, carriedSourceRowID: row.carriedSourceRowID,
                    order: order(key, id: row.id, collection: "deduction", index: index))),
                "label": try json(Label(parsed: row.label, input: text("deduction.label." + row.id))),
                "value": try json(DeductionValue(money: row.money, recurs: row.recurs, input: numeric("deduction.amount." + row.id)))])
        }
        for (region, rows) in [("qatar", scratch.plan.qatarCommitments), ("india", scratch.plan.indiaCommitments)] {
            for (index, row) in rows.enumerated() {
                let key = owners[row.id].map { "recurring:" + $0 } ?? "bill:" + row.id
                guard document[key] == nil else { throw AdapterError.structure("Duplicate " + key) }
                document[key] = CompanionMerge.Item([
                    "identity": try json(RowIdentity(id: row.id, region: region, carriedSourceRowID: row.carriedSourceRowID,
                        order: order(key, id: row.id, collection: region, index: index))),
                    "label": try json(Label(parsed: row.label, input: text("label." + row.id))),
                    "value": try json(BillValue(money: row.money, included: row.included, fundingAccountID: row.fundingAccountID,
                        recurs: row.recurs, temporaryCarryBasis: row.temporaryCarryBasis, dueDate: row.dueDate,
                        preReductionBasis: scratch.preReductionBasis[row.id], carriedDate: scratch.plan.assistance?.carriedBillDates?[row.id],
                        input: numeric("amount." + row.id))),
                    "provenance": try json(row.provenance), "remark": try json(row.remark)])
            }
        }
        guard Set(applications.values).isSubset(of: Set((scratch.plan.qatarCommitments + scratch.plan.indiaCommitments).map(\.id))) else {
            throw AdapterError.structure("Applied occurrence has no bill")
        }
        for (index, row) in scratch.plan.balances.enumerated() {
            let key = "balance:" + row.accountID
            guard document[key] == nil else { throw AdapterError.structure("Duplicate " + key) }
            document[key] = CompanionMerge.Item(["value": try json(BalanceValue(accountID: row.accountID, currency: row.nativeCurrency, row: row,
                input: numeric("balance." + row.accountID), unavailable: scratch.unavailableBalanceAccountIDs.contains(row.accountID),
                order: order(key, id: row.id, collection: "balance", index: index)))])
        }
        let representedBanks = Set(scratch.plan.balances.map(\.accountID))
        let rawOnlyBanks = Set(scratch.rawText.keys.filter { $0.hasPrefix("balance.") }.map { String($0.dropFirst("balance.".count)) })
            .union(scratch.fieldErrors.keys.filter { $0.hasPrefix("balance.") }.map { String($0.dropFirst("balance.".count)) })
            .union(scratch.unavailableBalanceAccountIDs)
            .subtracting(representedBanks)
        for accountID in rawOnlyBanks {
            guard let currency = base?.bankCurrencies[accountID] ?? authorityBankCurrencies?[accountID] else { throw AdapterError.structure("Unknown raw-only balance account") }
            document["balance:" + accountID] = CompanionMerge.Item(["value": try json(BalanceValue(
                accountID: accountID, currency: currency, row: nil, input: numeric("balance." + accountID),
                unavailable: scratch.unavailableBalanceAccountIDs.contains(accountID), order: nil))])
        }
        guard Set(metadata.origins.keys).isSubset(of: Set(nextMetadata.origins.keys)),
              Set(metadata.order.keys).isSubset(of: Set(nextMetadata.order.keys)) else {
            throw AdapterError.structure("Orphan lexical/order metadata")
        }
        return EncodedMonth(document: document, metadata: nextMetadata)
    }

    private static func addingIdentity(to document: CompanionMerge.Document, scope: CompanionMerge.SyncScope,
                                      plan: FundingPlan) throws -> CompanionMerge.Document {
        var result = document
        result["identity"] = CompanionMerge.Item(["binding": try json(Identity(format: 1, scope: scope,
            workspaceID: plan.workspaceID, planID: plan.id, month: plan.month.canonical, calculationVersion: plan.calculationVersion))])
        return result
    }
    private static func scalar(_ field: String, in plan: FundingPlan, input: NumericInput) -> Scalar {
        switch field {
        case "fixed": return Scalar(money: plan.expectedFixedEarnings, provenance: plan.expectedFixedProvenance, input: input)
        case "variable": return Scalar(money: plan.expectedVariableEarnings, provenance: plan.expectedVariableProvenance, input: input)
        case "deductions": return Scalar(money: plan.expectedDeductions, provenance: plan.expectedDeductionsProvenance, input: input)
        case "fee": return Scalar(money: plan.configuredTransferFee, provenance: plan.configuredTransferFeeProvenance, input: input)
        case "investment": return Scalar(money: plan.plannedInvestment, provenance: plan.plannedInvestmentProvenance, input: input)
        default: return Scalar(money: plan.keepInCBQ, provenance: nil, input: input)
        }
    }
    private static func setScalar(_ scalar: Scalar, field: String, plan: inout FundingPlan) {
        switch field {
        case "fixed": plan.expectedFixedEarnings = scalar.money!; plan.expectedFixedProvenance = scalar.provenance!
        case "variable": plan.expectedVariableEarnings = scalar.money!; plan.expectedVariableProvenance = scalar.provenance!
        case "deductions": plan.expectedDeductions = scalar.money!; plan.expectedDeductionsProvenance = scalar.provenance!
        case "fee": plan.configuredTransferFee = scalar.money!; plan.configuredTransferFeeProvenance = scalar.provenance!
        case "investment": plan.plannedInvestment = scalar.money!; plan.plannedInvestmentProvenance = scalar.provenance!
        default: plan.keepInCBQ = scalar.money
        }
    }
    private static func intentEqual(_ a: MonthlyPlanScratchpad, _ b: MonthlyPlanScratchpad) -> Bool {
        var left = a, right = b
        left.canonical = nil; right.canonical = nil
        left.plan.updatedAtISO = ""; right.plan.updatedAtISO = ""
        return left == right
    }
    private static func clear(_ key: String, from scratch: inout MonthlyPlanScratchpad) {
        scratch.rawText[key] = nil; scratch.fieldErrors[key] = nil; scratch.untouchedZeroFields.remove(key)
    }
    private static func install(_ input: NumericInput, key: String, into scratch: inout MonthlyPlanScratchpad,
                                metadata: inout Metadata, uncertain: inout Set<String>) {
        scratch.rawText[key] = input.raw; scratch.fieldErrors[key] = input.error
        if input.untouched { scratch.untouchedZeroFields.insert(key) }
        metadata.origins[key] = input.origin
        if input.raw != nil, input.origin == .unknown { uncertain.insert(key) }
    }
    private static func install(_ input: TextInput, key: String, into scratch: inout MonthlyPlanScratchpad) {
        scratch.rawText[key] = input.raw; scratch.fieldErrors[key] = input.error
    }
    private static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    private static func payload<T: Codable>(_ value: String?) throws -> T {
        guard let value else { throw AdapterError.structure("Missing group") }
        let result = try JSONDecoder().decode(T.self, from: Data(value.utf8))
        guard try json(result) == value else { throw AdapterError.structure("Noncanonical or unrecognized group fields") }
        return result
    }
    private static func requireKeys(_ item: CompanionMerge.Item, _ keys: Set<String>) throws {
        guard Set(item.groups.keys) == keys else { throw AdapterError.structure("Wrong group set") }
    }
    private static func group<T: Codable>(_ item: CompanionMerge.Item?, _ key: String, keys: Set<String>) throws -> T {
        guard let item else { throw AdapterError.structure("Missing item") }
        try requireKeys(item, keys); return try payload(item.groups[key])
    }
    private static func optionalGroup<T: Codable>(_ item: CompanionMerge.Item?, _ key: String) throws -> T? {
        guard let item else { return nil }; return try payload(item.groups[key])
    }

    private static func validateOccurrenceID(_ id: String) throws {
        guard !id.isEmpty else { throw AdapterError.structure("Empty recurring occurrence identity") }
    }
    private static func collectionName(key: String, item: CompanionMerge.Item?) throws -> String {
        if key.hasPrefix("deduction:") { return "deduction" }
        if key.hasPrefix("balance:") { return "balance" }
        if key.hasPrefix("bill:") || key.hasPrefix("recurring:") {
            guard let identity: RowIdentity = try optionalGroup(item, "identity") else { throw AdapterError.structure(key) }
            guard let region = identity.region, ["qatar", "india"].contains(region) else { throw AdapterError.structure(key) }
            return region
        }
        throw AdapterError.structure(key)
    }
    private static func validateOrder(_ order: OrderKey, rowID: String, collection: String,
                                      binding: Binding, key: String) throws {
        guard order.position >= 0, order.position < Int.max, order.stableRowID == rowID else { throw AdapterError.invalidOrder(key) }
        var maximum = -1
        for (oldKey, oldOrder) in binding.baselineMetadata.order {
            if try collectionName(key: oldKey, item: binding.baselineDocument[oldKey]) == collection {
                maximum = max(maximum, oldOrder.position)
            }
        }
        guard order.position > maximum else { throw AdapterError.invalidOrder(key) }
    }
    private static func validateIdentity(_ identity: RowIdentity, old: RowIdentity?, collection: String,
                                         binding: Binding, key: String) throws {
        if let old { guard identity == old else { throw AdapterError.identity }; return }
        guard identity.carriedSourceRowID == nil else { throw AdapterError.sourceOwnedMutation(key) }
        let existingIDs = Set((binding.baselineScratchpad.plan.qatarCommitments + binding.baselineScratchpad.plan.indiaCommitments).map(\.id))
            .union(binding.baselineScratchpad.plan.deductions.map(\.id)).union(binding.baselineScratchpad.plan.balances.map(\.id))
        guard !existingIDs.contains(identity.id) else { throw AdapterError.identity }
        try validateOrder(identity.order, rowID: identity.id, collection: collection, binding: binding, key: key)
    }
    private static func validateNumeric(_ input: NumericInput, amount: Money?, old: NumericInput?, oldAmount: Money?,
                                        currency: String, nonnegative: Bool, upperBound: Money?, key: String) throws {
        if input == old, amount == oldAmount { return }
        guard let locale = input.origin.locale, let raw = input.raw else { throw AdapterError.unknownEditedLocale(key) }
        let parsed = try? PlannerInputCodec.money(raw, currency: currency, locale: locale)
        let valid = parsed.map { (!nonnegative || $0.amount >= 0) && (upperBound.map { $0.currency.code == currency && parsed!.amount <= $0.amount } ?? true) } ?? false
        if valid {
            guard amount == parsed, input.error == nil else { throw AdapterError.inconsistentInput(key) }
        } else {
            // A pending snapshot may contain several edits: the last valid parsed
            // value can differ from the common ancestor while current raw is incomplete.
            guard input.error?.isEmpty == false,
                  amount == nil || amount?.currency.code == currency else { throw AdapterError.inconsistentInput(key) }
        }
        if input.untouched {
            guard amount?.amount == 0, parsed?.amount == 0,
                  old == nil || old?.untouched == true else { throw AdapterError.inconsistentInput(key + ":untouched") }
        }
    }
    private static func validateLabel(_ value: Label, old: Label?, key: String, alwaysStoresRaw: Bool) throws {
        if value == old { return }
        guard let raw = value.input.raw else { throw AdapterError.inconsistentInput(key) }
        let valid = !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && raw.count <= 240
        if valid {
            guard value.parsed == raw, value.input.error == nil else { throw AdapterError.inconsistentInput(key) }
        } else {
            guard value.input.error?.isEmpty == false,
                  alwaysStoresRaw ? value.parsed == raw : (!value.parsed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.parsed.count <= 240) else { throw AdapterError.inconsistentInput(key) }
        }
    }
    private static func validateFX(_ value: FX, old: FX, key: String, version: FundingPlanCalculationVersion) throws {
        if value == old { return }
        guard value.legacy == nil else { throw AdapterError.sourceOwnedMutation(key + ":legacy") }
        if value.mode == .alDar {
            guard version == .budgetV1, value.manual == nil, value.rate.raw == "", value.date.raw == "",
                  value.rate.error == nil, value.date.error == nil else { throw AdapterError.inconsistentInput(key) }
            return
        }
        guard let raw = value.rate.raw, let dateRaw = value.date.raw else { throw AdapterError.inconsistentInput(key) }
        let rate: Decimal?
        if let locale = value.rate.origin.locale { rate = try? PlannerInputCodec.rate(raw, locale: locale) }
        else {
            guard value.rate == old.rate else { throw AdapterError.unknownEditedLocale(key) }
            rate = old.manual?.inrPerQAR
        }
        let date = try? StatementDate(canonical: dateRaw)
        if raw.isEmpty && dateRaw.isEmpty {
            guard value.manual == nil, value.date.error == nil,
                  version == .legacy ? value.rate.error == nil : value.rate.error?.isEmpty == false else { throw AdapterError.inconsistentInput(key) }
            return
        }
        guard (date != nil) == (value.date.error == nil) else { throw AdapterError.inconsistentInput(key + ":dateError") }
        if value.rate.origin.locale != nil {
            guard (rate != nil) == (value.rate.error == nil) else { throw AdapterError.inconsistentInput(key + ":rateError") }
        }
        if let rate, let date, value.rate.error == nil, value.date.error == nil {
            guard value.manual == (try? FundingPlanFX(inrPerQAR: rate, observationDate: date)) else { throw AdapterError.inconsistentInput(key) }
        } else {
            guard value.manual == nil, (rate != nil || value.rate.error?.isEmpty == false),
                  (date != nil || value.date.error?.isEmpty == false),
                  value.rate.error != nil || value.date.error != nil else { throw AdapterError.inconsistentInput(key) }
        }
    }
    private static func validateBill(_ value: BillValue, old: BillValue?, recurring: Bool,
                                     binding: Binding, key: String) throws {
        if let account = value.fundingAccountID {
            guard binding.fundingAccountIDs.contains(account) else { throw AdapterError.structure(key + ":account") }
        }
        if recurring, value.fundingAccountID != old?.fundingAccountID { throw AdapterError.sourceOwnedMutation(key + ":recurringAccount") }
        if value.dueDate != old?.dueDate {
            guard binding.baselineScratchpad.plan.calculationVersion == .budgetV1, value.carriedDate == nil else { throw AdapterError.inconsistentInput(key + ":date") }
            if recurring {
                guard let date = value.dueDate, binding.baselineScratchpad.plan.includesRecurring(date) else { throw AdapterError.inconsistentInput(key + ":date") }
            }
        } else if value.carriedDate != old?.carriedDate, value.carriedDate != nil { throw AdapterError.sourceOwnedMutation(key + ":carriedDate") }
        for basis in [value.temporaryCarryBasis, value.preReductionBasis].compactMap({ $0 }) {
            guard basis.currency == value.money.currency, basis.amount >= 0 else { throw AdapterError.inconsistentInput(key + ":basis") }
        }
        if !value.recurs, value.temporaryCarryBasis != nil || value.preReductionBasis != nil { throw AdapterError.inconsistentInput(key + ":recurs") }
        if let basis = value.temporaryCarryBasis {
            guard value.money.amount <= basis.amount else { throw AdapterError.inconsistentInput(key + ":temporaryBasis") }
        }
        if value.preReductionBasis != nil, value.temporaryCarryBasis != nil { throw AdapterError.inconsistentInput(key + ":duplicateBasis") }

    }

    /// Metadata is carried inside canonical groups and therefore uses the same merge result.
    /// Full trust requires decode(against:) or restoreBinding, never this extraction alone.
    static func metadata(in document: CompanionMerge.Document) throws -> Metadata {
        var result = Metadata()
        for field in scalarKeys {
            let value: Scalar = try group(document["scalar:" + field], "value", keys: ["value"])
            result.origins[field] = value.input.origin
        }
        let fx: FX = try group(document["fx"], "value", keys: ["value"])
        result.origins["fx.rate"] = fx.rate.origin
        for (key, item) in document {
            if key.hasPrefix("deduction:") {
                let identity: RowIdentity = try payload(item.groups["identity"])
                let value: DeductionValue = try payload(item.groups["value"])
                result.origins["deduction.amount." + identity.id] = value.input.origin; result.order[key] = identity.order
            } else if key.hasPrefix("bill:") || key.hasPrefix("recurring:") {
                let identity: RowIdentity = try payload(item.groups["identity"])
                let value: BillValue = try payload(item.groups["value"])
                result.origins["amount." + identity.id] = value.input.origin; result.order[key] = identity.order
            } else if key.hasPrefix("balance:") {
                let value: BalanceValue = try group(item, "value", keys: ["value"])
                result.origins["balance." + value.accountID] = value.input.origin; result.order[key] = value.order
            }
        }
        return result
    }
    static func restoreBinding(scope: CompanionMerge.SyncScope, scratchpad: MonthlyPlanScratchpad,
                               document: CompanionMerge.Document, bankCurrencies: [String: CurrencyCode],
                               fundingAccountIDs: Set<String>, excludedHistoryAccountIDs: Set<String>,
                               availableAlDarQuote: AlDarReferenceQuote? = nil) throws -> Binding {
        let result = try makeBinding(scope: scope, scratchpad: scratchpad, metadata: metadata(in: document),
            bankCurrencies: bankCurrencies, fundingAccountIDs: fundingAccountIDs,
            excludedHistoryAccountIDs: excludedHistoryAccountIDs, availableAlDarQuote: availableAlDarQuote)
        guard result.baselineDocument == document else { throw AdapterError.inconsistentInput("Durable editor and sync document diverged") }
        return result
    }
    enum BindingChange: Equatable, Sendable { case identical, dependenciesOnly, requiresMerge, incompatible }
    static func classifyBindingChange(from old: Binding, to new: Binding) -> BindingChange {
        let a = old.baselineScratchpad.plan, b = new.baselineScratchpad.plan
        guard old.scope == new.scope, a.workspaceID == b.workspaceID, a.id == b.id,
              a.month == b.month, a.calculationVersion == b.calculationVersion else { return .incompatible }
        if old.baselineDocument != new.baselineDocument { return .requiresMerge }
        return old == new ? .identical : .dependenciesOnly
    }
    /// Reconstruct phone pending intent over a new source context without seeding or
    /// rewriting the pending document. A Mac intent edit still needs the kernel merge.
    static func dependencyRebind(document: CompanionMerge.Document, from old: Binding, to new: Binding) throws -> DecodedMonth {
        guard [.identical, .dependenciesOnly].contains(classifyBindingChange(from: old, to: new)) else { throw AdapterError.identity }
        _ = try decode(document: document, against: old)
        let result = try decode(document: document, against: new)
        guard try encode(result.scratchpad, metadata: result.metadata, against: new).document == document else { throw AdapterError.inconsistentInput("Dependency refresh changed pending intent") }
        return result
    }
}
