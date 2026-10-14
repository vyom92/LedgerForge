import Foundation

/// Portable two-device mechanics; opaque nonfinancial item groups.
nonisolated public enum CompanionMerge {

    /// Generic mechanics only. No financial types, source fixtures or storage adapter.
    nonisolated public struct Item: Codable, Equatable, Sendable {
        /// Each value is one indivisible semantic group, encoded by the caller.
        public var groups: [String: String]
        public init(_ groups: [String: String]) { self.groups = groups }
    }
    public typealias Document = [String: Item]
    nonisolated public struct Conflict: Codable, Equatable, Sendable {
        public let itemID: String
        public let group: String? // nil means whole-item conflict, including delete/edit
        public let base: Item?
        public let local: Item?
        public let remote: Item?
    }
    nonisolated public struct MergeResult: Codable, Equatable, Sendable {
        /// Conflicted items are deliberately absent; do not persist this as a complete document.
        public var merged: Document
        public var conflicts: [Conflict]
        public var isComplete: Bool { conflicts.isEmpty }
    }
    nonisolated public enum ThreeWay {
        public static func merge(base: Document, local: Document, remote: Document) -> MergeResult {
            var result = MergeResult(merged: [:], conflicts: [])
            for id in Set(base.keys).union(local.keys).union(remote.keys).sorted() {
                let b = base[id], l = local[id], r = remote[id]
                if l == r { result.merged[id] = l; continue }
                if l == b { result.merged[id] = r; continue }
                if r == b { result.merged[id] = l; continue }
                // Concurrent insertion under the same identity, or delete versus edit.
                guard let b, let l, let r else {
                    result.conflicts.append(.init(itemID: id, group: nil, base: b, local: l, remote: r)); continue
                }
                var groups: [String: String] = [:]
                var itemConflicts: [Conflict] = []
                for key in Set(b.groups.keys).union(l.groups.keys).union(r.groups.keys).sorted() {
                    let bv = b.groups[key], lv = l.groups[key], rv = r.groups[key]
                    if lv == rv { groups[key] = lv }
                    else if lv == bv { groups[key] = rv }
                    else if rv == bv { groups[key] = lv }
                    else { itemConflicts.append(.init(itemID: id, group: key, base: b, local: l, remote: r)) }
                }
                if itemConflicts.isEmpty { result.merged[id] = Item(groups) }
                else { result.conflicts += itemConflicts }
            }
            return result
        }
    }


    /// Operational identities only; no financial domain or platform transport types.
    nonisolated public struct SyncScope: Codable, Equatable, Sendable {
        public let lineage: String
        public let session: String
        public let phone: String
        public let month: String
        public init(lineage: String, session: String, phone: String, month: String) {
            self.lineage = lineage; self.session = session; self.phone = phone; self.month = month
        }
        public func validate() throws {
            guard !lineage.isEmpty, !session.isEmpty, !phone.isEmpty, !month.isEmpty else { throw ProtocolError.invalidScope }
        }
        fileprivate func require(_ incoming: SyncScope) throws {
            try validate(); try incoming.validate()
            guard incoming.lineage == lineage else { throw ProtocolError.lineage }
            guard incoming.session == session else { throw ProtocolError.session }
            guard incoming.phone == phone else { throw ProtocolError.phone }
            guard incoming.month == month else { throw ProtocolError.month }
        }
    }
    nonisolated public enum ProtocolError: Error, Equatable {
        case unsupportedFormat, invalidScope, invalidDocument, invalidState
        case lineage, session, phone, month, staleBase, sequenceGap, identityCollision
        case invalidReply, noOutstandingProposal, noConflict, resolutionRequired, staleResolution, counterExhausted
    }
    private static func validateDocument(_ document: Document) throws {
        guard document.keys.allSatisfy({ !$0.isEmpty }),
              document.values.allSatisfy({ $0.groups.keys.allSatisfy { !$0.isEmpty } }) else {
            throw ProtocolError.invalidDocument
        }
    }
    private static func increment(_ value: UInt64) throws -> UInt64 {
        guard value < UInt64.max else { throw ProtocolError.counterExhausted }
        return value + 1
    }

    nonisolated public struct Proposal: Codable, Equatable, Sendable {
        public let format: Int
        public let scope: SyncScope
        public let sequence: UInt64
        public let baseRevision: UInt64
        public let base: Document
        public let proposed: Document
        public init(scope: SyncScope, sequence: UInt64, baseRevision: UInt64, base: Document, proposed: Document) {
            self.format = 1; self.scope = scope; self.sequence = sequence
            self.baseRevision = baseRevision; self.base = base; self.proposed = proposed
        }
        public func validate() throws {
            guard format == 1 else { throw ProtocolError.unsupportedFormat }
            try scope.validate(); try CompanionMerge.validateDocument(base); try CompanionMerge.validateDocument(proposed)
            guard sequence > 0 else { throw ProtocolError.sequenceGap }
        }
    }
    nonisolated public enum ReplyOutcome: String, Codable, Sendable { case applied, conflict }
    nonisolated public struct Reply: Codable, Equatable, Sendable {
        public let format: Int
        /// The exact proposal is retained, not merely its sequence or a weak hash.
        public let proposal: Proposal
        public let macBeforeRevision: UInt64
        public let macBefore: Document
        public let resultRevision: UInt64
        public let result: Document
        public let outcome: ReplyOutcome

        fileprivate init(proposal: Proposal, macBeforeRevision: UInt64, macBefore: Document,
                         resultRevision: UInt64, result: Document, outcome: ReplyOutcome) {
            self.format = 1; self.proposal = proposal; self.macBeforeRevision = macBeforeRevision
            self.macBefore = macBefore; self.resultRevision = resultRevision; self.result = result; self.outcome = outcome
        }
        /// Deterministically check the receipt's merge decision, including revisions.
        public func validate() throws {
            guard format == 1 else { throw ProtocolError.unsupportedFormat }
            try proposal.validate(); try CompanionMerge.validateDocument(macBefore); try CompanionMerge.validateDocument(result)
            guard macBeforeRevision >= proposal.baseRevision else { throw ProtocolError.invalidReply }
            if macBeforeRevision == proposal.baseRevision, macBefore != proposal.base { throw ProtocolError.invalidReply }
            let merge = ThreeWay.merge(base: proposal.base, local: macBefore, remote: proposal.proposed)
            if merge.isComplete {
                let expectedRevision = merge.merged == macBefore ? macBeforeRevision : try CompanionMerge.increment(macBeforeRevision)
                guard outcome == .applied, result == merge.merged, resultRevision == expectedRevision else {
                    throw ProtocolError.invalidReply
                }
            } else {
                guard outcome == .conflict, result == macBefore, resultRevision == macBeforeRevision else {
                    throw ProtocolError.invalidReply
                }
            }
        }
    }
    nonisolated public struct MacAdvertisement: Codable, Equatable, Sendable {
        public let format: Int
        public let scope: SyncScope
        public let revision: UInt64
        fileprivate init(scope: SyncScope, revision: UInt64) { format = 1; self.scope = scope; self.revision = revision }
    }
    nonisolated public enum MacReceiveKind: Equatable, Sendable { case applied, conflict, replayed, obsolete }
    nonisolated public struct MacReceive: Sendable {
        public let state: MacMonthState
        /// Send only after state + actual editor/canonical mutation commit atomically.
        public let reply: Reply?
        public let kind: MacReceiveKind
    }

    nonisolated public struct MacMonthState: Codable, Equatable, Sendable {
        public let format: Int
        public let scope: SyncScope
        public private(set) var revision: UInt64
        public private(set) var current: Document
        /// The only base the next proposal may use. An unreceived reply remains retryable.
        public private(set) var baseRevision: UInt64
        public private(set) var base: Document
        public private(set) var lastReply: Reply?
        public private(set) var completedSequence: UInt64

        public init(scope: SyncScope, initial: Document) throws {
            format = 1; self.scope = scope; revision = 0; current = initial
            baseRevision = 0; base = initial; lastReply = nil; completedSequence = 0
            try validate()
        }
        public func validate() throws {
            guard format == 1 else { throw ProtocolError.unsupportedFormat }
            try scope.validate(); try CompanionMerge.validateDocument(current); try CompanionMerge.validateDocument(base)
            guard revision >= baseRevision else { throw ProtocolError.invalidState }
            if revision == baseRevision, current != base { throw ProtocolError.invalidState }
            if let lastReply {
                guard completedSequence == lastReply.proposal.sequence else { throw ProtocolError.invalidState }
                try lastReply.validate(); try scope.require(lastReply.proposal.scope)
                guard baseRevision == lastReply.resultRevision, base == lastReply.result else { throw ProtocolError.invalidState }
            } else if baseRevision != 0 || completedSequence != 0 { throw ProtocolError.invalidState }
        }
        public func editing(_ document: Document) throws -> Self {
            try validate(); try CompanionMerge.validateDocument(document)
            var next = self
            if current != document { next.revision = try CompanionMerge.increment(revision); next.current = document }
            return next
        }
        public var advertisement: MacAdvertisement { .init(scope: scope, revision: revision) }

        public func receiving(_ proposal: Proposal) throws -> MacReceive {
            try validate(); try proposal.validate(); try scope.require(proposal.scope)
            let processed = completedSequence
            if proposal.sequence < processed { return .init(state: self, reply: nil, kind: .obsolete) }
            if proposal.sequence == processed, let lastReply {
                guard proposal == lastReply.proposal else { throw ProtocolError.identityCollision }
                return .init(state: self, reply: lastReply, kind: .replayed)
            }
            guard proposal.sequence == (try CompanionMerge.increment(processed)) else { throw ProtocolError.sequenceGap }
            guard proposal.baseRevision == baseRevision, proposal.base == base else { throw ProtocolError.staleBase }
            let merge = ThreeWay.merge(base: base, local: current, remote: proposal.proposed)
            var next = self
            if merge.isComplete, merge.merged != current {
                next.current = merge.merged; next.revision = try CompanionMerge.increment(revision)
            }
            let reply = Reply(proposal: proposal, macBeforeRevision: revision, macBefore: current,
                              resultRevision: next.revision, result: next.current,
                              outcome: merge.isComplete ? .applied : .conflict)
            next.baseRevision = reply.resultRevision; next.base = reply.result; next.lastReply = reply
            next.completedSequence = proposal.sequence
            try next.validate()
            return .init(state: next, reply: reply, kind: merge.isComplete ? .applied : .conflict)
        }
    }

    nonisolated public enum ReconciliationCause: String, Codable, Sendable {
        case macConflict, editsAfterSending
    }
    nonisolated public struct Reconciliation: Codable, Equatable, Sendable {
        public let sequence: UInt64
        public let cause: ReconciliationCause
        public let ancestor: Document
    }
    nonisolated public struct ResolutionContext: Equatable, Sendable {
        public let sequence: UInt64
        public let cause: ReconciliationCause
        public let ancestor: Document
        public let local: Document
        public let remote: Document
        public var merge: MergeResult { ThreeWay.merge(base: ancestor, local: local, remote: remote) }

        /// Selects a side only for genuine conflicts; every independent group survives.
        /// Caller must still pass this exact context to PhoneMonthState.resolving.
        public func resolvedDocument(choosingLocalForConflicts: Bool) -> Document {
            var result: Document = [:]
            for id in Set(ancestor.keys).union(local.keys).union(remote.keys).sorted() {
                let b = ancestor[id], l = local[id], r = remote[id]
                if l == r { result[id] = l; continue }
                if l == b { result[id] = r; continue }
                if r == b { result[id] = l; continue }
                // Concurrent insertion or delete/edit conflicts concern the whole item.
                guard let b, let l, let r else {
                    result[id] = choosingLocalForConflicts ? l : r
                    continue
                }
                var groups: [String: String] = [:]
                for key in Set(b.groups.keys).union(l.groups.keys).union(r.groups.keys).sorted() {
                    let bv = b.groups[key], lv = l.groups[key], rv = r.groups[key]
                    if lv == rv { groups[key] = lv }
                    else if lv == bv { groups[key] = rv }
                    else if rv == bv { groups[key] = lv }
                    else { groups[key] = choosingLocalForConflicts ? lv : rv }
                }
                result[id] = Item(groups)
            }
            return result
        }
    }
    nonisolated public struct PhoneSend: Sendable {
        public let state: PhoneMonthState
        /// Send only after the outstanding proposal is durably retained locally.
        public let proposal: Proposal
    }
    nonisolated public enum PhoneReceiveKind: Equatable, Sendable { case accepted, needsResolution, replayed, obsolete }
    nonisolated public struct PhoneReceive: Sendable {
        public let state: PhoneMonthState
        public let kind: PhoneReceiveKind
    }
    nonisolated public enum PhonePhase: String, Codable, Sendable {
        case editable, awaitingReply, needsResolution, resolutionChosen
    }
    nonisolated public struct PhoneMonthState: Codable, Equatable, Sendable {
        public let format: Int
        public let scope: SyncScope
        public private(set) var baseRevision: UInt64
        public private(set) var base: Document
        public private(set) var draft: Document
        public private(set) var observedMacRevision: UInt64
        public private(set) var outstanding: Proposal?
        public private(set) var lastReply: Reply?
        public private(set) var reconciliation: Reconciliation?
        /// An explicit/automatic conflict choice is confirmed even when it equals the Mac base.
        public private(set) var confirmationPending: Bool
        /// Mandatory evidence of pending/conflict/explicit-resolution disposition.
        public private(set) var phase: PhonePhase
        public private(set) var completedSequence: UInt64

        public init(scope: SyncScope, initial: Document) throws {
            format = 1; self.scope = scope; baseRevision = 0; base = initial; draft = initial
            observedMacRevision = 0; outstanding = nil; lastReply = nil; reconciliation = nil; confirmationPending = false; phase = .editable; completedSequence = 0
            try validate()
        }
        public func validate() throws {
            guard format == 1 else { throw ProtocolError.unsupportedFormat }
            try scope.validate(); try CompanionMerge.validateDocument(base); try CompanionMerge.validateDocument(draft)
            guard observedMacRevision >= baseRevision else { throw ProtocolError.invalidState }
            switch phase {
            case .editable:
                guard outstanding == nil, reconciliation == nil else { throw ProtocolError.invalidState }
            case .awaitingReply:
                guard outstanding != nil, reconciliation == nil else { throw ProtocolError.invalidState }
            case .needsResolution:
                guard outstanding == nil, reconciliation != nil else { throw ProtocolError.invalidState }
            case .resolutionChosen:
                guard outstanding == nil, reconciliation == nil, confirmationPending else { throw ProtocolError.invalidState }
            }
            if let lastReply {
                guard completedSequence == lastReply.proposal.sequence else { throw ProtocolError.invalidState }
                try lastReply.validate(); try scope.require(lastReply.proposal.scope)
                guard baseRevision == lastReply.resultRevision, base == lastReply.result else { throw ProtocolError.invalidState }
            } else if baseRevision != 0 || completedSequence != 0 { throw ProtocolError.invalidState }
            if let outstanding {
                try outstanding.validate(); try scope.require(outstanding.scope)
                guard reconciliation == nil, outstanding.base == base, outstanding.baseRevision == baseRevision,
                      outstanding.sequence == (try CompanionMerge.increment(completedSequence)) else { throw ProtocolError.invalidState }
            }
            if let reconciliation {
                guard outstanding == nil, let lastReply,
                      reconciliation.sequence == lastReply.proposal.sequence else { throw ProtocolError.invalidState }
                let applied = lastReply.outcome == .applied
                guard reconciliation.cause == (applied ? .editsAfterSending : .macConflict),
                      reconciliation.ancestor == (applied ? lastReply.proposal.proposed : lastReply.proposal.base) else {
                    throw ProtocolError.invalidState
                }
            }
        }
        public var needsExchange: Bool {
            reconciliation == nil && (outstanding != nil || confirmationPending || draft != base || observedMacRevision > baseRevision)
        }
        public var resolutionContext: ResolutionContext? {
            reconciliation.map { .init(sequence: $0.sequence, cause: $0.cause, ancestor: $0.ancestor, local: draft, remote: base) }
        }
        public func editing(_ document: Document) throws -> Self {
            try validate(); try CompanionMerge.validateDocument(document)
            var next = self; next.draft = document
            // Never mutate the already-published proposal or discard a conflict.
            return next
        }
        public func observing(_ advertisement: MacAdvertisement) throws -> Self {
            try validate()
            guard advertisement.format == 1 else { throw ProtocolError.unsupportedFormat }
            try scope.require(advertisement.scope)
            var next = self; next.observedMacRevision = max(observedMacRevision, advertisement.revision)
            return next
        }
        public func beginExchange() throws -> PhoneSend {
            try validate()
            guard reconciliation == nil else { throw ProtocolError.resolutionRequired }
            if let outstanding { return .init(state: self, proposal: outstanding) }
            let proposal = Proposal(scope: scope, sequence: try CompanionMerge.increment(completedSequence),
                                    baseRevision: baseRevision, base: base, proposed: draft)
            var next = self; next.outstanding = proposal; next.phase = .awaitingReply
            return .init(state: next, proposal: proposal)
        }
        public func receiving(_ reply: Reply) throws -> PhoneReceive {
            try validate(); try reply.validate(); try scope.require(reply.proposal.scope)
            let completed = completedSequence
            if reply.proposal.sequence < completed { return .init(state: self, kind: .obsolete) }
            if reply.proposal.sequence == completed, let lastReply {
                guard reply == lastReply else { throw ProtocolError.identityCollision }
                return .init(state: self, kind: .replayed)
            }
            guard let outstanding else { throw ProtocolError.noOutstandingProposal }
            guard reply.proposal.sequence == outstanding.sequence else { throw ProtocolError.sequenceGap }
            guard reply.proposal == outstanding else { throw ProtocolError.identityCollision }
            let ancestor = reply.outcome == .applied ? outstanding.proposed : outstanding.base
            let rebase = ThreeWay.merge(base: ancestor, local: draft, remote: reply.result)
            var next = self
            next.baseRevision = reply.resultRevision; next.base = reply.result
            next.observedMacRevision = max(observedMacRevision, reply.resultRevision)
            next.lastReply = reply; next.outstanding = nil; next.confirmationPending = reply.outcome == .conflict
            next.completedSequence = reply.proposal.sequence
            if rebase.isComplete {
                next.draft = rebase.merged; next.reconciliation = nil; next.phase = .editable
            } else {
                next.phase = .needsResolution
                next.reconciliation = .init(sequence: reply.proposal.sequence,
                    cause: reply.outcome == .applied ? .editsAfterSending : .macConflict, ancestor: ancestor)
                // draft still contains all later local edits; receipt contains both earlier alternatives.
            }
            try next.validate()
            return .init(state: next, kind: next.reconciliation == nil ? .accepted : .needsResolution)
        }
        /// The caller supplies an explicit complete owner decision, never last-clock-wins.
        public func resolving(expected: ResolutionContext, document: Document) throws -> Self {
            try validate(); try CompanionMerge.validateDocument(document)
            guard let context = resolutionContext else { throw ProtocolError.noConflict }
            guard context == expected else { throw ProtocolError.staleResolution }
            var next = self; next.draft = document; next.reconciliation = nil; next.confirmationPending = true; next.phase = .resolutionChosen
            return next
        }
    }

    nonisolated public enum ProtocolCodec {
        public static func encode<T: Encodable>(_ value: T) throws -> Data {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(value)
        }
        public static func decodeMac(_ data: Data) throws -> MacMonthState {
            let state = try JSONDecoder().decode(MacMonthState.self, from: data); try state.validate(); return state
        }
        public static func decodePhone(_ data: Data) throws -> PhoneMonthState {
            let state = try JSONDecoder().decode(PhoneMonthState.self, from: data); try state.validate(); return state
        }
        public static func decodeProposal(_ data: Data) throws -> Proposal {
            let proposal = try JSONDecoder().decode(Proposal.self, from: data); try proposal.validate(); return proposal
        }
        public static func decodeReply(_ data: Data) throws -> Reply {
            let reply = try JSONDecoder().decode(Reply.self, from: data); try reply.validate(); return reply
        }
    }
}
