// LedgerForge
// ImportPersistenceMapper.swift

import Foundation

enum ImportPersistenceError: Error, LocalizedError, Equatable {
    case validationFailed
    case missingTransactionDate(UUID)
    case unsupportedCurrency(String)
    case nonIntegralMinorAmount(Decimal, currency: String)
    case missingTransactionDirection(UUID)

    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Import persistence requires a passed validation result."
        case .missingTransactionDate(let id):
            return "Transaction \(id) is missing a posted date."
        case .unsupportedCurrency(let currency):
            return "Currency \(currency) is not supported by import persistence mapping."
        case .nonIntegralMinorAmount(let amount, let currency):
            return "Amount \(amount) cannot be represented exactly in minor units for \(currency)."
        case .missingTransactionDirection(let id):
            return "Transaction \(id) is missing a debit or credit direction."
        }
    }
}

struct ImportPersistencePayload {
    let workspace: WorkspaceDTO
    let account: AccountDTO
    let importSession: ImportSessionDTO
    let completedAtISO: String
    let transactions: [TransactionDTO]
}

struct ImportPersistenceMapper {

    private let workspaceId: String
    private let workspaceName: String
    private let dateFormatter: ISO8601DateFormatter

    init(
        workspaceId: String = "default-workspace",
        workspaceName: String = "Default Workspace",
        dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) {
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.dateFormatter = dateFormatter
    }

    func payload(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistencePayload {
        guard validation.passed else {
            throw ImportPersistenceError.validationFailed
        }

        let importedAtISO = dateFormatter.string(from: importSession.importedAt)
        let account = accountDTO(
            financialDocument: financialDocument,
            importSession: importSession,
            createdAtISO: importedAtISO
        )

        return ImportPersistencePayload(
            workspace: WorkspaceDTO(
                id: workspaceId,
                name: workspaceName,
                createdAtISO: importedAtISO
            ),
            account: account,
            importSession: ImportSessionDTO(
                id: importSession.id.uuidString,
                workspaceId: workspaceId,
                userVisibleName: importSession.fileName,
                startedAtISO: importedAtISO,
                validationStatus: "pending",
                readerVersion: nil,
                parserVersion: importSession.parserName,
                layoutVersion: nil
            ),
            completedAtISO: importedAtISO,
            transactions: try financialDocument.transactions.map {
                try transactionDTO(
                    from: $0,
                    accountId: account.id,
                    importSessionId: importSession.id.uuidString,
                    documentId: nil,
                    createdAtISO: importedAtISO
                )
            }
        )
    }

    private func accountDTO(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        createdAtISO: String
    ) -> AccountDTO {
        let institutionName = importSession.institution?.rawValue ?? "Unknown"
        let accountName = Self.displayAccountName(
            institutionName: institutionName,
            documentType: importSession.documentType,
            currency: financialDocument.transactions.first?.currency,
            fallbackFileName: importSession.fileName
        )
        let accountType: String? = {
            switch importSession.documentType {
            case .bankAccount:
                return "bank"
            case .creditCard:
                return "credit_card"
            default:
                return nil
            }
        }()

        return AccountDTO(
            id: stableID(prefix: "account", components: [workspaceId, institutionName, importSession.fileName]),
            workspaceId: workspaceId,
            name: accountName,
            institutionId: nil,
            accountType: accountType,
            nativeCurrency: financialDocument.transactions.first?.currency ?? "INR",
            description: "Imported from \(importSession.fileName)",
            createdAtISO: createdAtISO
        )
    }

    static func displayAccountName(
        institutionName: String,
        documentType: DocumentType?,
        currency: String?,
        fallbackFileName: String
    ) -> String {
        let trimmedInstitution = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstitution.isEmpty && trimmedInstitution != "Unknown" {
            switch documentType {
            case .bankAccount?:
                return [trimmedInstitution, currency].compactMap { value in
                    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed?.isEmpty == false ? trimmed : nil
                }.joined(separator: " ")
            case .creditCard?:
                return "\(trimmedInstitution) Credit Card"
            default:
                return trimmedInstitution
            }
        }

        let baseName = (fallbackFileName as NSString).deletingPathExtension
        let separators = CharacterSet(charactersIn: "_-")
        let cleaned = baseName
            .components(separatedBy: separators)
            .filter { component in
                let lowercased = component.lowercased()
                return !["csv", "statement", "statements", "export", "baseline"].contains(lowercased)
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Imported Account" : cleaned.capitalized
    }

    private func transactionDTO(
        from transaction: Transaction,
        accountId: String,
        importSessionId: String,
        documentId: String?,
        createdAtISO: String
    ) throws -> TransactionDTO {
        guard let postedDate = transaction.date else {
            throw ImportPersistenceError.missingTransactionDate(transaction.id)
        }

        let direction: String
        if transaction.debit != nil {
            direction = "debit"
        } else if transaction.credit != nil {
            direction = "credit"
        } else {
            throw ImportPersistenceError.missingTransactionDirection(transaction.id)
        }

        return TransactionDTO(
            id: transaction.id.uuidString,
            workspaceId: workspaceId,
            accountId: accountId,
            importSessionId: importSessionId,
            documentId: documentId,
            originalRowId: nil,
            postedDateISO: Self.dayFormatter.string(from: postedDate),
            valueDateISO: nil,
            description: transaction.description,
            payee: nil,
            reference: nil,
            nativeCurrency: transaction.currency,
            amountMinor: try minorUnits(for: transaction.amount, currency: transaction.currency),
            amountDecimal: decimalString(transaction.amount),
            direction: direction,
            runningBalanceMinor: try transaction.balance.map {
                try minorUnits(for: $0, currency: transaction.currency)
            },
            isReconciled: false,
            isTrusted: true,
            trustedAtISO: createdAtISO,
            createdAtISO: createdAtISO,
            updatedAtISO: nil,
            rawRows: []
        )
    }

    private func minorUnits(for amount: Decimal, currency: String) throws -> Int64 {
        guard let scale = minorUnitScale(for: currency) else {
            throw ImportPersistenceError.unsupportedCurrency(currency)
        }

        var multiplier = Decimal(1)
        for _ in 0..<scale {
            multiplier *= 10
        }

        let scaled = amount * multiplier
        var mutableScaled = scaled
        var rounded = Decimal()
        NSDecimalRound(&rounded, &mutableScaled, 0, .plain)

        guard rounded == scaled else {
            throw ImportPersistenceError.nonIntegralMinorAmount(amount, currency: currency)
        }

        return NSDecimalNumber(decimal: rounded).int64Value
    }

    private func minorUnitScale(for currency: String) -> Int? {
        switch currency.uppercased() {
        case "INR":
            return 2
        default:
            return nil
        }
    }

    private func decimalString(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

    private func stableID(prefix: String, components: [String]) -> String {
        let body = components
            .joined(separator: "-")
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber {
                    return character
                }
                return "-"
            }
        return "\(prefix)-\(String(body))"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
