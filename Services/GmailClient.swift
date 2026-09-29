import Foundation

nonisolated struct GmailHTTPResponse: Sendable {
    let statusCode: Int
    let data: Data
    let retryAfter: String?

    init(statusCode: Int, data: Data, retryAfter: String? = nil) {
        self.statusCode = statusCode
        self.data = data
        self.retryAfter = retryAfter
    }
}

nonisolated protocol GmailHTTPTransport: Sendable {
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> GmailHTTPResponse
}

/// No mutable delegate state; redirects are refused so a bearer token cannot
/// follow an unexpected endpoint. URLSession owns its own synchronization.
nonisolated private final class GmailRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

nonisolated struct GmailURLSessionTransport: GmailHTTPTransport {
    private let session: URLSession
    private let delegate = GmailRedirectDelegate()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 90
        configuration.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest, maximumBytes: Int) async throws -> GmailHTTPResponse {
        guard maximumBytes > 0 else { throw GmailIntakeError.resourceLimit }
        do {
            let (stream, response) = try await session.bytes(for: request, delegate: delegate)
            guard let response = response as? HTTPURLResponse else { throw GmailIntakeError.invalidResponse }
            guard response.expectedContentLength <= Int64(maximumBytes) else { throw GmailIntakeError.resourceLimit }
            var data = Data()
            data.reserveCapacity(min(maximumBytes, 65_536))
            for try await byte in stream {
                if data.count % 65_536 == 0 { try Task.checkCancellation() }
                guard data.count < maximumBytes else { throw GmailIntakeError.resourceLimit }
                data.append(byte)
            }
            try Task.checkCancellation()
            return GmailHTTPResponse(statusCode: response.statusCode, data: data,
                                     retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw GmailIntakeError.timedOut
            default: throw GmailIntakeError.network
            }
        }
    }
}

nonisolated protocol GmailAccessTokenProvider: Sendable {
    func accessToken(refresh: Bool) async throws -> String
}

