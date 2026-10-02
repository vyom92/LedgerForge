import CryptoKit
import Foundation

nonisolated struct GmailInboxSource: Codable, Equatable, Identifiable, Sendable {
    enum Attention: String, Codable, Sendable {
        case pending, review, password, unsupported, invalid, failed, skipped
    }
    enum Acquisition: String, Codable, Sendable { case pending, available, unavailable, sizeLimit }
    let id: String
    let account: String
    let messageID: String
    let partID: String
    let originalFilename: String
    let fileExtension: String
    let mimeType: String
    let sender: String
    let family: GmailSourceFamily
    let receivedMilliseconds: Int64
    let expectedByteCount: Int
    var acquisition: Acquisition = .pending
    var retrievedAt: Date?
    var sha256: String?
    var attention: Attention
    var dismissed: Bool
    /// Inbox-only disposition of a verified, single-scope older holdings source.
    /// Optional for existing cached inboxes; it never means financially imported.
    var retainedNewerHoldings: Bool? = nil

    static func deliveryID(account: String, messageID: String, partID: String) -> String {
        digest(Data((account.lowercased() + "\0" + messageID + "\0" + partID).utf8))
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    var displayName: String {
        let value = originalFilename.components(separatedBy: .controlCharacters).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Email attachment.\(fileExtension)" : value
    }

    /// An opaque locator, never a writable filesystem path. Only the inbox
    /// adapter can resolve it to an integrity-checked immutable RAM snapshot.
    var importURL: URL? {
        var components = URLComponents()
        components.scheme = "ledgerforge-email"
        components.host = "inbox"
        components.queryItems = [URLQueryItem(name: "account", value: account)]
        let name = (displayName as NSString).lastPathComponent
        components.path = "/\(id)/\(name.lowercased().hasSuffix("." + fileExtension) ? name : name + "." + fileExtension)"
        return components.url
    }

    func validate() throws {
        guard !account.isEmpty, account == account.lowercased(),
              id == Self.deliveryID(account: account, messageID: messageID, partID: partID),
              ["pdf", "csv", "xls", "xlsx"].contains(fileExtension),
              expectedByteCount >= 0, partID.utf8.count <= 1_024,
              sha256.map(Self.isDigest) ?? true,
              acquisition != .available || (sha256 != nil && expectedByteCount > 0),
              (sha256 == nil) == (retrievedAt == nil) else { throw GmailIntakeError.integrity }
        try GmailClient.validateMessageID(messageID)
    }

    static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

nonisolated struct GmailMessageReceipt: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable { case attachments, attachmentFree, excluded, unsupportedCarrier, unavailable, outsideInterval }
    let messageID: String
    let outcome: Outcome
    let receivedMilliseconds: Int64?
    let sourceIDs: [String]
}

nonisolated struct GmailInboxScan: Codable, Equatable, Sendable {
    let id: UUID
    let interval: GmailCollectionInterval
    var pageCursor: String?
    var seenPageCursors: [String]
    var pendingMessageIDs: [String]
    var nextPageCursor: String?
    var pageLoaded: Bool
    var accountedMessageIDs: Set<String>

    init(interval: GmailCollectionInterval) {
        self.id = UUID(); self.interval = interval
        pageCursor = nil; seenPageCursors = []; pendingMessageIDs = []
        nextPageCursor = nil; pageLoaded = false; accountedMessageIDs = []
    }
}

/// Small acquisition/attention state, separate from the accepted financial
/// graph. There is deliberately no persisted "imported" bit or preparation.
nonisolated public struct GmailInboxState: Codable, Equatable, Sendable {
    var formatVersion = 1
    let account: String
    var revision: Int64 = 0
    var activeScan: GmailInboxScan?
    var completedIntervals: [GmailCollectionInterval] = []
    var messages: [String: GmailMessageReceipt] = [:]
    var sources: [String: GmailInboxSource] = [:]
    var senderRules: [GmailSenderRule]?

    init(account: String) { self.account = account.lowercased() }

    var completedThrough: Date? { completedIntervals.map(\.until).max() }
    var configuredSenders: [GmailSenderRule] { senderRules ?? GmailSenderRule.initial }
    func completedThrough(senders: Set<String>) -> Date? {
        guard !senders.isEmpty else { return nil }
        return completedIntervals.filter { $0.senders.isSuperset(of: senders) }.map(\.until).max()
    }
    var orderedSources: [GmailInboxSource] {
        sources.values.sorted {
            if $0.receivedMilliseconds != $1.receivedMilliseconds { return $0.receivedMilliseconds < $1.receivedMilliseconds }
            if $0.messageID != $1.messageID { return $0.messageID < $1.messageID }
            return $0.partID < $1.partID
        }
    }

    func validate() throws {
        guard formatVersion == 1, !account.isEmpty, account == account.lowercased(), revision >= 0 else {
            throw GmailIntakeError.integrity
        }
        if let senderRules {
            guard Set(senderRules.map(\.address)).count == senderRules.count,
                  try senderRules.allSatisfy({ try GmailSenderRule.validatedAddress($0.address) == $0.address }) else {
                throw GmailIntakeError.integrity
            }
        }
        for (id, source) in sources {
            try source.validate()
            guard source.id == id, source.account == account else { throw GmailIntakeError.integrity }
        }
        for (id, message) in messages {
            guard id == message.messageID, message.sourceIDs.allSatisfy({ sources[$0]?.messageID == id }) else {
                throw GmailIntakeError.integrity
            }
        }
        let intervals = completedIntervals + (activeScan.map { [$0.interval] } ?? [])
        for interval in intervals {
            _ = try GmailCollectionInterval(from: interval.from, until: interval.until,
                                             timeZoneIdentifier: interval.timeZoneIdentifier, senders: interval.senderAddresses)
        }
        if let scan = activeScan {
            guard scan.accountedMessageIDs.allSatisfy({ messages[$0] != nil }),
                  Set(scan.seenPageCursors).count == scan.seenPageCursors.count else { throw GmailIntakeError.integrity }
        }
    }
}
