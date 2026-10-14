import Foundation
import Observation

nonisolated struct CompanionPhoneMonthRecord: Codable, Equatable, Sendable {
    var state: CompanionMerge.PhoneMonthState
    var anchor: CompanionMonthAnchor
    var scratchpad: MonthlyPlanScratchpad
    var metadata: MonthlyPlanSyncAdapter.Metadata
    var selectedHistoryAccountIDs: Set<String>
    // Retain the exact visible edit even if conversion cannot yet produce a proposal.
    var unencodedDraft: Bool = false
    var hold: String?
    var heldPacket: CompanionMacMonthPacket?
}
nonisolated struct CompanionPhonePairing: Codable, Equatable, Sendable {
    let session: String
    let epoch: String
    let lineage: String
}
nonisolated struct CompanionPhoneVersionReview: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let writer: CompanionWriter
    let choiceIDs: [String]
}
nonisolated struct CompanionPhoneLocalState: Codable, Equatable, Sendable {
    var format = 1
    let phoneID: String
    var connection: CompanionFolderConnection?
    var pairing: CompanionPhonePairing?
    var lastMacEnvelope: CompanionEnvelope?
    var months: [String: CompanionPhoneMonthRecord] = [:]
    var selectedMonth: String?
    var outboundEnvelope: CompanionEnvelope?
    var publishedGeneration: UInt64?
    var lastCheckedAt: Date?
    var heldEnvelope: CompanionEnvelope?
    var hold: String?
    var versionReview: CompanionPhoneVersionReview?
    var recoveryProgress: CompanionPhoneRecoveryProgress?
    var ledgerReviewIDs: [String]?
    var folderVersionArchiveIDs: [String]?

    @discardableResult
    func validate() throws -> CompanionReadSnapshot? {
        var validatedSnapshot: CompanionReadSnapshot?
        guard format == 1, UUID(uuidString: phoneID) != nil, months.count <= 240 else {
            throw CompanionPacketError.invalid("The saved iPhone identity or monthly state needs recovery.")
        }
        if let lastMacEnvelope {
            let packet = try CompanionMacPacket.decode(lastMacEnvelope, phoneID: phoneID)
            guard pairing == CompanionPhonePairing(session: lastMacEnvelope.sessionID,
                epoch: lastMacEnvelope.activationEpoch, lineage: packet.snapshot.ledgerLineage) else {
                throw CompanionPacketError.invalid("The saved pairing does not match the retained publication.")
            }
            validatedSnapshot = packet.snapshot
        } else if pairing != nil || !months.isEmpty { throw CompanionPacketError.invalid("The saved pairing evidence is missing.") }
        for (month, record) in months {
            try validateRetainedMonth(record, month: month)
        }
        if let outboundEnvelope {
            guard let pairing, outboundEnvelope.activationEpoch == pairing.epoch else { throw CompanionPacketError.invalid("The pending publication has a different activation.") }
            let packet = try JSONDecoder().decode(CompanionPhonePacket.self, from: outboundEnvelope.payload)
            try packet.validate(envelope: outboundEnvelope, expectedPhoneID: phoneID, lineage: pairing.lineage)
            if let publishedGeneration, publishedGeneration > outboundEnvelope.generation { throw CompanionPacketError.invalid("The delivery marker is inconsistent.") }
        } else if publishedGeneration != nil { throw CompanionPacketError.invalid("The delivery evidence is missing.") }
        if let ids = folderVersionArchiveIDs {
            guard Set(ids).count == ids.count, ids.allSatisfy({ UUID(uuidString: $0) != nil }) else {
                throw CompanionPacketError.invalid("A retained folder version archive reference is invalid.")
            }
        }
        if let ids = ledgerReviewIDs {
            guard Set(ids).count == ids.count, ids.allSatisfy({ UUID(uuidString: $0) != nil }) else {
                throw CompanionPacketError.invalid("A retained ledger archive reference is invalid.")
            }
        }
        if let progress = recoveryProgress {
            guard ledgerReviewIDs?.contains(progress.archiveID) == true,
                  Set(progress.issues.keys).isSubset(of: Set(progress.choices.keys)) else {
                throw CompanionPacketError.invalid("Recovery progress has no matching retained archive.")
            }
            for (key, choice) in progress.choices {
                try choice.review.validate()
                guard choice.review.oldPhone.scope.phone == phoneID,
                      choice.review.fresh.scope.month == key,
                      months[key]?.state.scope == choice.review.fresh.scope else {
                    throw CompanionPacketError.invalid("A recovery choice has a different active monthly scope.")
                }
            }
        }
        if let review = versionReview {
            guard UUID(uuidString: review.id) != nil, !review.choiceIDs.isEmpty,
                  Set(review.choiceIDs).count == review.choiceIDs.count,
                  review.choiceIDs.allSatisfy({ $0.count == 64 && $0.allSatisfy(\.isHexDigit) }) else { throw CompanionPacketError.invalid("The version review reference is invalid.") }
        }
        return validatedSnapshot
    }
    @inline(never)
    private func validateRetainedMonth(_ record: CompanionPhoneMonthRecord, month: String) throws {
        try record.state.validate()
        guard let pairing, month == record.state.scope.month,
              record.state.scope.phone == phoneID, record.state.scope.session == pairing.session,
              record.state.scope.lineage == pairing.lineage else { throw CompanionPacketError.invalid("A retained month has a different identity.") }
        let binding = try record.anchor.binding(for: record.state.scope)
        guard binding.baselineDocument == record.state.base else { throw CompanionPacketError.invalid("A retained monthly base has no matching context.") }
        if !record.unencodedDraft && record.hold == nil && record.state.reconciliation == nil {
            guard try MonthlyPlanSyncAdapter.encode(record.scratchpad, metadata: record.metadata,
                against: binding).document == record.state.draft else { throw CompanionPacketError.invalid("A retained monthly edit and proposal differ.") }
        }
    }
}

/// Call-local heap storage only. No serialized shape or persistent ownership changes.
/// The candidate is installed only after its whole month operation returns.
@MainActor
private final class CompanionPhoneMonthTransition {
    let incoming: CompanionMacMonthPacket
    let original: CompanionPhoneMonthRecord
    var candidate: CompanionPhoneMonthRecord
    let usesRecovery: Bool
    var recoveryProgress: CompanionPhoneRecoveryProgress?

    @inline(never)
    init(incoming: CompanionMacMonthPacket, saved: CompanionPhoneMonthRecord?,
         recoveryProgress: CompanionPhoneRecoveryProgress?) throws {
        self.incoming = incoming
        self.recoveryProgress = recoveryProgress
        usesRecovery = recoveryProgress?.choices[incoming.scope.month] != nil
        if let saved { original = saved }
        else {
            guard incoming.bootstrapCompletedSequence == 0 else {
                throw CompanionPacketError.invalid("The Mac has already processed this month's iPhone state, but its local copy is missing. Recovery is required.")
            }
            original = .init(state: try .init(scope: incoming.scope, initial: incoming.initialDocument),
                anchor: incoming.bootstrap, scratchpad: incoming.bootstrap.scratchpad, metadata: incoming.bootstrap.metadata,
                selectedHistoryAccountIDs: incoming.bootstrap.context.allHistoryAccountIDs.subtracting(incoming.bootstrap.excludedHistoryAccountIDs))
        }
        candidate = original
    }

    @inline(never)
    func retainFailure(_ error: Error) {
        candidate = original
        candidate.hold = error.localizedDescription
        candidate.heldPacket = incoming
    }
}

