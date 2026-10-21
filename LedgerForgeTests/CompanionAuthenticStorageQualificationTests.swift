import CryptoKit
import Foundation
import XCTest
@testable import LedgerForge

/// Opt-in qualification against one explicitly selected native owner backup.
/// No financial/domain fixture is created. No financial value is printed or attached.
/// Writes are confined to test-owned ordinary SQLite databases and native backups.
@MainActor
final class CompanionAuthenticStorageQualificationTests: XCTestCase {
    private enum Failure: Error { case assertion(String) }

    @MainActor
    private final class Ledger {
        let directory: URL
        let path: URL
        let source: URL
        let sourceManifest: BackupManifest
        let workspaceID: String
        var sqlite: SQLiteRepositoryProvider
        var provider: DatabaseProvider

        init(directory: URL, path: URL, source: URL, manifest: BackupManifest, workspaceID: String) throws {
            self.directory = directory; self.path = path; self.source = source
            sourceManifest = manifest; self.workspaceID = workspaceID
            let opened = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            sqlite = opened
            provider = .verifiedSQLite(opened)
        }
        func reopen() throws {
            provider.invalidateGeneration()
            try sqlite.database.checkpointAndClose()
            sqlite = try SQLiteRepositoryProvider(path: path.path, migrations: allMigrations, access: .existing)
            provider = .verifiedSQLite(sqlite)
        }
        func close() { provider.invalidateGeneration(); sqlite.database.close() }
    }

    private struct SelectedMonth {
        let session: CompanionSyncSessionDTO
        let initial: CompanionMonthSyncDTO
        let initialMonthRevision: PlanningMonthRevision
        let originalScratchpad: MonthlyPlanScratchpadDTO
        let canonicalPlans: [FundingPlanDTO]
        let canonicalDigest: SHA256.Digest
        let month: String
    }

