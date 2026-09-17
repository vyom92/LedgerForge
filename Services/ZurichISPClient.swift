@preconcurrency import Foundation

// Adapted from the owner-qualified native ZIO pilot. Source payloads,
// credentials and transport snapshots remain in process memory.

nonisolated struct ZurichISPCredentials: Codable, Equatable, Sendable {
    let username: String
    let password: String
    let memorablePIN: String
}

nonisolated struct ZurichISPSourcePolicy: Equatable, Sendable {
    let policyID: String
    let label: String
    let valuationDateDisplay: String
    let fundLiteral: String
    let regularLiteral: String
    let summaryRows: [[String]]
    let contributionRows: [[String]]
}

nonisolated struct ZurichISPSourceAccount: Equatable, Sendable {
    let fetchedAt: Date
    let policies: [ZurichISPSourcePolicy]
}

/// A caller may consume a response immediately to make a RAM-only independent
/// oracle. The client neither logs nor retains the observed bytes.
typealias ZurichISPResponseObserver = @Sendable (_ endpoint: String, _ body: Data) -> Void

nonisolated enum ZurichISPClientError: Error, LocalizedError, Equatable, Sendable {
    case inFlight
    case cancelled
    case timedOut
    case network
    case responseTooLarge
    case unauthorizedRedirect
    case malformedSource
    case unsupportedSignIn
    case rejectedSignIn
    case malformedPINChallenge
    case rejectedPIN
    case sessionExpired
    case policySelection
    case partialResponse
    case incompleteAccount

    var invalidatesSession: Bool {
        switch self {
        case .rejectedSignIn, .rejectedPIN, .unsupportedSignIn, .sessionExpired, .unauthorizedRedirect, .timedOut, .cancelled:
            true
        default:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .inFlight: "An ISP connection check is already in progress."
        case .cancelled: "The ISP connection check was cancelled."
        case .timedOut: "The ISP connection check took too long."
        case .rejectedSignIn, .rejectedPIN: "Zurich did not accept the supplied credentials."
        case .unsupportedSignIn: "Zurich requested a sign-in step LedgerForge cannot complete."
        case .unauthorizedRedirect: "Zurich redirected outside the approved sign-in origin."
        case .responseTooLarge: "A Zurich response exceeded the safety limit."
        default: "The Zurich response could not be safely verified."
        }
    }
}

