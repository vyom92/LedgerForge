import Foundation
import Testing
@testable import LedgerForge

/// Source-independent HTML control mechanics only. These fragments are not
/// portal/financial fixtures and do not certify a live sign-in or holdings read.
@Suite("Zurich optional sign-in notices")
struct ZurichISPSignInNoticeTests {
    private let page = URL(string: "https://online.zurichinternationalsolutions.com/Login/RecommendPasswordReset.aspx")!

    @Test func approvedDeclineUsesAssociatedControlAndRetainsHiddenState() throws {
        let html = """
        <form method="post" action="./RecommendPasswordReset.aspx">
        <input name="__VIEWSTATE" type="hidden" value="control-mechanics-only">
        <input name="decline" id="decline-id" type="checkbox">
        <label for="decline-id">I confirm I do not wish to reset my password at this time</label>
        <input name="next" type="submit" value="Continue">
        </form>
        """
        let request = try #require(try ZurichISPSignInContinuation.read(html: html, pageURL: page))
        let query = try #require(URLComponents(string: "https://local.invalid/?" + String(decoding: request.body, as: UTF8.self)))
        let values = Dictionary(uniqueKeysWithValues: (query.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(values["decline"] == "on")
        #expect(values["__VIEWSTATE"] == "control-mechanics-only")
        #expect(values["next"] == "Continue")
        #expect(request.url == page)
    }

    @Test func maintenanceCanContinueWithoutPasswordHeadingOrFixedControlNames() throws {
        let html = """
        <form method="post" action="">
        <p>Scheduled maintenance</p>
        <input name="noticeContinue" type="submit" value="Continue">
        </form>
        """
        let maintenancePage = URL(string: "https://online.zurichinternationalsolutions.com/Login/Notice.aspx")!
        #expect(try ZurichISPSignInContinuation.read(html: html, pageURL: maintenancePage) != nil)
    }

    @Test(arguments: [
        "<input name='newPassword' type='password'>",
        "<input name='verificationCode' type='text'>",
        "<input name='consent' id='c' type='checkbox'><label for='c'>I accept new terms</label>",
        "<input name='hideNotice' id='c' type='checkbox'><label for='c'>Do not show this notice again</label>",
        "<input name='other' type='submit' value='Change password'>",
        "<select name='choice'><option>Continue</option></select>"
    ])
    func additionalActionsAreNeverInferredAsNotices(_ control: String) throws {
        let html = "<form method='post'><p>Maintenance</p>\(control)<input name='next' type='submit' value='Continue'></form>"
        #expect(try ZurichISPSignInContinuation.read(html: html, pageURL: page) == nil)
    }

    @Test func externalActionAndAmbiguousFormsDoNotContinue() throws {
        let form = "<form method='post'><p>Maintenance</p><input name='next' type='submit' value='Continue'></form>"
        #expect(try ZurichISPSignInContinuation.read(html: form + form, pageURL: page) == nil)
        let external = form.replacingOccurrences(of: "method='post'", with: "method='post' action='https://example.invalid/'")
        #expect(throws: ZurichISPClientError.unauthorizedRedirect) {
            try ZurichISPSignInContinuation.read(html: external, pageURL: page)
        }
    }

    @Test func signInErrorsIdentifyTheirStepWithoutCallingUnknownPagesBadPasswords() {
        #expect(ZurichISPClientError.rejectedSignIn.errorDescription?.contains("username and password step") == true)
        #expect(ZurichISPClientError.rejectedPIN.errorDescription?.contains("memorable PIN step") == true)
        #expect(ZurichISPClientError.unexpectedSignInPage.errorDescription?.contains("does not mean your password was rejected") == true)
        #expect(ZurichISPClientError.unexpectedSignInPage.invalidatesSession)
    }
}

/// Calendar-only proof for the authenticated ISP monthly check. These tests make
/// no network, Keychain, or repository call.
@Suite("Zurich ISP monthly schedule")
struct ZurichISPMonthlyScheduleTests {
    private static func utc(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    @Test func fifthAtUTCBeginsTheFirstActiveOpportunity() {
        let before = Self.utc("2026-04-05T00:00:00Z").addingTimeInterval(-0.001)
        let due = Self.utc("2026-04-05T00:00:00Z")
        #expect(!ZurichISPMonthlySchedule.isDue(at: before, lastSuccess: nil))
        #expect(ZurichISPMonthlySchedule.isDue(at: due, lastSuccess: nil))
        #expect(ZurichISPMonthlySchedule.nextDate(after: before) == due)
    }

    @Test func successBeforeTheFifthDoesNotSatisfyTheNewMonthlyDueCheck() {
        let before = Self.utc("2026-04-04T23:59:59Z")
        let after = Self.utc("2026-04-05T12:00:00Z")
        #expect(ZurichISPMonthlySchedule.isDue(at: after, lastSuccess: before))
    }

    @Test func successAfterTheFifthPreventsAnotherAutomaticReadThatMonth() {
        let success = Self.utc("2026-04-05T00:00:01Z")
        #expect(!ZurichISPMonthlySchedule.isDue(at: Self.utc("2026-04-05T23:59:59Z"), lastSuccess: success))
        #expect(!ZurichISPMonthlySchedule.isDue(at: Self.utc("2026-04-30T23:59:59Z"), lastSuccess: success))
        #expect(ZurichISPMonthlySchedule.isDue(at: Self.utc("2026-05-05T00:00:00Z"), lastSuccess: success))
    }

    @Test func monthEndLeapYearAndLocalTimezoneDoNotChangeTheUTCDecision() {
        let success = Self.utc("2028-02-05T00:00:00Z")
        #expect(ZurichISPMonthlySchedule.nextDate(after: Self.utc("2028-02-29T23:59:59Z")) == Self.utc("2028-03-05T00:00:00Z"))
        #expect(ZurichISPMonthlySchedule.isDue(at: Self.utc("2028-03-05T00:00:00Z"), lastSuccess: success))

        // The input is an absolute instant. The fixed UTC schedule therefore has
        // the same answer regardless of the process's local display timezone.
        let instant = Self.utc("2028-03-05T00:00:00Z")
        let qatar = TimeZone(identifier: "Asia/Qatar")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        #expect(Calendar(identifier: .gregorian).dateComponents(in: qatar, from: instant).day !=
                Calendar(identifier: .gregorian).dateComponents(in: losAngeles, from: instant).day)
        #expect(ZurichISPMonthlySchedule.isDue(at: instant, lastSuccess: success))
    }
}

/// Command admission only; no credentials, statement data or transport response.
@MainActor
@Suite("Zurich ISP command availability")
struct ZurichISPSessionCommandTests {
    @Test func disabledSessionExplainsTheRefusalAndCannotReachSharedFetch() {
        let session = ZurichISPSyncSession(enabled: false)
        var forwarded = false
        session.sharedHoldingsRefresh = { _ in forwarded = true }
        #expect(!session.isConnectionAvailable)
        #expect(session.connectionSummary.contains("disabled"))
        session.fetchHoldings()
        #expect(!forwarded)
        #expect(session.message?.contains("disabled") == true)
        session.checkConnection()
        session.usePilotConnection()
        #expect(!session.isBusy)
        #expect(session.completedConnectionID == nil)
    }

