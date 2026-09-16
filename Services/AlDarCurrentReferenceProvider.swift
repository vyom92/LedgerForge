import Foundation
#if DEBUG
import OSLog
#endif

/// Public forward QAR→INR/USD only. Scheduling/retries belong to the shared
/// session; each invocation performs exactly one bounded public request.
nonisolated struct AlDarCurrentReferenceProvider: Sendable {
    private static let endpoint = URL(string: "https://www.aldarexchange.com/aldarportal/Home/GetRate")!

    @concurrent func fetch(submittedQAR: Money) async throws -> AlDarReferenceQuote {
        guard submittedQAR.currency.code == "QAR", submittedQAR.amount > 0 else {
            throw AlDarReferenceError.invalidBinding
        }
        let reference = try await request(currency: .inr, amount: submittedQAR.canonicalDecimalString())
        return try AlDarReferenceQuote(submittedQAR: submittedQAR, returnedINR: reference.returned, fetchedAtISO: reference.fetchedAtISO)
    }

    @concurrent func fetchUnit(currency: AlDarCurrency) async throws -> AlDarUnitReference {
        try await request(currency: currency, amount: "1")
    }

    @concurrent private func request(currency: AlDarCurrency, amount: String) async throws -> AlDarUnitReference {
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
            "currency": currency.rawValue, "amount": amount, "isFCY": false
        ])
        try Task.checkCancellation()
#if DEBUG
        Logger(subsystem: "com.vyom.LedgerForge", category: "AlDarReference")
            .notice("Public reference request receiving \(currency.rawValue, privacy: .public)")
#endif
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
        let result = try AlDarUnitReference(currency: currency, rawToken: AlDarReturnedINRDecimal.parseResponse(body).rawToken,
                                          fetchedAtISO: ISO8601DateFormatter().string(from: Date()))
#if DEBUG
        Logger(subsystem: "com.vyom.LedgerForge", category: "AlDarReference")
            .notice("Public reference fetched \(currency.rawValue, privacy: .public)")
#endif
        return result
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