/// An actor-bound native WebForms transport. One caller owns calls sequentially;
/// it makes no timer, retry, or persistent-state decisions.
actor ZurichISPClient {
    typealias Transport = @Sendable (_ request: URLRequest, _ session: URLSession) async throws -> (Data, HTTPURLResponse)

    private static let authorizedHost = "online.zurichinternationalsolutions.com"
    private static let memberJourneyURL = URL(string: "https://online.zurichinternationalsolutions.com/Corporate/MemberJourney/")!
    private static let policyDetailURL = URL(string: "https://online.zurichinternationalsolutions.com/Corporate/MemberJourney/MyAccount/PolicyDetail")!
    private static let maximumResponseBytes = 2 * 1024 * 1024
    private static let requestTimeout: TimeInterval = 30
    private static let completeFetchTimeout: TimeInterval = 90
    private static let policyLabels = ["(Employee Mandatory)", "(Employee AVC)", "(Employer Mandatory)"]

    private let redirectDelegate: SameOriginRedirectDelegate
    private let transport: Transport
    private let now: @Sendable () -> Date
    private let observer: ZurichISPResponseObserver?
    private var session: URLSession
    private var sessionCredentials: ZurichISPCredentials?
    private var isAuthenticated = false
    private var isFetching = false
    private var sessionGeneration = 0

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        observer: ZurichISPResponseObserver? = nil,
        transport: Transport? = nil
    ) {
        let redirectDelegate = SameOriginRedirectDelegate()
        self.redirectDelegate = redirectDelegate
        self.now = now
        self.observer = observer
        self.transport = transport ?? { request, session in
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ZurichISPClientError.network }
            return (data, http)
        }
        self.session = Self.makeSession(delegate: redirectDelegate)
    }

    /// Cancels the current session and discards its in-memory cookies and credentials.
    func reset() {
        session.invalidateAndCancel()
        session = Self.makeSession(delegate: redirectDelegate)
        sessionGeneration &+= 1
        sessionCredentials = nil
        isAuthenticated = false
    }

    /// `reset()` is the explicit cancellation mechanism for a currently awaited read.
    func cancel() {
        reset()
    }

    func fetch(
        credentials: ZurichISPCredentials,
        expectedPolicyIDs: Set<String>,
        status: @escaping @Sendable (String) -> Void
    ) async throws -> ZurichISPSourceAccount {
        guard !isFetching else { throw ZurichISPClientError.inFlight }
        guard expectedPolicyIDs.isEmpty || expectedPolicyIDs.count == Self.policyLabels.count else {
            throw ZurichISPClientError.incompleteAccount
        }
        guard credentials.username.isEmpty == false, credentials.password.isEmpty == false, credentials.memorablePIN.count >= 3 else {
            throw ZurichISPClientError.rejectedSignIn
        }
        if sessionCredentials != credentials {
            reset()
            sessionCredentials = credentials
        }
        isFetching = true
        defer { isFetching = false }

        do {
            return try await Self.withTimeout(seconds: Self.completeFetchTimeout) { [self] in
                try await readCompleteAccount(credentials: credentials, expectedPolicyIDs: expectedPolicyIDs, status: status)
            }
        } catch is CancellationError {
            reset()
            throw ZurichISPClientError.cancelled
        } catch let error as ZurichISPClientError {
            if error.invalidatesSession { reset() }
            throw error
        } catch {
            throw ZurichISPClientError.network
        }
    }

    private func readCompleteAccount(
        credentials: ZurichISPCredentials,
        expectedPolicyIDs: Set<String>,
        status: @escaping @Sendable (String) -> Void
    ) async throws -> ZurichISPSourceAccount {
        if !isAuthenticated {
            try await authenticate(credentials: credentials, status: status)
        }

        status("Reading Zurich policy holdings…")
        let policyPage = try await request(label: "PolicyDetail", url: Self.policyDetailURL, method: "GET")
        if isLoginPage(policyPage) { throw ZurichISPClientError.sessionExpired }
        let policies = try observedPolicies(in: policyPage, expectedPolicyIDs: expectedPolicyIDs)
        guard policies.count == Self.policyLabels.count,
              expectedPolicyIDs.isEmpty || Set(policies.map(\.id)) == expectedPolicyIDs else {
            throw ZurichISPClientError.incompleteAccount
        }

        var selectedPage = policyPage
        var sourcePolicies: [ZurichISPSourcePolicy] = []
        for policy in policies {
            try Task.checkCancellation()
            status("Reading \(policy.label) holdings…")
            selectedPage = try await select(policy: policy, from: selectedPage)
            sourcePolicies.append(try await fetchPartials(policy: policy, selectedPage: selectedPage))
        }
        guard sourcePolicies.count == Self.policyLabels.count,
              expectedPolicyIDs.isEmpty || Set(sourcePolicies.map(\.policyID)) == expectedPolicyIDs else {
            throw ZurichISPClientError.incompleteAccount
        }
        return ZurichISPSourceAccount(fetchedAt: now(), policies: sourcePolicies)
    }

    private func authenticate(credentials: ZurichISPCredentials, status: @escaping @Sendable (String) -> Void) async throws {
        status("Opening Zurich sign-in…")
        let loginPage = try await request(label: "MemberJourney", url: Self.memberJourneyURL, method: "GET")
        let loginForm = try requireForm(in: loginPage, containing: "ctl00$ContentPlaceHolder1$txtUserName")
        let loginAction = try formAction(loginForm, relativeTo: loginPage.response.url ?? Self.memberJourneyURL)
        let loginSubmit = "ctl00$ContentPlaceHolder1$cmdLogin"
        guard loginForm.hasEnabledSubmit(named: loginSubmit) else { throw ZurichISPClientError.malformedSource }
        var loginFields = formFields(loginForm, selectedSubmit: loginSubmit)
        loginFields.set("ctl00$ContentPlaceHolder1$txtUserName", to: credentials.username)
        loginFields.set("ctl00$ContentPlaceHolder1$txtPassword", to: credentials.password)
        loginFields.removeAll { $0.name.lowercased().contains("remember") }

        status("Submitting Zurich sign-in…")
        let loginReply = try await request(label: "Login", url: loginAction, method: "POST", form: loginFields)
        let pinForm = try pinChallengeForm(in: loginReply)
        let requestedIndexes = try requestedPINIndexes(in: pinForm, memorablePIN: credentials.memorablePIN)
        let pinAction = try formAction(pinForm, relativeTo: loginReply.response.url ?? loginAction)
        let pinSubmit = "ctl00$ContentPlaceHolder1$ucPinValidator$btnRandomPinContinue"
        guard pinForm.hasEnabledSubmit(named: pinSubmit) else { throw ZurichISPClientError.malformedPINChallenge }
        var pinFields = formFields(pinForm, selectedSubmit: pinSubmit)
        for index in requestedIndexes {
            let field = "ctl00$ContentPlaceHolder1$ucPinValidator$TextBoxPin\(index)"
            let position = credentials.memorablePIN.index(credentials.memorablePIN.startIndex, offsetBy: index - 1)
            pinFields.set(field, to: String(credentials.memorablePIN[position]))
        }

        status("Submitting the requested memorable PIN positions…")
        let pinReply = try await request(label: "PIN", url: pinAction, method: "POST", form: pinFields)
        try requireSuccessfulHome(pinReply)
        isAuthenticated = true
    }

    private func select(policy: ObservedPolicy, from page: HTTPPayload) async throws -> HTTPPayload {
        let form = try requireForm(in: page, id: "frmPolicy")
        let action = try formAction(form, relativeTo: page.response.url ?? Self.policyDetailURL)
        var fields = formFields(form)
        guard fields.contains(name: "__RequestVerificationToken") else { throw ZurichISPClientError.policySelection }
        fields.set("PolicyNumber", to: policy.id)
        let response = try await request(label: "PolicyDetail.select", url: action, method: "POST", form: fields)
        if isLoginPage(response) { throw ZurichISPClientError.sessionExpired }
        guard try selectedPolicy(in: response) == policy.id,
              hiddenInput(named: "PolicyNumber", in: response)?.value == policy.id else {
            throw ZurichISPClientError.policySelection
        }
        return response
    }

    private func fetchPartials(policy: ObservedPolicy, selectedPage: HTTPPayload) async throws -> ZurichISPSourcePolicy {
        guard let base = selectedPage.response.url?.deletingLastPathComponent() else { throw ZurichISPClientError.partialResponse }
        let names = ["PolicyValuePartial", "PolicySummaryPartial", "ContributionsPartial", "InvestementStrategyPartial"]
        var payloads: [String: HTTPPayload] = [:]
        for name in names {
            var components = URLComponents(url: base.appendingPathComponent(name), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "policynumber", value: policy.id)]
            guard let url = components?.url else { throw ZurichISPClientError.partialResponse }
            payloads[name] = try await request(label: name, url: url, method: "GET", ajax: true)
        }
        guard let value = payloads["PolicyValuePartial"], let summary = payloads["PolicySummaryPartial"],
              let contributions = payloads["ContributionsPartial"], let strategy = payloads["InvestementStrategyPartial"] else {
            throw ZurichISPClientError.partialResponse
        }
        if [value, summary, contributions, strategy].contains(where: isLoginPage) {
            throw ZurichISPClientError.sessionExpired
        }
        let funds = try structuredFunds(in: value)
        let valuationDate = try valuationDateDisplay(in: value)
        let summaryRows = try tableRows(in: summary, requireAtLeastOne: true)
        try validateKeyValueRows(summaryRows, required: ["Policy type", "Status", "Start date", "Maturity date", "Plan currency", "Total contributions", "Value", "Growth"], optional: ["Vested value"])
        let contributionRows = try tableRows(in: contributions, requireAtLeastOne: true)
        try validateKeyValueRows(contributionRows, required: ["Contributions", "Value", "Growth"], optional: ["Vested value"])
        let regular = try structuredRegularStrategy(in: strategy)
        return ZurichISPSourcePolicy(
            policyID: policy.id,
            label: policy.label,
            valuationDateDisplay: valuationDate,
            fundLiteral: funds.literal,
            regularLiteral: regular.literal,
            summaryRows: summaryRows,
            contributionRows: contributionRows
        )
    }

    private func request(label: String, url: URL, method: String, form: [FormField] = [], ajax: Bool = false) async throws -> HTTPPayload {
        try Task.checkCancellation()
        guard Self.isAuthorized(url) else { throw ZurichISPClientError.unauthorizedRedirect }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.requestTimeout)
        request.httpMethod = method
        request.setValue("text/html, */*; q=0.01", forHTTPHeaderField: "Accept")
        if ajax { request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With") }
        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try formEncoded(form)
        }
        do {
            let requestSession = session
            let requestGeneration = sessionGeneration
            let (data, response) = try await transport(request, requestSession)
            try Task.checkCancellation()
            guard requestGeneration == sessionGeneration else { throw ZurichISPClientError.cancelled }
            guard let finalURL = response.url, Self.isAuthorized(finalURL) else { throw ZurichISPClientError.unauthorizedRedirect }
            guard data.count <= Self.maximumResponseBytes else { throw ZurichISPClientError.responseTooLarge }
            guard (200...299).contains(response.statusCode) else { throw ZurichISPClientError.network }
            observer?(label, data)
            return HTTPPayload(data: data, response: response)
        } catch is CancellationError {
            throw ZurichISPClientError.cancelled
        } catch let error as ZurichISPClientError {
            throw error
        } catch {
            throw ZurichISPClientError.network
        }
    }

    private static func makeSession(delegate: URLSessionTaskDelegate) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private static func withTimeout<T: Sendable>(seconds: TimeInterval, work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ZurichISPClientError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw ZurichISPClientError.network }
            return result
        }
    }

    private static func isAuthorized(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.host?.lowercased() == authorizedHost else { return false }
        return url.port == nil || url.port == 443
    }
}

