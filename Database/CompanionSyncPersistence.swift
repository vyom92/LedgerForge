import Foundation

/// Companion operational state. No new schema number or migration is declared here.
nonisolated public struct CompanionSyncSessionDTO: Equatable, Sendable {
    public let sessionID: String
    public let workspaceID: String
    public let activationEpoch: String
    public let phoneID: String
    public let protocolVersion: Int
    public let disposition: String

    func validate() throws {
        try CompanionSyncValidation.uuid(sessionID)
        try CompanionSyncValidation.uuid(activationEpoch)
        try CompanionSyncValidation.uuid(phoneID)
        guard !workspaceID.isEmpty, protocolVersion == 1,
              disposition == "active" || disposition == "held" else { throw CompanionSyncRepositoryError.invalidSession }
    }
    func scope(month: String) -> CompanionMerge.SyncScope {
        .init(lineage: activationEpoch, session: sessionID, phone: phoneID, month: month)
    }
}
nonisolated public struct CompanionMonthSyncDTO: Equatable, Sendable {
    public let sessionID: String
    public let month: String
    public let stateRevision: Int64
    public let stateVersion: Int
    public let stateJSON: String

    func decoded(session: CompanionSyncSessionDTO) throws -> CompanionMerge.MacMonthState {
        try session.validate(); try CompanionSyncValidation.month(month)
        guard sessionID == session.sessionID, stateRevision >= 0, stateVersion == 1 else {
            throw CompanionSyncRepositoryError.invalidState
        }
        guard stateJSON.utf8.count <= CompanionSyncValidation.maximumStateBytes else { throw CompanionSyncRepositoryError.byteLimit }
        return try decodedEnvelope(session: session).kernel
    }
    func decodedEnvelope(session: CompanionSyncSessionDTO) throws -> CompanionStoredMonth {
        try session.validate(); try CompanionSyncValidation.month(month)
        guard sessionID == session.sessionID, stateRevision >= 0, stateVersion == 1,
              stateJSON.utf8.count <= CompanionSyncValidation.maximumStateBytes else {
            throw CompanionSyncRepositoryError.invalidState
        }
        let value = try JSONDecoder().decode(CompanionStoredMonth.self, from: Data(stateJSON.utf8))
        try value.validate()
        guard value.kernel.scope == session.scope(month: month) else { throw CompanionSyncRepositoryError.invalidState }
        return value
    }
}
/// Atomically stored operational context. Frozen anchors are never reconstructed from a newer plan.
nonisolated struct CompanionStoredMonth: Codable, Equatable, Sendable {
    let format: Int
    let kernel: CompanionMerge.MacMonthState
    let bootstrap: CompanionMonthAnchor
    let current: CompanionMonthAnchor
    let replyAnchor: CompanionMonthAnchor?

    func packet() throws -> CompanionMacMonthPacket {
        .init(scope: kernel.scope, initialDocument: try bootstrap.binding(for: kernel.scope).baselineDocument,
              bootstrapCompletedSequence: kernel.completedSequence, bootstrap: bootstrap, current: current,
              currentDocument: kernel.current, advertisement: kernel.advertisement,
              reply: kernel.lastReply, replyAnchor: replyAnchor)
    }
    func validate() throws {
        guard format == 1 else { throw CompanionSyncRepositoryError.invalidState }
        try kernel.validate()
        let validatedPacket = try CompanionMacMonthPacket.validated(scope: kernel.scope,
            bootstrapCompletedSequence: kernel.completedSequence, bootstrap: bootstrap, current: current,
            currentDocument: kernel.current, advertisement: kernel.advertisement,
            reply: kernel.lastReply, replyAnchor: replyAnchor)
        if kernel.completedSequence == 0 {
            guard kernel.base == validatedPacket.initialDocument else {
                throw CompanionSyncRepositoryError.invalidState
            }
        }
    }
}
nonisolated public enum CompanionMonthOperation: Sendable {
    case initialize(CompanionMerge.Document)
    /// Trusted Mac planner retention/save only; never decoded from a phone payload.
    case localEdit(CompanionMerge.Document)
    /// Trusted Mac provider-context observation; editor and document remain unchanged.
    case refreshDependencies
    case receive(CompanionMerge.Proposal)
}
nonisolated public struct CompanionMonthCommitRequest: Sendable {
    let sessionID: String
    let workspaceID: String
    let month: String
    let expectedActivationEpoch: String
    let expectedStateRevision: Int64?
    /// Exact durable bytes are compared inside the transaction, not merely a view-model generation.
    let expectedScratchpad: MonthlyPlanScratchpadDTO
    let editor: MonthlyPlanScratchpadDTO
    let canonical: FundingPlanDTO?
    let binding: MonthlyPlanSyncAdapter.Binding
    let metadata: MonthlyPlanSyncAdapter.Metadata
    let operation: CompanionMonthOperation
    /// Full resulting editor plus source context, stored with its protocol receipt.
    let currentAnchor: CompanionMonthAnchor
}
nonisolated public enum CompanionCommitDisposition: String, Sendable {
    case initialized, localEdit, dependenciesRefreshed, applied, conflict, replayed, obsolete
}
nonisolated public struct CompanionMonthCommitResult: Sendable {
    public let stored: CompanionMonthSyncDTO
    public let reply: CompanionMerge.Reply?
    public let disposition: CompanionCommitDisposition
    let replyAnchor: CompanionMonthAnchor?
}
nonisolated enum CompanionSyncRepositoryError: Error {
    case unavailable, invalidSession, invalidState, invalidMonth, staleActivation
    case staleScratchpad, staleRevision, pairedMonthRequiresAtomicWrite, invalidProjection
    case byteLimit, exhaustedRevision, sessionCollision
}