@MainActor @Observable
final class CompanionPhoneModel {
    private(set) var local: CompanionPhoneLocalState?
    /// Produced only by complete retained-state validation, never by a view read.
    private(set) var snapshot: CompanionReadSnapshot?
    private(set) var retentionFailure: String?
    private(set) var connectionMessage = "Choose the companion folder to check the Mac publication."
    private(set) var isChecking = false
    private(set) var startupFailure: String?
    private(set) var versionChoices: [CompanionFileChoice] = []
    private(set) var ledgerRecoveryReview: CompanionPhoneLedgerReview?
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let transport = CompanionFolderTransport()
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var syncRequested = false
    @ObservationIgnored private var restoredConnection = false
    private var stateURL: URL { directory.appendingPathComponent("phone-state-v1.json") }

    init(directory: URL) {
        self.directory = directory
        do {
            if let saved = try CompanionLocalFile.load(CompanionPhoneLocalState.self, at: stateURL) {
                snapshot = try saved.validate(); local = saved
                if let review = saved.versionReview { versionChoices = try loadChoices(review) }
            } else {
                let initial = CompanionPhoneLocalState(phoneID: UUID().uuidString)
                try CompanionLocalFile.save(initial, to: stateURL); local = initial
            }
        } catch { startupFailure = "Saved iPhone data could not be opened. It has been retained for recovery. \(error.localizedDescription)" }
    }
    var phoneID: String? { local?.phoneID }
    var currentRecord: CompanionPhoneMonthRecord? {
        guard let local, let month = local.selectedMonth else { return nil }; return local.months[month]
    }
    var availableMonths: [SelectedStatementMonth] {
        (local?.months.keys.compactMap { try? SelectedStatementMonth(canonical: $0) } ?? []).sorted { $0.canonical > $1.canonical }
    }
    private var deliveryHoldMessage: String? {
        local?.hold ?? currentRecord?.hold
            ?? local?.selectedMonth.flatMap { local?.recoveryProgress?.issues[$0] }
            ?? (local?.versionReview != nil
                ? "Different iCloud versions are retained locally. Choose which complete publication to use."
                : nil)
    }
    var readStatus: CompanionReadStatus {
        .init(message: startupFailure ?? deliveryHoldMessage ?? connectionMessage,
              lastCheckedAt: local?.lastCheckedAt, isChecking: isChecking)
    }
    private var currentRecoveryPending: Bool {
        guard let key = local?.selectedMonth else { return false }
        return local?.recoveryProgress?.choices[key] != nil
    }
    var editor: PortableMonthlyPlanEditor? {
        guard let record = currentRecord else { return nil }
        let context = record.anchor.context
        return PortableMonthlyPlanEditor(scratchpad: record.scratchpad,
            lexicalContext: MonthlyPlanSyncAdapter.lexicalContext(from: record.metadata),
            accounts: context.accounts.map { .init(id: $0.id, nativeCurrency: $0.currency, isHistoryOnly: $0.isHistoryOnly) },
            allHistoryAccountIDs: context.allHistoryAccountIDs,
            selectedHistoryAccountIDs: record.selectedHistoryAccountIDs,
            manuallyExcludedPlanningAccountIDs: context.manuallyExcludedPlanningAccountIDs,
            receipt: context.receipt?.state,
            receiptBasis: context.receiptBasis,
            canEdit: record.state.reconciliation == nil && record.hold == nil && local?.hold == nil && !currentRecoveryPending,
            presentation: snapshot?.plannerPresentation)
    }
    var planStatus: CompanionPlanStatus {
        let record = currentRecord
        let conflict = record?.state.reconciliation != nil || record?.hold != nil || local?.hold != nil || local?.versionReview != nil || local?.selectedMonth.flatMap { local?.recoveryProgress?.issues[$0] } != nil
        let delivery: CompanionPlanStatus.Delivery
        if record?.state.reconciliation != nil { delivery = .conflict }
        else if conflict { delivery = .held(deliveryHoldMessage ?? connectionMessage) }
        else if local?.connection == nil { delivery = .offline }
        else if let state = record?.state, let pending = state.outstanding {
            let exactPublication = local?.outboundEnvelope.flatMap { envelope -> CompanionPhonePacket? in
                guard local?.publishedGeneration == envelope.generation else { return nil }
                return try? JSONDecoder().decode(CompanionPhonePacket.self, from: envelope.payload)
            }
            delivery = pending.proposed == state.draft && exactPublication?.proposals.contains(pending) == true
                ? .waitingForMac : .waitingToSend
        }
        else if record?.state.needsExchange == true { delivery = .waitingToSend }
        else if record?.state.lastReply != nil { delivery = .acknowledged }
        else { delivery = .fromMacSnapshot }
        return .init(retention: retentionFailure.map { .failed($0) } ?? .kept, delivery: delivery,
            permitsEditing: record != nil && record?.state.reconciliation == nil && record?.hold == nil && local?.hold == nil && !currentRecoveryPending,
            permitsCalculation: !conflict && !currentRecoveryPending && retentionFailure == nil && record?.unencodedDraft == false)
    }
    // All synchronous mutations update the visible value even on write failure.
    // Network work is forbidden until the exact visible state is durably retained.
    @discardableResult private func retain(_ next: CompanionPhoneLocalState) -> Bool {
        local = next
        do {
            snapshot = try next.validate()
            try CompanionLocalFile.save(next, to: stateURL)
            retentionFailure = nil
            return true
        }
        catch { retentionFailure = error.localizedDescription; return false }
    }
    func retryRetention() {
        guard let local, retain(local) else { return }
        do {
            if let review = local.versionReview { versionChoices = try loadChoices(review) }
            requestSync()
        } catch {
            connectionMessage = "The retained version archive could not be opened. No version was discarded. \(error.localizedDescription)"
        }
    }
    func selectMonth(_ month: SelectedStatementMonth) {
        guard var next = local, next.months[month.canonical] != nil else { return }
        next.selectedMonth = month.canonical; _ = retain(next)
    }
    func edit(_ change: PortableMonthlyPlanEditor.Edit) {
        guard var next = local, let key = next.selectedMonth, var record = next.months[key], var editor,
              editor.apply(change, inputLocaleIdentifier: Locale.current.identifier)?.changed == true else { return }
        record.scratchpad = editor.scratchpad
        record.selectedHistoryAccountIDs = editor.selectedHistoryAccountIDs
        record.metadata = MonthlyPlanSyncAdapter.metadata(for: editor.scratchpad,
            lexicalContext: editor.lexicalContext, retaining: record.metadata)
        do {
            let encoded = try MonthlyPlanSyncAdapter.encode(editor.scratchpad, metadata: record.metadata,
                against: record.anchor.binding(for: record.state.scope))
            record.state = try record.state.editing(encoded.document); record.metadata = encoded.metadata
            record.unencodedDraft = false
        } catch {
            record.unencodedDraft = true
            record.hold = "This exact edit is retained but cannot be sent yet: \(error.localizedDescription)"
        }
        next.months[key] = record
        if retain(next) { requestSync() }
    }
    func chooseFolder(_ url: URL) {
        changeFolder(url, retainingUnresolvedVersions: false)
    }
    func requestSync() {
        syncRequested = true
        guard syncTask == nil else { return }
        syncTask = Task { [weak self] in
            guard let self else { return }
            while syncRequested, !Task.isCancelled {
                syncRequested = false
                await syncOnce()
            }
            syncTask = nil
        }
    }
    private func syncOnce() async {
        guard retentionFailure == nil, let local, let connection = local.connection,
              local.versionReview == nil else { return }
        isChecking = true; defer { isChecking = false }
        do {
            if !restoredConnection {
                let restored = try await transport.restore(connection)
                guard var next = self.local else { return }; next.connection = restored
                guard retain(next) else { return }; restoredConnection = true
            }
            // Inspect both writers before accepting or publishing any version.
            for writer in [CompanionWriter.mac, .phone] {
                let choices = try await transport.conflictingChoices(writer)
                if !choices.isEmpty { try archiveVersions(writer: writer, choices: choices); return }
            }
            let incoming = try await transport.read(.mac)
            try accept(incoming.envelope)
            connectionMessage = "Mac snapshot checked; saved data remains available offline."
            guard retentionFailure == nil, self.local?.hold == nil else { return }
            if let envelope = try stagePublication() {
                try await transport.publish(envelope)
                // Only update the marker in the latest state; typing may have occurred during the await.
                guard var next = self.local else { return }
                if next.outboundEnvelope == envelope { next.publishedGeneration = envelope.generation; _ = retain(next) }
                connectionMessage = "Phone file written to the selected folder. Waiting for a matching Mac receipt."
            }
        } catch {
            let failure = error as NSError
            if self.local?.lastMacEnvelope == nil,
               failure.domain == NSCocoaErrorDomain, failure.code == NSFileReadNoSuchFileError {
                connectionMessage = "Waiting for the Mac's first publication. Pair this iPhone in LedgerForge on your Mac using the same folder."
            } else {
                connectionMessage = "Saved data and pending edits are retained. \(error.localizedDescription)"
            }
        }
    }
    private func accept(_ envelope: CompanionEnvelope, retryHeld: Bool = false) throws {
        guard var next = local else { return }
        do {
            let packet = try fencedMacPacket(envelope, phoneID: next.phoneID)
            let pair = CompanionPhonePairing(session: envelope.sessionID, epoch: envelope.activationEpoch, lineage: packet.snapshot.ledgerLineage)
            guard next.pairing == nil || next.pairing == pair else { throw CompanionPacketError.invalid("The ledger or pairing changed. Retained edits need explicit ledger comparison on this iPhone.") }
            let advances = try envelope.validateSuccessor(of: next.lastMacEnvelope)
            if !advances && !retryHeld { next.lastCheckedAt = Date(); _ = retain(next); return }
            next.pairing = pair
            for key in packet.months.keys {
                let transition = try makeMonthTransition(key: key, packet: packet, state: next)
                try receiveMonth(transition, envelope: envelope)
                installMonth(transition, key: key, state: &next)
            }
            if var progress = next.recoveryProgress {
                for key in progress.choices.keys where packet.months[key] == nil {
                    progress.issues[key] = "This recovery month is absent from the current Mac ledger; both phone states remain retained."
                }
                next.recoveryProgress = progress
            }
            next.lastMacEnvelope = envelope; next.lastCheckedAt = Date()
            next.hold = nil; next.heldEnvelope = nil
            if next.selectedMonth == nil { next.selectedMonth = next.months.keys.sorted().last }
            _ = retain(next)
        } catch {
            next.heldEnvelope = envelope; next.hold = error.localizedDescription; _ = retain(next)
            throw error
        }
    }
    /// Creation/copy temporaries end before any financial adapter is entered.
    @inline(never)
    private func makeMonthTransition(key: String, packet: CompanionMacPacket,
                                     state: CompanionPhoneLocalState) throws -> CompanionPhoneMonthTransition {
        guard let incoming = packet.months[key] else {
            throw CompanionPacketError.invalid("The monthly publication is unavailable.")
        }
        return try CompanionPhoneMonthTransition(incoming: incoming, saved: state.months[key],
            recoveryProgress: state.recoveryProgress)
    }

