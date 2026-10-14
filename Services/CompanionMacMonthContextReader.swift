import Foundation

/// Fresh dependencies of one monthly editor, read under the existing provider
/// snapshot boundary. No runtime store or previously captured context is reused.
@MainActor
enum CompanionMacMonthContextReader {
    static func read(scratchpad: MonthlyPlanScratchpad, metadata: MonthlyPlanSyncAdapter.Metadata,
                     provider: DatabaseProvider, selectedHistoryAccountIDs: Set<String>,
                     now: Date) throws -> CompanionMonthAnchor {
        guard let sqlite = provider.sqliteProvider else { throw LedgerAccessError.unavailable }
        return try provider.withConsistentSnapshot {
            let stamp = try sqlite.database.validatedActivationStamp()
            guard !stamp.transitioning else { throw LedgerAccessError.unavailable }
            let workspace = scratchpad.plan.workspaceID
            let accountDTOs = try provider.accountRepo.accounts(workspaceId: workspace)
            let accountsByID = Dictionary(accountDTOs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            guard accountsByID.count == accountDTOs.count,
                  accountDTOs.allSatisfy({ !$0.id.isEmpty && $0.workspaceId == workspace }) else {
                throw CompanionPacketError.invalid("Monthly account identities are inconsistent.")
            }
            let db = sqlite.database
            // Labels and masked identity presentation do not require transaction,
            // statement-balance, import, investment, or bank-occurrence hydration.
            let products = try db.query(sql: "SELECT account_id, product_label FROM bank_statement_sections WHERE workspace_id=? ORDER BY document_id,section_ordinal;", params: [workspace]) {
                ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "")
            }
            let bankPatterns = try db.query(sql: "SELECT s.account_id,i.kind,i.pattern FROM bank_section_identity_observations i JOIN bank_statement_sections s ON s.id=i.bank_statement_section_id WHERE s.workspace_id=? ORDER BY s.account_id,i.kind,i.pattern;", params: [workspace]) {
                ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2) ?? "")
            }.filter { $0.1.contains("account_number") }
            let cardPatterns = try db.query(sql: "SELECT subject_id,source_value FROM card_source_identity_observations WHERE workspace_id=? AND subject_kind='liability_account' ORDER BY created_at,id;", params: [workspace]) {
                ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "")
            }
            let cbqPatterns = try provider.accountRepo.cbqSourceIdentityRecords(workspaceId: workspace)
                .filter { $0.kind == CBQSourceIdentityObservationKind.maskedAccountNumber.rawValue }
            var productsByAccount: [String: [String]] = [:]
            var bankPatternsByAccount: [String: [String]] = [:]
            var numberPatternsByAccount: [String: [String]] = [:]
            for (id, product) in products { productsByAccount[id, default: []].append(product) }
            for (id, _, pattern) in bankPatterns {
                bankPatternsByAccount[id, default: []].append(pattern)
                numberPatternsByAccount[id, default: []].append(pattern)
            }
            for (id, pattern) in cardPatterns { numberPatternsByAccount[id, default: []].append(pattern) }
            for observation in cbqPatterns { numberPatternsByAccount[observation.accountId, default: []].append(observation.pattern) }
            let accounts = try accountDTOs.map { account -> CompanionMacMonthContext.AccountInput in
                let currency = try CurrencyCode(account.nativeCurrency)
                let history = account.closedAtISO != nil
                let identifiers = try provider.accountRepo.identifiers(accountId: account.id, workspaceId: workspace)
                let identities = RepositoryStoreHydrator.identitySummaries(from: identifiers)
                let accountNumbers = identities.filter { $0.kind != "IBAN" }.map(\.redactedValue)
                    + (numberPatternsByAccount[account.id] ?? [])
                let labels = Set(accountNumbers.compactMap(AccountDisplayText.maskedNumber)).sorted()
                let product = RepositoryStoreHydrator.sourceProductName(account: account,
                    productLabels: productsByAccount[account.id] ?? [])
                let sourceLabel = RepositoryStoreHydrator.sourceAccountLabel(
                    productLabels: productsByAccount[account.id] ?? [],
                    accountNumberPatterns: bankPatternsByAccount[account.id] ?? [])
                return .init(repositoryAccountId: account.id, workspaceId: account.workspaceId,
                    name: account.name, type: RepositoryStoreHydrator.accountType(from: account.accountType),
                    nativeCurrency: currency, status: history ? .closed : .active,
                    preferredDisplayName: AccountDisplayText.preferredName(nickname: nil, name: account.name,
                        sourceProductName: product, institution: account.institutionId ?? "Unknown"),
                    selectionContext: AccountDisplayText.selectionContext(numberLabel: labels.isEmpty ? nil : labels.joined(separator: " · "),
                        identities: identities, sourceLabel: sourceLabel, currency: currency, historyOnly: history))
            }
            let preferences = try SQLiteFinancialIntelligenceRepository(db: db).planningPreferences(workspaceID: workspace)
            let excluded = preferences?.excludedPlanningAccountIDs ?? []
            guard excluded.allSatisfy({ id in
                guard let account = accountsByID[id] else { return false }
                return ["bank", "credit_card"].contains(account.accountType ?? "")
            }) else { throw FinancialIntelligenceError.invalidRecord }

            var receiptTransactions: [Transaction] = []
            if let link = scratchpad.plan.assistance?.payslipFunding {
                guard let bank = accountsByID[link.accountID], bank.accountType == "bank", bank.nativeCurrency == link.net.currency else {
                    throw CompanionPacketError.invalid("The salary receipt account is unavailable or has a different native currency.")
                }
                let rows = try SQLiteTransactionRepo(db: db).companionReceiptTransactions(
                    workspaceId: workspace, accountID: link.accountID, month: scratchpad.plan.month)
                receiptTransactions = try rows.map {
                    // The exact existing mapper supplies all fields consulted by
                    // PayslipReceiptState.resolve: ID, account, date, Money,
                    // direction, description and complete parser provenance.
                    // Receipt resolution never consults document display names,
                    // preferred-source presentation, or bank occurrence details.
                    try RepositoryStoreHydrator.transaction(from: $0, accounts: accountDTOs,
                        importedDocumentsByID: [:], preferredSource: nil, workspaceID: workspace,
                        cardEvidence: nil)
                }
            }
            let quote = try SQLiteBackgroundPublicCacheRepository(database: db).planningINRReference(now: now)?.planningQuote()
            return try CompanionMacMonthContext.make(scratchpad: scratchpad, metadata: metadata,
                accounts: accounts, manuallyExcludedPlanningAccountIDs: excluded,
                receiptTransactions: receiptTransactions, latestAlDarQuote: quote,
                selectedHistoryAccountIDs: selectedHistoryAccountIDs)
        }
    }
}