nonisolated enum CompanionSyncValidation {
    static let maximumStateBytes = 16 * 1_024 * 1_024
    static let maximumEditorBytes = 4 * 1_024 * 1_024
    static let maximumWireBytes = 8 * 1_024 * 1_024

    static func uuid(_ text: String) throws {
        guard let value = UUID(uuidString: text), value.uuidString == text else { throw CompanionSyncRepositoryError.invalidSession }
    }
    static func month(_ text: String) throws {
        guard let value = try? SelectedStatementMonth(canonical: text), value.canonical == text else {
            throw CompanionSyncRepositoryError.invalidMonth
        }
    }
    struct Prepared {
        let result: CompanionMonthCommitResult
        let isReplay: Bool
    }
    /// Nonfinancial kernel transition plus concrete planner-codec revalidation.
    /// Both providers call this inside their existing exclusive transaction/lock.
    static func prepare(_ request: CompanionMonthCommitRequest, session: CompanionSyncSessionDTO,
                        existing: CompanionMonthSyncDTO?, scratchpad: MonthlyPlanScratchpadDTO?,
                        activationEpoch: String) throws -> Prepared {
        try session.validate(); try month(request.month); try uuid(request.expectedActivationEpoch)
        guard session.disposition == "active", session.workspaceID == request.workspaceID,
              session.sessionID == request.sessionID else { throw CompanionSyncRepositoryError.invalidSession }
        guard activationEpoch == request.expectedActivationEpoch, session.activationEpoch == activationEpoch else {
            throw CompanionSyncRepositoryError.staleActivation
        }
        let oldEnvelope = try existing?.decodedEnvelope(session: session)
        let oldState = oldEnvelope?.kernel
        // Exact duplicate/obsolete delivery is a no-write receipt lookup. Later account
        // changes and caller CAS staleness must not destroy a committed reply.
        if case .receive(let proposal) = request.operation, let oldState, let existing {
            guard try CompanionMerge.ProtocolCodec.encode(proposal).count <= maximumWireBytes else {
                throw CompanionSyncRepositoryError.byteLimit
            }
            let received = try oldState.receiving(proposal)
            if received.kind == .replayed || received.kind == .obsolete {
                let disposition: CompanionCommitDisposition = received.kind == .replayed ? .replayed : .obsolete
                return .init(result: .init(stored: existing, reply: received.reply, disposition: disposition,
                    replyAnchor: received.reply == nil ? nil : oldEnvelope?.replyAnchor), isReplay: true)
            }
        }
        guard existing?.stateRevision == request.expectedStateRevision else { throw CompanionSyncRepositoryError.staleRevision }
        guard scratchpad == request.expectedScratchpad,
              request.expectedScratchpad.workspaceID == request.workspaceID,
              request.expectedScratchpad.month == request.month else { throw CompanionSyncRepositoryError.staleScratchpad }
        guard request.editor.workspaceID == request.workspaceID, request.editor.month == request.month,
              request.editor.stateJSON.utf8.count <= maximumEditorBytes,
              request.expectedScratchpad.stateJSON.utf8.count <= maximumEditorBytes else { throw CompanionSyncRepositoryError.byteLimit }
        let baseline = try MonthlyPlanScratchpad.decode(request.expectedScratchpad)
        guard request.binding.baselineScratchpad == baseline else { throw CompanionSyncRepositoryError.staleScratchpad }
        if let oldEnvelope, request.binding != (try oldEnvelope.current.binding(for: oldEnvelope.kernel.scope)) {
            throw CompanionSyncRepositoryError.invalidProjection
        }
        let next: CompanionMerge.MacMonthState
        let reply: CompanionMerge.Reply?
        let disposition: CompanionCommitDisposition
        switch request.operation {
        case .initialize(let document):
            guard existing == nil, request.expectedStateRevision == nil,
                  document == request.binding.baselineDocument,
                  request.editor == request.expectedScratchpad, request.canonical == nil else {
                throw CompanionSyncRepositoryError.invalidState
            }
            next = try .init(scope: session.scope(month: request.month), initial: document)
            reply = nil; disposition = .initialized
        case .localEdit(let document):
            guard let oldState else { throw CompanionSyncRepositoryError.invalidState }
            next = try oldState.editing(document); reply = nil; disposition = .localEdit
        case .refreshDependencies:
            guard let oldState, request.editor == request.expectedScratchpad, request.canonical == nil else {
                throw CompanionSyncRepositoryError.invalidState
            }
            next = oldState; reply = nil; disposition = .dependenciesRefreshed
        case .receive(let proposal):
            guard let oldState else { throw CompanionSyncRepositoryError.invalidState }
            guard try CompanionMerge.ProtocolCodec.encode(proposal).count <= maximumWireBytes else {
                throw CompanionSyncRepositoryError.byteLimit
            }
            let received = try oldState.receiving(proposal)
            next = received.state; reply = received.reply
            switch received.kind {
            case .applied: disposition = .applied
            case .conflict: disposition = .conflict
            case .replayed: disposition = .replayed
            case .obsolete: disposition = .obsolete
            }
        }
        if disposition == .replayed || disposition == .obsolete || disposition == .conflict {
            guard request.editor == request.expectedScratchpad, request.canonical == nil else {
                throw CompanionSyncRepositoryError.invalidProjection
            }
        }
        let editor = try MonthlyPlanScratchpad.decode(request.editor)
        if let canonical = request.canonical {
            guard editor.canonical == editor.plan, try editor.plan.persistenceDTO() == canonical else {
                throw CompanionSyncRepositoryError.invalidProjection
            }
        } else if editor.canonical != baseline.canonical {
            throw CompanionSyncRepositoryError.invalidProjection
        }
        // Explicit Mac planner operations are the existing source-authorized local boundary.
        // Phone payloads can enter only .receive and remain bound to the retained anchor.
        let resultingBinding = try request.currentAnchor.binding(for: next.scope)
        let validationBinding: MonthlyPlanSyncAdapter.Binding
        switch request.operation {
        case .localEdit, .refreshDependencies: validationBinding = resultingBinding
        case .initialize, .receive: validationBinding = request.binding
        }
        // Concrete codec: no arbitrary caller-supplied validator/transaction closure.
        // Incomplete editor strings remain retained; nil canonical preserves the prior valid plan.
        try MonthlyPlanSyncAdapter.validateCommit(document: next.current, against: validationBinding,
            editor: editor, metadata: request.metadata, canonical: request.canonical == nil ? nil : editor.plan)
        guard request.currentAnchor.scratchpad == editor, request.currentAnchor.metadata == request.metadata,
              resultingBinding.baselineDocument == next.current else {
            throw CompanionSyncRepositoryError.invalidProjection
        }
        if oldEnvelope == nil {
            guard try request.currentAnchor.binding(for: next.scope) == request.binding else {
                throw CompanionSyncRepositoryError.invalidProjection
            }
        }
        if case .receive = request.operation, let oldEnvelope {
            guard request.currentAnchor.context == oldEnvelope.current.context,
                  request.currentAnchor.bankCurrencies == oldEnvelope.current.bankCurrencies,
                  request.currentAnchor.fundingAccountIDs == oldEnvelope.current.fundingAccountIDs,
                  request.currentAnchor.excludedHistoryAccountIDs == oldEnvelope.current.excludedHistoryAccountIDs else {
                throw CompanionSyncRepositoryError.invalidProjection
            }
        }
        let envelope = CompanionStoredMonth(format: 1, kernel: next,
            bootstrap: oldEnvelope?.bootstrap ?? request.currentAnchor, current: request.currentAnchor,
            replyAnchor: reply == nil ? oldEnvelope?.replyAnchor : request.currentAnchor)
        try envelope.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(envelope)
        guard encoded.count <= maximumStateBytes else { throw CompanionSyncRepositoryError.byteLimit }
        let revision: Int64
        if let existing {
            guard existing.stateRevision < Int64.max else { throw CompanionSyncRepositoryError.exhaustedRevision }
            revision = existing.stateRevision + 1
        } else { revision = 0 }
        let stored = CompanionMonthSyncDTO(sessionID: session.sessionID, month: request.month,
            stateRevision: revision, stateVersion: 1, stateJSON: String(decoding: encoded, as: UTF8.self))
        _ = try stored.decoded(session: session)
        return .init(result: .init(stored: stored, reply: reply, disposition: disposition,
            replyAnchor: reply == nil ? nil : envelope.replyAnchor), isReplay: false)
    }
}