    /// No large record parameter or return; mutable storage is scoped to this call.
    @inline(never)
    private func receiveMonth(_ transition: CompanionPhoneMonthTransition, envelope: CompanionEnvelope) throws {
        if transition.usesRecovery, var progress = transition.recoveryProgress {
            try acceptRecoveryMonth(&transition.candidate, incoming: transition.incoming,
                envelope: envelope, progress: &progress)
            transition.recoveryProgress = progress.choices.isEmpty ? nil : progress
            return
        }
        do {
            try receiveOrdinaryReceipt(&transition.candidate, incoming: transition.incoming)
            try refreshOrdinaryDependencies(&transition.candidate, incoming: transition.incoming)
            try validateOrdinaryCandidate(&transition.candidate)
            transition.candidate.hold = nil; transition.candidate.heldPacket = nil
        } catch {
            // The full original record is restored before retaining the failed packet.
            transition.retainFailure(error)
        }
    }

    @inline(never)
    private func installMonth(_ transition: CompanionPhoneMonthTransition, key: String,
                              state: inout CompanionPhoneLocalState) {
        state.months[key] = transition.candidate
        if transition.usesRecovery { state.recoveryProgress = transition.recoveryProgress }
    }

    @inline(never)
    private func receiveOrdinaryReceipt(_ record: inout CompanionPhoneMonthRecord,
                                        incoming: CompanionMacMonthPacket) throws {
        guard !record.unencodedDraft else { throw CompanionPacketError.invalid("An exact local edit is retained outside the proposal and needs review first.") }
        record.state = try record.state.observing(incoming.advertisement)
        if let reply = incoming.reply {
            let received = try record.state.receiving(reply)
            if received.kind == .accepted || received.kind == .needsResolution {
                guard let anchor = incoming.replyAnchor else { throw CompanionPacketError.invalid("The receipt context is missing.") }
                record.state = received.state; record.anchor = anchor
                if received.kind == .accepted {
                    let decoded = try MonthlyPlanSyncAdapter.decode(document: record.state.draft, against: anchor.binding(for: incoming.scope))
                    record.scratchpad = decoded.scratchpad; record.metadata = decoded.metadata
                }
            }
        }
    }

    @inline(never)
    private func refreshOrdinaryDependencies(_ record: inout CompanionPhoneMonthRecord,
                                             incoming: CompanionMacMonthPacket) throws {
        let previous = try record.anchor.binding(for: incoming.scope)
        let current = try incoming.current.binding(for: incoming.scope)
        switch MonthlyPlanSyncAdapter.classifyBindingChange(from: previous, to: current) {
        case .identical, .dependenciesOnly:
            if record.state.reconciliation == nil {
                let decoded = try MonthlyPlanSyncAdapter.dependencyRebind(document: record.state.draft, from: previous, to: current)
                record.anchor = incoming.current; record.scratchpad = decoded.scratchpad; record.metadata = decoded.metadata
            }
        case .requiresMerge: break // observation drives the ordinary exchange; never overwrite edits
        case .incompatible: throw CompanionPacketError.invalid("This month's plan identity or calculation version changed. Pending edits are retained for review.")
        }
    }