nonisolated struct GmailClient: Sendable {
    static let readOnlyScope = "https://www.googleapis.com/auth/gmail.readonly"
    static let maximumOriginalBytes = 32 * 1_024 * 1_024
    static let maximumMessageBytes = 48 * 1_024 * 1_024
    let expectedAccount: String
    let tokens: any GmailAccessTokenProvider
    let transport: any GmailHTTPTransport
    private let pause: @Sendable (TimeInterval) async throws -> Void

    init(expectedAccount: String, tokens: any GmailAccessTokenProvider,
         transport: any GmailHTTPTransport = GmailURLSessionTransport(),
         pause: @escaping @Sendable (TimeInterval) async throws -> Void = {
             try await Task.sleep(for: .seconds($0))
         }) {
        self.expectedAccount = expectedAccount.lowercased()
        self.tokens = tokens
        self.transport = transport
        self.pause = pause
    }

    func verifyAccount() async throws {
        struct Profile: Decodable, Sendable { let emailAddress: String }
        let profile: Profile = try await get(path: ["profile"], maximumBytes: 65_536)
        guard profile.emailAddress.lowercased() == expectedAccount else { throw GmailIntakeError.accountMismatch }
    }

    func page(interval: GmailCollectionInterval, cursor: String?) async throws -> GmailMessagePage {
        var query = [URLQueryItem(name: "q", value: interval.query),
                     URLQueryItem(name: "includeSpamTrash", value: "true"),
                     URLQueryItem(name: "maxResults", value: "100")]
        if let cursor { query.append(URLQueryItem(name: "pageToken", value: cursor)) }
        return try await get(path: ["messages"], query: query, maximumBytes: 1_048_576)
    }

    func message(id: String) async throws -> GmailMessage {
        try Self.validateMessageID(id)
        let message: GmailMessage = try await get(path: ["messages", id],
            query: [URLQueryItem(name: "format", value: "full")], maximumBytes: Self.maximumMessageBytes)
        guard message.id == id else { throw GmailIntakeError.integrity }
        return message
    }

    func original(messageID: String, body: GmailPartBody) async throws -> Data {
        try Self.validateMessageID(messageID)
        guard body.size > 0, body.size <= Self.maximumOriginalBytes else { throw GmailIntakeError.resourceLimit }
        let supplied: GmailPartBody
        if let attachmentID = body.attachmentId, !attachmentID.isEmpty {
            guard attachmentID.utf8.count <= 8_192 else { throw GmailIntakeError.invalidLocator }
            supplied = try await get(path: ["messages", messageID, "attachments", attachmentID],
                maximumBytes: min(Self.maximumMessageBytes, ((body.size + 2) / 3) * 4 + 65_536))
            guard supplied.size == body.size else { throw GmailIntakeError.integrity }
        } else { supplied = body }
        return try Self.decodeOriginal(supplied, expectedSize: body.size)
    }

    static func decodeOriginal(_ body: GmailPartBody, expectedSize: Int) throws -> Data {
        guard expectedSize > 0, expectedSize <= maximumOriginalBytes,
              body.size == expectedSize, let encoded = body.data,
              encoded.utf8.count <= ((expectedSize + 2) / 3) * 4 + 4,
              encoded.utf8.allSatisfy({
                  (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                      || $0 == 45 || $0 == 95 || $0 == 61
              }) else { throw GmailIntakeError.integrity }
        var base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.utf8.count % 4) % 4)
        guard let bytes = Data(base64Encoded: base64), bytes.count == expectedSize else { throw GmailIntakeError.integrity }
        return bytes
    }

    static func validateMessageID(_ id: String) throws {
        guard !id.isEmpty, id.utf8.count <= 128, id.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { throw GmailIntakeError.invalidLocator }
    }

    private func get<Value: Decodable & Sendable>(path: [String], query: [URLQueryItem] = [],
                                                 maximumBytes: Int) async throws -> Value {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let encoded = try path.map { part in
            guard let encoded = part.addingPercentEncoding(withAllowedCharacters: allowed) else {
                throw GmailIntakeError.invalidLocator
            }
            return encoded
        }.joined(separator: "/")
        guard var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/" + encoded) else {
            throw GmailIntakeError.invalidLocator
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw GmailIntakeError.invalidLocator }
        var refreshed = false
        var refreshNextRequest = false
        var retries = 0
        while true {
            try Task.checkCancellation()
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
            request.setValue("Bearer " + (try await tokens.accessToken(refresh: refreshNextRequest)), forHTTPHeaderField: "Authorization")
            refreshNextRequest = false
            let response = try await transport.send(request, maximumBytes: maximumBytes)
            guard response.data.count <= maximumBytes else { throw GmailIntakeError.resourceLimit }
            if response.statusCode == 401, !refreshed {
                refreshed = true
                refreshNextRequest = true
                continue
            }
            let reasons = (try? JSONDecoder().decode(GmailErrorEnvelope.self, from: response.data))?.error.errors?.map(\.reason) ?? []
            let transient = [429, 500, 502, 503, 504].contains(response.statusCode)
                || (response.statusCode == 403 && reasons.contains(where: {
                    ["rateLimitExceeded", "userRateLimitExceeded"].contains($0)
                }) && !reasons.contains("dailyLimitExceeded"))
            if transient {
                // Six bounded retries belong to this explicit collection, not
                // a background schedule. A longer server hold returns to the
                // durable scan cursor instead of retrying before it expires.
                guard let delay = Self.retryDelay(retries: retries, retryAfter: response.retryAfter,
                                                  now: Date(), jitter: Double.random(in: 0...1)) else {
                    throw GmailIntakeError.rateLimited
                }
                retries += 1
                try await pause(delay)
                continue
            }
            switch response.statusCode {
            case 200: break
            case 401: throw GmailIntakeError.unauthorized
            case 403:
                if reasons.contains("dailyLimitExceeded") { throw GmailIntakeError.rateLimited }
                throw GmailIntakeError.unauthorized
            case 404, 410: throw GmailIntakeError.unavailable
            default: throw GmailIntakeError.invalidResponse
            }
            do { return try JSONDecoder().decode(Value.self, from: response.data) }
            catch { throw GmailIntakeError.invalidResponse }
        }
    }

    static func retryDelay(retries: Int, retryAfter: String?, now: Date, jitter: Double) -> TimeInterval? {
        guard (0..<6).contains(retries) else { return nil }
        var delay = pow(2, Double(retries)) + min(1, max(0, jitter))
        if let retryAfter {
            let text = retryAfter.trimmingCharacters(in: .whitespacesAndNewlines)
            var serverDelay = Double(text)
            if serverDelay == nil {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                serverDelay = formatter.date(from: text)?.timeIntervalSince(now)
            }
            if let serverDelay, serverDelay.isFinite { delay = max(delay, serverDelay) }
        }
        return delay <= 60 ? delay : nil
    }
}

nonisolated private struct GmailErrorEnvelope: Decodable {
    struct Body: Decodable {
        struct Detail: Decodable { let reason: String }
        let errors: [Detail]?
    }
    let error: Body
}
