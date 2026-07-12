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

public struct ImportSessionDTO: Equatable {
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