/// SQL helper used only under the owning FundingPlanRepository transaction.
nonisolated struct SQLiteCompanionSyncPersistence {
    let db: SQLiteDatabase
    func isSupported() throws -> Bool {
        let count = try db.queryInt("SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('companion_sync_sessions','companion_month_sync');")
        guard count == 0 || count == 2 else { throw CompanionSyncRepositoryError.unavailable }
        return count == 2
    }
    /// Validate operational bytes without requiring the backup to have a live activation stamp.
    static func verifyBackupContents(_ db: SQLiteDatabase) throws {
        let store = Self(db: db)
        guard try store.isSupported() else { return }
        let workspaces = try db.query(sql: "SELECT DISTINCT workspace_id FROM companion_sync_sessions ORDER BY workspace_id;") { $0.string(at: 0) ?? "" }
        var sessions: [String: CompanionSyncSessionDTO] = [:]
        for workspace in workspaces {
            for session in try store.sessions(workspaceID: workspace) {
                guard sessions.updateValue(session, forKey: session.sessionID) == nil else { throw CompanionSyncRepositoryError.invalidSession }
            }
        }
        let months = try db.query(sql: "SELECT session_id,plan_month,state_version,length(CAST(state_json AS BLOB)) FROM companion_month_sync ORDER BY session_id,plan_month;") {
            ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.int64(at: 2) ?? 0, $0.int64(at: 3) ?? 0)
        }
        for (sessionID, month, version, count) in months {
            guard version == 1, count > 0, count <= Int64(CompanionSyncValidation.maximumStateBytes),
                  let session = sessions[sessionID] else { throw CompanionSyncRepositoryError.invalidState }
            guard try store.month(session: session, month: month) != nil else { throw CompanionSyncRepositoryError.invalidState }
        }
    }
    func requireSupport() throws { guard try isSupported() else { throw CompanionSyncRepositoryError.unavailable } }
    func activationEpoch() throws -> String {
        let stamp = try db.validatedActivationStamp()
        guard !stamp.transitioning else { throw CompanionSyncRepositoryError.staleActivation }
        return stamp.epoch.uuidString
    }
    func sessions(workspaceID: String) throws -> [CompanionSyncSessionDTO] {
        try requireSupport()
        return try db.query(sql: "SELECT session_id,workspace_id,activation_epoch,phone_id,protocol_version,disposition FROM companion_sync_sessions WHERE workspace_id=? ORDER BY session_id;", params: [workspaceID]) { row in
            let value = CompanionSyncSessionDTO(sessionID: row.string(at: 0) ?? "", workspaceID: row.string(at: 1) ?? "",
                activationEpoch: row.string(at: 2) ?? "", phoneID: row.string(at: 3) ?? "",
                protocolVersion: Int(row.int64(at: 4) ?? 0), disposition: row.string(at: 5) ?? "")
            try value.validate(); return value
        }
    }
    func session(id: String, workspaceID: String) throws -> CompanionSyncSessionDTO {
        guard let value = try sessions(workspaceID: workspaceID).first(where: { $0.sessionID == id }) else {
            throw CompanionSyncRepositoryError.invalidSession
        }
        return value
    }
    func month(session: CompanionSyncSessionDTO, month: String) throws -> CompanionMonthSyncDTO? {
        try requireSupport(); try CompanionSyncValidation.month(month)
        let value = try db.query(sql: "SELECT session_id,plan_month,state_revision,state_version,state_json FROM companion_month_sync WHERE session_id=? AND plan_month=?;", params: [session.sessionID, month]) { row in
            CompanionMonthSyncDTO(sessionID: row.string(at: 0) ?? "", month: row.string(at: 1) ?? "",
                stateRevision: row.int64(at: 2) ?? -1, stateVersion: Int(row.int64(at: 3) ?? 0), stateJSON: row.string(at: 4) ?? "")
        }.first
        if let value { _ = try value.decoded(session: session) }
        return value
    }
    func createSession(_ value: CompanionSyncSessionDTO) throws {
        try requireSupport(); try value.validate()
        guard value.disposition == "active", value.activationEpoch == (try activationEpoch()) else {
            throw CompanionSyncRepositoryError.staleActivation
        }
        let existing = try db.query(sql: "SELECT workspace_id FROM companion_sync_sessions WHERE session_id=?;", params: [value.sessionID]) { $0.string(at: 0) }.first
        if let existing {
            guard existing == value.workspaceID, try session(id: value.sessionID, workspaceID: value.workspaceID) == value else {
                throw CompanionSyncRepositoryError.sessionCollision
            }
            return
        }
        let workspaceExists = try db.query(sql: "SELECT id FROM workspaces WHERE id=?;", params: [value.workspaceID]) { $0.string(at: 0) }.first != nil
        guard workspaceExists else { throw CompanionSyncRepositoryError.invalidSession }
        guard try !sessions(workspaceID: value.workspaceID).contains(where: { $0.disposition == "active" }) else {
            throw CompanionSyncRepositoryError.sessionCollision
        }
        try db.executePrepared(sql: "INSERT INTO companion_sync_sessions(session_id,workspace_id,activation_epoch,phone_id,protocol_version,disposition) VALUES(?,?,?,?,?,?);",
            params: [value.sessionID,value.workspaceID,value.activationEpoch,value.phoneID,value.protocolVersion,value.disposition])
    }
    func holdSession(id: String, workspaceID: String) throws {
        _ = try session(id: id, workspaceID: workspaceID)
        try db.executePrepared(sql: "UPDATE companion_sync_sessions SET disposition='held' WHERE session_id=? AND workspace_id=?;", params: [id,workspaceID])
    }
    func reconcileActivation() throws {
        try requireSupport()
        let epoch = try activationEpoch()
        try db.executePrepared(sql: "UPDATE companion_sync_sessions SET disposition='held' WHERE disposition='active' AND activation_epoch<>?;", params: [epoch])
    }
    func refuseLegacyWrite(workspaceID: String, month: String) throws {
        guard try isSupported() else { return } // Historical schemas retain their existing behavior.
        let paired = try db.query(sql: "SELECT count(*) FROM companion_month_sync m JOIN companion_sync_sessions s ON s.session_id=m.session_id WHERE s.workspace_id=? AND m.plan_month=? AND s.disposition='active';", params: [workspaceID,month]) { $0.int64(at: 0) ?? 0 }.first ?? 0
        guard paired == 0 else { throw CompanionSyncRepositoryError.pairedMonthRequiresAtomicWrite }
    }
    func store(_ value: CompanionMonthSyncDTO) throws {
        try db.executePrepared(sql: "INSERT INTO companion_month_sync(session_id,plan_month,state_revision,state_version,state_json) VALUES(?,?,?,?,?) ON CONFLICT(session_id,plan_month) DO UPDATE SET state_revision=excluded.state_revision,state_version=excluded.state_version,state_json=excluded.state_json;",
            params: [value.sessionID,value.month,value.stateRevision,value.stateVersion,value.stateJSON])
    }
}