    @Test func missingLedgerDoesNotLookLikeACompletedConnection() {
        let session = ZurichISPSyncSession()
        session.checkConnection()
        #expect(session.isConnectionAvailable)
        #expect(!session.isBusy)
        #expect(session.message == ZurichISPSnapshotError.unavailable.localizedDescription)
        #expect(session.completedConnectionID == nil)
    }

    @Test func sharedRefreshPreventsCompetingConnectionAndPreservesBusyState() {
        let session = ZurichISPSyncSession()
        var forwarded = false
        session.sharedHoldingsRefresh = { _ in forwarded = true }
        session.sharedRefreshState(busy: true, message: "Updating holdings…")
        session.checkConnection()
        session.fetchHoldings()
        #expect(session.isBusy)
        #expect(!forwarded)
        #expect(session.message == ZurichISPClientError.inFlight.localizedDescription)
        #expect(session.completedConnectionID == nil)
    }

    @Test func sharedRefreshInvalidationClearsProgressAndAllowsAnotherCommand() {
        let session = ZurichISPSyncSession()
        var forwarded = false
        session.sharedHoldingsRefresh = { _ in forwarded = true }
        session.sharedRefreshState(busy: true, message: "Updating ISP holdings…")
        session.sharedRefreshState(busy: false, message: nil)
        #expect(!session.isBusy)
        #expect(session.message == nil)
        session.fetchHoldings()
        #expect(forwarded)
    }

