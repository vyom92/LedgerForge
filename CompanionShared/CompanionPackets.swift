import Foundation

/// Shared operational packet types, compiled in both Mac and iPhone targets.
/// Envelope session/activation and the installation identity fence these values.
nonisolated struct CompanionPlannerAccount: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let context: String
    let currency: CurrencyCode
    let isHistoryOnly: Bool
}

nonisolated struct CompanionMonthEditorContext: Codable, Equatable, Sendable {
    let accounts: [CompanionPlannerAccount]
    let relatedCards: [CompanionPlannerAccount]
    /// Display-only retained account names; never an eligibility or write-authority list.
    var displayAccounts: [CompanionPlannerAccount]? = nil
    let allHistoryAccountIDs: Set<String>
    let manuallyExcludedPlanningAccountIDs: Set<String>
    let receipt: MonthlyPlanSyncAdapter.ReceiptProjection?
    let receiptBasis: PlannerSalaryReceiptBasis?
    let latestAlDarQuote: AlDarReferenceQuote?
    /// Mac-supplied source-basis wording; distinct from snapshot/check timestamps.
    let sourceContext: String
}

nonisolated struct CompanionMonthAnchor: Codable, Equatable, Sendable {
    let scratchpad: MonthlyPlanScratchpad
    let metadata: MonthlyPlanSyncAdapter.Metadata
    let bankCurrencies: [String: CurrencyCode]
    let fundingAccountIDs: Set<String>
    let excludedHistoryAccountIDs: Set<String>
    let context: CompanionMonthEditorContext

    func binding(for scope: CompanionMerge.SyncScope) throws -> MonthlyPlanSyncAdapter.Binding {
        if let basis = context.receiptBasis {
            guard basis.workspaceID == scratchpad.plan.workspaceID, basis.month == scratchpad.plan.month else {
                throw CompanionPacketError.invalid("The salary receipt basis belongs to a different month or workspace.")
            }
        }
        guard context.receipt == nil || context.receiptBasis != nil else {
            throw CompanionPacketError.invalid("The saved salary receipt has no retained basis.")
        }
        if let labels = context.displayAccounts {
            guard Set(labels.map(\.id)).count == labels.count, labels.allSatisfy({ !$0.id.isEmpty }) else {
                throw CompanionPacketError.invalid("The retained account labels are inconsistent.")
            }
        }
        guard context.accounts.allSatisfy({ !$0.id.isEmpty }),
              Set(context.accounts.map(\.id)).count == context.accounts.count,
              Set(context.relatedCards.map(\.id)).count == context.relatedCards.count,
              context.relatedCards.allSatisfy({ !$0.id.isEmpty }),
              context.accounts.allSatisfy({ bankCurrencies[$0.id] == $0.currency }),
              Set(context.accounts.map(\.id)) == Set(bankCurrencies.keys),
              excludedHistoryAccountIDs.isSubset(of: context.allHistoryAccountIDs),
              context.accounts.allSatisfy({ $0.isHistoryOnly == context.allHistoryAccountIDs.contains($0.id) }) else {
            throw CompanionPacketError.invalid("Monthly account context is inconsistent.")
        }
        return try MonthlyPlanSyncAdapter.makeBinding(scope: scope, scratchpad: scratchpad,
            metadata: metadata, bankCurrencies: bankCurrencies,
            fundingAccountIDs: fundingAccountIDs, excludedHistoryAccountIDs: excludedHistoryAccountIDs,
            availableAlDarQuote: context.latestAlDarQuote)
    }
}