    func testAuthenticInitializationAndExactReceiptReplayDoNotDuplicatePlan() throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let initial = try selected.initial.decodedEnvelope(session: selected.session)
            // Actual retained source-backed scratchpad: replayed numeric bindings must
            // not promote unknown lexical origin or change provenance/canonical state.
            var unchangedEditor = self.portableEditor(initial.current)
            let unchangedScratchpad = unchangedEditor.scratchpad
            let unchangedLexical = unchangedEditor.lexicalContext
            let unchangedDocument = try self.encoded(unchangedEditor, against: initial.current, scope: initial.kernel.scope).document
            var callbacks: [PortableMonthlyPlanEditor.Edit] = []
            for field in PortableMonthlyPlanEditor.MoneyField.allCases where
                unchangedEditor.plan.calculationVersion == .legacy || ![.deductions, .investment].contains(field) {
                callbacks.append(.money(field, text: unchangedEditor.displayedInputText(field.rawValue, fallback: unchangedEditor.moneyText(field))))
            }
            callbacks.append(.manualFX(rate: unchangedScratchpad.rawText["fx.rate"] ?? "",
                date: unchangedScratchpad.rawText["fx.date"] ?? ""))
            for row in unchangedEditor.plan.deductions {
                callbacks.append(.deduction(id: row.id, label: nil,
                    amount: unchangedEditor.displayedInputText("deduction.amount." + row.id, fallback: try row.money.canonicalDecimalString()), recurs: nil))
            }
            for (region, rows) in [(PortableMonthlyPlanEditor.Region.qatar, unchangedEditor.plan.qatarCommitments), (.india, unchangedEditor.plan.indiaCommitments)] {
                for row in rows {
                    callbacks.append(.commitment(region: region, id: row.id, field: .amount,
                        text: unchangedEditor.displayedInputText("amount." + row.id, fallback: try row.money.canonicalDecimalString())))
                }
            }
            for account in unchangedEditor.accounts where
                !account.isHistoryOnly || unchangedEditor.selectedHistoryAccountIDs.contains(account.id) {
                let row = unchangedEditor.plan.balances.first { $0.accountID == account.id }
                callbacks.append(.manualBalance(accountID: account.id,
                    text: unchangedEditor.displayedInputText("balance." + account.id, fallback: try row?.money?.canonicalDecimalString() ?? ""),
                    newBalanceID: row?.id ?? UUID().uuidString))
            }
            for callback in callbacks {
                let mutation = unchangedEditor.apply(callback, inputLocaleIdentifier: "en_US_POSIX")
                try self.check(mutation?.changed == false, "An unchanged numeric callback was rejected or changed retained state")
                try self.check(unchangedEditor.scratchpad == unchangedScratchpad && unchangedEditor.lexicalContext == unchangedLexical,
                    "An unchanged numeric callback changed exact scratchpad or lexical context")
                try self.check(try self.encoded(unchangedEditor, against: initial.current, scope: initial.kernel.scope).document == unchangedDocument,
                    "An unchanged numeric callback changed the encoded sync document")
            }
            let phone = try CompanionMerge.PhoneMonthState(scope: initial.kernel.scope, initial: initial.kernel.current)
            let proposal = try phone.beginExchange().proposal
            let first = try self.receive(proposal, ledger: ledger, selected: selected)
            try self.check(first.disposition == .applied, "No-op proposal did not use the applied storage route")
            try self.check(first.reply != nil && first.replyAnchor != nil, "Committed receipt lost its frozen anchor")
            let firstStored = try self.savedMonth(ledger, selected)
            let replay = try self.receive(proposal, ledger: ledger, selected: selected)
            try self.check(replay.disposition == .replayed, "Exact retransmission did not use durable replay")
            try self.check(replay.reply == first.reply && replay.replyAnchor == first.replyAnchor,
                           "Exact retransmission changed its committed receipt or context")
            try self.check(try self.savedMonth(ledger, selected) == firstStored, "Replay rewrote protocol state")
            try self.check(try ledger.provider.fundingPlanRepo.plans(workspaceId: ledger.workspaceID) == selected.canonicalPlans,
                           "Initialization or no-op receipt changed the actual canonical plan graph")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "Initialization or replay changed canonical SQLite rows")
        }
    }

    func testAuthenticIncompleteInputCASAndReplaySurviveOrdinaryReopen() throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let proposal = try self.incompleteProposal(ledger, selected)
            let committed = try self.receive(proposal, ledger: ledger, selected: selected)
            try self.check(committed.disposition == .applied, "Incomplete raw entry was not durably accepted as an editor change")
            let retained = try self.savedMonth(ledger, selected)
            let envelope = try retained.decodedEnvelope(session: selected.session)
            try self.check(envelope.current.scratchpad.rawText["fee"] == "-", "Incomplete raw entry was not preserved exactly")
            try self.check(envelope.current.scratchpad.fieldErrors["fee"] != nil, "Incomplete input lost its visible error")
            try self.check(envelope.current.scratchpad.canonical == (try MonthlyPlanScratchpad.decode(selected.originalScratchpad)).canonical,
                           "Incomplete input replaced the prior canonical plan")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "Incomplete input changed canonical SQLite rows")

            let actual = try self.actualScratchpad(ledger, month: selected.month)
            let currentMonthRevision = try XCTUnwrap(committed.monthRevision)
            let binding = try envelope.current.binding(for: envelope.kernel.scope)
            let staleRevision = CompanionMonthCommitRequest(sessionID: selected.session.sessionID, workspaceID: ledger.workspaceID,
                month: selected.month, expectedActivationEpoch: selected.session.activationEpoch,
                expectedStateRevision: selected.initial.stateRevision, expectedMonthRevision: selected.initialMonthRevision,
                expectedScratchpad: actual, editor: actual,
                canonical: nil, binding: binding, metadata: envelope.current.metadata,
                operation: .localEdit(envelope.kernel.current), currentAnchor: envelope.current)
            do {
                _ = try ledger.provider.fundingPlanRepo.commitCompanionMonth(staleRevision)
                throw Failure.assertion("Stale revision unexpectedly committed")
            } catch CompanionSyncRepositoryError.staleRevision { }
              catch PlanningWriteError.staleRevision { }
            let staleBytes = CompanionMonthCommitRequest(sessionID: selected.session.sessionID, workspaceID: ledger.workspaceID,
                month: selected.month, expectedActivationEpoch: selected.session.activationEpoch,
                expectedStateRevision: retained.stateRevision, expectedMonthRevision: currentMonthRevision,
                expectedScratchpad: selected.originalScratchpad, editor: actual,
                canonical: nil, binding: binding, metadata: envelope.current.metadata,
                operation: .localEdit(envelope.kernel.current), currentAnchor: envelope.current)
            do {
                _ = try ledger.provider.fundingPlanRepo.commitCompanionMonth(staleBytes)
                throw Failure.assertion("Stale scratchpad bytes unexpectedly committed")
            } catch CompanionSyncRepositoryError.staleScratchpad { }
            try self.check(try self.savedMonth(ledger, selected) == retained, "Rejected CAS changed retained receipt state")
            try self.check(try self.actualScratchpad(ledger, month: selected.month) == actual, "Rejected CAS changed durable editor bytes")

            let epoch = try ledger.provider.fundingPlanRepo.companionActivationEpoch()
            try ledger.reopen()
            try self.check(try ledger.provider.fundingPlanRepo.companionActivationEpoch() == epoch, "Ordinary reopen rotated the activation")
            try self.check(try self.savedMonth(ledger, selected) == retained, "Reopen changed persisted protocol bytes")
            try self.check(try self.actualScratchpad(ledger, month: selected.month) == actual, "Reopen changed exact editor bytes")
            let replay = try self.receive(proposal, ledger: ledger, selected: selected)
            try self.check(replay.disposition == .replayed && replay.reply == committed.reply && replay.replyAnchor == committed.replyAnchor,
                           "Reopen did not preserve the exact committed receipt and anchor")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "CAS rejection or reopen replay changed canonical SQLite rows")
        }
    }

    func testAuthenticV33NativeBackupRetainsReceiptAndHoldsOldActivation() throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let proposal = try self.incompleteProposal(ledger, selected)
            _ = try self.receive(proposal, ledger: ledger, selected: selected)
            let retained = try self.savedMonth(ledger, selected)
            let actual = try self.actualScratchpad(ledger, month: selected.month)
            let package = try self.makeNativeBackup(ledger)
            let manifest = try BackupFiles.verifyPackage(package)
            try self.check(manifest.schemaVersion == BackupCompatibility.supportedSchemaVersion, "Qualification backup did not validate the current supported format")
            let restoredPath = ledger.directory.appendingPathComponent("restored-current.sqlite")
            _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restoredPath)
            let restored = try SQLiteRepositoryProvider(path: restoredPath.path, migrations: allMigrations, access: .existing)
            defer { restored.database.close() }
            let provider = DatabaseProvider.verifiedSQLite(restored)
            defer { provider.invalidateGeneration() }
            try self.check(try provider.fundingPlanRepo.companionActivationEpoch() != selected.session.activationEpoch,
                           "Restored native backup inherited the old activation authority")
            let rowBeforeHold = try provider.fundingPlanRepo.companionMonth(sessionID: selected.session.sessionID,
                workspaceID: ledger.workspaceID, month: selected.month)
            try self.check(rowBeforeHold == retained, "Native backup lost the exact operational receipt bytes")
            let envelope = try retained.decodedEnvelope(session: selected.session)
            let stale = CompanionMonthCommitRequest(sessionID: selected.session.sessionID, workspaceID: ledger.workspaceID,
                month: selected.month, expectedActivationEpoch: selected.session.activationEpoch,
                expectedStateRevision: retained.stateRevision, expectedMonthRevision: selected.initialMonthRevision,
                expectedScratchpad: actual, editor: actual, canonical: nil,
                binding: try envelope.current.binding(for: envelope.kernel.scope), metadata: envelope.current.metadata,
                operation: .receive(proposal), currentAnchor: envelope.current)
            do {
                _ = try provider.fundingPlanRepo.commitCompanionMonth(stale)
                throw Failure.assertion("Old activation replay was accepted by the restored ledger")
            } catch CompanionSyncRepositoryError.staleActivation { }
            try provider.fundingPlanRepo.reconcileCompanionActivation()
            let sessions = try provider.fundingPlanRepo.companionSessions(workspaceID: ledger.workspaceID)
            try self.check(sessions.first(where: { $0.sessionID == selected.session.sessionID })?.disposition == "held",
                           "Restored session was not held for explicit reconciliation")
            try self.check(try provider.fundingPlanRepo.companionMonth(sessionID: selected.session.sessionID,
                workspaceID: ledger.workspaceID, month: selected.month) == retained, "Holding a session discarded its retained month")
            try BackupCompatibility.verifyDatabase(restored.database)
            try self.check(try self.canonicalGraphDigest(restored.database) == selected.canonicalDigest,
                           "Backup restore or activation reconciliation changed canonical SQLite rows")
            let capture = try CompanionMacCapture.take(provider: provider, workspaceID: ledger.workspaceID,
                selectedGmailAccount: nil, now: Date())
            try self.check(capture.runtime.monthlyScratchpads.contains(where: { $0 == envelope.current.scratchpad }),
                           "Restored canonical hydration did not expose the exact retained incomplete editor")
        }
    }

    func testAuthenticDisjointMacAndPhoneInputsMergeWithoutChangingCanonicalGraph() throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let initial = try selected.initial.decodedEnvelope(session: selected.session)
            let phoneEdit = try self.edited(initial.current, scope: initial.kernel.scope, field: .fee, text: "-")
            var phone = try CompanionMerge.PhoneMonthState(scope: initial.kernel.scope, initial: initial.kernel.current)
            phone = try phone.editing(phoneEdit.document)
            let sent = try phone.beginExchange(); phone = sent.state
            let macEdit = try self.edited(initial.current, scope: initial.kernel.scope, field: .variable, text: ".")
            try self.saveMac(macEdit, ledger: ledger)
            let received = try self.receive(sent.proposal, ledger: ledger, selected: selected)
            try self.check(received.disposition == .applied, "Disjoint actual editor inputs did not merge")
            guard let reply = received.reply else { throw Failure.assertion("Disjoint merge lost its receipt") }
            phone = try phone.receiving(reply).state
            let persisted = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
            try self.check(persisted.current.scratchpad.rawText["fee"] == "-" && persisted.current.scratchpad.rawText["variable"] == ".",
                           "Disjoint merge discarded one device's retained raw input")
            try self.check(phone.draft == persisted.kernel.current && !phone.needsExchange,
                           "Disjoint actual editor exchange did not converge")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "Disjoint incomplete edits changed the accepted canonical graph")
        }
    }

    func testAuthenticSameFieldConflictRequiresExplicitResolutionAndConfirmation() throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let initial = try selected.initial.decodedEnvelope(session: selected.session)
            let phoneEdit = try self.edited(initial.current, scope: initial.kernel.scope, field: .fee, text: "-")
            var phone = try CompanionMerge.PhoneMonthState(scope: initial.kernel.scope, initial: initial.kernel.current)
            phone = try phone.editing(phoneEdit.document)
            let sent = try phone.beginExchange(); phone = sent.state
            let macEdit = try self.edited(initial.current, scope: initial.kernel.scope, field: .fee, text: ".")
            try self.saveMac(macEdit, ledger: ledger)
            let macBytes = try self.actualScratchpad(ledger, month: selected.month)
            let conflict = try self.receive(sent.proposal, ledger: ledger, selected: selected)
            try self.check(conflict.disposition == .conflict, "Same-field actual editor conflict was silently applied")
            try self.check(try self.actualScratchpad(ledger, month: selected.month) == macBytes,
                           "Conflict receipt overwrote the Mac's editor")
            guard let conflictReply = conflict.reply else { throw Failure.assertion("Conflict receipt was not retained") }
            phone = try phone.receiving(conflictReply).state
            guard let context = phone.resolutionContext else { throw Failure.assertion("Phone lost its unresolved actual conflict") }
            let chosen = context.resolvedDocument(choosingLocalForConflicts: true)
            phone = try phone.resolving(expected: context, document: chosen)
            try self.check(phone.confirmationPending && phone.needsExchange,
                           "Selecting a conflict choice incorrectly claimed delivery")
            let confirmation = try phone.beginExchange(); phone = confirmation.state
            let confirmed = try self.receive(confirmation.proposal, ledger: ledger, selected: selected)
            try self.check(confirmed.disposition == .applied, "Explicit resolution did not pass the next actual repository exchange")
            guard let confirmedReply = confirmed.reply else { throw Failure.assertion("Resolution confirmation lost its receipt") }
            phone = try phone.receiving(confirmedReply).state
            let persisted = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
            try self.check(persisted.current.scratchpad.rawText["fee"] == "-", "Explicit conflict choice was not retained")
            try self.check(phone.draft == persisted.kernel.current && !phone.needsExchange && !phone.confirmationPending,
                           "Confirmed resolution did not converge")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "Conflict handling changed canonical Money or plan rows")
        }
    }

    func testAuthenticLaterEditSurvivesOutstandingProposalAndRealReceiptDependencyRefresh() throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let initial = try selected.initial.decodedEnvelope(session: selected.session)
            let anchor = initial.current
            guard let linked = anchor.scratchpad.plan.assistance?.payslipFunding?.accountID,
                  let balance = anchor.scratchpad.plan.balances.first(where: { $0.accountID == linked }),
                  anchor.bankCurrencies[linked] != nil,
                  !anchor.excludedHistoryAccountIDs.contains(linked),
                  !anchor.context.manuallyExcludedPlanningAccountIDs.contains(linked) else {
                throw XCTSkip("AUTHENTIC_LINKED_SALARY_BALANCE_FOR_DEPENDENCY_REFRESH_UNAVAILABLE")
            }
            var editor = self.portableEditor(anchor)
            guard let mutation = editor.apply(.accountIncluded(accountID: linked, included: !balance.included, newBalanceID: balance.id),
                                              inputLocaleIdentifier: "en_US_POSIX"), mutation.changed else {
                throw XCTSkip("AUTHENTIC_LINKED_BALANCE_CANNOT_EXERCISE_INCLUDE_EDIT")
            }
            let firstEdit = try self.encoded(editor, against: anchor, scope: initial.kernel.scope)
            var phone = try CompanionMerge.PhoneMonthState(scope: initial.kernel.scope, initial: initial.kernel.current)
            phone = try phone.editing(firstEdit.document)
            let sent = try phone.beginExchange(); phone = sent.state
            guard let later = editor.apply(.money(.fee, text: "-"), inputLocaleIdentifier: "en_US_POSIX"), later.changed else {
                throw XCTSkip("AUTHENTIC_SELECTED_MONTH_CANNOT_EXERCISE_LATER_FEE_EDIT")
            }
            let laterEdit = try self.encoded(editor, against: anchor, scope: initial.kernel.scope)
            phone = try phone.editing(laterEdit.document)
            try self.check(try phone.beginExchange().proposal == sent.proposal,
                           "Later actual edit changed an already outstanding proposal")
            let first = try self.receive(sent.proposal, ledger: ledger, selected: selected)
            try self.check(first.disposition == .applied, "First actual proposal was not applied")
            guard let reply = first.reply, let frozenAnchor = first.replyAnchor else {
                throw Failure.assertion("First actual proposal lost its frozen source context")
            }
            let beforeRefresh = try self.savedMonth(ledger, selected)
            let old = try beforeRefresh.decodedEnvelope(session: selected.session)
            let capture = try CompanionMacCapture.take(provider: ledger.provider, workspaceID: ledger.workspaceID,
                selectedGmailAccount: nil, now: Date())
            let fresh = try CompanionMacMonthContext.refreshed(old: old.current, runtime: capture.runtime, cache: capture.publicCache)
            try self.check(fresh.context.receiptBasis != old.current.context.receiptBasis,
                           "Actual dependency refresh did not recompute the changed linked balance basis")
            let actual = try self.actualScratchpad(ledger, month: selected.month)
            _ = try ledger.provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: selected.session.sessionID,
                workspaceID: ledger.workspaceID, month: selected.month, expectedActivationEpoch: selected.session.activationEpoch,
                expectedStateRevision: beforeRefresh.stateRevision,
                expectedMonthRevision: try XCTUnwrap(first.monthRevision),
                expectedScratchpad: actual, editor: actual, canonical: nil,
                binding: old.current.binding(for: old.kernel.scope), metadata: old.current.metadata,
                operation: .refreshDependencies, currentAnchor: fresh))
            let refreshed = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
            try self.check(refreshed.kernel.current == old.kernel.current && refreshed.kernel.lastReply == reply
                           && refreshed.replyAnchor == frozenAnchor,
                           "Dependency refresh rewrote the document or frozen receipt anchor")
            phone = try phone.receiving(reply).state
            let pendingBeforeRebind = phone
            let rebound = try MonthlyPlanSyncAdapter.dependencyRebind(document: phone.draft,
                from: frozenAnchor.binding(for: phone.scope), to: refreshed.current.binding(for: phone.scope))
            try self.check(rebound.scratchpad.rawText["fee"] == "-" && phone == pendingBeforeRebind && phone.needsExchange,
                           "Actual dependency refresh discarded or falsely acknowledged a later edit")
            let next = try phone.beginExchange(); phone = next.state
            let second = try self.receive(next.proposal, ledger: ledger, selected: selected)
            guard let secondReply = second.reply else { throw Failure.assertion("Later actual edit lost its receipt") }
            phone = try phone.receiving(secondReply).state
            let final = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
            try self.check(final.current.scratchpad.rawText["fee"] == "-" && phone.draft == final.kernel.current && !phone.needsExchange,
                           "Later actual edit did not converge after dependency refresh")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "Raw/editor dependency exercise changed the accepted canonical graph")
        }
    }

    func testTwoAuthenticMonthsHaveIndependentDurableReceipts() throws {
        try run { ledger in
            let capture = try CompanionMacCapture.take(provider: ledger.provider, workspaceID: ledger.workspaceID,
                selectedGmailAccount: nil, now: Date())
            let plans = try ledger.provider.fundingPlanRepo.plans(workspaceId: ledger.workspaceID)
            let months = capture.runtime.monthlyScratchpads.filter { scratch in
                guard scratch.plan.workspaceID == ledger.workspaceID, let canonical = scratch.canonical,
                      let dto = try? canonical.persistenceDTO() else { return false }
                return plans.contains(dto)
            }.map { $0.plan.month.canonical }.sorted(by: >)
            guard months.count >= 2 else { throw XCTSkip("TWO_AUTHENTIC_COHERENT_MONTHS_UNAVAILABLE") }
            let requested = ProcessInfo.processInfo.environment["LEDGERFORGE_COMPANION_AUTHENTIC_MONTH"]
            let firstMonth = requested ?? months[0]
            guard months.contains(firstMonth), let secondMonth = months.first(where: { $0 != firstMonth }) else {
                throw XCTSkip("SELECTED_AUTHENTIC_MONTH_AND_SECOND_COHERENT_MONTH_UNAVAILABLE")
            }
            let first = try self.initializeActualMonth(ledger, monthOverride: firstMonth)
            let second = try self.initializeActualMonth(ledger, monthOverride: secondMonth, existingSession: first.session)
            let proposalOne = try self.incompleteProposal(ledger, first)
            let proposalTwo = try self.incompleteProposal(ledger, second)
            let untouchedFirst = try self.savedMonth(ledger, first)
            _ = try self.receive(proposalTwo, ledger: ledger, selected: second)
            let retainedSecond = try self.savedMonth(ledger, second)
            try self.check(try self.savedMonth(ledger, first) == untouchedFirst, "One actual month changed another month's protocol state")
            _ = try self.receive(proposalOne, ledger: ledger, selected: first)
            try self.check(try self.savedMonth(ledger, second) == retainedSecond, "Interleaved actual months shared receipt state")
            let replay = try self.receive(proposalOne, ledger: ledger, selected: first)
            try self.check(replay.disposition == .replayed, "First actual month did not replay independently")
            try self.check(try self.savedMonth(ledger, second) == retainedSecond, "Replaying one actual month rewrote the other")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == first.canonicalDigest,
                           "Interleaved incomplete month edits changed accepted canonical rows")
        }
    }

    func testOptInAuthenticCaptureAndPairedRetentionTiming() throws {
        guard ProcessInfo.processInfo.environment["LEDGERFORGE_COMPANION_TIMING"] == "1" else {
            throw XCTSkip("AUTHENTIC_COMPANION_TIMING_NOT_REQUESTED")
        }
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            var captureMilliseconds: [Double] = [], retentionMilliseconds: [Double] = []
            for index in 0..<5 {
                let start = ProcessInfo.processInfo.systemUptime
                let capture = try CompanionMacCapture.take(provider: ledger.provider, workspaceID: ledger.workspaceID,
                    selectedGmailAccount: nil, now: Date())
                // Timing uses the actual retained observation cache explicitly;
                // production supplies its live foreground presentation basis.
                let basis = CompanionMacReadBasis(alDarLegs: capture.publicCache.alDarLegs,
                    investmentQuotes: capture.publicCache.investmentQuotes,
                    rateFailures: Set(AlDarCurrency.allCases.filter { capture.publicProgress["aldar:" + $0.rawValue]?.failure != nil }),
                    priceFailures: Set(capture.publicProgress.values.filter {
                        !$0.identity.hasPrefix("aldar:") && $0.failure != nil
                    }.map(\.identity)))
                _ = try capture.projection(generation: UInt64(index + 1),
                    currencies: ReportingCurrencyPreferences.shared.currencies, readBasis: basis)
                captureMilliseconds.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
            }
            for _ in 0..<5 {
                let current = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
                let raw = current.current.scratchpad.rawText["fee"] == "-" ? "." : "-"
                let edit = try self.edited(current.current, scope: current.kernel.scope, field: .fee, text: raw)
                let start = ProcessInfo.processInfo.systemUptime
                try self.saveMac(edit, ledger: ledger)
                retentionMilliseconds.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
            }
            try self.check(captureMilliseconds.allSatisfy { $0.isFinite && $0 >= 0 }
                           && retentionMilliseconds.allSatisfy { $0.isFinite && $0 >= 0 }, "Timing clock produced an invalid duration")
            func summary(_ values: [Double], label: String) {
                let sorted = values.sorted()
                print(String(format: "COMPANION_TIMING %@ count=%d median_ms=%.3f max_ms=%.3f", label, sorted.count, sorted[sorted.count / 2], sorted.last!))
            }
            summary(captureMilliseconds, label: "capture_projection")
            summary(retentionMilliseconds, label: "paired_saveLocal")
            try self.check(try self.canonicalGraphDigest(ledger.sqlite.database) == selected.canonicalDigest,
                           "Timing raw retention changed accepted canonical rows")
        }
    }

    func testAuthenticScopedMonthContextMatchesFullRuntimeForEveryRetainedMonth() throws {
        try qualifyScopedMonthContext(payslipLinkedOnly: false)
    }

    func testAuthenticScopedMonthContextMatchesFullRuntimeForActualPayslipLinkedMonths() throws {
        try qualifyScopedMonthContext(payslipLinkedOnly: true)
    }

    private func qualifyScopedMonthContext(payslipLinkedOnly: Bool) throws {
        try run { ledger in
            try ledger.provider.withConsistentSnapshot {
                let now = Date()
                let capture = try CompanionMacCapture.take(provider: ledger.provider,
                    workspaceID: ledger.workspaceID, selectedGmailAccount: nil, now: now)
                let retained = capture.runtime.monthlyScratchpads.filter {
                    $0.plan.workspaceID == ledger.workspaceID
                        && (!payslipLinkedOnly || $0.plan.assistance?.payslipFunding != nil)
                }
                guard !retained.isEmpty else {
                    throw XCTSkip(payslipLinkedOnly
                        ? "AUTHENTIC_PAYSLIP_LINKED_MONTH_UNAVAILABLE"
                        : "AUTHENTIC_RETAINED_MONTH_UNAVAILABLE")
                }
                let sessions = try ledger.provider.fundingPlanRepo.companionSessions(workspaceID: ledger.workspaceID)
                    .filter { $0.disposition == "active" && $0.activationEpoch == capture.activationEpoch }
                try self.check(sessions.count <= 1, "Multiple active companion sessions in the selected snapshot")
                for scratchpad in retained {
                    // Unknown historical locale remains unknown. Reuse actual
                    // retained operational metadata and history choices when paired.
                    var metadata = MonthlyPlanSyncAdapter.metadata(for: scratchpad,
                        lexicalContext: .init(defaultLocaleIdentifier: nil, localeIdentifiersByField: [:]),
                        retaining: .init())
                    var selectedHistory: Set<String> = []
                    if let session = sessions.first,
                       let stored = try ledger.provider.fundingPlanRepo.companionMonth(
                        sessionID: session.sessionID, workspaceID: ledger.workspaceID,
                        month: scratchpad.plan.month.canonical) {
                        let anchor = try stored.decodedEnvelope(session: session).current
                        metadata = anchor.metadata
                        selectedHistory = anchor.context.allHistoryAccountIDs.subtracting(anchor.excludedHistoryAccountIDs)
                    }
                    let full = try CompanionMacMonthContext.make(scratchpad: scratchpad,
                        metadata: metadata, runtime: capture.runtime, cache: capture.publicCache,
                        selectedHistoryAccountIDs: selectedHistory)
                    let scoped = try CompanionMacMonthContextReader.read(scratchpad: scratchpad,
                        metadata: metadata, provider: ledger.provider,
                        selectedHistoryAccountIDs: selectedHistory, now: now)
                    try self.check(full == scoped,
                        "Scoped monthly context disagrees with the full runtime projection")
                    if payslipLinkedOnly {
                        try self.check(full.context.receipt != nil && scoped.context.receipt != nil,
                            "An actual payslip-linked month lost its receipt state")
                        try self.check(full.context.receiptBasis == scoped.context.receiptBasis,
                            "Scoped salary receipt basis differs from the full runtime projection")
                    }
                }
            }
        }
    }

    func testAuthenticRestoreRecoveryUsesFreshHandshakeAndPreservesIncompleteInputs() throws {
        try run { ledger in
            typealias Recovery = CompanionRecovery<CompanionMonthAnchor>
            let oldSelection = try self.initializeActualMonth(ledger)
            let oldStored = try oldSelection.initial.decodedEnvelope(session: oldSelection.session)
            let phoneEdit = try self.edited(oldStored.current, scope: oldStored.kernel.scope, field: .fee, text: "-")
            let oldPhone = try CompanionMerge.PhoneMonthState(scope: oldStored.kernel.scope, initial: oldStored.kernel.current)
                .editing(phoneEdit.document).beginExchange().state
            let oldPhoneBytes = try CompanionMerge.ProtocolCodec.encode(oldPhone)
            guard let oldProposal = oldPhone.outstanding else { throw Failure.assertion("Old phone pending proposal was missing") }

            // Only a native backup of the selected authentic ledger is restored.
            // The incomplete phone input remains an unsent operational draft.
            let package = try self.makeNativeBackup(ledger)
            let manifest = try BackupFiles.verifyPackage(package)
            let restoredPath = ledger.directory.appendingPathComponent("recovery-restored-current.sqlite")
            _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restoredPath)
            let restored = try Ledger(directory: ledger.directory, path: restoredPath, source: ledger.source,
                manifest: ledger.sourceManifest, workspaceID: ledger.workspaceID)
            defer { restored.close() }
            let newEpoch = try restored.provider.fundingPlanRepo.companionActivationEpoch()
            try self.check(newEpoch != oldSelection.session.activationEpoch, "Restore reused the old activation authority")
            try restored.provider.fundingPlanRepo.reconcileCompanionActivation()
            try self.check(try restored.provider.fundingPlanRepo.companionSessions(workspaceID: ledger.workspaceID)
                .first(where: { $0.sessionID == oldSelection.session.sessionID })?.disposition == "held",
                "Restore did not hold the old session before explicit recovery")
            try self.check(try restored.provider.fundingPlanRepo.companionMonth(sessionID: oldSelection.session.sessionID,
                workspaceID: ledger.workspaceID, month: oldSelection.month) == oldSelection.initial,
                "Recovery preparation changed the retained old month")

            let freshSession = CompanionSyncSessionDTO(sessionID: UUID().uuidString, workspaceID: ledger.workspaceID,
                activationEpoch: newEpoch, phoneID: oldSelection.session.phoneID, protocolVersion: 1, disposition: "active")
            let selected = try self.initializeActualMonth(restored, monthOverride: oldSelection.month, existingSession: freshSession)
            let initial = try selected.initial.decodedEnvelope(session: freshSession)
            // A disjoint, incomplete Mac input exercises real merge authority without
            // inventing or replacing any source-derived Money.
            let macEdit = try self.edited(initial.current, scope: initial.kernel.scope, field: .variable, text: ".")
            try self.saveMac(macEdit, ledger: restored)
            let reviewed = try self.savedMonth(restored, selected).decodedEnvelope(session: freshSession)
            let oldPlan = oldStored.current.scratchpad.plan
            let newPlan = reviewed.current.scratchpad.plan
            try self.check(oldPlan.workspaceID == newPlan.workspaceID && oldPlan.id == newPlan.id
                && oldPlan.month == newPlan.month && oldPlan.calculationVersion == newPlan.calculationVersion,
                "Restored monthly identity changed and cannot be mapped automatically")
            let identity = Recovery.Identity(planID: oldPlan.id, calculationIdentity: oldPlan.calculationVersion.rawValue)
            func freshMonth(_ value: CompanionStoredMonth) throws -> Recovery.FreshMonth {
                .init(scope: value.kernel.scope,
                    identity: .init(planID: value.current.scratchpad.plan.id,
                        calculationIdentity: value.current.scratchpad.plan.calculationVersion.rawValue),
                    bootstrap: try value.bootstrap.binding(for: value.kernel.scope).baselineDocument,
                    current: value.kernel.current, revision: value.kernel.revision,
                    completedSequence: value.kernel.completedSequence, context: value.current)
            }
            let fresh = try freshMonth(reviewed)
            let review = try Recovery.review(oldPhone: oldPhone, oldIdentity: identity, fresh: fresh,
                publicationID: UUID().uuidString, generation: 1)
            let choice = try review.choose(phoneForConflicts: true, currentOld: oldPhone,
                currentMonth: fresh, currentGeneration: 2)
            let chosen = try MonthlyPlanSyncAdapter.decode(document: choice.document,
                against: reviewed.current.binding(for: reviewed.kernel.scope))
            try self.check(chosen.scratchpad.rawText["fee"] == "-" && chosen.scratchpad.rawText["variable"] == ".",
                "Explicit restore comparison discarded an independent retained input")
            try self.check(chosen.scratchpad.fieldErrors["fee"] != nil && chosen.scratchpad.fieldErrors["variable"] != nil,
                "Explicit restore comparison lost incomplete-input errors")
            // Verify serializable operational decision continuity in memory only.
            // No derivative financial evidence file is created by qualification.
            let resumedChoice = try JSONDecoder().decode(Recovery.Choice.self, from: JSONEncoder().encode(choice))
            try self.check(resumedChoice == choice, "Operational recovery decision changed after serialization")
            let handshake = try resumedChoice.beginHandshake()
            try self.check(handshake.proposal.scope == reviewed.kernel.scope
                && handshake.proposal.scope != oldProposal.scope && handshake.proposal.sequence == 1
                && handshake.proposal.baseRevision == 0 && handshake.proposal.proposed == fresh.bootstrap,
                "Recovery copied old proposal authority instead of a fresh no-op handshake")
            let first = try self.receive(handshake.proposal, ledger: restored, selected: selected)
            guard let firstReply = first.reply, let replyAnchor = first.replyAnchor else {
                throw Failure.assertion("Actual recovery handshake lost its receipt or frozen context")
            }
            let acknowledged = try handshake.state.receiving(firstReply).state
            let afterHandshake = try self.savedMonth(restored, selected).decodedEnvelope(session: freshSession)
            let merged = try resumedChoice.prepareMergedProposal(handshake: acknowledged, currentOld: oldPhone,
                replyContext: replyAnchor, currentMonth: freshMonth(afterHandshake), currentGeneration: 3)
            try self.check(merged.proposal.sequence == 2 && merged.proposal.scope == reviewed.kernel.scope
                && merged.proposal.base == reviewed.kernel.current && merged.proposal.baseRevision == reviewed.kernel.revision,
                "Recovery merge did not use the legitimate fresh receipt as its base")
            let committed = try self.receive(merged.proposal, ledger: restored, selected: selected)
            guard let finalReply = committed.reply else { throw Failure.assertion("Actual recovery merge lost its acknowledgement") }
            let finalPhone = try merged.state.receiving(finalReply).state
            let finalStored = try self.savedMonth(restored, selected)
            let final = try finalStored.decodedEnvelope(session: freshSession)
            try self.check(final.current.scratchpad.rawText["fee"] == "-" && final.current.scratchpad.rawText["variable"] == ".",
                "Actual recovery commit changed retained raw input")
            try self.check(final.current.scratchpad.canonical == oldStored.current.scratchpad.canonical,
                "Incomplete recovery input replaced the accepted canonical plan")
            try self.check(!finalPhone.needsExchange && finalPhone.draft == final.kernel.current
                && finalPhone.completedSequence == 2, "Recovery acknowledgement did not converge in the new scope")
            try self.check(try CompanionMerge.ProtocolCodec.encode(oldPhone) == oldPhoneBytes,
                "Recovery mutated the retained old phone state")
            try self.check(try self.canonicalGraphDigest(restored.sqlite.database) == oldSelection.canonicalDigest,
                "Recovery handshake or merge changed canonical SQLite rows")

            let actual = try self.actualScratchpad(restored, month: selected.month)
            let stale = CompanionMonthCommitRequest(sessionID: oldSelection.session.sessionID, workspaceID: ledger.workspaceID,
                month: oldSelection.month, expectedActivationEpoch: oldSelection.session.activationEpoch,
                expectedStateRevision: oldSelection.initial.stateRevision,
                expectedMonthRevision: oldSelection.initialMonthRevision,
                expectedScratchpad: oldSelection.originalScratchpad,
                editor: oldSelection.originalScratchpad, canonical: nil,
                binding: try oldStored.current.binding(for: oldStored.kernel.scope), metadata: oldStored.current.metadata,
                operation: .receive(oldProposal), currentAnchor: oldStored.current)
            do {
                _ = try restored.provider.fundingPlanRepo.commitCompanionMonth(stale)
                throw Failure.assertion("Old-scope proposal committed after explicit restore recovery")
            } catch CompanionSyncRepositoryError.invalidSession { }
            try self.check(try self.savedMonth(restored, selected) == finalStored
                && self.actualScratchpad(restored, month: selected.month) == actual,
                "Rejected old-scope delivery changed the new session or editor")
            try restored.reopen()
            try self.check(try self.savedMonth(restored, selected) == finalStored
                && self.actualScratchpad(restored, month: selected.month) == actual,
                "Ordinary reopen changed recovered protocol or raw editor bytes")
            let replay = try self.receive(merged.proposal, ledger: restored, selected: selected)
            try self.check(replay.disposition == .replayed && replay.reply == committed.reply
                && replay.replyAnchor == committed.replyAnchor, "Recovered receipt did not replay exactly after reopen")
            try self.check(try self.canonicalGraphDigest(restored.sqlite.database) == oldSelection.canonicalDigest,
                "Rejected old authority or recovered replay changed canonical rows")
            try BackupCompatibility.verifyDatabase(restored.sqlite.database)
        }
    }

    func testAuthenticPairedMacReopenPreservesNewerRetainedLexicalInput() throws {
        try checkAuthenticStalePlannerHydration(cacheMonth: false)
    }

    func testAuthenticPairedMacCachedMonthPreservesNewerRetainedLexicalInput() throws {
        try checkAuthenticStalePlannerHydration(cacheMonth: true)
    }

    private func checkAuthenticStalePlannerHydration(cacheMonth: Bool) throws {
        try run { ledger in
            let selected = try self.initializeActualMonth(ledger)
            let initialCapture = try CompanionMacCapture.take(provider: ledger.provider, workspaceID: ledger.workspaceID,
                selectedGmailAccount: nil, now: Date())
            let accounts = AccountStore(), transactions = TransactionStore(), salaries = SalaryStore()
            let funding = FundingPlanStore(), intelligence = FinancialIntelligenceStore()
            @MainActor func install(_ snapshot: RepositoryRuntimeSnapshot) {
                accounts.installAccountsWithoutObservation(snapshot.accounts)
                transactions.installTransactionsWithoutObservation(snapshot.transactions, validation: nil)
                salaries.installWithoutObservation(snapshot.salaryStatements)
                intelligence.installWithoutObservation(snapshot.intelligence, generation: snapshot.providerGeneration, sources: snapshot.financialSources)
                funding.installWithoutObservation(snapshot.fundingPlans, generation: snapshot.providerGeneration, scratchpads: snapshot.monthlyScratchpads)
                funding.notifyInstalledValue()
            }
            @MainActor func hydrate() throws {
                install(try CompanionMacCapture.take(provider: ledger.provider, workspaceID: ledger.workspaceID,
                    selectedGmailAccount: nil, now: Date()).runtime)
            }
            install(initialCapture.runtime)
            let month = try SelectedStatementMonth(canonical: selected.month)
            let planner = SalaryWorkspaceViewModel(month: month, workspaceID: ledger.workspaceID,
                provider: { ledger.provider }, accountStore: accounts, transactionStore: transactions,
                salaryStore: salaries, fundingPlanStore: funding, intelligenceStore: intelligence,
                locale: Locale(identifier: "en_US_POSIX"), refresh: { _ in try hydrate() })
            planner.plannerOpened()
            planner.receiveSharedReference(initialCapture.publicCache.alDarLegs[.inr])
            guard planner.canSave else { throw XCTSkip("AUTHENTIC_SELECTED_PLAN_CANNOT_EXERCISE_MAC_REOPEN") }
            // Settle ordinary opening effects using the real editor's save/hydration path.
            planner.save()
            guard planner.saveState == .saved, planner.plan == funding.plan(for: month, workspaceID: ledger.workspaceID),
                  let reserve = planner.plan.keepInCBQ else {
                throw XCTSkip("AUTHENTIC_SELECTED_PLAN_HAS_NO_SETTLED_RESERVE")
            }
            let oldText = planner.amountInputText("reserve")
            let alternatives = [oldText + "0", oldText + ".0", String(oldText.dropLast())]
            guard let newText = alternatives.first(where: { text in
                text != oldText && (try? PlannerInputCodec.money(text, currency: reserve.currency.code,
                    locale: Locale(identifier: "en_US_POSIX"))) == reserve
            }) else { throw XCTSkip("AUTHENTIC_RESERVE_HAS_NO_SELECTED_LEXICAL_VARIANT") }
            let baselinePlan = planner.plan
            try self.check(planner.updateMoney(.reserve, text: newText), "Actual reserve formatting edit failed")
            let planAfterEdit = planner.plan
            planner.flushPendingEntries()
            print("Retained lexical boundary: editPlanEqual=\(planAfterEdit == baselinePlan) flushPlanEqual=\(planner.plan == planAfterEdit) updatedAtChanged=\(planner.plan.updatedAtISO != baselinePlan.updatedAtISO) referenceChanged=\(planner.plan.effectiveAlDarReference != baselinePlan.effectiveAlDarReference) hydratedOldText=\(funding.scratchpads.first(where: { $0.plan.month == month })?.rawText["reserve"] == oldText) saveState=\(planner.saveState)")
            try self.check(planner.plan.keepInCBQ == reserve,
                "Formatting edit changed the actual reserve Money")
            try self.check(planner.rawText["reserve"] == newText,
                "Formatting edit failed to retain its exact text")
            let retained = try self.actualScratchpad(ledger, month: selected.month)
            try self.check(try MonthlyPlanScratchpad.decode(retained).rawText["reserve"] == newText,
                "Actual Mac editor did not durably retain the formatting edit")
            try self.check(funding.scratchpads.first(where: { $0.plan.month == month })?.rawText["reserve"] == oldText,
                "Regression did not exercise hydration older than the retained edit")
            if cacheMonth {
                guard let other = initialCapture.runtime.fundingPlans.first(where: {
                    $0.workspaceID == ledger.workspaceID && $0.month != month && SalaryWorkspaceViewModel.planningMonths.contains($0.month)
                })?.month else { throw XCTSkip("SECOND_AUTHENTIC_PLANNING_MONTH_UNAVAILABLE") }
                planner.switchMonth(to: other)
                try self.check(planner.month == other, "Could not exercise the actual cached month")
                let cached = try SalaryWorkspaceViewModel.initialCompanionContext(workspaceID: ledger.workspaceID, month: month, provider: ledger.provider)
                try self.check(cached != nil, "Actual edited month was not cached")
                funding.notifyInstalledValue()
                let afterNotification = try SalaryWorkspaceViewModel.initialCompanionContext(workspaceID: ledger.workspaceID, month: month, provider: ledger.provider)
                try self.check(afterNotification?.knownLocaleIdentifiers == cached?.knownLocaleIdentifiers
                    && afterNotification?.selectedHistoryAccountIDs == cached?.selectedHistoryAccountIDs,
                    "Stale hydration evicted the newer retained cached month")
                planner.switchMonth(to: month)
            } else {
                // Same shared VM receives the second window's onAppear.
                planner.plannerOpened()
            }
            try self.check(planner.rawText["reserve"] == newText,
                "Stale hydration replaced the newer retained lexical input")
            planner.flushPendingEntries()
            try self.check(try MonthlyPlanScratchpad.decode(self.actualScratchpad(ledger, month: selected.month)).rawText["reserve"] == newText,
                "Opening a planner wrote stale lexical input back to durable storage")

            // A genuine later phone receipt must still rebase when its exact
            // durable scratchpad is subsequently installed in the runtime store.
            let beforePhone = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
            try self.check(beforePhone.kernel.completedSequence == 0, "Fresh phone already had a receipt")
            let initialPhone = try CompanionMerge.PhoneMonthState(scope: beforePhone.kernel.scope, initial: beforePhone.kernel.base)
            let handshake = try initialPhone.beginExchange()
            let bootstrap = try self.receive(handshake.proposal, ledger: ledger, selected: selected)
            let bootstrapReply = try XCTUnwrap(bootstrap.reply, "Fresh phone handshake had no reply")
            let phone = try handshake.state.receiving(bootstrapReply).state
            let afterHandshake = try self.savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
            let phoneEdit = try self.edited(afterHandshake.current, scope: afterHandshake.kernel.scope, field: .fee, text: "-")
            let proposal = try phone.editing(phoneEdit.document).beginExchange().proposal
            let reply = try self.receive(proposal, ledger: ledger, selected: selected)
            try self.check(reply.disposition == .applied, "Genuine phone edit did not commit")
            try hydrate()
            try self.check(planner.rawText["reserve"] == newText && planner.rawText["fee"] == "-",
                "Durable hydration fence suppressed a genuine later phone receipt")
        }
    }

    private struct EditorChange {
        let editor: PortableMonthlyPlanEditor
        let document: CompanionMerge.Document
    }
    private func portableEditor(_ anchor: CompanionMonthAnchor) -> PortableMonthlyPlanEditor {
        let context = anchor.context
        return PortableMonthlyPlanEditor(scratchpad: anchor.scratchpad,
            lexicalContext: MonthlyPlanSyncAdapter.lexicalContext(from: anchor.metadata),
            accounts: context.accounts.map { .init(id: $0.id, nativeCurrency: $0.currency, isHistoryOnly: $0.isHistoryOnly) },
            allHistoryAccountIDs: context.allHistoryAccountIDs,
            selectedHistoryAccountIDs: context.allHistoryAccountIDs.subtracting(anchor.excludedHistoryAccountIDs),
            manuallyExcludedPlanningAccountIDs: context.manuallyExcludedPlanningAccountIDs,
            receipt: context.receipt?.state, receiptBasis: context.receiptBasis, canEdit: true)
    }
    private func edited(_ anchor: CompanionMonthAnchor, scope: CompanionMerge.SyncScope,
                        field: PortableMonthlyPlanEditor.MoneyField, text: String) throws -> EditorChange {
        var editor = portableEditor(anchor)
        guard let mutation = editor.apply(.money(field, text: text), inputLocaleIdentifier: "en_US_POSIX"), mutation.changed else {
            throw XCTSkip("AUTHENTIC_MONTH_CANNOT_EXERCISE_SELECTED_RAW_EDIT")
        }
        try check(editor.scratchpad.fieldErrors[field.rawValue] != nil, "Selected incomplete raw edit was unexpectedly accepted as Money")
        return try encoded(editor, against: anchor, scope: scope)
    }
    private func encoded(_ editor: PortableMonthlyPlanEditor, against anchor: CompanionMonthAnchor,
                         scope: CompanionMerge.SyncScope) throws -> EditorChange {
        let metadata = MonthlyPlanSyncAdapter.metadata(for: editor.scratchpad, lexicalContext: editor.lexicalContext,
            retaining: anchor.metadata, previousScratchpad: anchor.scratchpad)
        let document = try MonthlyPlanSyncAdapter.encode(editor.scratchpad, metadata: metadata,
            against: anchor.binding(for: scope)).document
        return EditorChange(editor: editor, document: document)
    }
    private func saveMac(_ change: EditorChange, ledger: Ledger) throws {
        let revision = try ledger.provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: change.editor.scratchpad.plan.workspaceID,
            month: change.editor.scratchpad.plan.month.canonical).monthRevision
        _ = try CompanionMacCoordinator.saveLocal(change.editor.scratchpad, canonical: nil, provider: ledger.provider,
            expectedMonthRevision: revision,
            knownLocaleIdentifiers: change.editor.lexicalContext.localeIdentifiersByField,
            selectedHistoryAccountIDs: change.editor.selectedHistoryAccountIDs)
    }

    // MARK: Selected authentic application state, never generated financial fixtures

    private func run(_ body: (Ledger) throws -> Void) throws {
        let environment = ProcessInfo.processInfo.environment
        guard let input = environment["LEDGERFORGE_COMPANION_AUTHENTIC_BACKUP"], !input.isEmpty else {
            throw XCTSkip("AUTHENTIC_NATIVE_BACKUP_NOT_SELECTED")
        }
        guard let output = environment["LEDGERFORGE_COMPANION_QUALIFICATION_ROOT"], !output.isEmpty else {
            throw XCTSkip("ISOLATED_QUALIFICATION_ROOT_NOT_SELECTED")
        }
        let source = URL(fileURLWithPath: input).standardizedFileURL.resolvingSymlinksInPath()
        let root = URL(fileURLWithPath: output, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        var stage = "qualification directory"
        do {
            try check(root.path != source.path && !root.path.hasPrefix(source.path + "/"), "Qualification output overlaps the selected native package")
            try BackupFiles.rejectGitDestination(root)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let directory = root.appendingPathComponent("companion-qualification-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: directory) }
            stage = "selected backup verification"
            let manifest = try BackupFiles.verifyPackage(source)
            let sourceManifestDigest = try BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256
            let path = directory.appendingPathComponent("current.sqlite")
            stage = "candidate preparation"
            _ = try BackupCompatibility.prepareCandidate(package: source, manifest: manifest, destination: path)
            stage = "provider open"
            let ledger = try Ledger(directory: directory, path: path, source: source, manifest: manifest,
                                    workspaceID: environment["LEDGERFORGE_COMPANION_AUTHENTIC_WORKSPACE"] ?? "default-workspace")
            defer { ledger.close() }
            stage = "qualification body"
            try body(ledger)
            stage = "source preservation"
            try check(try BackupFiles.verifyPackage(source) == manifest, "Qualification altered its selected original native backup")
            try check(try BackupFiles.hash(source.appendingPathComponent("manifest.json")).sha256 == sourceManifestDigest,
                      "Qualification altered the selected native backup manifest")
        } catch let skipped as XCTSkip {
            throw skipped
        } catch let error as Failure {
            if case .assertion(let reason) = error { XCTFail(reason) }
        } catch {
            // Never interpolate Error/localizedDescription: repository errors can carry source details.
            let failure = error as NSError
            XCTFail("Authentic companion qualification failed at \(stage); type=\(type(of: error)); domain=\(failure.domain); code=\(failure.code)")
        }
    }

    private func initializeActualMonth(_ ledger: Ledger, monthOverride: String? = nil,
                                       existingSession: CompanionSyncSessionDTO? = nil) throws -> SelectedMonth {
        try ledger.provider.withConsistentSnapshot {
            let capture = try CompanionMacCapture.take(provider: ledger.provider, workspaceID: ledger.workspaceID,
                selectedGmailAccount: nil, now: Date())
            let plans = try ledger.provider.fundingPlanRepo.plans(workspaceId: ledger.workspaceID)
            let requested = monthOverride ?? ProcessInfo.processInfo.environment["LEDGERFORGE_COMPANION_AUTHENTIC_MONTH"]
            let candidates = capture.runtime.monthlyScratchpads.filter {
                $0.plan.workspaceID == ledger.workspaceID && (requested == nil || $0.plan.month.canonical == requested)
            }.sorted { $0.plan.month.canonical > $1.plan.month.canonical }
            guard let scratch = candidates.first(where: { value in
                guard let canonical = value.canonical, let dto = try? canonical.persistenceDTO() else { return false }
                return plans.contains(dto)
            }) else { throw XCTSkip("AUTHENTIC_COHERENT_MONTH_AND_CANONICAL_PLAN_UNAVAILABLE") }
            let actual = try actualScratchpad(ledger, month: scratch.plan.month.canonical)
            try check(try MonthlyPlanScratchpad.decode(actual) == scratch, "Selected hydration disagrees with durable editor")
            let canonicalDigest = try canonicalGraphDigest(ledger.sqlite.database)
            try ledger.provider.fundingPlanRepo.reconcileCompanionActivation()
            let session = existingSession ?? CompanionSyncSessionDTO(sessionID: UUID().uuidString, workspaceID: ledger.workspaceID,
                activationEpoch: capture.activationEpoch, phoneID: UUID().uuidString, protocolVersion: 1, disposition: "active")
            try check(session.workspaceID == ledger.workspaceID && session.activationEpoch == capture.activationEpoch,
                      "Reused operational session belongs to a different selected ledger")
            try ledger.provider.fundingPlanRepo.createCompanionSession(session)
            let seedMetadata = MonthlyPlanSyncAdapter.metadata(for: scratch,
                lexicalContext: .init(defaultLocaleIdentifier: nil, localeIdentifiersByField: [:]), retaining: .init())
            let draft = try CompanionMacMonthContext.make(scratchpad: scratch, metadata: seedMetadata,
                runtime: capture.runtime, cache: capture.publicCache, selectedHistoryAccountIDs: [])
            let binding = try draft.binding(for: session.scope(month: scratch.plan.month.canonical))
            let anchor = replacing(draft, scratchpad: scratch, metadata: binding.baselineMetadata)
            let normalized = try anchor.binding(for: session.scope(month: scratch.plan.month.canonical))
            let originalMonthRevision = try ledger.provider.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: ledger.workspaceID, month: scratch.plan.month.canonical).monthRevision
            let initialized = try ledger.provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: session.sessionID,
                workspaceID: ledger.workspaceID, month: scratch.plan.month.canonical, expectedActivationEpoch: session.activationEpoch,
                expectedStateRevision: nil, expectedMonthRevision: originalMonthRevision,
                expectedScratchpad: actual, editor: actual, canonical: nil,
                binding: normalized, metadata: anchor.metadata, operation: .initialize(normalized.baselineDocument), currentAnchor: anchor))
            try check(initialized.disposition == .initialized && initialized.stored.stateRevision == 0,
                      "Actual month did not initialize through the production repository")
            return SelectedMonth(session: session, initial: initialized.stored,
                                 initialMonthRevision: try XCTUnwrap(initialized.monthRevision), originalScratchpad: actual,
                                 canonicalPlans: plans, canonicalDigest: canonicalDigest, month: scratch.plan.month.canonical)
        }
    }

    private func incompleteProposal(_ ledger: Ledger, _ selected: SelectedMonth) throws -> CompanionMerge.Proposal {
        let stored = try savedMonth(ledger, selected).decodedEnvelope(session: selected.session)
        let anchor = stored.current, context = anchor.context
        var editor = PortableMonthlyPlanEditor(scratchpad: anchor.scratchpad,
            lexicalContext: MonthlyPlanSyncAdapter.lexicalContext(from: anchor.metadata),
            accounts: context.accounts.map { .init(id: $0.id, nativeCurrency: $0.currency, isHistoryOnly: $0.isHistoryOnly) },
            allHistoryAccountIDs: context.allHistoryAccountIDs,
            selectedHistoryAccountIDs: context.allHistoryAccountIDs.subtracting(anchor.excludedHistoryAccountIDs),
            manuallyExcludedPlanningAccountIDs: context.manuallyExcludedPlanningAccountIDs,
            receipt: context.receipt?.state, receiptBasis: context.receiptBasis, canEdit: true)
        guard let mutation = editor.apply(.money(.fee, text: "-"), inputLocaleIdentifier: "en_US_POSIX"), mutation.changed else {
            throw XCTSkip("AUTHENTIC_SELECTED_MONTH_CANNOT_EXERCISE_INCOMPLETE_FEE_EDIT")
        }
        try check(editor.scratchpad.rawText["fee"] == "-" && editor.scratchpad.fieldErrors["fee"] != nil,
                  "Portable editor did not preserve the actual incomplete entry")
        try check(editor.scratchpad.plan.configuredTransferFee == anchor.scratchpad.plan.configuredTransferFee,
                  "Incomplete entry fabricated a replacement financial value")
        let metadata = MonthlyPlanSyncAdapter.metadata(for: editor.scratchpad, lexicalContext: editor.lexicalContext,
            retaining: anchor.metadata, previousScratchpad: anchor.scratchpad)
        let encoded = try MonthlyPlanSyncAdapter.encode(editor.scratchpad, metadata: metadata,
            against: anchor.binding(for: stored.kernel.scope))
        let phone = try CompanionMerge.PhoneMonthState(scope: stored.kernel.scope, initial: stored.kernel.current)
        return try phone.editing(encoded.document).beginExchange().proposal
    }

    private func receive(_ proposal: CompanionMerge.Proposal, ledger: Ledger, selected: SelectedMonth) throws -> CompanionMonthCommitResult {
        try ledger.provider.withConsistentSnapshot {
            let saved = try savedMonth(ledger, selected)
            let stored = try saved.decodedEnvelope(session: selected.session)
            let expected = try actualScratchpad(ledger, month: selected.month)
            let expectedMonthRevision = try monthRevision(ledger, month: selected.month)
            let binding = try stored.current.binding(for: stored.kernel.scope)
            let transition = try stored.kernel.receiving(proposal)
            let anchor: CompanionMonthAnchor
            let editor: MonthlyPlanScratchpadDTO
            if transition.kind == .applied {
                let decoded = try MonthlyPlanSyncAdapter.decode(document: transition.state.current, against: binding)
                anchor = replacing(stored.current, scratchpad: decoded.scratchpad, metadata: decoded.metadata)
                editor = try decoded.scratchpad.dto()
            } else { anchor = stored.current; editor = expected }
            return try ledger.provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: selected.session.sessionID,
                workspaceID: ledger.workspaceID, month: selected.month, expectedActivationEpoch: selected.session.activationEpoch,
                expectedStateRevision: saved.stateRevision, expectedMonthRevision: expectedMonthRevision,
                expectedScratchpad: expected, editor: editor, canonical: nil,
                binding: binding, metadata: anchor.metadata, operation: .receive(proposal), currentAnchor: anchor))
        }
    }

    private func savedMonth(_ ledger: Ledger, _ selected: SelectedMonth) throws -> CompanionMonthSyncDTO {
        guard let result = try ledger.provider.fundingPlanRepo.companionMonth(sessionID: selected.session.sessionID,
            workspaceID: ledger.workspaceID, month: selected.month) else { throw Failure.assertion("Durable companion month disappeared") }
        return result
    }

    private func monthRevision(_ ledger: Ledger, month: String) throws -> PlanningMonthRevision {
        try ledger.provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: ledger.workspaceID, month: month).monthRevision
    }
    private func actualScratchpad(_ ledger: Ledger, month: String) throws -> MonthlyPlanScratchpadDTO {
        guard let result = try ledger.provider.fundingPlanRepo.scratchpads(workspaceId: ledger.workspaceID).first(where: { $0.month == month }) else {
            throw Failure.assertion("Selected durable scratchpad disappeared")
        }
        return result
    }
    private func replacing(_ anchor: CompanionMonthAnchor, scratchpad: MonthlyPlanScratchpad,
                           metadata: MonthlyPlanSyncAdapter.Metadata) -> CompanionMonthAnchor {
        .init(scratchpad: scratchpad, metadata: metadata, bankCurrencies: anchor.bankCurrencies,
              fundingAccountIDs: anchor.fundingAccountIDs, excludedHistoryAccountIDs: anchor.excludedHistoryAccountIDs,
              context: anchor.context)
    }
    private func check(_ condition: @autoclosure () throws -> Bool, _ reason: String) throws {
        guard try condition() else { throw Failure.assertion(reason) }
    }

    /// Hash exact canonical SQLite row literals in memory only. Never serialize this evidence to disk.
    private func canonicalGraphDigest(_ database: SQLiteDatabase) throws -> SHA256.Digest {
        let names = try database.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND (name='funding_plans' OR name LIKE 'funding_plan_%' OR name IN ('plan_assistance','salary_assistance')) ORDER BY name;") { $0.string(at: 0) ?? "" }
        var hash = SHA256()
        func quotedIdentifier(_ name: String) -> String { "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        for table in names {
            let columns = try database.query(sql: "PRAGMA table_info(" + quotedIdentifier(table) + ");") { $0.string(at: 1) ?? "" }
            try check(!columns.isEmpty, "Canonical graph table has no columns")
            let expressions = columns.map { "quote(" + quotedIdentifier($0) + ")" }.joined(separator: ",")
            let ordering = (1...columns.count).map(String.init).joined(separator: ",")
            let rows = try database.query(sql: "SELECT " + expressions + " FROM " + quotedIdentifier(table) + " ORDER BY " + ordering + ";") { row in
                (0..<columns.count).map { row.string(at: Int32($0)) ?? "NULL" }
            }
            hash.update(data: try JSONEncoder().encode([table] + columns))
            for row in rows { hash.update(data: try JSONEncoder().encode(row)) }
        }
        try check(names.contains("funding_plans"), "Canonical graph oracle did not select the production plan table")
        return hash.finalize()
    }

    private func makeNativeBackup(_ ledger: Ledger) throws -> URL {
        let package = ledger.directory.appendingPathComponent("qualified.ledgerforgebackup", isDirectory: true)
        try BackupFiles.createDirectory(package)
        let payload = package.appendingPathComponent("ledger.sqlite")
        try ledger.sqlite.database.withExclusiveAccess {
            try BackupCompatibility.checkContents(ledger.sqlite.database)
            try ledger.sqlite.database.createBackup(at: payload.path)
        }
        let digest = try BackupFiles.hash(payload)
        let manifest = BackupManifest(formatVersion: 1, backupID: UUID(), createdAt: ISO8601DateFormatter().string(from: Date()),
            application: .init(identifier: nil, version: nil, build: nil),
            database: .init(file: "ledger.sqlite", byteSize: digest.size, sha256: digest.sha256),
            schemaVersion: BackupCompatibility.supportedSchemaVersion, migrations: BackupCompatibility.migrationIdentities,
            contents: BackupManifest.contentDescription, exclusions: BackupManifest.excluded)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(manifest).write(to: package.appendingPathComponent("manifest.json"), options: .withoutOverwriting)
        try BackupFiles.flushPackage(package)
        return package
    }
}
