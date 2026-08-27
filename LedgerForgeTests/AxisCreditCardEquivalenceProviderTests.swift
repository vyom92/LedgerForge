import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Provider-level Axis equivalence coverage. The fixtures below are synthetic
/// and intentionally small: the two representations have the same financial
/// event multiset, but different source order and distinct source containers.
@MainActor
struct AxisCreditCardEquivalenceProviderTests {
    @Test func bothImportOrdersPersistOneCanonicalMultisetWithTwoDurableSources() throws {
        let pdf = try syntheticAxisPDF(order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund], totalDue: 1_450)
        let xlsx = try syntheticAxisXLSX(order: [.duplicateCharge, .refund, .openingCharge, .duplicateCharge], totalDue: 1_450)
        var baselineFinalGraph: [String]?

        for ordered in [[pdf, xlsx], [xlsx, pdf]] {
            try forEachProvider { runtime, sqliteURL in
                let caseLabel = "\(ordered[0].metadata.fileFormat.rawValue)->\(ordered[1].metadata.fileFormat.rawValue) / \(sqliteURL == nil ? "memory" : "sqlite")"
                do {
                let firstSeed = "axis-first-\(ordered[0].metadata.fileFormat.rawValue)"
                let firstAuthority = try #require(fingerprintSet(firstSeed).duplicateAuthority)
                let first = try persist(
                    ordered[0], seed: firstSeed,
                    provider: runtime, accountChoice: .createNewAccount
                )
                #expect(first.persisted)
                #expect(first.transactionCount == 4)
                #expect(!first.isEquivalentSupportingSource)

                let accountID = try #require(first.accountId)
                let firstImportSessionID = try #require(first.importSessionId)
                let firstAttemptID = try #require(first.importAttemptId)
                let firstTransactions = try runtime.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
                #expect(firstTransactions.count == 4)
                let firstTransactionIDs = Set(firstTransactions.map(\.id))
                let firstTransactionOwnership = transactionOwnership(firstTransactions)
                let firstCardSnapshot = try runtime.cardRepo.snapshot(
                    workspaceId: "default-workspace"
                )
                #expect(firstCardSnapshot.instruments.isEmpty)
                #expect(firstCardSnapshot.sections.isEmpty)
                #expect(firstCardSnapshot.sectionObservations.isEmpty)
                #expect(firstCardSnapshot.statements.count == 1)
                #expect(firstCardSnapshot.semanticProjections.count == 1)
                let firstStatementID = try #require(firstCardSnapshot.statements.first?.id)
                let firstProjectionID = try #require(firstCardSnapshot.semanticProjections.first?.id)

                let secondSeed = "axis-second-\(ordered[1].metadata.fileFormat.rawValue)"
                let secondAuthority = try #require(fingerprintSet(secondSeed).duplicateAuthority)
                let second = try persist(
                    ordered[1], seed: secondSeed,
                    provider: runtime,
                    accountChoice: .useExistingAccount(accountId: accountID)
                )
                #expect(second.persisted)
                #expect(second.transactionCount == 0)
                #expect(second.isEquivalentSupportingSource)
                let secondImportSessionID = try #require(second.importSessionId)
                let secondAttemptID = try #require(second.importAttemptId)

                try assertAxisMultisetShape(
                    runtime,
                    expectedOrders: [expectedKeys(for: ordered[0]), expectedKeys(for: ordered[1])],
                    authoritativeProjectionID: firstProjectionID,
                    authoritativeStatementID: firstStatementID,
                    authoritativeImportSessionID: firstImportSessionID,
                    supportingImportSessionID: secondImportSessionID,
                    canonicalTransactionIDs: firstTransactionIDs,
                    transactionOwnershipBeforeSupportingSource: firstTransactionOwnership
                )
                try assertDurableSourceEvidence(
                    runtime,
                    firstAuthority: firstAuthority,
                    secondAuthority: secondAuthority,
                    firstImportSessionID: firstImportSessionID,
                    secondImportSessionID: secondImportSessionID,
                    firstAttemptID: firstAttemptID,
                    secondAttemptID: secondAttemptID
                )
                let finalGraph = try finalGraphShape(runtime)
                if let baselineFinalGraph {
                    #expect(finalGraph == baselineFinalGraph)
                } else {
                    baselineFinalGraph = finalGraph
                }

                if let sqliteURL {
                    let reopened = try SQLiteRepositoryProvider(path: sqliteURL.path)
                    defer { reopened.database.close() }
                    let reopenedProvider = databaseProvider(reopened)
                    try assertAxisMultisetShape(
                        reopenedProvider,
                        expectedOrders: [expectedKeys(for: ordered[0]), expectedKeys(for: ordered[1])],
                        authoritativeProjectionID: firstProjectionID,
                        authoritativeStatementID: firstStatementID,
                        authoritativeImportSessionID: firstImportSessionID,
                        supportingImportSessionID: secondImportSessionID,
                        canonicalTransactionIDs: firstTransactionIDs,
                        transactionOwnershipBeforeSupportingSource: firstTransactionOwnership
                    )
                    try assertDurableSourceEvidence(
                        reopenedProvider,
                        firstAuthority: firstAuthority,
                        secondAuthority: secondAuthority,
                        firstImportSessionID: firstImportSessionID,
                        secondImportSessionID: secondImportSessionID,
                        firstAttemptID: firstAttemptID,
                        secondAttemptID: secondAttemptID
                    )
                    #expect(try finalGraphShape(reopenedProvider) == finalGraph)
                    let snapshot = try RepositoryStoreHydrator(
                        accountRepo: reopenedProvider.accountRepo,
                        importSessionRepo: reopenedProvider.importSessionRepo,
                        transactionRepo: reopenedProvider.transactionRepo,
                        categoryRepo: reopenedProvider.categoryRepo,
                        cardRepo: reopenedProvider.cardRepo,
                        workspaceId: "default-workspace",
                        persistenceState: .verifiedSQLite,
                        providerGeneration: reopenedProvider.generationToken,
                        categoryReconciliationGate: nil,
                        participatesInLifecycleGate: false
                    ).stageHydration()
                    #expect(snapshot.transactions.count == 4)
                    #expect(snapshot.cardSnapshot.statements.count == 2)
                    #expect(snapshot.cardSnapshot.transactionEvidence.count == 4)
                }
                } catch {
                    Issue.record("Axis equivalence case \(caseLabel) failed: \(error)")
                    throw error
                }
            }
        }
    }

    @Test func oneFieldMismatchIsRejectedWithZeroAdditionalFinancialResidue() throws {
        let authoritative = try syntheticAxisPDF(order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund], totalDue: 1_450)
        let mismatch = try syntheticAxisXLSX(order: [.duplicateCharge, .refund, .openingCharge, .mismatchCharge], totalDue: 1_451)

        try forEachProvider { runtime, _ in
            let first = try persist(
                authoritative, seed: "axis-mismatch-authoritative", provider: runtime,
                accountChoice: .createNewAccount
            )
            let accountID = try #require(first.accountId)
            #expect(throws: ImportPersistenceCommitFailure.self) {
                _ = try persist(
                    mismatch, seed: "axis-mismatch-candidate", provider: runtime,
                    accountChoice: .useExistingAccount(accountId: accountID)
                )
            }
            try assertOnlyAuthoritativeAxisResidue(runtime)
        }
    }

    @Test func axisReviewAndPersistenceRemainLiabilityOnlyForExistingOrNewAccount() throws {
        try forEachProvider { runtime, _ in
            let workspace = WorkspaceDTO(
                id: "default-workspace",
                name: "Axis liability-choice workspace",
                createdAtISO: "2026-07-13T00:00:00Z"
            )
            _ = try runtime.workspaceRepo.upsertWorkspace(workspace)
            let eligible = AccountDTO(
                id: "axis-eligible-liability",
                workspaceId: workspace.id,
                name: "Axis Credit Card",
                institutionId: Institution.axis.rawValue,
                accountType: "credit_card",
                nativeCurrency: "INR",
                description: nil,
                createdAtISO: workspace.createdAtISO
            )
            let wrongCurrency = AccountDTO(
                id: "axis-wrong-currency",
                workspaceId: workspace.id,
                name: "Axis QAR Card",
                institutionId: Institution.axis.rawValue,
                accountType: "credit_card",
                nativeCurrency: "QAR",
                description: nil,
                createdAtISO: workspace.createdAtISO
            )
            let wrongType = AccountDTO(
                id: "axis-bank-account",
                workspaceId: workspace.id,
                name: "Axis INR Bank",
                institutionId: Institution.axis.rawValue,
                accountType: "bank",
                nativeCurrency: "INR",
                description: nil,
                createdAtISO: workspace.createdAtISO
            )
            let wrongInstitution = AccountDTO(
                id: "other-bank-card",
                workspaceId: workspace.id,
                name: "Other Bank Card",
                institutionId: "Other Bank",
                accountType: "credit_card",
                nativeCurrency: "INR",
                description: nil,
                createdAtISO: workspace.createdAtISO
            )
            for account in [eligible, wrongCurrency, wrongType, wrongInstitution] {
                _ = try runtime.accountRepo.upsertAccount(account)
            }

            let document = try syntheticAxisPDF(
                order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund],
                totalDue: 1_450
            )
            let validation = ImportValidator.validate(financialDocument: document)
            #expect(validation.passed)
            let coordinator = DefaultImportPersistenceCoordinator(
                databaseProvider: runtime,
                mapper: ImportPersistenceMapper(workspaceId: workspace.id, workspaceName: workspace.name)
            )
            let review = try coordinator.reviewValidatedImport(
                financialDocument: document,
                validation: validation
            )
            #expect(review == .liabilityAccountChoiceRequired(
                eligibleLiabilityAccountIds: [eligible.id]
            ))
            #expect(ImportAccountConfirmationPolicy.initialChoice(for: review) == nil)
            #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
                review: review,
                choice: .useExistingAccount(accountId: eligible.id)
            ))
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: review,
                choice: .useExistingAccount(accountId: wrongCurrency.id)
            ))

            let session = ImportSession(
                fileName: document.sourceDocument.filename,
                institution: .axis,
                documentType: .creditCard,
                parserName: document.parserName,
                transactionCount: document.transactions.count,
                validation: validation
            )
            let result = try coordinator.persistValidatedImport(
                financialDocument: document,
                importSession: session,
                validation: validation,
                fingerprintSet: fingerprintSet("axis-liability-existing"),
                accountChoice: .useExistingAccount(accountId: eligible.id),
                providerGeneration: runtime.generationToken
            )
            #expect(result.persisted)
            #expect(result.accountId == eligible.id)
            #expect(try runtime.accountRepo.accounts(workspaceId: workspace.id).count == 4)
            let card = try runtime.cardRepo.snapshot(workspaceId: workspace.id)
            #expect(card.instruments.isEmpty)
            #expect(card.sections.isEmpty)
            #expect(card.sectionObservations.isEmpty)
            #expect(card.statements.count == 1)
        }

        try forEachProvider { runtime, _ in
            let document = try syntheticAxisPDF(
                order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund],
                totalDue: 1_450
            )
            let validation = ImportValidator.validate(financialDocument: document)
            #expect(validation.passed)
            let coordinator = DefaultImportPersistenceCoordinator(
                databaseProvider: runtime,
                mapper: ImportPersistenceMapper(workspaceId: "default-workspace", workspaceName: "Axis liability-choice workspace")
            )
            let review = try coordinator.reviewValidatedImport(
                financialDocument: document,
                validation: validation
            )
            #expect(review == .liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: []))
            #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
                review: review,
                choice: .createNewAccount
            ))

            let session = ImportSession(
                fileName: document.sourceDocument.filename,
                institution: .axis,
                documentType: .creditCard,
                parserName: document.parserName,
                transactionCount: document.transactions.count,
                validation: validation
            )
            let result = try coordinator.persistValidatedImport(
                financialDocument: document,
                importSession: session,
                validation: validation,
                fingerprintSet: fingerprintSet("axis-liability-new"),
                accountChoice: .createNewAccount,
                providerGeneration: runtime.generationToken
            )
            #expect(result.persisted)
            // Axis zero-section statements intentionally carry no strong
            // account identifier. The account-outcome field therefore stays
            // `.unavailable` even though the explicit create-new choice
            // commits successfully; persistence/account identity are the
            // acceptance boundary for this liability-only flow.
            #expect(result.accountOutcome == .unavailable)
            #expect(result.accountId?.hasPrefix("account-") == true)
            #expect(try runtime.accountRepo.accounts(workspaceId: "default-workspace").count == 1)
            let card = try runtime.cardRepo.snapshot(workspaceId: "default-workspace")
            #expect(card.instruments.isEmpty)
            #expect(card.sections.isEmpty)
            #expect(card.sectionObservations.isEmpty)
            #expect(card.statements.count == 1)
        }
    }

    @Test func axisLiabilityPlanRejectsInstrumentOrSectionChoicesAtPersistenceBoundary() throws {
        let document = try syntheticAxisPDF(
            order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund],
            totalDue: 1_450
        )
        let validation = ImportValidator.validate(financialDocument: document)
        #expect(validation.passed)

        try forEachProvider { runtime, _ in
            let choices: [ImportAccountChoice] = [
                .createNewCardLiabilityAccountAndInstrument,
                .useExistingCardLiabilityAccount(
                    accountId: "axis-account",
                    instrumentChoice: .reuseExistingInstrument(instrumentId: "instrument")
                ),
                .useExistingCardLiabilityAccountSections(
                    accountId: "axis-account",
                    sectionChoices: [
                        "section": .createNewInstrument()
                    ]
                )
            ]
            let coordinator = DefaultImportPersistenceCoordinator(
                databaseProvider: runtime,
                mapper: ImportPersistenceMapper(workspaceId: "default-workspace")
            )
            for (index, choice) in choices.enumerated() {
                let session = ImportSession(
                    fileName: document.sourceDocument.filename,
                    institution: .axis,
                    documentType: .creditCard,
                    parserName: document.parserName,
                    transactionCount: document.transactions.count,
                    validation: validation
                )
                #expect(throws: ImportPersistenceCoordinationError.repositoryIntegrityConflict) {
                    _ = try coordinator.persistValidatedImport(
                        financialDocument: document,
                        importSession: session,
                        validation: validation,
                        fingerprintSet: fingerprintSet("axis-invalid-(index)"),
                        accountChoice: choice,
                        providerGeneration: runtime.generationToken
                    )
                }
                let remainingAccounts = try runtime.accountRepo.accounts(workspaceId: "default-workspace")
                let remainingCard = try runtime.cardRepo.snapshot(workspaceId: "default-workspace")
                #expect(remainingAccounts.isEmpty)
                #expect(remainingCard == .empty)
            }
        }
    }

    @Test func optionalStatementMetadataDoesNotSelectOrRejectEquivalentTransactions() throws {
        let pdf = try syntheticAxisPDF(
            order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund],
            totalDue: 9_999,
            includeSelectedMonth: false
        )
        let xlsx = try syntheticAxisXLSX(
            order: [.duplicateCharge, .refund, .openingCharge, .duplicateCharge],
            totalDue: 1_450
        )

        try forEachProvider { runtime, _ in
            let first = try persist(
                pdf, seed: "axis-optional-metadata-pdf", provider: runtime,
                accountChoice: .createNewAccount
            )
            let accountID = try #require(first.accountId)
            let second = try persist(
                xlsx, seed: "axis-optional-metadata-xlsx", provider: runtime,
                accountChoice: .useExistingAccount(accountId: accountID)
            )

            #expect(second.persisted)
            #expect(second.transactionCount == 0)
            #expect(second.isEquivalentSupportingSource)
            #expect(try runtime.transactionRepo.trustedTransactions(workspaceId: "default-workspace").count == 4)
            let card = try runtime.cardRepo.snapshot(workspaceId: "default-workspace")
            #expect(card.semanticGroups.count == 1)
            #expect(card.semanticGroups.first?.cycleMonthISO == nil)
            #expect(Set(card.semanticProjections.compactMap(\.cycleMonthISO)) == Set(["2026-06"]))
        }
    }

    @Test func multiplicityMismatchIsRejectedWithZeroAdditionalFinancialResidue() throws {
        let authoritative = try syntheticAxisPDF(order: [.openingCharge, .duplicateCharge, .duplicateCharge, .refund], totalDue: 1_450)
        let missingOccurrence = try syntheticAxisXLSX(order: [.duplicateCharge, .refund, .openingCharge], totalDue: 1_250)

        try forEachProvider { runtime, _ in
            let first = try persist(
                authoritative, seed: "axis-multiplicity-authoritative", provider: runtime,
                accountChoice: .createNewAccount
            )
            let accountID = try #require(first.accountId)
            #expect(throws: ImportPersistenceCommitFailure.self) {
                _ = try persist(
                    missingOccurrence, seed: "axis-multiplicity-candidate", provider: runtime,
                    accountChoice: .useExistingAccount(accountId: accountID)
                )
            }
            try assertOnlyAuthoritativeAxisResidue(runtime)
        }
    }

    private enum AxisEvent: CaseIterable {
        case openingCharge
        case duplicateCharge
        case mismatchCharge
        case refund

        var date: String {
            switch self {
            case .openingCharge: return "31 May '26"
            case .duplicateCharge, .mismatchCharge: return "02 Jun '26"
            case .refund: return "03 Jun '26"
            }
        }

        var amount: String {
            switch self {
            case .openingCharge: return "100.00"
            case .duplicateCharge: return "200.00"
            case .mismatchCharge: return "201.00"
            case .refund: return "50.00"
            }
        }

        var effect: String { self == .refund ? "Credit" : "Debit" }
        var detail: String { self == .refund ? "Sanitized refund" : "Sanitized charge" }
    }

    private func expectedKeys(for document: FinancialDocument) -> [String] {
        document.transactions.map { eventKey(transaction: $0) }
    }

    private func eventKey(transaction: Transaction) -> String {
        let date = transaction.statementDate?.canonical ?? ""
        return [date, transaction.cardLiabilityEffect?.rawValue ?? "", transaction.money.currency.code, decimal(transaction.money)]
            .joined(separator: "|")
    }

    private func decimal(_ money: Money) -> String {
        (try? money.canonicalDecimalString()) ?? ""
    }

    private func assertAxisMultisetShape(
        _ provider: DatabaseProvider,
        expectedOrders: [[String]],
        authoritativeProjectionID: String,
        authoritativeStatementID: String,
        authoritativeImportSessionID: String,
        supportingImportSessionID: String,
        canonicalTransactionIDs: Set<String>,
        transactionOwnershipBeforeSupportingSource: [String]
    ) throws {
        let card = try provider.cardRepo.snapshot(workspaceId: "default-workspace")
        #expect(card.instruments.isEmpty)
        #expect(card.sections.isEmpty)
        #expect(card.sectionObservations.isEmpty)
        #expect(card.statements.count == 2)
        #expect(card.semanticProjections.count == 2)
        #expect(card.semanticGroups.count == 1)
        #expect(card.semanticMembers.count == 2)
        #expect(card.semanticMembers.filter { $0.role == .authoritative }.count == 1)
        #expect(card.semanticMembers.filter { $0.role == .supporting }.count == 1)
        #expect(card.semanticProjections.allSatisfy { $0.algorithm == CardStatementSemanticProjectionDTO.axisMultisetAlgorithm })
        #expect(card.semanticProjections.allSatisfy { $0.events.count == 4 })

        let group = try #require(card.semanticGroups.first)
        let authoritativeMember = try #require(card.semanticMembers.first { $0.role == .authoritative })
        let supportingMember = try #require(card.semanticMembers.first { $0.role == .supporting })
        let authoritativeProjection = try #require(card.semanticProjections.first { $0.id == authoritativeMember.projectionId })
        let supportingProjection = try #require(card.semanticProjections.first { $0.id == supportingMember.projectionId })
        #expect(group.authoritativeProjectionId == authoritativeProjectionID)
        #expect(group.cycleMonthISO == nil)
        #expect(authoritativeMember.projectionId == authoritativeProjectionID)
        #expect(authoritativeProjection.importSessionId == authoritativeImportSessionID)
        #expect(supportingProjection.importSessionId == supportingImportSessionID)
        #expect(authoritativeProjection.documentId != supportingProjection.documentId)
        #expect(authoritativeProjection.parserProfileId != supportingProjection.parserProfileId)
        #expect(Set(card.semanticProjections.map(\.parserProfileId)) == Set(["axis.credit-card.pdf", "axis.credit-card.xlsx"]))
        #expect(card.semanticProjections.allSatisfy { $0.cycleMonthISO == "2026-06" })
        #expect(card.semanticProjections.first { $0.parserProfileId == "axis.credit-card.xlsx" }?.selectedStatementMonthISO == "2026-06")
        #expect(Set(authoritativeProjection.events.compactMap(\.canonicalTransactionId)) == canonicalTransactionIDs)
        #expect(authoritativeProjection.events.allSatisfy { $0.canonicalTransactionId != nil })
        let supportingBuckets = Dictionary(grouping: supportingProjection.events) { event in
            [event.financialDateISO, event.liabilityEffectCode, event.postedCurrency, event.postedAmountDecimal]
                .joined(separator: "|")
        }
        #expect(supportingBuckets.values.contains { $0.count > 1 })
        #expect(supportingBuckets.values.allSatisfy { bucket in
            if bucket.count == 1 {
                return bucket[0].canonicalTransactionId.map(canonicalTransactionIDs.contains) == true
            }
            return bucket.allSatisfy { $0.canonicalTransactionId == nil }
        })
        #expect(Set(authoritativeProjection.events.map(\.normalizedRowId)).isDisjoint(with: Set(supportingProjection.events.map(\.normalizedRowId))))
        let authoritativeStatement = try #require(card.statements.first { $0.importSessionId == authoritativeImportSessionID })
        let supportingStatement = try #require(card.statements.first { $0.importSessionId == supportingImportSessionID })
        #expect(authoritativeStatement.id == authoritativeStatementID)
        #expect(authoritativeStatement.documentId == authoritativeProjection.documentId)
        #expect(supportingStatement.documentId == supportingProjection.documentId)
        #expect(authoritativeStatement.documentId != supportingStatement.documentId)
        let xlsxStatement = try #require(card.statements.first { $0.parserProfileId == "axis.credit-card.xlsx" })
        #expect(xlsxStatement.statementDateISO == nil)
        #expect(xlsxStatement.statementStartDateISO == nil)
        #expect(xlsxStatement.statementEndDateISO == nil)
        #expect(xlsxStatement.selectedStatementMonthISO == "2026-06")
        #expect(card.summaryComponents.count == 6)
        #expect(Dictionary(grouping: card.summaryComponents, by: \.componentCode).values.allSatisfy { $0.count == 2 })
        #expect(card.transactionEvidence.allSatisfy {
            $0.cardStatementId == authoritativeStatementID && canonicalTransactionIDs.contains($0.transactionId)
        })

        let projectedOrders = card.semanticProjections
            .sorted { $0.parserProfileId < $1.parserProfileId }
            .map { $0.events.sorted { $0.sourceOrdinal < $1.sourceOrdinal }.map { event in
                [event.financialDateISO, event.liabilityEffectCode, event.postedCurrency, event.postedAmountDecimal]
                    .joined(separator: "|")
            }}
        #expect(projectedOrders.count == expectedOrders.count)
        #expect(projectedOrders.allSatisfy { $0.sorted() == expectedOrders[0].sorted() })
        let expectedMultiplicity = Dictionary(
            grouping: expectedOrders.flatMap { $0 },
            by: { $0 }
        ).mapValues(\.count)

        let projectedMultiplicity = Dictionary(
            grouping: projectedOrders.flatMap { $0 },
            by: { $0 }
        ).mapValues(\.count)

        #expect(projectedMultiplicity == expectedMultiplicity)
        #expect(expectedMultiplicity.values.contains(4))
        #expect(Set(projectedOrders.map { $0 }) == Set(expectedOrders))

        let physicalOrdinals = card.semanticProjections.map { $0.events.map(\.sourceOrdinal).sorted() }
        #expect(physicalOrdinals.allSatisfy { $0 == [1, 2, 3, 4] })
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        #expect(transactions.count == 4)
        #expect(Set(transactions.map(\.id)) == canonicalTransactionIDs)
        #expect(Set(transactions.compactMap(\.importSessionId)) == Set([authoritativeImportSessionID]))
        #expect(transactionOwnership(transactions) == transactionOwnershipBeforeSupportingSource)
    }

    private func assertDurableSourceEvidence(
        _ provider: DatabaseProvider,
        firstAuthority: VersionedDocumentFingerprint,
        secondAuthority: VersionedDocumentFingerprint,
        firstImportSessionID: String,
        secondImportSessionID: String,
        firstAttemptID: String,
        secondAttemptID: String
    ) throws {
        let firstPriorLookup = try provider.importSessionRepo.priorImportedStatement(
            algorithm: firstAuthority.algorithm,
            fingerprint: firstAuthority.digest
        )
        let firstPrior = try #require(firstPriorLookup)
        let secondPriorLookup = try provider.importSessionRepo.priorImportedStatement(
            algorithm: secondAuthority.algorithm,
            fingerprint: secondAuthority.digest
        )
        let secondPrior = try #require(secondPriorLookup)
        #expect(firstPrior.importSessionId == firstImportSessionID)
        #expect(secondPrior.importSessionId == secondImportSessionID)

        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: "default-workspace")
        let firstAttempt = try #require(attempts.first { $0.id == firstAttemptID })
        let secondAttempt = try #require(attempts.first { $0.id == secondAttemptID })
        #expect(firstAttempt.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue)
        #expect(firstAttempt.persistenceCode == ImportAttemptPersistence.committed.rawValue)
        #expect(firstAttempt.importSessionId == firstImportSessionID)
        #expect(secondAttempt.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue)
        #expect(secondAttempt.persistenceCode == ImportAttemptPersistence.committed.rawValue)
        #expect(secondAttempt.importSessionId == secondImportSessionID)
        #expect(secondAttempt.relatedImportSessionId == firstImportSessionID)
        #expect(secondAttempt.transactionCount == 0)
        #expect(secondAttempt.importedTransactionCount == 0)
        #expect(secondAttempt.recognizedExistingRowCount == 4)
        #expect(firstAttempt.documentId != nil && secondAttempt.documentId != nil)
        #expect(firstAttempt.documentId != secondAttempt.documentId)
    }

    private func transactionOwnership(_ transactions: [TransactionDTO]) -> [String] {
        transactions.map {
            [$0.id, $0.documentId ?? "", $0.importSessionId ?? ""].joined(separator: "|")
        }.sorted()
    }

    private func finalGraphShape(_ provider: DatabaseProvider) throws -> [String] {
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let card = try provider.cardRepo.snapshot(workspaceId: "default-workspace")
        var shape = transactions.map {
            ["transaction", $0.postedDateISO, $0.financialDateRole, $0.nativeCurrency, $0.amountDecimal, $0.direction]
                .joined(separator: "|")
        }
        shape.append(contentsOf: card.statements.map {
            ["statement", $0.parserProfileId, $0.parserProfileVersion,
             $0.statementStartDateISO ?? "", $0.statementEndDateISO ?? "",
             $0.selectedStatementMonthISO ?? "", $0.statementCurrency, String($0.sourceRowCount)]
                .joined(separator: "|")
        })
        let statementProfiles = Dictionary(uniqueKeysWithValues: card.statements.map {
            ($0.id, $0.parserProfileId)
        })
        shape.append(contentsOf: card.summaryComponents.map { component in
            [ "summary", statementProfiles[component.cardStatementId] ?? "", component.componentCode,
              component.moneyCurrency ?? "", String(component.moneyMinor ?? -1),
              component.moneyDecimal ?? "", component.dateISO ?? ""
            ].joined(separator: "|")
        })
        // Cross-order structural equivalence deliberately excludes canonical
        // binding state. The first accepted representation is authoritative,
        // so duplicate-event bindings are expected to move with authority.
        // assertAxisMultisetShape verifies those authority-specific bindings.
        shape.append(contentsOf: card.semanticProjections.map { projection in
            let events = projection.events.sorted { $0.sourceOrdinal < $1.sourceOrdinal }.map {
                [String($0.sourceOrdinal), $0.financialDateISO, $0.liabilityEffectCode,
                 $0.postedCurrency, $0.postedAmountDecimal]
                    .joined(separator: ":")
            }.joined(separator: ";")
            return ["projection", projection.parserProfileId, projection.parserProfileVersion, projection.algorithm,
                    projection.digest, projection.cycleMonthISO ?? "", events]
                .joined(separator: "|")
        })
        shape.append(contentsOf: card.semanticGroups.map {
            ["group", $0.institutionCode, $0.statementFamilyCode,
             $0.statementStartDateISO ?? "", $0.statementEndDateISO ?? "", $0.cycleMonthISO ?? "",
             $0.nativeCurrency, $0.projectionAlgorithm, $0.projectionDigest]
                .joined(separator: "|")
        })
        shape.append("members|authoritative=\(card.semanticMembers.filter { $0.role == .authoritative }.count)|supporting=\(card.semanticMembers.filter { $0.role == .supporting }.count)")
        return shape.sorted()
    }

    private func assertOnlyAuthoritativeAxisResidue(_ provider: DatabaseProvider) throws {
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").count == 4)
        #expect(try provider.importSessionRepo.statementFinancialProjections(workspaceId: "default-workspace").isEmpty)
        let card = try provider.cardRepo.snapshot(workspaceId: "default-workspace")
        #expect(card.instruments.isEmpty)
        #expect(card.sections.isEmpty)
        #expect(card.sectionObservations.isEmpty)
        #expect(card.statements.count == 1)
        #expect(card.semanticProjections.count == 1)
        #expect(card.semanticGroups.count == 1)
        #expect(card.semanticMembers.count == 1)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: "default-workspace").filter {
            $0.persistenceCode == ImportAttemptPersistence.committed.rawValue
        }.count == 1)
    }

    private func persist(
        _ document: FinancialDocument,
        seed: String,
        provider: DatabaseProvider,
        accountChoice: ImportAccountChoice
    ) throws -> ImportPersistenceResult {
        let validation = ImportValidator.validate(financialDocument: document)
        #expect(validation.passed)
        let session = ImportSession(
            fileName: document.sourceDocument.filename,
            institution: .axis,
            documentType: .creditCard,
            parserName: document.parserName,
            transactionCount: document.transactions.count,
            validation: validation
        )
        return try DefaultImportPersistenceCoordinator(databaseProvider: provider, mapper: ImportPersistenceMapper())
            .persistValidatedImport(
                financialDocument: document,
                importSession: session,
                validation: validation,
                fingerprintSet: fingerprintSet(seed),
                accountChoice: accountChoice,
                providerGeneration: provider.generationToken
            )
    }

    private func fingerprintSet(_ seed: String) -> PreparedDocumentFingerprintSet {
        let digest = SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
        return PreparedDocumentFingerprintSet(fingerprints: [
            VersionedDocumentFingerprint(
                algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
                digest: digest,
                byteCount: 80,
                isDuplicateAuthority: false
            ),
            VersionedDocumentFingerprint(
                algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                digest: digest,
                byteCount: 100,
                isDuplicateAuthority: true
            )
        ])
    }

    private func forEachProvider(_ body: (DatabaseProvider, URL?) throws -> Void) throws {
        let memory = InMemoryRepositoryProvider()
        try body(databaseProvider(memory), nil)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-AxisEquivalence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("axis-equivalence.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: url.path)
        try body(databaseProvider(sqlite), url)
        sqlite.database.close()
    }

    private func databaseProvider(_ memory: InMemoryRepositoryProvider) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: memory.workspaceRepo,
            transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo,
            accountRepo: memory.accountRepo,
            cardRepo: memory.cardRepo,
            importSessionRepo: memory.importSessionRepo,
            confirmedImportRepo: memory.confirmedImportRepo,
            generationToken: memory.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory)
        )
    }

    private func databaseProvider(_ sqlite: SQLiteRepositoryProvider) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: sqlite.workspaceRepo,
            transactionRepo: sqlite.transactionRepo,
            categoryRepo: sqlite.categoryRepo,
            accountRepo: sqlite.accountRepo,
            cardRepo: sqlite.cardRepo,
            importSessionRepo: sqlite.importSessionRepo,
            confirmedImportRepo: sqlite.confirmedImportRepo,
            generationToken: sqlite.generationToken,
            persistenceState: .verifiedSQLite
        )
    }

    private func syntheticAxisPDF(
        order: [AxisEvent],
        totalDue: Int,
        includeSelectedMonth: Bool = true
    ) throws -> FinancialDocument {
        let rows = order.map { event in
            "\(event.date) \(event.detail) INR\(event.amount) \(event.effect)"
        }.joined(separator: "\n")
        let text = """
        AXIS CREDIT CARD STATEMENT
        Credit Card Number: 4111 XXXX XXXX 0001
        \(includeSelectedMonth ? "Selected Statement Month: Jun 2026" : "")
        Statement Generation Date: 30 Jun '26
        Statement Period 01 Jun '26 to 30 Jun '26
        Opening Balance INR1,000.00
        Payments INR0.00
        Credits INR0.00
        Purchases INR0.00
        Cash Advance INR0.00
        Other Debit/Charges INR0.00
        Total Payment Due INR\(totalDue).00
        Minimum Payment Due INR100.00
        Payment Due Date 08 Jul '26
        Date Transaction Details Amount (INR) Debit/Credit
        \(rows)
        """
        let url = URL(fileURLWithPath: "/tmp/axis-equivalence-synthetic.pdf")
        let normalized = try AxisCreditCardPDFNormalizer().normalize(
            text: text,
            pageTexts: [text],
            taggedTables: [syntheticTaggedAxisTable(order: order)],
            fileURL: url
        )
        let metadata = DocumentMetadata(institution: .axis, documentType: .creditCard, fileFormat: .pdf, confidence: 1)
        return try AxisCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalized.document, metadata: metadata, rows: normalized.rows,
            header: normalized.header, sourceContext: normalized.sourceContext
        ))
    }

    private func syntheticTaggedAxisTable(order: [AxisEvent]) -> RawPDFTaggedTableEvidence {
        var mcid = 1
        func cell(_ role: RawPDFTaggedCellRole, _ text: String) -> RawPDFTaggedCellEvidence {
            defer { mcid += 2 }
            return RawPDFTaggedCellEvidence(
                role: role,
                children: [
                    .markedContent(.init(pageNumber: 1, mcid: mcid, textBlocks: [], rectangleCount: 1)),
                    .structure(.init(
                        role: "NonStruct",
                        markedContent: [.init(pageNumber: 1, mcid: mcid + 1, textBlocks: [text], rectangleCount: 0)]
                    ))
                ]
            )
        }
        let header = RawPDFTaggedRowEvidence(cells: [
            cell(.header, "Date"), cell(.header, "Transaction Details"),
            cell(.header, "Amount (INR)"), cell(.header, "Debit/Credit")
        ])
        let rows = order.map { event in
            RawPDFTaggedRowEvidence(cells: [
                cell(.data, event.date), cell(.data, event.detail),
                cell(.data, "INR\(event.amount)"), cell(.data, event.effect)
            ])
        }
        return RawPDFTaggedTableEvidence(rows: [header] + rows)
    }

    private func syntheticAxisXLSX(order: [AxisEvent], totalDue: Int) throws -> FinancialDocument {
        func cell(_ row: Int, _ column: Int, _ value: String) -> RawTabularCell {
            RawTabularCell(sourceRow: row, sourceColumn: column, value: .string(value))
        }
        var rows = [
            RawTabularRow(sourceRow: -6, cells: [cell(-6, 1, "Credit Card Number: 4111 XXXX XXXX 0001")]),
            RawTabularRow(sourceRow: -5, cells: [cell(-5, 1, "Selected Statement Month: Jun 2026")]),
            RawTabularRow(sourceRow: -4, cells: [cell(-4, 1, "Opening Balance INR1,000.00")]),
            RawTabularRow(sourceRow: -3, cells: [cell(-3, 1, "Total Payment Due INR\(totalDue).00")]),
            RawTabularRow(sourceRow: -2, cells: [cell(-2, 1, "Minimum Payment Due INR100.00")]),
            RawTabularRow(sourceRow: -1, cells: [cell(-1, 1, "Payment Due Date 08 Jul '26")]),
            RawTabularRow(sourceRow: 0, cells: [
                cell(0, 1, "Date"), cell(0, 2, "Transaction Details"), cell(0, 3, ""),
                cell(0, 4, "Amount (INR)"), cell(0, 5, "Debit/Credit"), cell(0, 6, ""),
                cell(0, 7, ""), cell(0, 8, ""), cell(0, 9, "")
            ])
        ]
        rows.append(contentsOf: order.enumerated().map { index, event in
            let row = index + 1
            return RawTabularRow(sourceRow: row, cells: [
                cell(row, 1, event.date), cell(row, 2, event.detail), cell(row, 3, ""),
                cell(row, 4, "INR\(event.amount)"), cell(row, 5, event.effect), cell(row, 6, ""),
                cell(row, 7, ""), cell(row, 8, ""), cell(row, 9, "")
            ])
        })
        let raw = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/axis-equivalence-synthetic.xlsx"),
            fileName: "axis-equivalence-synthetic.xlsx",
            fileExtension: "xlsx",
            content: .tabular(RawTabularSheet(name: "Statement", visibility: .visible, columnCount: 9, rows: rows))
        )
        let normalized = try AxisCreditCardXLSXNormalizer().normalize(rawDocument: raw)
        let metadata = DocumentMetadata(institution: .axis, documentType: .creditCard, fileFormat: .xlsx, confidence: 1)
        return try AxisCreditCardXLSXParser().parse(document: NormalizedDocument(
            document: normalized.document, metadata: metadata, rows: normalized.rows,
            header: normalized.header, sourceContext: normalized.sourceContext
        ))
    }
}