    @Test func generationInvalidationDoesNotLeaveAStaleProgressMessage() {
        let session = ZurichISPSyncSession()
        session.sharedRefreshState(busy: true, message: "Updating ISP holdings…")
        session.installWithoutObservation(.empty, generation: ProviderGenerationToken())
        #expect(!session.isBusy)
        #expect(session.message == nil)
        session.cancel()
        #expect(session.message == nil) // No running request can be called cancelled.
    }

    @Test func sharedFetchExplainsKnownFailuresWithoutExposingArbitraryErrorContent() {
        let validation = BackgroundUpdateExecutor.ispFailureMessage(ZurichISPSnapshotError.invalidSource)
        #expect(validation == ZurichISPSnapshotError.invalidSource.errorDescription)
        #expect(BackgroundUpdateExecutor.ispFailureMessage(ZurichISPSnapshotError.inconsistentPolicyFigures) ==
            "Connected to Zurich, but its policy summary and contribution details do not agree. Previous holdings are retained.")
        #expect(BackgroundUpdatesSession.summary(.ispFailed(validation)) == validation)
        #expect(BackgroundUpdateExecutor.ispFailureMessage(InvestmentError.olderSnapshot) == InvestmentError.olderSnapshot.errorDescription)
        let privateError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "private-response-marker"])
        #expect(!BackgroundUpdateExecutor.ispFailureMessage(privateError).contains("private-response-marker"))
        #expect(!BackgroundUpdateExecutor.ispFailureMessage(InvestmentError.missingSourceField("private-field-marker")).contains("private-field-marker"))
    }
}

/// These checks exercise the production installed shared command/task owner and
/// its synchronous publication gate using only counters and outcome markers.
/// No financial source, holdings DTO, provider, Keychain or network is involved.
@MainActor
@Suite("Zurich ISP shared request ownership")
struct ZurichISPSharedRequestOwnershipTests {
    @Test(.timeLimit(.minutes(1))) func cancelReachesTheOwningTaskRejectsLateCallbackAndAllowsSubsequentFetch() async {
        let session = ZurichISPSyncSession()
        let adapter = BackgroundUpdatesSession(networkEnabled: false)
        let firstGate = ISPRequestMechanicsGate(), secondGate = ISPRequestMechanicsGate()
        let probe = ISPRequestMechanicsProbe()
        var requests = 0
        adapter.installSharedISPHandlers(on: session) { manual in
            #expect(manual)
            requests += 1
            let gate = requests == 1 ? firstGate : secondGate
            adapter.startISPRequest { request in
                await gate.wait()
                let cancelled = Task.isCancelled
                // A late callback can arrive in a fresh uncancelled task. The
                // request's publication gate must still refuse that callback.
                return await Task { @MainActor in
                    probe.taskCancellations.append(cancelled)
                    #expect(!Task.isCancelled)
                    do {
                        _ = try request.publish { probe.publications += 1; return .saved }
                        return BackgroundUpdateExecutor.Outcome.completed(.committedCurrentHoldings)
                    } catch {
                        return BackgroundUpdateExecutor.Outcome.ispFailed("Late callback after cancellation")
                    }
                }.value
            } completion: { outcome in probe.finish(outcome) }
        }

        session.fetchHoldings()
        await firstGate.waitUntilEntered()
        #expect(session.isBusy)
        session.cancel()
        #expect(session.isBusy)
        #expect(session.message == "Cancelling ISP update…")
        session.fetchHoldings()
        #expect(requests == 1)
        #expect(session.message == ZurichISPClientError.inFlight.localizedDescription)
        await firstGate.open()
        await probe.waitForCompletions(1)
        #expect(probe.outcomes == [.cancelled])
        #expect(probe.publications == 0)
        #expect(!session.isBusy)
        #expect(session.message == "Cancelled. Previous ISP holdings are retained.")

        session.fetchHoldings()
        await secondGate.waitUntilEntered()
        #expect(requests == 2)
        #expect(session.isBusy)
        #expect(session.message == "Updating ISP holdings…")
        await secondGate.open()
        await probe.waitForCompletions(2)
        #expect(probe.taskCancellations == [true, false])
        #expect(probe.publications == 1)
        #expect(probe.outcomes == [.cancelled, .completed(.committedCurrentHoldings)])
        #expect(!session.isBusy)
        #expect(session.message == "ISP holdings updated.")
        session.cancel()
        #expect(session.message == "ISP holdings updated.")
    }

