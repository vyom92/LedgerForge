import CryptoKit
import Foundation

/// A month baseline captured with the editor's original durable contents.
/// The provider identity prevents a revision from an earlier open or restored
/// database from being accepted merely because its counter happens to match.
nonisolated public enum PlanningSaveOrigin: String, Sendable {
    case unknown, manual, chatgpt
}

nonisolated public struct PlanningMonthRevision: Equatable, Sendable {
    public let workspaceID: String
    public let month: String
    public let counter: Int64
    public let providerID: String
    public let latestOrigin: PlanningSaveOrigin

    public init(workspaceID: String, month: String, counter: Int64, providerID: String,
                latestOrigin: PlanningSaveOrigin) {
        self.workspaceID = workspaceID; self.month = month; self.counter = counter
        self.providerID = providerID; self.latestOrigin = latestOrigin
    }
}

nonisolated public struct PlanningWriteSnapshot: Sendable {
    public let plan: FundingPlanDTO?
    public let scratchpad: MonthlyPlanScratchpadDTO?
    public let monthRevision: PlanningMonthRevision
    /// Nil when no canonical plan exists. This never authorizes creating one.
    public let writeRevision: String?
    public let financial: FinancialIntelligenceSnapshot?
    public let accounts: [AccountDTO]
    public let salaryStatements: [SalaryStatementDTO]
    public let productLabels: [String: [String]]
    public let receiptTransactions: [TransactionDTO]
    public let activeCompanionSession: CompanionSyncSessionDTO?
    public let companionMonth: CompanionMonthSyncDTO?
}

nonisolated public struct PlanningChangeCommitRequest: Sendable {
    public let requestID: String
    public let requestDigest: String
    public let workspaceID: String
    public let month: String
    public let planID: String
    public let expectedWriteRevision: String
    public let committedAtISO: String

    public init(requestID: String, requestDigest: String, workspaceID: String, month: String,
                planID: String, expectedWriteRevision: String, committedAtISO: String) {
        self.requestID = requestID; self.requestDigest = requestDigest; self.workspaceID = workspaceID
        self.month = month; self.planID = planID; self.expectedWriteRevision = expectedWriteRevision
        self.committedAtISO = committedAtISO
    }
}

nonisolated public struct PlanningChangeCommitCandidate: Sendable {
    public let plan: FundingPlanDTO
    public let scratchpad: MonthlyPlanScratchpadDTO?
    /// Bounded successful-result fields. The repository owns outcome/revision.
    public let resultJSON: String
    public let companionRequest: CompanionMonthCommitRequest?

    public init(plan: FundingPlanDTO, scratchpad: MonthlyPlanScratchpadDTO?, resultJSON: String,
                companionRequest: CompanionMonthCommitRequest? = nil) {
        self.plan = plan; self.scratchpad = scratchpad; self.resultJSON = resultJSON
        self.companionRequest = companionRequest
    }
}

nonisolated public struct PlanningRequestReceipt: Equatable, Sendable {
    public enum Outcome: String, Sendable { case saved, noChange = "no_change" }
    public let requestID: String
    public let requestDigest: String
    public let workspaceID: String
    public let month: String
    public let planID: String
    public let committedRevision: Int64
    public let committedAtISO: String
    public let outcome: Outcome
    public let resultJSON: String
    public var committedMonthRevision: String { String(committedRevision) }
}

nonisolated public enum PlanningWriteError: Error, Equatable {
    case unavailable
    case staleRevision
    case unavailableContext
    case unsupportedPlan
    case requestIDConflict
    case invalidReceipt
    case exhaustedRevision
    case invalidCandidate
    case pairedMonthRequiresAtomicWrite
}

