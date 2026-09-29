import Foundation

/// Mail metadata nominates an original. It never establishes financial identity
/// or parser support; those decisions remain in the ordinary import pipeline.
nonisolated enum GmailSourceFamily: String, Codable, CaseIterable, Sendable {
    case axisBank, axisCard, cbqBank, cbqCard, hdfcBank, amex, salary, cbqInvestment, consolidatedFunds, other

    var displayName: String {
        switch self {
        case .axisBank: "Axis bank"
        case .axisCard: "Axis credit card"
        case .cbqBank: "CBQ bank"
        case .cbqCard: "CBQ credit card"
        case .hdfcBank: "HDFC bank"
        case .amex: "American Express"
        case .salary: "Qatar Airways salary"
        case .cbqInvestment: "CBQ investments"
        case .consolidatedFunds: "Consolidated mutual funds"
        case .other: "Email attachment"
        }
    }
}

/// Owner-managed collection addresses. These are nomination rules, never a
/// declaration of parser support or financial identity.
nonisolated struct GmailSenderRule: Codable, Equatable, Identifiable, Sendable {
    var address: String
    var isSelected: Bool
    var id: String { address }

    static var initial: [Self] {
        GmailNomination.approvedSenders.sorted().map { .init(address: $0, isSelected: true) }
    }

    static func validatedAddress(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.utf8.count <= 254,
              value.range(of: #"^[a-z0-9._%+\-]+@[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?)+$"#,
                          options: .regularExpression) != nil else { throw GmailIntakeError.invalidSender }
        guard !GmailNomination.excludedSenders.contains(value) else { throw GmailIntakeError.excludedSender }
        return value
    }
}

nonisolated struct GmailCollectionInterval: Codable, Equatable, Sendable {
    /// Nil is an explicitly selected all-history collection, not a moving bound.
    let from: Date?
    let until: Date
    let timeZoneIdentifier: String
    // Nil decodes the original candidate's fixed, approved sender set. New
    // scans always freeze the owner's selected addresses with their dates.
    let senderAddresses: Set<String>?
    var senders: Set<String> { senderAddresses ?? GmailNomination.approvedSenders }

    init(from: Date?, until: Date, timeZoneIdentifier: String,
         senders: Set<String>? = nil) throws {
        guard until.timeIntervalSince1970.isFinite,
              from.map({ $0.timeIntervalSince1970.isFinite && $0 < until }) ?? true,
              TimeZone(identifier: timeZoneIdentifier) != nil else { throw GmailIntakeError.invalidInterval }
        self.from = from
        self.until = until
        self.timeZoneIdentifier = timeZoneIdentifier
        if let senders {
            guard !senders.isEmpty,
                  try senders.allSatisfy({ try GmailSenderRule.validatedAddress($0) == $0 }) else {
                throw GmailIntakeError.invalidSender
            }
        }
        self.senderAddresses = senders
    }

    static func calendarDays(from: Date, through: Date, timeZone: TimeZone, now: Date,
                             senders: Set<String>? = nil) throws -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let lower = calendar.startOfDay(for: from)
        guard let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: through)) else {
            throw GmailIntakeError.invalidInterval
        }
        return try Self(from: lower, until: min(upper, now), timeZoneIdentifier: timeZone.identifier, senders: senders)
    }

    func contains(milliseconds: Int64) -> Bool {
        let instant = Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
        return (from.map { instant >= $0 } ?? true) && instant < until
    }

    var query: String {
        // Gmail's date-only search uses PST. Overfetch by a second, then verify
        // every actual internalDate against the exact half-open interval.
        let lower = from.map { "after:\(Int64(floor($0.timeIntervalSince1970)) - 1) " } ?? ""
        let upper = "before:\(Int64(ceil(until.timeIntervalSince1970)))"
        let querySenders = senders.sorted().map { "from:\($0)" }.joined(separator: " ")
        return "\(lower)\(upper) {\(querySenders)}"
    }
}

