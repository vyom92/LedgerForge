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
        #expect(session.message == "Cancelled. Previous ISP holdings are retained.")
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