/// The fingerprint is a write precondition, never a display snapshot identity.
/// Values are length-framed so concatenation cannot alias different fields.
nonisolated enum PlanningWriteFingerprint {
    static func make(_ snapshot: PlanningWriteSnapshot, companion: [CompanionMonthSyncDTO] = []) throws -> String? {
        guard let plan = snapshot.plan, snapshot.financial != nil else { return nil }
        var values: [String] = [
            snapshot.monthRevision.providerID,
            snapshot.monthRevision.workspaceID,
            snapshot.monthRevision.month,
            String(snapshot.monthRevision.counter),
            plan.id,
            try canonical(plan.allocationCalculationInput()),
            snapshot.scratchpad?.stateJSON ?? "<absent>"
        ]
        // The selectors include membership. A newly qualifying receipt or
        // designation changes the fingerprint even if old rows are untouched.
        values += snapshot.accounts.sorted { $0.id < $1.id }.map { account in
            [account.id, account.workspaceId, account.nativeCurrency, account.accountType ?? "",
             account.closedAtISO ?? "", account.institutionId ?? ""].joined(separator: "\u{0}")
        }
        let linkedStatementID = plan.assistance?.payslipFunding?.statementID
        let priorMonth = previousMonth(before: snapshot.monthRevision.month)
        values += snapshot.salaryStatements.filter {
            $0.financialPeriodISO.hasPrefix(snapshot.monthRevision.month) ||
            $0.financialPeriodISO.hasPrefix(priorMonth) || $0.id == linkedStatementID
        }.sorted { $0.id < $1.id }.map { statement in
            var parts = [statement.id, statement.workspaceId, statement.documentId,
                         statement.importSessionId, statement.sourceFingerprintAlgorithm,
                         statement.sourceFingerprintDigest, statement.financialPeriodISO,
                         statement.nativeCurrency, statement.printedEarningsDecimal,
                         statement.printedDeductionsDecimal ?? "", statement.printedNetDecimal,
                         statement.printedPaymentDecimal]
            for component in statement.components.sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
                parts += [component.id, component.sideCode, String(component.sourceOrdinal),
                          component.sourceLabel, component.amountCurrency, component.amountDecimal]
            }
            return parts.joined(separator: "\u{0}")
        }
        values += snapshot.receiptTransactions.sorted { $0.id < $1.id }.map { transaction in
            var parts = [transaction.id, transaction.workspaceId, transaction.accountId ?? "",
                         transaction.postedDateISO, transaction.financialDateRole,
                         transaction.statementTimezoneEvidence, transaction.description ?? "",
                         transaction.nativeCurrency, transaction.amountDecimal, transaction.direction,
                         transaction.isTrusted ? "1" : "0"]
            for raw in transaction.rawRows.sorted(by: { $0.id < $1.id }) {
                parts += [raw.id, raw.normalizedRowId, raw.contributionType ?? "",
                          raw.sourceOrdinal.map(String.init) ?? "", raw.normalizedRecordDigest ?? "",
                          raw.normalizedDocumentId ?? "", raw.parserProfileId ?? "",
                          raw.parserProfileVersion ?? ""]
            }
            return parts.joined(separator: "\u{0}")
        }
        if let financial = snapshot.financial {
            let nextMonth = nextMonth(after: snapshot.monthRevision.month)
            values += try financial.recurring.filter { $0.isEnabled && ($0.endsOn == nil || $0.endsOn! >= snapshot.monthRevision.month) }
                .sorted { $0.id < $1.id }.map(canonical)
            values += try financial.occurrences.filter {
                $0.dueDate.hasPrefix(snapshot.monthRevision.month) || $0.dueDate.hasPrefix(nextMonth)
            }.sorted { $0.id < $1.id }.map(canonical)
            values += try financial.reserves.sorted { $0.id < $1.id }.map(canonical)
            values += try financial.salaries.filter { $0.targetMonth == snapshot.monthRevision.month }
                .sorted { $0.id < $1.id }.map(canonical)
            if let preferences = financial.preferences {
                values.append(preferences.retentionAccountID ?? "")
                values.append(preferences.salaryAssistanceEnabled ? "1" : "0")
                values.append(preferences.salaryISPEnabled ? "1" : "0")
                values += preferences.salaryRuleIDs.sorted()
                values += (preferences.excludedPlanningAccountIDs ?? []).sorted()
                if let decisions = preferences.recurringCandidateDecisions {
                    values.append(try canonical(decisions))
                }
            }
        }
        for id in snapshot.productLabels.keys.sorted() {
            values.append(id)
            values += (snapshot.productLabels[id] ?? []).sorted()
        }
        if let session = snapshot.activeCompanionSession {
            values += [session.sessionID, session.workspaceID, session.activationEpoch,
                       session.phoneID, String(session.protocolVersion), session.disposition]
        }
        values += companion.sorted { $0.sessionID < $1.sessionID }.map {
            [$0.sessionID, $0.month, String($0.stateRevision), $0.stateJSON].joined(separator: "\u{0}")
        }
        var bytes = Data()
        for value in values {
            let part = Data(value.utf8)
            var length = UInt64(part.count).bigEndian
            withUnsafeBytes(of: &length) { bytes.append(contentsOf: $0) }
            bytes.append(part)
        }
        return "planning-write-v1:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func nextMonth(after month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let number = Int(parts[1]) else { return month }
        return String(format: "%04d-%02d", number == 12 ? year + 1 : year, number == 12 ? 1 : number + 1)
    }

    private static func previousMonth(before month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let number = Int(parts[1]) else { return month }
        return String(format: "%04d-%02d", number == 1 ? year - 1 : year, number == 1 ? 12 : number - 1)
    }

    private static func canonical<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let normalized = normalize(object)
        let canonical = try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys, .fragmentsAllowed])
        guard let text = String(data: canonical, encoding: .utf8) else { throw PlanningWriteError.unavailableContext }
        return text
    }

    private static func normalize(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues(normalize)
        }
        // Domain arrays carry source order and sometimes multiplicity. The only
        // fingerprinted sets (preference IDs) are projected as sorted strings
        // above, so preserve every Codable array's original order here.
        if let array = value as? [Any] { return array.map(normalize) }
        return value
    }

    static func validateRequest(_ request: PlanningChangeCommitRequest) throws {
        guard let uuid = UUID(uuidString: request.requestID),
              uuid.uuidString.lowercased() == request.requestID,
              request.requestDigest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              request.expectedWriteRevision.range(of: "^planning-write-v1:[0-9a-f]{64}$", options: .regularExpression) != nil,
              !request.workspaceID.isEmpty, !request.planID.isEmpty,
              (try? SelectedStatementMonth(canonical: request.month))?.canonical == request.month else {
            throw PlanningWriteError.invalidCandidate
        }
    }

    static func validateCandidate(_ candidate: PlanningChangeCommitCandidate, request: PlanningChangeCommitRequest) throws {
        guard candidate.plan.id == request.planID,
              candidate.plan.workspaceId == request.workspaceID,
              candidate.plan.planMonthISO == request.month,
              candidate.scratchpad?.workspaceID == request.workspaceID || candidate.scratchpad == nil,
              candidate.scratchpad?.month == request.month || candidate.scratchpad == nil,
              !candidate.resultJSON.isEmpty,
              candidate.resultJSON.utf8.count <= 65_536,
              let data = candidate.resultJSON.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw PlanningWriteError.invalidCandidate
        }
        if let raw = candidate.scratchpad {
            let scratch = try MonthlyPlanScratchpad.decode(raw)
            guard scratch.canonical == scratch.plan,
                  try scratch.plan.persistenceDTO() == candidate.plan else { throw PlanningWriteError.invalidCandidate }
        }
    }
}
