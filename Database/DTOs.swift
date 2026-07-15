// Database/DTOs.swift
// Strongly typed DTOs for repository APIs

import Foundation

public struct WorkspaceDTO: nonisolated Equatable {
    public let id: String
    public let name: String
    public let createdAtISO: String
    public let updatedAtISO: String?

    public init(id: String = UUID().uuidString,
                name: String,
                createdAtISO: String,
                updatedAtISO: String? = nil) {
        self.id = id
        self.name = name
        self.createdAtISO = createdAtISO
        self.updatedAtISO = updatedAtISO
    }
}

public struct TransactionRawRowDTO: nonisolated Equatable {
    public let id: String
    public let normalizedRowId: String
    public let contributionType: String?

    public init(id: String = UUID().uuidString, normalizedRowId: String, contributionType: String? = nil) {
        self.id = id
        self.normalizedRowId = normalizedRowId
        self.contributionType = contributionType
    }
}

public struct TransactionDTO: nonisolated Equatable {
    public let id: String
    public let workspaceId: String
    public let accountId: String?
    public let importSessionId: String?
    public let documentId: String?
    public let originalRowId: String?
    public let postedDateISO: String
    public let valueDateISO: String?
    public let description: String?
    public let payee: String?
    public let reference: String?
    public let nativeCurrency: String
    public let amountMinor: Int64
    public let amountDecimal: String
    public let direction: String
    public let runningBalanceMinor: Int64?
    public let isReconciled: Bool
    public let isTrusted: Bool
    public let trustedAtISO: String?
    public let createdAtISO: String
    public let updatedAtISO: String?
    public let rawRows: [TransactionRawRowDTO]

    public init(id: String = UUID().uuidString,
                workspaceId: String,
                accountId: String? = nil,
                importSessionId: String? = nil,
                documentId: String? = nil,
                originalRowId: String? = nil,
                postedDateISO: String,
                valueDateISO: String? = nil,
                description: String? = nil,
                payee: String? = nil,
                reference: String? = nil,
                nativeCurrency: String,
                amountMinor: Int64,
                amountDecimal: String,
                direction: String,
                runningBalanceMinor: Int64? = nil,
                isReconciled: Bool = false,
                isTrusted: Bool = false,
                trustedAtISO: String? = nil,
                createdAtISO: String,
                updatedAtISO: String? = nil,
                rawRows: [TransactionRawRowDTO] = []) {
        self.id = id
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.documentId = documentId
        self.originalRowId = originalRowId
        self.postedDateISO = postedDateISO
        self.valueDateISO = valueDateISO
        self.description = description
        self.payee = payee
        self.reference = reference
        self.nativeCurrency = nativeCurrency
        self.amountMinor = amountMinor
        self.amountDecimal = amountDecimal
        self.direction = direction
        self.runningBalanceMinor = runningBalanceMinor
        self.isReconciled = isReconciled
        self.isTrusted = isTrusted
        self.trustedAtISO = trustedAtISO
        self.createdAtISO = createdAtISO
        self.updatedAtISO = updatedAtISO
        self.rawRows = rawRows
    }
}

public struct AccountDTO: nonisolated Equatable {
    public let id: String
    public let workspaceId: String
    public let name: String
    public let institutionId: String?
    public let accountType: String?
    public let nativeCurrency: String
    public let description: String?
    public let createdAtISO: String

    public init(id: String = UUID().uuidString,
                workspaceId: String,
                name: String,
                institutionId: String? = nil,
                accountType: String? = nil,
                nativeCurrency: String,
                description: String? = nil,
                createdAtISO: String) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.institutionId = institutionId
        self.accountType = accountType
        self.nativeCurrency = nativeCurrency
        self.description = description
        self.createdAtISO = createdAtISO
    }
}

public struct AccountIdentifierDTO: nonisolated Equatable {
    public let id: String
    public let accountId: String
    public let workspaceId: String
    public let scheme: String
    public let identifier: String
    public let strength: String
    public let verificationState: String
    public let provenance: String
    public let createdAtISO: String

    public init(id: String = UUID().uuidString,
                accountId: String,
                workspaceId: String,
                scheme: String,
                identifier: String,
                strength: String,
                verificationState: String,
                provenance: String,
                createdAtISO: String) {
        self.id = id
        self.accountId = accountId
        self.workspaceId = workspaceId
        self.scheme = scheme
        self.identifier = identifier
        self.strength = strength
        self.verificationState = verificationState
        self.provenance = provenance
        self.createdAtISO = createdAtISO
    }
}