nonisolated private final class SameOriginRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let url = request.url,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "online.zurichinternationalsolutions.com",
              url.port == nil || url.port == 443 else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

nonisolated private struct HTTPPayload: Sendable {
    let data: Data
    let response: HTTPURLResponse
    var html: String? { String(data: data, encoding: .utf8) }
}

nonisolated private struct ObservedPolicy: Sendable {
    let id: String
    let label: String
}

nonisolated private struct FormField: Sendable {
    let name: String
    var value: String
}

private extension Array where Element == FormField {
    nonisolated mutating func set(_ name: String, to value: String) {
        if let index = firstIndex(where: { $0.name == name }) { self[index].value = value }
        else { append(FormField(name: name, value: value)) }
    }
    nonisolated func contains(name: String) -> Bool { contains { $0.name == name } }
}

nonisolated private struct HTMLInput: Sendable {
    let name: String
    let type: String
    let value: String
    let attributes: [String: String]
}

nonisolated private struct HTMLForm: Sendable {
    let attributes: [String: String]
    let inputs: [HTMLInput]
    func hasEnabledSubmit(named name: String) -> Bool {
        inputs.contains { $0.name == name && $0.type.lowercased() == "submit" && $0.attributes["disabled"] == nil }
    }
}

nonisolated private enum HTMLParser {
    static func forms(in html: String) -> [HTMLForm] {
        let pattern = #"(?is)<form\b([^>]*)>(.*?)</form\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let attributes = substring(html, match.range(at: 1)), let body = substring(html, match.range(at: 2)) else { return nil }
            return HTMLForm(attributes: attributesMap(attributes), inputs: inputs(in: body))
        }
    }

    static func inputs(in html: String) -> [HTMLInput] {
        let pattern = #"(?is)<input\b([^>]*)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let raw = substring(html, match.range(at: 1)) else { return nil }
            let attributes = attributesMap(raw)
            guard let name = attributes["name"], !name.isEmpty else { return nil }
            return HTMLInput(name: name, type: attributes["type"] ?? "text", value: attributes["value"] ?? "", attributes: attributes)
        }
    }

    static func attributesMap(_ source: String) -> [String: String] {
        let pattern = #"(?is)([A-Za-z_:][A-Za-z0-9_:.\-]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let range = NSRange(source.startIndex..., in: source)
        var result = regex.matches(in: source, range: range).reduce(into: [String: String]()) { result, match in
            guard let key = substring(source, match.range(at: 1))?.lowercased() else { return }
            let raw = substring(source, match.range(at: 2)) ?? substring(source, match.range(at: 3)) ?? substring(source, match.range(at: 4)) ?? ""
            result[key] = htmlDecode(raw)
        }
        for boolean in ["selected", "checked", "disabled"] {
            let escaped = NSRegularExpression.escapedPattern(for: boolean)
            if source.range(of: "(?i)(?:^|\\s)\(escaped)(?=\\s|=|/?>|$)", options: .regularExpression) != nil {
                result[boolean] = result[boolean] ?? ""
            }
        }
        return result
    }

    private static func substring(_ string: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound, let range = Range(range, in: string) else { return nil }
        return String(string[range])
    }
}