    @inline(never)
    private func validateOrdinaryCandidate(_ record: inout CompanionPhoneMonthRecord) throws {
        guard record.selectedHistoryAccountIDs.isSubset(of: record.anchor.context.allHistoryAccountIDs) else {
            throw CompanionPacketError.invalid("A selected history account is no longer available in the Mac context. Its local selection is retained for review.")
        }
        // Validate the complete candidate before installing any receipt transition.
        try record.state.validate()
        let candidateBinding = try record.anchor.binding(for: record.state.scope)
        guard candidateBinding.baselineDocument == record.state.base else {
            throw CompanionPacketError.invalid("The received plan has no matching retained base context.")
        }
        if record.state.reconciliation == nil {
            guard try MonthlyPlanSyncAdapter.encode(record.scratchpad, metadata: record.metadata,
                against: candidateBinding).document == record.state.draft else {
                throw CompanionPacketError.invalid("The received plan and visible entries differ.")
            }
        }
    }
    private func stagePublication() throws -> CompanionEnvelope? {
        guard var next = local, let pairing = next.pairing, next.hold == nil else { return nil }
        var proposals: [CompanionMerge.Proposal] = []
        for key in next.months.keys.sorted() {
            guard var record = next.months[key], record.hold == nil, !record.unencodedDraft,
                  next.recoveryProgress?.issues[key] == nil, record.state.needsExchange else { continue }
            let send = try record.state.beginExchange(); record.state = send.state
            next.months[key] = record; proposals.append(send.proposal)
        }
        guard !proposals.isEmpty else { return nil }
        let packet = CompanionPhonePacket(format: 1, phoneID: next.phoneID, proposals: proposals,
            acceptedMacGeneration: next.lastMacEnvelope?.generation)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(packet)
        if let existing = next.outboundEnvelope, existing.payload == payload {
            guard retain(next) else { return nil }; return existing
        }
        let oldGeneration = next.outboundEnvelope?.generation ?? 0
        guard oldGeneration < UInt64.max else { throw CompanionPacketError.invalid("The publication counter is exhausted.") }
        let envelope = try CompanionEnvelope(sessionID: pairing.session, activationEpoch: pairing.epoch,
            writer: .phone, generation: oldGeneration + 1, payload: payload)
        next.outboundEnvelope = envelope
        guard retain(next) else { return nil }
        return envelope
    }
    func resolvePlan(expected: CompanionMerge.ResolutionContext, usePhone: Bool) {
        guard var next = local, let key = next.selectedMonth, var record = next.months[key] else { return }
        do {
            let document = expected.resolvedDocument(choosingLocalForConflicts: usePhone)
            let decoded = try MonthlyPlanSyncAdapter.decode(document: document, against: record.anchor.binding(for: record.state.scope))
            let resolved = try record.state.resolving(expected: expected, document: document)
            // Retain both complete alternatives and the exact decision before changing live draft state.
            let archive = CompanionPhoneResolutionArchive(sequence: expected.sequence, cause: expected.cause,
                ancestor: expected.ancestor, local: expected.local, remote: expected.remote, chosenPhone: usePhone, month: key)
            try CompanionLocalFile.save(archive, to: directory.appendingPathComponent("PlanReviews/\(UUID().uuidString).json"))
            record.state = resolved; record.scratchpad = decoded.scratchpad; record.metadata = decoded.metadata
            record.hold = nil; record.heldPacket = nil; next.months[key] = record
            if retain(next) { requestSync() }
        } catch { connectionMessage = "The choice was not applied. Both plans remain retained. \(error.localizedDescription)" }
    }
    private func archiveVersions(writer: CompanionWriter, choices: [CompanionFileChoice]) throws {
        let review = CompanionPhoneVersionReview(id: UUID().uuidString, writer: writer, choiceIDs: choices.map(\.id).sorted())
        let folder = directory.appendingPathComponent("VersionReviews/\(review.id)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for choice in choices {
            guard choice.id == CompanionEnvelope.hash(choice.bytes) else { throw CompanionTransportError.changedDuringReview }
            let url = folder.appendingPathComponent(choice.id + ".json")
            try choice.bytes.write(to: url, options: .atomic)
            guard try Data(contentsOf: url) == choice.bytes else { throw CompanionTransportError.changedDuringReview }
        }
        try CompanionLocalFile.save(review, to: folder.appendingPathComponent("manifest.json"))
        guard var next = local else { return }; next.versionReview = review
        if retain(next) { versionChoices = try loadChoices(review); connectionMessage = "Different iCloud versions are retained locally. Choose which complete publication to use." }
    }
    private func loadChoices(_ review: CompanionPhoneVersionReview) throws -> [CompanionFileChoice] {
        let folder = directory.appendingPathComponent("VersionReviews/\(review.id)")
        guard try CompanionLocalFile.load(CompanionPhoneVersionReview.self, at: folder.appendingPathComponent("manifest.json")) == review else { throw CompanionTransportError.changedDuringReview }
        return try review.choiceIDs.map { id in
            let url = folder.appendingPathComponent(id + ".json")
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            let bytes = try handle.read(upToCount: CompanionEnvelope.maximumBytes + 1) ?? Data()
            guard bytes.count <= CompanionEnvelope.maximumBytes, CompanionEnvelope.hash(bytes) == id else { throw CompanionTransportError.changedDuringReview }
            do { return .init(id: id, bytes: bytes, envelope: try CompanionEnvelope.decode(bytes, writer: review.writer), issue: nil) }
            catch { return .init(id: id, bytes: bytes, envelope: nil, issue: error.localizedDescription) }
        }
    }
    func resolveVersion(_ selectedID: String) {
        guard !isChecking, retentionFailure == nil, let review = local?.versionReview else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                if !restoredConnection {
                    guard let connection = local?.connection else { throw CompanionPacketError.invalid("Choose the retained companion folder to resolve its versions.") }
                    let restored = try await transport.restore(connection)
                    guard var next = local else { return }; next.connection = restored
                    guard retain(next) else { return }; restoredConnection = true
                }
                let choices = try loadChoices(review)
                guard let local = self.local, let choice = choices.first(where: { $0.id == selectedID }), let envelope = choice.envelope else { throw CompanionTransportError.changedDuringReview }
                if review.writer == .mac {
                    _ = try CompanionMacPacket.decode(envelope, phoneID: local.phoneID)
                    _ = try envelope.validateSuccessor(of: local.lastMacEnvelope)
                } else {
                    guard envelope == local.outboundEnvelope else { throw CompanionPacketError.invalid("This phone version does not match the exact retained outgoing publication. Keep both versions for reconciliation.") }
                }
                try await transport.resolveVersions(writer: review.writer, selectedID: selectedID,
                    retainedChoices: choices, lastAccepted: review.writer == .mac ? local.lastMacEnvelope : local.outboundEnvelope)
                guard var next = self.local, next.versionReview == review else { return }
                next.versionReview = nil
                if retain(next) { versionChoices = []; requestSync() }
            } catch { connectionMessage = "No version was discarded. \(error.localizedDescription)" }
        }
    }
}
nonisolated private struct CompanionPhoneResolutionArchive: Codable {
    let sequence: UInt64
    let cause: CompanionMerge.ReconciliationCause
    let ancestor: CompanionMerge.Document
    let local: CompanionMerge.Document
    let remote: CompanionMerge.Document
    let chosenPhone: Bool
    let month: String
}

typealias CompanionPhoneRecovery = CompanionRecovery<CompanionMonthAnchor>
nonisolated struct CompanionPhoneRecoveryProgress: Codable, Equatable, Sendable {
    var archiveID: String
    var choices: [String: CompanionPhoneRecovery.Choice]
    var issues: [String: String]
}
nonisolated struct CompanionPhoneLedgerArchive: Codable, Equatable, Sendable {
    let id: String
    let oldState: CompanionPhoneLocalState
    let originalRecords: [String: CompanionPhoneMonthRecord]
    let reviewedEnvelope: CompanionEnvelope
    let adoptedEnvelope: CompanionEnvelope
    let choices: [String: CompanionRecoverySide]
}
@MainActor struct CompanionPhoneLedgerReview {
    let id: String
    let oldState: CompanionPhoneLocalState
    let originalRecords: [String: CompanionPhoneMonthRecord]
    let envelope: CompanionEnvelope
    let reviews: [String: CompanionPhoneRecovery.Review]
    let issues: [String: String]
    let keys: [String]
    let samePair: Bool
    let presentation: CompanionPhoneLedgerRecoveryPresentation
}
@MainActor struct CompanionPhoneLedgerRecoveryPresentation: Identifiable {
    let id: String
    let oldLedgerLabel: String
    let newLedgerLabel: String
    let phoneID: String
    let months: [CompanionRecoveryMonthPresentation]
    let recordedChoices: [String: CompanionRecoverySide]
}

// This extension intentionally shares the model's source file and private mutation boundary.
extension CompanionPhoneModel {
    var ledgerArchiveIDs: [String] { local?.ledgerReviewIDs ?? [] }
    var canReviewChangedLedger: Bool {
        local?.heldEnvelope != nil || !(local?.recoveryProgress?.issues.isEmpty ?? true)
    }
    var ledgerRecoveryPresentation: CompanionPhoneLedgerRecoveryPresentation? { ledgerRecoveryReview?.presentation }

