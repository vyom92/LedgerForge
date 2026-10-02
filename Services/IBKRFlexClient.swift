import Foundation

/// For an explicitly selected RAM-only original-source inspection. No URL,
/// credential, file or cache is supplied by this callback.
typealias IBKRFlexResponseObserver = @Sendable (_ originalBytes: Data) -> Void

nonisolated enum IBKRFlexClientError: Error, LocalizedError, Equatable, Sendable {
    case inFlight, cancelled, timedOut, network, responseTooLarge, invalidResponse, reportNotReady
    case httpStatus(Int), brokerRejected(Int?)
    var errorDescription: String? {
        switch self {
        case .inFlight: "An IBKR holdings update is already in progress."
        case .cancelled: "The IBKR update was cancelled. Previous holdings are retained."
        case .timedOut, .reportNotReady: "IBKR did not finish the report in time. Previous holdings are retained."
        case .network: "The IBKR connection could not complete. Previous holdings are retained."
        case .responseTooLarge: "The IBKR report exceeded the supported response size. Previous holdings are retained."
        case .invalidResponse: "IBKR did not return a valid Flex response. Previous holdings are retained."
        case .httpStatus: "IBKR rejected the report request. Check the saved connection and try again."
        case .brokerRejected: "IBKR could not generate this Flex report. Check the token, query and account settings."
        }
    }
}

/// A single native reader shared by manual and scheduled callers. Scheduling,
/// credential writes and durable holdings publication belong to its caller.
actor IBKRFlexClient {
    private let session: URLSession
    private var active: (id: UUID, task: Task<IBKRFlexAccountSnapshot, Error>)?

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: IBKRFlexNoRedirect(), delegateQueue: nil)
    }

    func fetch(credentials: IBKRFlexCredentials,
               observeOriginal: IBKRFlexResponseObserver? = nil) async throws -> IBKRFlexAccountSnapshot {
        guard active == nil else { throw IBKRFlexClientError.inFlight }
        let credentials = try credentials.validated(), id = UUID()
        let task = Task { try await self.perform(credentials: credentials, observeOriginal: observeOriginal) }
        active = (id, task)
        defer { if active?.id == id { active = nil } }
        return try await withTaskCancellationHandler {
            do { return try await task.value }
            catch is CancellationError { throw IBKRFlexClientError.cancelled }
            catch let error as IBKRFlexSourceError { throw error }
            catch let error as IBKRFlexClientError { throw error }
            // URLSession errors may carry the token-bearing request URL.
            // They never escape the reader or enter presentation/diagnostics.
            catch { throw IBKRFlexClientError.network }
        } onCancel: { task.cancel() }
    }

    func cancel() { active?.task.cancel() }

    private func perform(credentials: IBKRFlexCredentials,
                         observeOriginal: IBKRFlexResponseObserver?) async throws -> IBKRFlexAccountSnapshot {
        try Task.checkCancellation()
        let deadline = Date().addingTimeInterval(120)
        let (generated, response) = try await request(operation: "SendRequest", token: credentials.token,
                                                    reference: credentials.queryID, deadline: deadline)
        guard response.statusCode == 200 else { throw IBKRFlexClientError.httpStatus(response.statusCode) }
        let receipt = try IBKRFlexXML.decode(generated)
        guard receipt.rootName == "FlexStatementResponse", receipt.control["Status"] == "Success",
              let reference = receipt.control["ReferenceCode"], IBKRFlexCredentials.asciiDigits(reference) else {
            throw IBKRFlexClientError.brokerRejected(Self.errorCode(receipt))
        }
        var delay: TimeInterval = 10
        for _ in 0..<8 {
            try Task.checkCancellation()
            guard delay.isFinite, delay >= 10, Date().addingTimeInterval(delay) < deadline else {
                throw IBKRFlexClientError.reportNotReady
            }
            try await Task.sleep(for: .seconds(delay))
            let (data, response) = try await request(operation: "GetStatement", token: credentials.token,
                                                    reference: reference, deadline: deadline)
            if let value = response.value(forHTTPHeaderField: "Retry-After"), let retry = Self.retryDelay(value) { delay = retry }
            if response.statusCode == 429 || response.statusCode == 503 { continue }
            guard response.statusCode == 200 else { throw IBKRFlexClientError.httpStatus(response.statusCode) }
            try Task.checkCancellation()
            // Original report bytes are observable only in RAM, before parsing.
            // A not-ready Flex control response can also reach this callback.
            observeOriginal?(data)
            let document = try IBKRFlexXML.decode(data)
            if document.rootName == "FlexStatementResponse" {
                let code = Self.errorCode(document)
                if let code, [1001, 1004, 1005, 1006, 1007, 1008, 1009, 1019, 1021].contains(code) { continue }
                throw IBKRFlexClientError.brokerRejected(code)
            }
            try Task.checkCancellation()
            return try IBKRFlexAccountSnapshot.parse(originalBytes: data, credentials: credentials,
                                                    referenceCode: reference, fetchedAt: Date())
        }
        throw IBKRFlexClientError.reportNotReady
    }

    private func request(operation: String, token: String, reference: String,
                         deadline: Date) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        guard ["SendRequest", "GetStatement"].contains(operation) else { throw IBKRFlexClientError.invalidResponse }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { throw IBKRFlexClientError.timedOut }
        var components = URLComponents(string: "https://ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService/" + operation)!
        components.queryItems = [.init(name: "t", value: token), .init(name: "q", value: reference), .init(name: "v", value: "3")]
        guard let url = components.url else { throw IBKRFlexClientError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = min(30, remaining)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("LedgerForge/IBKR-Flex", forHTTPHeaderField: "User-Agent")
        let session = session, boundedRequest = request
        do {
            let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                defer { group.cancelAll() }
                group.addTask { try await session.data(for: boundedRequest) }
                group.addTask {
                    try await Task.sleep(for: .seconds(min(remaining, 45)))
                    throw IBKRFlexClientError.timedOut
                }
                guard let first = try await group.next() else { throw IBKRFlexClientError.invalidResponse }
                return first
            }
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse,
                  response.url?.scheme == "https", response.url?.host == "ndcdyn.interactivebrokers.com" else {
                throw IBKRFlexClientError.invalidResponse
            }
            guard data.count <= IBKRFlexXML.maximumResponseBytes else { throw IBKRFlexClientError.responseTooLarge }
            return (data, response)
        } catch is CancellationError { throw IBKRFlexClientError.cancelled }
        catch let error as IBKRFlexClientError { throw error }
        catch let error as URLError {
            if error.code == .cancelled || Task.isCancelled { throw IBKRFlexClientError.cancelled }
            if error.code == .timedOut { throw IBKRFlexClientError.timedOut }
            throw IBKRFlexClientError.network
        } catch { throw IBKRFlexClientError.network }
    }

    private static func errorCode(_ document: IBKRFlexXML) -> Int? {
        guard let token = document.control["ErrorCode"], IBKRFlexCredentials.asciiDigits(token) else { return nil }
        return Int(token)
    }

    private static func retryDelay(_ value: String, now: Date = Date()) -> TimeInterval? {
        if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 { return max(10, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        return formatter.date(from: value).map { max(10, $0.timeIntervalSince(now)) }
    }
}

/// Immutable delegate: no shared mutable state or unchecked Sendable escape.
nonisolated private final class IBKRFlexNoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