nonisolated private func requireForm(in payload: HTTPPayload, id: String) throws -> HTMLForm {
    guard let html = payload.html,
          let form = HTMLParser.forms(in: html).first(where: { $0.attributes["id"] == id }) else {
        throw ZurichISPClientError.malformedSource
    }
    return form
}

nonisolated private func requireForm(in payload: HTTPPayload, containing fieldName: String) throws -> HTMLForm {
    guard let html = payload.html,
          let form = HTMLParser.forms(in: html).first(where: { $0.inputs.contains { $0.name == fieldName } }) else {
        throw ZurichISPClientError.malformedSource
    }
    return form
}

nonisolated private func formAction(_ form: HTMLForm, relativeTo pageURL: URL) throws -> URL {
    let action = form.attributes["action"] ?? ""
    guard let url = URL(string: action, relativeTo: pageURL)?.absoluteURL,
          url.scheme?.lowercased() == "https",
          url.host?.lowercased() == "online.zurichinternationalsolutions.com",
          url.port == nil || url.port == 443 else {
        throw ZurichISPClientError.unauthorizedRedirect
    }
    return url
}

nonisolated private func formFields(_ form: HTMLForm, selectedSubmit: String? = nil) -> [FormField] {
    form.inputs.compactMap { input in
        let type = input.type.lowercased()
        guard input.attributes["disabled"] == nil else { return nil }
        if type == "submit", input.name != selectedSubmit { return nil }
        guard !["button", "image", "reset", "file"].contains(type) else { return nil }
        guard !["checkbox", "radio"].contains(type) || input.attributes["checked"] != nil else { return nil }
        return FormField(name: input.name, value: input.value)
    }
}

