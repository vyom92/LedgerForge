import CryptoKit
import Foundation

enum TransactionEventIdentityError: Error, Equatable {
    case invalidAccountID
    case invalidEvidence
    case duplicateIncomingEvidence
}

struct TransactionEventIdentity: Equatable, Sendable {
    static let algorithm = "ledgerforge.transaction-event.axis-upi-reference.v1"
    static let family = "axis-upi"

    let transactionID: UUID
    let accountID: String
    let algorithmIdentifier: String
    let digest: String

    static func make(
        transaction: Transaction,
        accountID: String
    ) throws -> TransactionEventIdentity? {
        guard let evidence = transaction.verifiedAxisUPIEventEvidence else { return nil }
        return try make(transactionID: transaction.id, evidence: evidence, accountID: accountID)
    }

    static func make(
        transactionID: UUID,
        evidence: AxisUPITransactionEventEvidence,
        accountID: String
    ) throws -> TransactionEventIdentity {
        let payload = try canonicalPayload(evidence: evidence, accountID: accountID)
        let digest = SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
        return TransactionEventIdentity(transactionID: transactionID, accountID: accountID, algorithmIdentifier: algorithm, digest: digest)
    }

    static func canonicalPayload(
        evidence: AxisUPITransactionEventEvidence,
        accountID: String,
        algorithmIdentifier: String = algorithm,
        familyIdentifier: String = family
    ) throws -> String {
        guard !accountID.isEmpty, algorithmIdentifier == algorithm, familyIdentifier == family,
              evidence.reference.count == 12,
              evidence.reference.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else {
            throw TransactionEventIdentityError.invalidEvidence
        }
        let components = [algorithmIdentifier, accountID, familyIdentifier, evidence.operation.rawValue, evidence.reference, evidence.subtype.rawValue]
        return components.map { "\($0.lengthOfBytes(using: .utf8)):\($0)" }.joined()
    }

    static func incomingDuplicates(in identities: [TransactionEventIdentity]) -> Set<TransactionEventIdentityKey> {
        var seen = Set<TransactionEventIdentityKey>()
        var duplicates = Set<TransactionEventIdentityKey>()
        for identity in identities {
            let key = TransactionEventIdentityKey(algorithm: identity.algorithmIdentifier, digest: identity.digest)
            if !seen.insert(key).inserted { duplicates.insert(key) }
        }
        return duplicates
    }
}

struct TransactionEventIdentityKey: Hashable, Sendable {
    let algorithm: String
    let digest: String
}
