import Foundation

/// The public Home/GetRate forward QAR→INR contract only. Each explicit
/// refresh owns one ephemeral session and one request; there are no retries.
nonisolated struct AlDarCurrentReferenceProvider: Sendable {
    private static let endpoint = URL(string: "https://www.aldarexchange.com/aldarportal/Home/GetRate")!

    @concurrent func fetch(submittedQAR: Money) async throws -> AlDarReferenceQuote {
        guard submittedQAR.currency.code == "QAR", submittedQAR.amount > 0 else {
            throw AlDarReferenceError.invalidBinding
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.aldarexchange.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.aldarexchange.com/aldarportal/Home", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "currency": "INR", "amount": try submittedQAR.canonicalDecimalString(), "isFCY": false
        ])
        try Task.checkCancellation()
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url == Self.endpoint, response.mimeType?.lowercased() == "application/json" else {
            throw AlDarReferenceError.unavailable
        }
        var body = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard body.count < 128 else { throw AlDarReferenceError.invalidResponse }
            body.append(byte)
        }
        return try AlDarReferenceQuote(submittedQAR: submittedQAR,
                                      returnedINR: .parseResponse(body),
                                      fetchedAtISO: ISO8601DateFormatter().string(from: Date()))
    }

    private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}