nonisolated private func formEncoded(_ fields: [FormField]) throws -> Data {
    let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    func encoded(_ value: String) throws -> String {
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved) else { throw ZurichISPClientError.malformedSource }
        return encoded.replacingOccurrences(of: "%20", with: "+")
    }
    let body = try fields.map { "\(try encoded($0.name))=\(try encoded($0.value))" }.joined(separator: "&")
    guard let data = body.data(using: .utf8) else { throw ZurichISPClientError.malformedSource }
    return data
}

nonisolated private func hiddenInput(named name: String, in payload: HTTPPayload) -> HTMLInput? {
    guard let html = payload.html else { return nil }
    return HTMLParser.inputs(in: html).first { $0.name == name && $0.type.lowercased() == "hidden" }
}

nonisolated private func containsUnsupportedSignIn(_ payload: HTTPPayload) -> Bool {
    guard let html = payload.html?.lowercased() else { return true }
    return ["captcha", "one-time password", "otp", "device consent", "device verification", "security code"].contains { html.contains($0) }
}

nonisolated private func isLoginPage(_ payload: HTTPPayload) -> Bool {
    payload.html?.localizedCaseInsensitiveContains("txtUserName") == true
}

nonisolated private func pinChallengeForm(in payload: HTTPPayload) throws -> HTMLForm {
    if containsUnsupportedSignIn(payload) { throw ZurichISPClientError.unsupportedSignIn }
    guard let html = payload.html else { throw ZurichISPClientError.malformedSource }
    if html.localizedCaseInsensitiveContains("txtUserName") { throw ZurichISPClientError.rejectedSignIn }
    guard let form = HTMLParser.forms(in: html).first(where: { form in
        form.inputs.contains { $0.name.contains("ucPinValidator$TextBoxPin") }
    }) else { throw ZurichISPClientError.unsupportedSignIn }
    return form
}