    private func fencedMacPacket(_ envelope: CompanionEnvelope, phoneID: String) throws -> CompanionMacPacket {
        try envelope.validate()
        let packet = try JSONDecoder().decode(CompanionMacPacket.self, from: envelope.payload)
        // Scope checks precede packet.validate's financial adapter calls.
        guard envelope.writer == .mac, packet.phoneID == phoneID,
              packet.snapshot.ledgerLineage == envelope.activationEpoch,
              packet.months.allSatisfy({ key, month in key == month.scope.month &&
                  month.scope.phone == phoneID && month.scope.session == envelope.sessionID &&
                  month.scope.lineage == envelope.activationEpoch }) else {
            throw CompanionPacketError.invalid("This publication belongs to a different iPhone or ledger scope.")
        }
        try packet.validate(envelope: envelope, expectedPhoneID: phoneID)
        return packet
    }
    private func recoveryArchiveURL(_ id: String) throws -> URL {
        guard UUID(uuidString: id) != nil else { throw CompanionPacketError.invalid("The ledger archive reference is invalid.") }
        return directory.appendingPathComponent("LedgerReviews/\(id).json")
    }
    private func loadLedgerArchive(_ id: String) throws -> CompanionPhoneLedgerArchive {
        guard let archive = try CompanionLocalFile.load(CompanionPhoneLedgerArchive.self, at: recoveryArchiveURL(id)),
              archive.id == id, archive.oldState.phoneID == local?.phoneID else {
            throw CompanionPacketError.invalid("The retained ledger comparison could not be opened.")
        }
        try archive.oldState.validate()
        _ = try fencedMacPacket(archive.reviewedEnvelope, phoneID: archive.oldState.phoneID)
        _ = try fencedMacPacket(archive.adoptedEnvelope, phoneID: archive.oldState.phoneID)
        for (key, record) in archive.originalRecords {
            try record.state.validate()
            guard record.state.scope.month == key, record.state.scope.phone == archive.oldState.phoneID else {
                throw CompanionPacketError.invalid("A retained original month has a different identity.")
            }
            guard try record.anchor.binding(for: record.state.scope).baselineDocument == record.state.base else {
                throw CompanionPacketError.invalid("A retained original month has no matching context.")
            }
        }
        return archive
    }
    private func effectiveRecoveryRecords(_ state: CompanionPhoneLocalState) throws -> [String: CompanionPhoneMonthRecord] {
        var records = state.months
        if let progress = state.recoveryProgress {
            let archive = try loadLedgerArchive(progress.archiveID)
            for key in Set(progress.choices.keys).union(progress.issues.keys) {
                guard let original = archive.originalRecords[key] else {
                    throw CompanionPacketError.invalid("The original pending recovery month is missing from its archive.")
                }
                records[key] = original
            }
        }
        return records
    }
    private func freshMonth(_ incoming: CompanionMacMonthPacket) -> CompanionPhoneRecovery.FreshMonth {
        let plan = incoming.current.scratchpad.plan
        return .init(scope: incoming.scope,
            identity: .init(planID: plan.id, calculationIdentity: plan.calculationVersion.rawValue),
            bootstrap: incoming.initialDocument, current: incoming.currentDocument,
            revision: incoming.advertisement.revision, completedSequence: incoming.bootstrapCompletedSequence,
            context: incoming.current)
    }
    private func recoveryReview(old: CompanionPhoneMonthRecord, incoming: CompanionMacMonthPacket,
                               envelope: CompanionEnvelope, acknowledged: CompanionMerge.PhoneMonthState?) throws -> CompanionPhoneRecovery.Review {
        // Check original identities before interpreting any cross-ledger financial groups.
        let a = old.anchor.scratchpad.plan, b = incoming.current.scratchpad.plan
        guard old.state.scope.phone == incoming.scope.phone, old.state.scope.month == incoming.scope.month,
              a.workspaceID == b.workspaceID, a.id == b.id, a.month == b.month,
              a.calculationVersion == b.calculationVersion else {
            throw CompanionPacketError.invalid("The plan, workspace, month or calculation identity changed. The original plan remains retained.")
        }
        guard old.selectedHistoryAccountIDs.isSubset(of: incoming.current.context.allHistoryAccountIDs) else {
            throw CompanionPacketError.invalid("A retained history-account selection is unavailable in the new ledger. Keep it for review.")
        }
        guard !old.unencodedDraft, old.hold == nil else {
            throw CompanionPacketError.invalid("The original phone contains an edit or held evidence that needs separate review. It remains retained exactly.")
        }
        let review = try CompanionPhoneRecovery.review(oldPhone: old.state,
            oldIdentity: .init(planID: a.id, calculationIdentity: a.calculationVersion.rawValue),
            fresh: freshMonth(incoming), publicationID: CompanionEnvelope.hash(try envelope.encoded()),
            generation: envelope.generation, acknowledgedFresh: acknowledged)
        let binding = try incoming.current.binding(for: incoming.scope)
        // Reject unknown account, currency, occurrence, source or row authority on either
        // offered choice. A complete generic merge does not certify financial meaning.
        for side in [true, false] {
            let choice = try review.choose(phoneForConflicts: side, currentOld: old.state,
                currentMonth: freshMonth(incoming), currentGeneration: envelope.generation)
            _ = try MonthlyPlanSyncAdapter.decode(document: choice.document, against: binding)
        }
        return review
    }
    private func bootstrapRecord(_ incoming: CompanionMacMonthPacket) throws -> CompanionPhoneMonthRecord {
        guard incoming.bootstrapCompletedSequence == 0 else {
            throw CompanionPacketError.invalid("The fresh month's acknowledged phone state is missing; it cannot be restarted.")
        }
        return .init(state: try CompanionMerge.PhoneMonthState(scope: incoming.scope,
            initial: incoming.initialDocument).observing(incoming.advertisement),
            anchor: incoming.bootstrap, scratchpad: incoming.bootstrap.scratchpad,
            metadata: incoming.bootstrap.metadata,
            selectedHistoryAccountIDs: incoming.bootstrap.context.allHistoryAccountIDs.subtracting(incoming.bootstrap.excludedHistoryAccountIDs))
    }
    private func planPresentation(_ record: CompanionPhoneMonthRecord) -> CompanionRecoveryPlanPresentation {
        let c = record.anchor.context
        return .init(editor: PortableMonthlyPlanEditor(scratchpad: record.scratchpad,
            lexicalContext: MonthlyPlanSyncAdapter.lexicalContext(from: record.metadata),
            accounts: c.accounts.map { .init(id: $0.id, nativeCurrency: $0.currency, isHistoryOnly: $0.isHistoryOnly) },
            allHistoryAccountIDs: c.allHistoryAccountIDs, selectedHistoryAccountIDs: c.allHistoryAccountIDs,
            manuallyExcludedPlanningAccountIDs: c.manuallyExcludedPlanningAccountIDs,
            receipt: c.receipt?.state, receiptBasis: c.receiptBasis, canEdit: false),
            accountLabels: (c.displayAccounts ?? c.accounts).map { .init(id: $0.id, title: $0.title, context: $0.context, currency: $0.currency.code) },
            relatedCards: c.relatedCards.map { .init(id: $0.id, title: $0.title, context: $0.context, currency: $0.currency.code) },
            sourceContext: c.sourceContext)
    }
    private func presentation(id: String, originals: [String: CompanionPhoneMonthRecord], packet: CompanionMacPacket,
                              keys: [String], reviews: [String: CompanionPhoneRecovery.Review], issues: [String: String],
                              choices: [String: CompanionRecoverySide]) -> CompanionPhoneLedgerRecoveryPresentation {
        let months = keys.map { key -> CompanionRecoveryMonthPresentation in
            let fresh = packet.months[key]
            let macRecord = fresh.flatMap { incoming -> CompanionPhoneMonthRecord? in
                guard let state = try? CompanionMerge.PhoneMonthState(scope: incoming.scope, initial: incoming.currentDocument) else { return nil }
                return CompanionPhoneMonthRecord(
                state: state,
                anchor: incoming.current, scratchpad: incoming.current.scratchpad, metadata: incoming.current.metadata,
                selectedHistoryAccountIDs: incoming.current.context.allHistoryAccountIDs) }
            let conflicts = reviews[key]?.comparison.conflicts ?? []
            let readiness: CompanionRecoveryMonthPresentation.Readiness = issues[key].map { .held($0) }
                ?? (conflicts.isEmpty ? .independentChanges : .chooseConflicts)
            return .init(id: key, title: key, readiness: readiness,
                conflictingEntryNames: Array(Set(conflicts.map(\.itemID))).sorted().enumerated().map { "Conflicting entry \($0.offset + 1)" },
                oldPhone: originals[key].map(planPresentation), newMac: macRecord.map(planPresentation),
                phoneIssue: originals[key] == nil ? "This month exists only in the new Mac ledger." : nil,
                macIssue: fresh == nil ? "This month is absent from the new Mac ledger. Its complete phone plan is retained." : nil)
        }
        return .init(id: id, oldLedgerLabel: "Retained iPhone ledger", newLedgerLabel: "Current Mac ledger",
                     phoneID: packet.phoneID, months: months, recordedChoices: choices)
    }
    func prepareLedgerRecoveryReview() {
        guard !isChecking, retentionFailure == nil, let state = local else { return }
        do {
            guard state.versionReview == nil else {
                throw CompanionPacketError.invalid("Resolve this folder's versions or explicitly retain them and choose another folder before reviewing the ledger.")
            }
            guard let envelope = state.heldEnvelope ?? state.lastMacEnvelope else { return }
            let packet = try fencedMacPacket(envelope, phoneID: state.phoneID)
            let pair = CompanionPhonePairing(session: envelope.sessionID, epoch: envelope.activationEpoch, lineage: packet.snapshot.ledgerLineage)
            let samePair = pair == state.pairing
            if samePair && (state.recoveryProgress?.issues.isEmpty ?? true) {
                throw CompanionPacketError.invalid("No recovery month currently needs another review.")
            }
            let originals = try effectiveRecoveryRecords(state)
            let keys = samePair ? state.recoveryProgress!.issues.keys.sorted()
                : Set(originals.keys).union(packet.months.keys).sorted()
            var reviews: [String: CompanionPhoneRecovery.Review] = [:], issues: [String: String] = [:]
            for key in keys {
                guard let incoming = packet.months[key] else { issues[key] = "This month is missing from the new Mac ledger."; continue }
                guard let old = originals[key] else {
                    do { _ = try bootstrapRecord(incoming) } catch { issues[key] = error.localizedDescription }
                    continue
                }
                do {
                    reviews[key] = try recoveryReview(old: old, incoming: incoming, envelope: envelope,
                        acknowledged: samePair ? state.months[key]?.state : nil)
                } catch { issues[key] = error.localizedDescription }
            }
            let id = UUID().uuidString
            ledgerRecoveryReview = .init(id: id, oldState: state, originalRecords: originals, envelope: envelope,
                reviews: reviews, issues: issues, keys: keys, samePair: samePair,
                presentation: presentation(id: id, originals: originals, packet: packet, keys: keys,
                    reviews: reviews, issues: issues, choices: [:]))
        } catch { connectionMessage = "The ledger comparison could not be prepared. All saved data remains retained. \(error.localizedDescription)" }
    }
    func closeLedgerRecoveryReview() { ledgerRecoveryReview = nil }
    func ledgerArchivePresentation(_ id: String) throws -> CompanionPhoneLedgerRecoveryPresentation {
        guard ledgerArchiveIDs.contains(id) else { throw CompanionPacketError.invalid("This ledger archive is not linked to the phone state.") }
        let archive = try loadLedgerArchive(id)
        let packet = try fencedMacPacket(archive.reviewedEnvelope, phoneID: archive.oldState.phoneID)
        let keys = archive.choices.keys.sorted()
        var reviews: [String: CompanionPhoneRecovery.Review] = [:], issues: [String: String] = [:]
        for key in keys {
            if archive.choices[key] == .retainForReview { issues[key] = "The original phone plan was retained for later review."; continue }
            if let old = archive.originalRecords[key], let incoming = packet.months[key] {
                reviews[key] = try? recoveryReview(old: old, incoming: incoming, envelope: archive.reviewedEnvelope,
                    acknowledged: archive.oldState.pairing?.session == incoming.scope.session ? archive.oldState.months[key]?.state : nil)
            }
        }
        return presentation(id: id, originals: archive.originalRecords, packet: packet, keys: keys,
            reviews: reviews, issues: issues, choices: archive.choices)
    }
    func confirmLedgerRecovery(reviewID: String, choices: [String: CompanionRecoverySide]) async {
        guard !isChecking, retentionFailure == nil, let reviewed = ledgerRecoveryReview,
              reviewed.id == reviewID, let current = local else { return }
        do {
            guard current.versionReview == nil else {
                throw CompanionPacketError.invalid("The selected folder has unresolved versions. Resolve them or explicitly retain them and choose another folder before confirming this ledger.")
            }
            // Ignore only observation timestamps/held-envelope churn. Any logical user or
            // protocol mutation invalidates the open comparison rather than losing edits.
            guard current.pairing == reviewed.oldState.pairing, current.months == reviewed.oldState.months,
                  current.connection == reviewed.oldState.connection,
                  current.outboundEnvelope == reviewed.oldState.outboundEnvelope,
                  current.recoveryProgress == reviewed.oldState.recoveryProgress else {
                throw CompanionPacketError.invalid("Saved phone plans changed while this comparison was open. Prepare the comparison again.")
            }
            guard let latestEnvelope = current.heldEnvelope ?? current.lastMacEnvelope else { return }
            let packet = try fencedMacPacket(latestEnvelope, phoneID: current.phoneID)
            guard latestEnvelope.sessionID == reviewed.envelope.sessionID,
                  latestEnvelope.activationEpoch == reviewed.envelope.activationEpoch,
                  latestEnvelope.generation >= reviewed.envelope.generation else {
                throw CompanionPacketError.invalid("A different ledger publication arrived. Prepare the comparison again.")
            }
            let reviewedPacket = try fencedMacPacket(reviewed.envelope, phoneID: current.phoneID)
            var selected: [String: CompanionPhoneRecovery.Choice] = [:]
            var recorded: [String: CompanionRecoverySide] = [:]
            guard Set(choices.keys).isSubset(of: Set(reviewed.keys)) else {
                throw CompanionPacketError.invalid("The choices belong to another comparison.")
            }
            for key in reviewed.keys {
                if reviewed.issues[key] != nil {
                    guard choices[key] == .retainForReview else { throw CompanionPacketError.invalid("Explicitly retain each month that cannot be merged.") }
                    // A held month must not silently acquire a different Mac alternative.
                    guard packet.months[key] == reviewedPacket.months[key] else {
                        throw CompanionPacketError.invalid("A held Mac month changed. Review its new context first.")
                    }
                    recorded[key] = .retainForReview
                } else if let review = reviewed.reviews[key], let old = reviewed.originalRecords[key] {
                    let hasConflicts = !review.comparison.isComplete
                    guard !hasConflicts || choices[key] == .phone || choices[key] == .mac else {
                        throw CompanionPacketError.invalid("Choose a side for every conflicting month.")
                    }
                    let side = choices[key] ?? .phone
                    guard side != .retainForReview else { throw CompanionPacketError.invalid("This compatible month requires the reviewed merge choice.") }
                    let choice = try review.choose(phoneForConflicts: side == .phone, currentOld: old.state,
                        currentMonth: packet.months[key].map(freshMonth), currentGeneration: latestEnvelope.generation)
                    guard let incoming = packet.months[key] else { throw CompanionPhoneRecovery.RecoveryError.missingMonth }
                    _ = try MonthlyPlanSyncAdapter.decode(document: choice.document, against: incoming.current.binding(for: incoming.scope))
                    selected[key] = choice; recorded[key] = side
                } else {
                    guard let incoming = packet.months[key], incoming == reviewedPacket.months[key] else {
                        throw CompanionPacketError.invalid("A new Mac month changed. Review its context first.")
                    }
                    _ = try bootstrapRecord(incoming); recorded[key] = .mac
                }
            }
            let archive = CompanionPhoneLedgerArchive(id: reviewed.id, oldState: current,
                originalRecords: reviewed.originalRecords, reviewedEnvelope: reviewed.envelope,
                adoptedEnvelope: latestEnvelope, choices: recorded)
            let url = try recoveryArchiveURL(archive.id)
            try CompanionLocalFile.save(archive, to: url)
            guard try CompanionLocalFile.load(CompanionPhoneLedgerArchive.self, at: url) == archive else {
                throw CompanionPacketError.invalid("The complete ledger comparison could not be verified on disk.")
            }
            var next = current
            var pending = reviewed.samePair ? (next.recoveryProgress?.choices ?? [:]) : [:]
            var issues = reviewed.samePair ? (next.recoveryProgress?.issues ?? [:]) : [:]
            if !reviewed.samePair {
                next.pairing = .init(session: latestEnvelope.sessionID, epoch: latestEnvelope.activationEpoch, lineage: packet.snapshot.ledgerLineage)
                next.months = [:]; next.outboundEnvelope = nil; next.publishedGeneration = nil
                for (key, incoming) in packet.months {
                    if incoming.bootstrapCompletedSequence == 0 { next.months[key] = try bootstrapRecord(incoming) }
                    else if recorded[key] != .retainForReview {
                        throw CompanionPacketError.invalid("An acknowledged Mac month lacks its retained phone state.")
                    }
                }
            }
            for key in reviewed.keys {
                issues.removeValue(forKey: key); pending.removeValue(forKey: key)
                if let choice = selected[key], var record = next.months[key] {
                    let send = try choice.beginHandshake()
                    record.state = send.state; record.hold = nil; record.heldPacket = nil
                    next.months[key] = record; pending[key] = choice
                } else if reviewed.samePair, packet.months[key] == nil, var record = next.months[key] {
                    record.hold = "This month is absent from the current Mac ledger. Its acknowledged phone state and original plan remain retained."
                    next.months[key] = record
                }
            }
            next.recoveryProgress = pending.isEmpty ? nil : .init(archiveID: archive.id, choices: pending, issues: issues)
            var ids = next.ledgerReviewIDs ?? []; ids.append(archive.id); next.ledgerReviewIDs = ids
            next.lastMacEnvelope = latestEnvelope; next.lastCheckedAt = Date(); next.heldEnvelope = nil; next.hold = nil
            if next.selectedMonth.flatMap({ next.months[$0] }) == nil { next.selectedMonth = next.months.keys.sorted().last }
            // Archive was verified before any pairing/outbound reset. The entire new
            // provisional state is retained before transport can publish a handshake.
            if retain(next) { ledgerRecoveryReview = nil; requestSync() }
        } catch { connectionMessage = "The ledger choice was not applied. Both versions remain retained. \(error.localizedDescription)" }
    }