nonisolated enum GmailNomination {
    // Exact owner-approved list in Account_and_document_lifecycle.md. Keep the
    // older HDFC address and CBQ aliases; do not infer addresses from issuers.
    static let approvedSenders: Set<String> = [
        "cc.statements@axis.bank.in", "cc.statements@axisbank.com",
        "statements@axis.bank.in", "statements@axisbank.com",
        "estatements@cbq.com.qa", "estatements@cbq.qa",
        "hdfcbanksmartstatement@hdfcbank.bank.in", "hdfcbanksmartstatement@hdfcbank.net",
        "e-statement@americanexpress.com.bh", "peoplexnotification@qatarairways.com.qa",
        "cb_wealth@cbq.com.qa", "cb_trader@cbq.com.qa", "cb_trader@cbq.qa",
        "samfs@kfintech.com", "donotreply@camsonline.com"
    ]
    static let excludedSenders: Set<String> = [
        "cbadmin@cbq.com.qa", "enq_sbimf@camsonline.com", "ecas@cdslstatement.com",
        "exg.statements@paytmmoney.com", "alerts@paytmmoney.com"
    ]

    static func address(_ header: String) -> String? {
        let text = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value: String
        if let open = text.lastIndex(of: "<"), let close = text.lastIndex(of: ">"), open < close {
            value = String(text[text.index(after: open)..<close])
        } else { value = text }
        guard value.filter({ $0 == "@" }).count == 1,
              !value.contains(where: { $0.isWhitespace || "<>,;".contains($0) }) else { return nil }
        return value
    }

    static func family(sender: String, subject: String,
                       selectedSenders: Set<String> = approvedSenders) -> GmailSourceFamily? {
        guard let sender = address(sender), selectedSenders.contains(sender), !excludedSenders.contains(sender) else { return nil }
        let subject = subject.lowercased()
        switch sender {
        case "cc.statements@axis.bank.in", "cc.statements@axisbank.com":
            return subject.contains("credit card") || subject.contains("statement") ? .axisCard : nil
        case "statements@axis.bank.in", "statements@axisbank.com":
            return subject.contains("statement") ? .axisBank : nil
        case "estatements@cbq.com.qa", "estatements@cbq.qa":
            guard subject.contains("statement") else { return nil }
            return subject.contains("credit card") ? .cbqCard : .cbqBank
        case "hdfcbanksmartstatement@hdfcbank.bank.in", "hdfcbanksmartstatement@hdfcbank.net":
            return subject.contains("statement") ? .hdfcBank : nil
        case "e-statement@americanexpress.com.bh":
            return subject.contains("statement") ? .amex : nil
        case "peoplexnotification@qatarairways.com.qa":
            guard !subject.contains("roster report") else { return nil }
            return ["payslip", "salary", "adhoc payment"].contains(where: subject.contains) ? .salary : nil
        case "cb_wealth@cbq.com.qa", "cb_trader@cbq.com.qa", "cb_trader@cbq.qa":
            return subject.contains("holding") && subject.contains("statement") ? .cbqInvestment : nil
        case "samfs@kfintech.com", "donotreply@camsonline.com":
            return subject.contains("statement") || subject.contains("capital gain") ? .consolidatedFunds : nil
        default: return .other
        }
    }

    static func supportedCarrier(filename: String, mimeType: String) -> String? {
        let name = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = (name as NSString).pathExtension.lowercased()
        let mime = mimeType.lowercased().split(separator: ";").first.map(String.init) ?? ""
        if ["pdf", "csv", "xls", "xlsx"].contains(ext) { return ext }
        if mime == "application/pdf" { return "pdf" }
        // No ZIP, EML, signature, image or download-link expansion.
        return nil
    }
}

nonisolated struct GmailMessagePage: Decodable, Sendable {
    struct Reference: Decodable, Sendable { let id: String }
    let messages: [Reference]?
    let nextPageToken: String?
}

nonisolated struct GmailMessage: Decodable, Sendable {
    let id: String
    let internalDate: String
    let payload: GmailMessagePart

    func header(_ name: String) -> String? {
        let values = (payload.headers ?? []).filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        return values.count == 1 ? values[0].value : nil
    }
}

nonisolated struct GmailMessagePart: Decodable, Sendable {
    struct Header: Decodable, Sendable { let name: String; let value: String }
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [Header]?
    let body: GmailPartBody?
    let parts: [GmailMessagePart]?

    func flattened() throws -> [GmailMessagePart] {
        var result: [GmailMessagePart] = []
        var pending: [(GmailMessagePart, Int)] = [(self, 0)]
        while let (part, depth) = pending.popLast() {
            guard depth < 64, result.count < 10_000 else { throw GmailIntakeError.resourceLimit }
            result.append(part)
            for child in (part.parts ?? []).reversed() { pending.append((child, depth + 1)) }
        }
        return result
    }
}

nonisolated struct GmailPartBody: Decodable, Sendable {
    let attachmentId: String?
    let size: Int
    let data: String?
}

nonisolated enum GmailIntakeError: Error, LocalizedError, Equatable, Sendable {
    case invalidInterval, invalidResponse, invalidLocator, resourceLimit, integrity
    case unauthorized, accountMismatch, scopeMismatch, unavailable, rateLimited, timedOut, network
    case keychainUnavailable, configurationRequired, repeatedPage, busy, staleProvider, storageUnavailable
    case invalidSender, duplicateSender, excludedSender

    var errorDescription: String? {
        switch self {
        case .invalidInterval: "Choose a valid email delivery date range."
        case .invalidResponse: "Gmail returned an incomplete or unreadable response. Collection remains incomplete."
        case .invalidLocator: "The original attachment location could not be verified."
        case .resourceLimit: "This response exceeds the bounded intake size. The source remains held."
        case .integrity: "The original's byte identity or size could not be verified. The source remains held."
        case .unauthorized: "The Gmail grant has expired or was revoked. Reconnect to continue."
        case .accountMismatch: "The Gmail account does not match the selected connection."
        case .scopeMismatch: "This connection must grant only read-only Gmail access."
        case .unavailable: "The message or attachment is no longer available in Gmail."
        case .rateLimited: "Gmail temporarily limited collection. Resume when you are ready."
        case .timedOut: "Gmail did not respond in time. The incomplete collection can be resumed."
        case .network: "Gmail could not be reached. The incomplete collection can be resumed."
        case .keychainUnavailable: "The saved Gmail connection could not be read from Keychain."
        case .configurationRequired: "Select the existing Desktop OAuth client configuration to connect."
        case .repeatedPage: "Gmail repeated a page cursor. Collection stopped without advancing coverage."
        case .busy: "An email collection is already in progress."
        case .staleProvider: "The active ledger changed. Resume collection against the current ledger."
        case .storageUnavailable: "The email inbox could not be saved. Collection remains incomplete."
        case .invalidSender: "Enter one complete sender email address, without a name or search expression."
        case .duplicateSender: "That sender is already in the list."
        case .excludedSender: "That address is excluded from the current email intake scope."
        }
    }
}