nonisolated private func requestedPINIndexes(in form: HTMLForm, memorablePIN: String) throws -> [Int] {
    let indexes = form.inputs.compactMap { input -> Int? in
        guard input.type.lowercased() == "password",
              let marker = input.name.range(of: "TextBoxPin", options: .backwards) else { return nil }
        return Int(input.name[marker.upperBound...])
    }
    let unique = Array(Set(indexes)).sorted()
    guard unique.count == 3, unique.allSatisfy({ $0 >= 1 && $0 <= memorablePIN.count }) else {
        throw ZurichISPClientError.malformedPINChallenge
    }
    return unique
}

nonisolated private func requireSuccessfulHome(_ payload: HTTPPayload) throws {
    guard let url = payload.response.url else { throw ZurichISPClientError.rejectedPIN }
    if containsUnsupportedSignIn(payload) { throw ZurichISPClientError.unsupportedSignIn }
    guard url.path.lowercased() == "/corporate/memberjourney/home/index" else { throw ZurichISPClientError.rejectedPIN }
}

nonisolated private func observedPolicies(in payload: HTTPPayload, expectedPolicyIDs: Set<String>) throws -> [ObservedPolicy] {
    guard let html = payload.html, let select = element(id: "ddlPolicy", tag: "select", in: html) else {
        throw ZurichISPClientError.policySelection
    }
    let options = optionElements(in: select.body)
    let policies = ["(Employee Mandatory)", "(Employee AVC)", "(Employer Mandatory)"].compactMap { label -> ObservedPolicy? in
        let matches = options.filter { normalizedText($0.body).hasSuffix(label) && !$0.attributes["value", default: ""].isEmpty }
        guard matches.count == 1, let id = matches.first?.attributes["value"] else { return nil }
        return ObservedPolicy(id: id, label: label)
    }
    guard policies.count == 3,
          Set(policies.map(\.id)).count == 3,
          expectedPolicyIDs.isEmpty || Set(policies.map(\.id)) == expectedPolicyIDs else {
        throw ZurichISPClientError.policySelection
    }
    return policies
}

nonisolated private func selectedPolicy(in payload: HTTPPayload) throws -> String {
    guard let html = payload.html, let select = element(id: "ddlPolicy", tag: "select", in: html) else {
        throw ZurichISPClientError.policySelection
    }
    let selected = optionElements(in: select.body).filter { $0.attributes["selected"] != nil }
    guard selected.count == 1, let id = selected[0].attributes["value"], !id.isEmpty else {
        throw ZurichISPClientError.policySelection
    }
    return id
}

nonisolated private struct HTMLElement {
    let attributes: [String: String]
    let body: String
}

nonisolated private func element(id: String, tag: String, in html: String) -> HTMLElement? {
    let escapedID = NSRegularExpression.escapedPattern(for: id)
    let pattern = "(?is)<\(tag)\\b([^>]*\\bid\\s*=\\s*(?:\"\(escapedID)\"|'\(escapedID)'|\(escapedID))[^>]*)>(.*?)</\(tag)\\s*>"
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
          let attributes = Range(match.range(at: 1), in: html),
          let body = Range(match.range(at: 2), in: html) else { return nil }
    return HTMLElement(attributes: HTMLParser.attributesMap(String(html[attributes])), body: String(html[body]))
}

nonisolated private func optionElements(in html: String) -> [HTMLElement] {
    let pattern = #"(?is)<option\b([^>]*)>(.*?)</option\s*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
        guard let attributes = Range(match.range(at: 1), in: html), let body = Range(match.range(at: 2), in: html) else { return nil }
        return HTMLElement(attributes: HTMLParser.attributesMap(String(html[attributes])), body: String(html[body]))
    }
}

nonisolated private struct JSONArraySlice {
    let literal: String
    let range: Range<String.Index>
}