    @inline(never)
    private func acceptRecoveryMonth(_ record: inout CompanionPhoneMonthRecord, incoming: CompanionMacMonthPacket,
                                     envelope: CompanionEnvelope, progress: inout CompanionPhoneRecoveryProgress) throws {
        guard progress.choices[incoming.scope.month] != nil else { return }
        try receiveRecoveryReceipt(&record, incoming: incoming)
        guard record.state.outstanding == nil else { return }
        do {
            // Load/validate the archive before allocating merge-specific value locals.
            let archive = try loadLedgerArchive(progress.archiveID)
            try applyRecoveryMerge(&record, incoming: incoming, envelope: envelope,
                archive: archive, progress: &progress)
        } catch {
            // The valid real receipt stays advanced. A new review uses this actual base
            // and next sequence; it never replays/restarts the original handshake.
            progress.issues[incoming.scope.month] = "The Mac month changed during recovery or needs authority review. The acknowledged state and original phone plan are retained. \(error.localizedDescription)"
        }
    }

    @inline(never)
    private func receiveRecoveryReceipt(_ record: inout CompanionPhoneMonthRecord,
                                        incoming: CompanionMacMonthPacket) throws {
        record.state = try record.state.observing(incoming.advertisement)
        if let reply = incoming.reply {
            let received = try record.state.receiving(reply)
            if received.kind == .accepted || received.kind == .needsResolution {
                guard let anchor = incoming.replyAnchor else { throw CompanionPacketError.invalid("The recovery receipt context is missing.") }
                record.state = received.state
                record.anchor = anchor; record.scratchpad = anchor.scratchpad; record.metadata = anchor.metadata
                record.selectedHistoryAccountIDs = anchor.context.allHistoryAccountIDs.subtracting(anchor.excludedHistoryAccountIDs)
                record.unencodedDraft = false; record.hold = nil; record.heldPacket = nil
            }
        }
    }