    @Test(.timeLimit(.minutes(1))) func cancelAfterSynchronousCommitReportsSavedAndDoesNotCancelFinishingTask() async {
        let session = ZurichISPSyncSession()
        let adapter = BackgroundUpdatesSession(networkEnabled: false)
        let gate = ISPRequestMechanicsGate()
        let probe = ISPRequestMechanicsProbe()
        adapter.installSharedISPHandlers(on: session) { _ in
            adapter.startISPRequest { request in
                do {
                    _ = try await MainActor.run {
                        try request.publish { probe.publications += 1; return .saved }
                    }
                } catch { return .cancelled }
                // Model only the post-commit asynchronous metadata interval.
                await gate.wait()
                let cancelled = Task.isCancelled
                await MainActor.run { probe.taskCancellations.append(cancelled) }
                return .completed(.committedCurrentHoldings)
            } completion: { outcome in probe.finish(outcome) }
        }
        session.fetchHoldings()
        await gate.waitUntilEntered()
        #expect(probe.publications == 1)
        session.cancel()
        #expect(session.isBusy)
        #expect(session.message == "ISP holdings were already updated. Finishing the refresh…")
        await gate.open()
        await probe.waitForCompletions(1)
        #expect(probe.taskCancellations == [false])
        #expect(probe.outcomes == [.completed(.committedCurrentHoldings)])
        #expect(session.message == "ISP holdings updated.")
        #expect(!session.isBusy)
    }

    @Test(.timeLimit(.minutes(1))) func invalidatedRequestsCannotClearOrCompleteTheirSuccessor() async {
        let session = ZurichISPSyncSession()
        let adapter = BackgroundUpdatesSession(networkEnabled: false)
        let firstGate = ISPRequestMechanicsGate(), secondGate = ISPRequestMechanicsGate()
        let probe = ISPRequestMechanicsProbe()
        var requests = 0
        adapter.installSharedISPHandlers(on: session) { _ in
            requests += 1
            let gate = requests == 1 ? firstGate : secondGate
            adapter.startISPRequest { request in
                await gate.wait()
                return await Task { @MainActor in
                    do {
                        _ = try request.publish { probe.publications += 1; return .saved }
                        return BackgroundUpdateExecutor.Outcome.completed(.committedCurrentHoldings)
                    } catch { return BackgroundUpdateExecutor.Outcome.cancelled }
                }.value
            } completion: { outcome in probe.finish(outcome) }
        }
        session.fetchHoldings()
        await firstGate.waitUntilEntered()
        let retiredTask = adapter.invalidateISPRequest()
        #expect(!session.isBusy)
        session.fetchHoldings()
        await secondGate.waitUntilEntered()
        await firstGate.open()
        await retiredTask?.value
        #expect(probe.publications == 0)
        #expect(probe.outcomes.isEmpty)
        #expect(session.isBusy)
        #expect(session.message == "Updating ISP holdings…")
        await secondGate.open()
        await probe.waitForCompletions(1)
        #expect(probe.publications == 1)
        #expect(probe.outcomes == [.completed(.committedCurrentHoldings)])
        #expect(!session.isBusy)
    }

    @Test func rejectedPublicationRemainsCancellableAndCannotBeReportedAsSaved() throws {
        let request = ZurichISPRefreshRequest()
        let rejected = try request.publish { .unavailable }
        #expect(rejected == .unavailable)
        #expect(!request.didCommit)
        #expect(request.cancel())
        var entered = false
        #expect(throws: CancellationError.self) {
            try request.publish { entered = true; return .saved }
        }
        #expect(!entered)
        #expect(request.resolved(.ispFailed("Publication refused")) == .cancelled)
    }
}

private actor ISPRequestMechanicsGate {
    private var entered = false
    private var opened = false
    private var entry: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?

    func wait() async {
        entered = true
        entry?.resume(); entry = nil
        if opened { return }
        await withCheckedContinuation { release = $0 }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entry = $0 }
    }

    func open() {
        opened = true
        release?.resume(); release = nil
    }
}

@MainActor
private final class ISPRequestMechanicsProbe {
    var publications = 0
    var taskCancellations: [Bool] = []
    private(set) var outcomes: [BackgroundUpdateExecutor.Outcome] = []
    private var awaitedCount = 0
    private var completion: CheckedContinuation<Void, Never>?

    func finish(_ outcome: BackgroundUpdateExecutor.Outcome) {
        outcomes.append(outcome)
        if outcomes.count >= awaitedCount { completion?.resume(); completion = nil }
    }

    func waitForCompletions(_ count: Int) async {
        if outcomes.count >= count { return }
        awaitedCount = count
        await withCheckedContinuation { completion = $0 }
    }
}