nonisolated private func structuredFunds(in payload: HTTPPayload) throws -> (literal: String, count: Int) {
    guard let html = payload.html,
          let assignment = try? NSRegularExpression(pattern: #"(?is)\bvar\s+dt\s*=\s*\["#),
          let binding = try? NSRegularExpression(pattern: #"(?is)^\s*;?\s*makeFundValuePieChart\s*\(\s*dt\s*,\s*['\"]Fund values['\"]\s*,\s*['\"]FundValueChart['\"]\s*\)"#) else {
        throw ZurichISPClientError.partialResponse
    }
    let candidates = assignment.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match -> JSONArraySlice? in
        guard let assignmentRange = Range(match.range, in: html) else { return nil }
        let arrayStart = html.index(before: assignmentRange.upperBound)
        guard let slice = balancedJSONArray(in: html, startingAt: arrayStart) else { return nil }
        let trailing = String(html[slice.range.upperBound...])
        return binding.firstMatch(in: trailing, range: NSRange(trailing.startIndex..., in: trailing)) == nil ? nil : slice
    }
    guard candidates.count == 1, let candidate = candidates.first,
          let data = candidate.literal.data(using: .utf8),
          let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty else {
        throw ZurichISPClientError.partialResponse
    }
    let identity = ["FundCode", "FundName", "FundCurrency"]
    let requiredNumerics = ["FXRate", "Percentage", "Price", "Units", "Value"]
    guard rows.allSatisfy({ row in
        identity.allSatisfy { isNonemptyString(row[$0]) }
            && requiredNumerics.allSatisfy { isSourceNumber(row[$0]) }
            && (row["VestedValue"] == nil || isSourceNumber(row["VestedValue"]))
    }) else {
        throw ZurichISPClientError.partialResponse
    }
    return (candidate.literal, rows.count)
}

nonisolated private func balancedJSONArray(in text: String, startingAt start: String.Index) -> JSONArraySlice? {
    var depth = 0
    var quote: Character?
    var escaping = false
    var index = start
    while index < text.endIndex {
        let character = text[index]
        if let active = quote {
            if escaping { escaping = false }
            else if character == "\\" { escaping = true }
            else if character == active { quote = nil }
        } else if character == "\"" || character == "'" { quote = character }
        else if character == "[" { depth += 1 }
        else if character == "]" {
            depth -= 1
            if depth == 0 {
                let upper = text.index(after: index)
                return JSONArraySlice(literal: String(text[start..<upper]), range: start..<upper)
            }
        }
        index = text.index(after: index)
    }
    return nil
}

nonisolated private func valuationDateDisplay(in payload: HTTPPayload) throws -> String {
    guard let html = payload.html else { throw ZurichISPClientError.partialResponse }
    let pattern = #"(?is)<label\b[^>]*\bfor\s*=\s*(?:\"ValuationDate\"|'ValuationDate'|ValuationDate)[^>]*>.*?</label\s*>\s*<([A-Za-z][A-Za-z0-9]*)\b[^>]*>(.*?)</\1\s*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { throw ZurichISPClientError.partialResponse }
    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
    guard matches.count == 1, let body = Range(matches[0].range(at: 2), in: html) else { throw ZurichISPClientError.partialResponse }
    let display = normalizedText(String(html[body]))
    guard display.range(of: #"^\d{2}/\d{2}/\d{4}$"#, options: .regularExpression) != nil else {
        throw ZurichISPClientError.partialResponse
    }
    return display
}

nonisolated private func tableRows(in payload: HTTPPayload, requireAtLeastOne: Bool) throws -> [[String]] {
    guard let html = payload.html else { throw ZurichISPClientError.partialResponse }
    let rows = rowsFromHTML(html)
    guard !requireAtLeastOne || !rows.isEmpty else { throw ZurichISPClientError.partialResponse }
    return rows
}

nonisolated private func validateKeyValueRows(_ rows: [[String]], required: [String], optional: [String]) throws {
    for key in required {
        let matches = rows.filter { $0.count == 2 && $0[0] == key }
        guard matches.count == 1, !matches[0][1].isEmpty else { throw ZurichISPClientError.partialResponse }
    }
    for key in optional {
        let matches = rows.filter { $0.count == 2 && $0[0] == key }
        guard matches.count <= 1, matches.first.map({ !$0[1].isEmpty }) ?? true else { throw ZurichISPClientError.partialResponse }
    }
}