    @inline(never)
    private func applyRecoveryMerge(_ record: inout CompanionPhoneMonthRecord, incoming: CompanionMacMonthPacket,
                                    envelope: CompanionEnvelope, archive: CompanionPhoneLedgerArchive,
                                    progress: inout CompanionPhoneRecoveryProgress) throws {
        guard let choice = progress.choices[incoming.scope.month] else { return }
        guard let old = archive.originalRecords[incoming.scope.month], let replyAnchor = incoming.replyAnchor else {
            throw CompanionPacketError.invalid("Original recovery or receipt context is unavailable.")
        }
        let send = try choice.prepareMergedProposal(handshake: record.state, currentOld: old.state,
            replyContext: replyAnchor, currentMonth: freshMonth(incoming), currentGeneration: envelope.generation)
        let decoded = try MonthlyPlanSyncAdapter.decode(document: send.state.draft,
            against: incoming.current.binding(for: incoming.scope))
        record.state = send.state; record.anchor = incoming.current
        record.scratchpad = decoded.scratchpad; record.metadata = decoded.metadata
        record.selectedHistoryAccountIDs = old.selectedHistoryAccountIDs
        record.unencodedDraft = false; record.hold = nil; record.heldPacket = nil
        progress.choices.removeValue(forKey: incoming.scope.month); progress.issues.removeValue(forKey: incoming.scope.month)
    }
    func retryHeldEvidence() {
        guard !isChecking, retentionFailure == nil, let state = local,
              let envelope = state.heldEnvelope ?? state.lastMacEnvelope else { return }
        do { try accept(envelope, retryHeld: true); if retentionFailure == nil { requestSync() } }
        catch { connectionMessage = "The same retained evidence still needs review. \(error.localizedDescription)" }
    }
}

nonisolated struct CompanionPhoneFolderVersionArchive: Codable, Equatable, Sendable {
    let id: String
    let oldState: CompanionPhoneLocalState
    let review: CompanionPhoneVersionReview
}
@MainActor struct CompanionPhoneFolderVersionArchivePresentation: Identifiable {
    let id: String
    let writer: CompanionWriter
    let choices: [CompanionFileChoice]
}

