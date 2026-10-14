import Foundation

/// Pure recovery mechanics. Context must include the complete typed monthly binding,
/// source/calculation dependencies and independently retained receipt basis.
/// The caller fences envelope identity BEFORE financial decoding, retains the old
/// record durably, and validates the chosen document through the financial codec.
nonisolated public enum CompanionRecovery<Context: Codable & Equatable & Sendable> {
    nonisolated public enum RecoveryError: Error, Equatable {
        case missingMonth, incompatibleIdentity, notFreshSession, staleReview, invalidHandshake
    }

    nonisolated public struct Identity: Codable, Equatable, Sendable {
        public let planID: String
        public let calculationIdentity: String
        public init(planID: String, calculationIdentity: String) {
            self.planID = planID; self.calculationIdentity = calculationIdentity
        }
    }

    /// This is a projection of an already identity-fenced Mac packet, not a wire format.
    nonisolated public struct FreshMonth: Codable, Equatable, Sendable {
        public let scope: CompanionMerge.SyncScope
        public let identity: Identity
        public let bootstrap: CompanionMerge.Document
        public let current: CompanionMerge.Document
        public let revision: UInt64
        public let completedSequence: UInt64
        public let context: Context
        public init(scope: CompanionMerge.SyncScope, identity: Identity,
                    bootstrap: CompanionMerge.Document, current: CompanionMerge.Document,
                    revision: UInt64, completedSequence: UInt64, context: Context) {
            self.scope = scope; self.identity = identity; self.bootstrap = bootstrap
            self.current = current; self.revision = revision
            self.completedSequence = completedSequence; self.context = context
        }
    }

    nonisolated public struct Review: Codable, Equatable, Sendable {
        public let oldPhone: CompanionMerge.PhoneMonthState
        public let oldIdentity: Identity
        public let acknowledgedFresh: CompanionMerge.PhoneMonthState?
        public let fresh: FreshMonth
        public let publicationID: String
        public let generation: UInt64

        /// Old unresolved conflicts retain their original ancestor; using oldPhone.base
        /// for that case would turn the current Mac alternative into an agreed base.
        public var ancestor: CompanionMerge.Document {
            oldPhone.resolutionContext?.ancestor ?? oldPhone.base
        }
        public var comparison: CompanionMerge.MergeResult {
            CompanionMerge.ThreeWay.merge(base: ancestor, local: oldPhone.draft, remote: fresh.current)
        }

        public func validate() throws {
            try oldPhone.scope.validate(); try fresh.scope.validate()
            guard oldPhone.scope.phone == fresh.scope.phone,
                  oldPhone.scope.month == fresh.scope.month,
                  !oldIdentity.planID.isEmpty, !oldIdentity.calculationIdentity.isEmpty,
                  oldIdentity == fresh.identity else { throw RecoveryError.incompatibleIdentity }
            guard oldPhone.scope.session != fresh.scope.session,
                  oldPhone.scope.lineage != fresh.scope.lineage else { throw RecoveryError.notFreshSession }
            if let acknowledgedFresh {
                try acknowledgedFresh.validate()
                guard acknowledgedFresh.scope == fresh.scope, acknowledgedFresh.completedSequence > 0,
                      acknowledgedFresh.completedSequence == fresh.completedSequence,
                      acknowledgedFresh.phase == .editable, acknowledgedFresh.outstanding == nil,
                      acknowledgedFresh.reconciliation == nil, !acknowledgedFresh.confirmationPending,
                      acknowledgedFresh.draft == acknowledgedFresh.base,
                      fresh.revision >= acknowledgedFresh.baseRevision,
                      fresh.revision != acknowledgedFresh.baseRevision || fresh.current == acknowledgedFresh.base else {
                    throw RecoveryError.invalidHandshake
                }
            } else if fresh.completedSequence != 0 { throw RecoveryError.notFreshSession }
            guard !publicationID.isEmpty else { throw RecoveryError.staleReview }
            try oldPhone.validate()
            _ = try CompanionMerge.PhoneMonthState(scope: fresh.scope, initial: fresh.bootstrap)
            _ = try CompanionMerge.PhoneMonthState(scope: fresh.scope, initial: fresh.current)
            guard fresh.revision > 0 || fresh.current == fresh.bootstrap else {
                throw RecoveryError.staleReview
            }
        }

        /// A later publication is harmless only when this exact month's semantics,
        /// including independently captured receipt basis, have not changed.
        public func requireCurrent(oldPhone currentOld: CompanionMerge.PhoneMonthState,
                                   month: FreshMonth?, generation currentGeneration: UInt64) throws {
            try validate()
            guard let month else { throw RecoveryError.missingMonth }
            guard currentOld == oldPhone, month == fresh, currentGeneration >= generation else {
                throw RecoveryError.staleReview
            }
        }

        public func choose(phoneForConflicts: Bool, currentOld: CompanionMerge.PhoneMonthState,
                           currentMonth: FreshMonth?, currentGeneration: UInt64) throws -> Choice {
            try requireCurrent(oldPhone: currentOld, month: currentMonth, generation: currentGeneration)
            return Choice(review: self, phoneForConflicts: phoneForConflicts)
        }
    }

    public static func review(oldPhone: CompanionMerge.PhoneMonthState, oldIdentity: Identity,
                              fresh: FreshMonth?, publicationID: String, generation: UInt64,
                              acknowledgedFresh: CompanionMerge.PhoneMonthState? = nil) throws -> Review {
        guard let fresh else { throw RecoveryError.missingMonth }
        let result = Review(oldPhone: oldPhone, oldIdentity: oldIdentity, acknowledgedFresh: acknowledgedFresh, fresh: fresh,
                            publicationID: publicationID, generation: generation)
        try result.validate(); return result
    }

    /// Store this explicit choice with the retained old record before publishing a handshake.
    /// Codable reconstruction is revalidated whenever a transition is requested.
    nonisolated public struct Choice: Codable, Equatable, Sendable {
        public let review: Review
        public let phoneForConflicts: Bool
        public var document: CompanionMerge.Document {
            // Same kernel resolver used for ordinary conflict review; clean groups survive.
            CompanionMerge.ResolutionContext(sequence: 0, cause: .macConflict,
                ancestor: review.ancestor, local: review.oldPhone.draft,
                remote: review.fresh.current).resolvedDocument(choosingLocalForConflicts: phoneForConflicts)
        }

        /// Fresh revision-zero base comes from the actual new-session bootstrap.
        /// No old proposal, counter, base revision or receipt crosses the boundary.
        public func beginHandshake() throws -> CompanionMerge.PhoneSend {
            try review.validate()
            let baseline = try review.acknowledgedFresh ?? CompanionMerge.PhoneMonthState(
                scope: review.fresh.scope, initial: review.fresh.bootstrap)
            return try baseline.beginExchange()
        }

        /// `handshake` is the locally persisted fresh no-op state after receiving its
        /// real Mac receipt. Its receipt context is supplied from the frozen reply anchor.
        /// The current packet must still match the reviewed monthly semantics, allowing
        /// only completedSequence's expected next-handshake transition.
        public func prepareMergedProposal(handshake: CompanionMerge.PhoneMonthState,
                                          currentOld: CompanionMerge.PhoneMonthState,
                                          replyContext: Context, currentMonth: FreshMonth?,
                                          currentGeneration: UInt64) throws -> CompanionMerge.PhoneSend {
            try review.validate(); try handshake.validate()
            guard currentOld == review.oldPhone else { throw RecoveryError.staleReview }
            guard let currentMonth else { throw RecoveryError.missingMonth }
            let expected = review.fresh
            let sent = try beginHandshake()
            guard currentGeneration >= review.generation,
                  currentMonth.scope == expected.scope, currentMonth.identity == expected.identity,
                  currentMonth.bootstrap == expected.bootstrap, currentMonth.current == expected.current,
                  currentMonth.revision == expected.revision, currentMonth.completedSequence == sent.proposal.sequence,
                  currentMonth.context == expected.context, replyContext == expected.context else {
                throw RecoveryError.staleReview
            }
            guard handshake.scope == expected.scope, handshake.completedSequence == sent.proposal.sequence,
                  handshake.phase == .editable, !handshake.confirmationPending,
                  handshake.outstanding == nil, handshake.reconciliation == nil,
                  let reply = handshake.lastReply, reply.proposal == sent.proposal,
                  reply.outcome == .applied, reply.result == expected.current,
                  reply.resultRevision == expected.revision,
                  handshake.base == expected.current, handshake.draft == expected.current else {
                throw RecoveryError.invalidHandshake
            }
            // Even choosing unchanged Mac data produces explicit fresh confirmation.
            return try handshake.editing(document).beginExchange()
        }
    }
}