nonisolated private func structuredRegularStrategy(in payload: HTTPPayload) throws -> (literal: String, count: Int) {
    guard let html = payload.html else { throw ZurichISPClientError.partialResponse }
    var candidates: [JSONArraySlice] = []
    var start = html.startIndex
    while let binding = html.range(of: "makeDonutChartWithLegend", range: start..<html.endIndex) {
        let after = html[binding.upperBound...]
        if let arrayStart = after.firstIndex(of: "["), let slice = balancedJSONArray(in: html, startingAt: arrayStart) {
            let trailing = html[slice.range.upperBound...]
            if let close = trailing.firstIndex(of: ")"),
               trailing[..<close].range(of: #"(?is),\s*['\"]RegularStrategyChart['\"]\s*$"#, options: .regularExpression) != nil {
                candidates.append(slice)
            }
        }
        start = binding.upperBound
    }
    guard candidates.count == 1, let candidate = candidates.first,
          let data = candidate.literal.data(using: .utf8),
          let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty else {
        throw ZurichISPClientError.partialResponse
    }
    guard rows.allSatisfy({ row in
        (row["StrategyType"] as? String) == "R" && isDateLiteral(row["EffectiveDate"]) && isSourceNumber(row["StrategySequence"])
            && isNonemptyString(row["FundCode"]) && isNonemptyString(row["FundDescription"]) && isSourceNumber(row["FundPercentage"])
    }) else { throw ZurichISPClientError.partialResponse }
    return (candidate.literal, rows.count)
}

nonisolated private func isNonemptyString(_ value: Any?) -> Bool {
    guard let string = value as? String else { return false }
    return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

nonisolated private func isSourceNumber(_ value: Any?) -> Bool {
    if value is NSNumber { return true }
    guard let string = value as? String else { return false }
    return string.range(of: #"^-?\d+(?:\.\d+)?$"#, options: .regularExpression) != nil
}

nonisolated private func isDateLiteral(_ value: Any?) -> Bool {
    guard let string = value as? String else { return false }
    return string.range(of: #"^/[dD]ate\(-?\d+\)/$"#, options: .regularExpression) != nil
}

nonisolated private func rowsFromHTML(_ html: String) -> [[String]] {
    let rowPattern = #"(?is)<tr\b[^>]*>(.*?)</tr\s*>"#
    let cellPattern = #"(?is)<t[dh]\b[^>]*>(.*?)</t[dh]\s*>"#
    guard let rows = try? NSRegularExpression(pattern: rowPattern), let cells = try? NSRegularExpression(pattern: cellPattern) else { return [] }
    return rows.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { row in
        guard let rowRange = Range(row.range(at: 1), in: html) else { return nil }
        let content = String(html[rowRange])
        let values = cells.matches(in: content, range: NSRange(content.startIndex..., in: content)).compactMap { cell -> String? in
            guard let range = Range(cell.range(at: 1), in: content) else { return nil }
            return normalizedText(String(content[range]))
        }
        return values.isEmpty ? nil : values
    }
}

nonisolated private func normalizedText(_ html: String) -> String {
    let plain = html.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
    return htmlDecode(plain).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
}

nonisolated private func htmlDecode(_ string: String) -> String {
    var result = string
    for (encoded, decoded) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
        result = result.replacingOccurrences(of: encoded, with: decoded, options: .caseInsensitive)
    }
    let pattern = #"&#(x[0-9A-Fa-f]+|[0-9]+);"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
    for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
        guard let range = Range(match.range(at: 1), in: result), let full = Range(match.range, in: result) else { continue }
        let token = String(result[range])
        let value = token.lowercased().hasPrefix("x") ? UInt32(token.dropFirst(), radix: 16) : UInt32(token)
        guard let scalar = value.flatMap(UnicodeScalar.init) else { continue }
        result.replaceSubrange(full, with: String(Character(scalar)))
    }
    return result
}