extension CompanionPhoneModel {
    var versionArchiveIDs: [String] { local?.folderVersionArchiveIDs ?? [] }
    private func folderVersionArchiveURL(_ id: String) throws -> URL {
        guard UUID(uuidString: id) != nil else { throw CompanionPacketError.invalid("The retained folder review reference is invalid.") }
        return directory.appendingPathComponent("FolderVersionReviews/\(id).json")
    }
    func versionArchivePresentation(_ id: String) throws -> CompanionPhoneFolderVersionArchivePresentation {
        guard versionArchiveIDs.contains(id),
              let archive = try CompanionLocalFile.load(CompanionPhoneFolderVersionArchive.self, at: folderVersionArchiveURL(id)),
              archive.id == id, archive.oldState.phoneID == local?.phoneID,
              archive.oldState.versionReview == archive.review else {
            throw CompanionPacketError.invalid("The retained folder versions could not be opened.")
        }
        try archive.oldState.validate()
        // Return the exact verified old local alternatives. These are read-only and
        // must never be passed to resolveVersion against the newly selected folder.
        return .init(id: id, writer: archive.review.writer, choices: try loadChoices(archive.review))
    }
    /// Call only after the UI explicitly confirms retention of unresolved alternatives
    /// and choosing a different folder. This does not resolve or delete old versions.
    func chooseFolderRetainingVersions(_ url: URL) {
        changeFolder(url, retainingUnresolvedVersions: true)
    }
    private func changeFolder(_ url: URL, retainingUnresolvedVersions: Bool) {
        guard !isChecking, retentionFailure == nil, let before = local else { return }
        if before.versionReview != nil && !retainingUnresolvedVersions {
            connectionMessage = "Resolve the current folder's versions, or explicitly retain them before choosing another folder."
            return
        }
        isChecking = true
        Task {
            defer { isChecking = false }
            // select changes the transport's internal URL even if later CAS/archive
            // retention fails. Force the next sync to restore its retained connection.
            restoredConnection = false
            do {
                let connection = try await transport.select(url)
                guard var next = local, next.connection == before.connection,
                      next.versionReview == before.versionReview else {
                    throw CompanionPacketError.invalid("The folder or version review changed while the picker was open. Choose again from the current review.")
                }
                if let review = next.versionReview {
                    guard retainingUnresolvedVersions else { throw CompanionTransportError.changedDuringReview }
                    _ = try loadChoices(review)
                    let archive = CompanionPhoneFolderVersionArchive(id: UUID().uuidString,
                        oldState: next, review: review)
                    let url = try folderVersionArchiveURL(archive.id)
                    try CompanionLocalFile.save(archive, to: url)
                    guard try CompanionLocalFile.load(CompanionPhoneFolderVersionArchive.self, at: url) == archive else {
                        throw CompanionPacketError.invalid("The complete old folder review could not be verified on disk.")
                    }
                    _ = try loadChoices(review)
                    var ids = next.folderVersionArchiveIDs ?? []; ids.append(archive.id)
                    next.folderVersionArchiveIDs = ids
                    next.versionReview = nil
                }
                next.connection = connection
                // Clear a cached comparison tied to the previous connection; all its
                // original states remain retained and can be prepared again explicitly.
                if retain(next) {
                    versionChoices = []; ledgerRecoveryReview = nil
                    restoredConnection = true; requestSync()
                }
            } catch {
                connectionMessage = "The folder change was not completed. Old versions and saved plans remain retained. \(error.localizedDescription)"
            }
        }
    }
}

// Append in CompanionPhoneModel.swift so existing private archive/presentation helpers
// remain scoped to the model. Read-only: never installs a draft or publishes a file.
extension CompanionPhoneModel {
    func versionArchivePlanPresentation(archiveID: String, choiceID: String) throws -> CompanionPhoneLedgerRecoveryPresentation {
        let available = try versionArchivePresentation(archiveID)
        guard let choice = available.choices.first(where: { $0.id == choiceID }) else {
            throw CompanionPacketError.invalid("This version is not among the exact retained alternatives.")
        }
        guard let envelope = choice.envelope else {
            throw CompanionPacketError.invalid("This retained version cannot be decoded: \(choice.issue ?? "Invalid companion envelope.") Its original bytes remain retained.")
        }
        guard let archive = try CompanionLocalFile.load(CompanionPhoneFolderVersionArchive.self,
            at: folderVersionArchiveURL(archiveID)), archive.id == archiveID,
              archive.oldState.phoneID == local?.phoneID,
              archive.oldState.versionReview == archive.review,
              archive.review.writer == envelope.writer,
              archive.review.choiceIDs.contains(choiceID) else {
            throw CompanionPacketError.invalid("The original folder review no longer matches this retained alternative.")
        }
        try archive.oldState.validate()
        let previewID = archiveID + ":" + choiceID
        switch envelope.writer {
        case .mac:
            let packet = try fencedMacPacket(envelope, phoneID: archive.oldState.phoneID)
            let originals = try effectiveRecoveryRecords(archive.oldState)
            let keys = Set(originals.keys).union(packet.months.keys).sorted()
            let issues = Dictionary(uniqueKeysWithValues: keys.map {
                ($0, "Read-only retained Mac publication. No pairing or plan changes are made by opening this alternative.")
            })
            return presentation(id: previewID, originals: originals, packet: packet,
                keys: keys, reviews: [:], issues: issues, choices: [:])
        case .phone:
            guard let pair = archive.oldState.pairing,
                  envelope.sessionID == pair.session, envelope.activationEpoch == pair.epoch else {
                throw CompanionPacketError.invalid("This retained phone version belongs to another pairing or ledger activation. Its bytes remain retained, but it cannot be interpreted using this archive's plan authority.")
            }
            let packet = try JSONDecoder().decode(CompanionPhonePacket.self, from: envelope.payload)
            try packet.validate(envelope: envelope, expectedPhoneID: archive.oldState.phoneID, lineage: pair.lineage)
            let months = packet.proposals.sorted { $0.scope.month < $1.scope.month }.map { proposal -> CompanionRecoveryMonthPresentation in
                let key = proposal.scope.month
                do {
                    guard let original = archive.oldState.months[key], original.state.scope == proposal.scope else {
                        throw CompanionPacketError.invalid("No matching original monthly scope is retained for this phone proposal.")
                    }
                    let binding = try original.anchor.binding(for: original.state.scope)
                    guard proposal.base == binding.baselineDocument,
                          proposal.baseRevision == original.state.baseRevision else {
                        throw CompanionPacketError.invalid("This proposal's original agreed base differs from the retained monthly authority. Its exact values cannot be safely previewed using a later plan context.")
                    }
                    let decoded = try MonthlyPlanSyncAdapter.decode(document: proposal.proposed, against: binding)
                    // Present exact decoded proposal values, not the later archived editor
                    // draft. This temporary wrapper is never saved or used for syncing.
                    var preview = original
                    preview.scratchpad = decoded.scratchpad; preview.metadata = decoded.metadata
                    return .init(id: key, title: key,
                        readiness: .held("Read-only retained phone proposal. Opening it does not apply or send these edits."),
                        conflictingEntryNames: [], oldPhone: planPresentation(preview), newMac: nil,
                        phoneIssue: nil, macIssue: "This is a phone publication; it contains no Mac alternative.")
                } catch {
                    return .init(id: key, title: key,
                        readiness: .held("This retained phone proposal cannot be interpreted using the available original authority."),
                        conflictingEntryNames: [], oldPhone: nil, newMac: nil,
                        phoneIssue: "\(error.localizedDescription) The complete original version remains retained.",
                        macIssue: "This is a phone publication; it contains no Mac alternative.")
                }
            }
            return .init(id: previewID, oldLedgerLabel: "Retained phone publication",
                newLedgerLabel: "No Mac alternative in this publication", phoneID: packet.phoneID,
                months: months, recordedChoices: [:])
        }
    }
}