public struct ImportSessionDTO: nonisolated Equatable {
    public let id: String
    public let workspaceId: String
    public let userVisibleName: String?
    public let startedAtISO: String
    public let validationStatus: String
    public let readerVersion: String?
    public let parserVersion: String?
    public let layoutVersion: String?

    public init(id: String = UUID().uuidString,
                workspaceId: String,
                userVisibleName: String? = nil,
                startedAtISO: String,
                validationStatus: String = "pending",
                readerVersion: String? = nil,
                parserVersion: String? = nil,
                layoutVersion: String? = nil) {
        self.id = id
        self.workspaceId = workspaceId
        self.userVisibleName = userVisibleName
        self.startedAtISO = startedAtISO
        self.validationStatus = validationStatus
        self.readerVersion = readerVersion
        self.parserVersion = parserVersion
        self.layoutVersion = layoutVersion
    }
}

public struct ImportSessionRecordDTO: nonisolated Equatable {
    public let id: String
    public let workspaceId: String
    public let userVisibleName: String?
    public let startedAtISO: String
    public let completedAtISO: String?
    public let validationStatus: String
    public let readerVersion: String?
    public let parserVersion: String?
    public let layoutVersion: String?

    public init(id: String,
                workspaceId: String,
                userVisibleName: String?,
                startedAtISO: String,
                completedAtISO: String?,
                validationStatus: String,
                readerVersion: String?,
                parserVersion: String?,
                layoutVersion: String?) {
        self.id = id
        self.workspaceId = workspaceId
        self.userVisibleName = userVisibleName
        self.startedAtISO = startedAtISO
        self.completedAtISO = completedAtISO
        self.validationStatus = validationStatus
        self.readerVersion = readerVersion
        self.parserVersion = parserVersion
        self.layoutVersion = layoutVersion
    }
}

public struct ImportedDocumentDTO: nonisolated Equatable {
    public let id: String
    public let workspaceId: String
    public let importSessionId: String
    public let filename: String
    public let mimeType: String?
    public let sizeBytes: Int64?
    public let sha256: String
    public let createdAtISO: String

    public init(
        id: String,
        workspaceId: String,
        importSessionId: String,
        filename: String,
        mimeType: String?,
        sizeBytes: Int64?,
        sha256: String,
        createdAtISO: String
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.importSessionId = importSessionId
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.createdAtISO = createdAtISO
    }
}

public struct DocumentFingerprintDTO: nonisolated Equatable {
    public let id: String
    public let documentId: String
    public let importSessionId: String
    public let algorithm: String
    public let fingerprint: String
    public let fingerprintData: String?
    public let createdAtISO: String

    public init(
        id: String,
        documentId: String,
        importSessionId: String,
        algorithm: String,
        fingerprint: String,
        fingerprintData: String?,
        createdAtISO: String
    ) {
        self.id = id
        self.documentId = documentId
        self.importSessionId = importSessionId
        self.algorithm = algorithm
        self.fingerprint = fingerprint
        self.fingerprintData = fingerprintData
        self.createdAtISO = createdAtISO
    }
}

public struct PriorImportedStatementDTO: nonisolated Equatable {
    public let importSessionId: String
    public let completedAtISO: String?
    public let transactionCount: Int
    public let accountId: String?
    public let accountDisplayName: String?

    public init(
        importSessionId: String,
        completedAtISO: String?,
        transactionCount: Int,
        accountId: String?,
        accountDisplayName: String?
    ) {
        self.importSessionId = importSessionId
        self.completedAtISO = completedAtISO
        self.transactionCount = transactionCount
        self.accountId = accountId
        self.accountDisplayName = accountDisplayName
    }
}

public struct AtomicImportHistoryDTO: nonisolated Equatable {
    public let document: ImportedDocumentDTO
    public let fingerprint: DocumentFingerprintDTO
    public let importSession: ImportSessionDTO
    public let completedAtISO: String
    public let transactions: [TransactionDTO]

    public init(
        document: ImportedDocumentDTO,
        fingerprint: DocumentFingerprintDTO,
        importSession: ImportSessionDTO,
        completedAtISO: String,
        transactions: [TransactionDTO]
    ) {
        self.document = document
        self.fingerprint = fingerprint
        self.importSession = importSession
        self.completedAtISO = completedAtISO
        self.transactions = transactions
    }
}

public enum AtomicImportHistoryResult: nonisolated Equatable {
    case committed
    case duplicate(PriorImportedStatementDTO)
}