nonisolated struct CompanionMacMonthPacket: Codable, Equatable, Sendable {
    let scope: CompanionMerge.SyncScope
    /// Original revision-zero agreed base, retained across later Mac input edits.
    let initialDocument: CompanionMerge.Document
    /// Actual current completedSequence, not a sticky "was initially zero" flag.
    let bootstrapCompletedSequence: UInt64
    let bootstrap: CompanionMonthAnchor
    let current: CompanionMonthAnchor
    let currentDocument: CompanionMerge.Document
    let advertisement: CompanionMerge.MacAdvertisement
    let reply: CompanionMerge.Reply?
    /// Frozen context of reply.result, never reconstructed from later Mac state.
    let replyAnchor: CompanionMonthAnchor?

    /// Build and validate a packet from retained anchors without projecting its
    /// bootstrap twice. The binding never escapes to a caller-supplied validator.
    static func validated(scope: CompanionMerge.SyncScope, bootstrapCompletedSequence: UInt64,
                          bootstrap: CompanionMonthAnchor, current: CompanionMonthAnchor,
                          currentDocument: CompanionMerge.Document,
                          advertisement: CompanionMerge.MacAdvertisement,
                          reply: CompanionMerge.Reply?, replyAnchor: CompanionMonthAnchor?) throws -> Self {
        let initialBinding = try bootstrap.binding(for: scope)
        let packet = Self(scope: scope, initialDocument: initialBinding.baselineDocument,
            bootstrapCompletedSequence: bootstrapCompletedSequence, bootstrap: bootstrap, current: current,
            currentDocument: currentDocument, advertisement: advertisement, reply: reply, replyAnchor: replyAnchor)
        try packet.validate(initialBinding: initialBinding)
        return packet
    }

    func validate() throws {
        try validate(initialBinding: bootstrap.binding(for: scope))
    }

    private func validate(initialBinding: MonthlyPlanSyncAdapter.Binding) throws {
        try scope.validate()
        guard (try? SelectedStatementMonth(canonical: scope.month)) != nil,
              advertisement.format == 1, advertisement.scope == scope else {
            throw CompanionPacketError.invalid("Monthly scope or advertisement is invalid.")
        }
        let currentBinding = try current.binding(for: scope)
        guard initialBinding.baselineDocument == initialDocument,
              currentBinding.baselineDocument == currentDocument else {
            throw CompanionPacketError.invalid("Monthly documents do not match their retained context.")
        }
        if let reply {
            try reply.validate()
            guard reply.proposal.scope == scope, reply.proposal.sequence == bootstrapCompletedSequence,
                  advertisement.revision >= reply.resultRevision, let replyAnchor,
                  try replyAnchor.binding(for: scope).baselineDocument == reply.result else {
                throw CompanionPacketError.invalid("The Mac receipt does not match its frozen monthly context.")
            }
            if advertisement.revision == reply.resultRevision, currentDocument != reply.result {
                throw CompanionPacketError.invalid("One Mac revision has two different monthly documents.")
            }
        } else {
            guard bootstrapCompletedSequence == 0, replyAnchor == nil else {
                throw CompanionPacketError.invalid("The completed monthly receipt is missing.")
            }
        }
        if advertisement.revision == 0, currentDocument != initialDocument {
            throw CompanionPacketError.invalid("The initial Mac revision changed without advancing.")
        }
    }
}

nonisolated struct CompanionMacPacket: Codable, Equatable, Sendable {
    let format: Int
    let phoneID: String
    let snapshot: CompanionReadSnapshot
    let months: [String: CompanionMacMonthPacket]

    func validate(envelope: CompanionEnvelope, expectedPhoneID: String) throws {
        try envelope.validate()
        guard format == 1, envelope.writer == .mac, UUID(uuidString: phoneID) != nil,
              phoneID == expectedPhoneID, snapshot.generation == envelope.generation,
              snapshot.ledgerLineage == envelope.activationEpoch,
              UUID(uuidString: snapshot.ledgerLineage) != nil, UUID(uuidString: snapshot.publicationID) != nil else {
            throw CompanionPacketError.invalid("The publication is for a different iPhone or generation.")
        }
        try snapshot.validateStructure()
        guard months.count <= 240 else { throw CompanionPacketError.invalid("There are too many monthly plans in this publication.") }
        for (month, packet) in months {
            guard month == packet.scope.month, packet.scope.phone == phoneID,
                  packet.scope.lineage == snapshot.ledgerLineage,
                  packet.scope.session == envelope.sessionID else {
                throw CompanionPacketError.invalid("A monthly plan belongs to a different pairing or ledger.")
            }
            try packet.validate()
        }
    }

    static func decode(_ envelope: CompanionEnvelope, phoneID: String) throws -> Self {
        try envelope.validate()
        let packet = try JSONDecoder().decode(Self.self, from: envelope.payload)
        try packet.validate(envelope: envelope, expectedPhoneID: phoneID)
        return packet
    }
}

nonisolated struct CompanionPhonePacket: Codable, Equatable, Sendable {
    let format: Int
    let phoneID: String
    let proposals: [CompanionMerge.Proposal]
    /// Observation only; not a claim that the Mac received a phone edit.
    let acceptedMacGeneration: UInt64?

    func validate(envelope: CompanionEnvelope, expectedPhoneID: String, lineage: String) throws {
        try envelope.validate()
        guard format == 1, envelope.writer == .phone, UUID(uuidString: phoneID) != nil,
              phoneID == expectedPhoneID, envelope.activationEpoch == lineage, proposals.count <= 240,
              Set(proposals.map { $0.scope.month }).count == proposals.count else {
            throw CompanionPacketError.invalid("The phone publication has an invalid identity or month list.")
        }
        for proposal in proposals {
            try proposal.validate()
            guard proposal.scope.phone == phoneID, proposal.scope.session == envelope.sessionID,
                  proposal.scope.lineage == lineage else {
                throw CompanionPacketError.invalid("A phone proposal belongs to a different ledger or pairing.")
            }
        }
    }
}

nonisolated enum CompanionPacketError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let reason) = self { reason } else { nil } }
}
