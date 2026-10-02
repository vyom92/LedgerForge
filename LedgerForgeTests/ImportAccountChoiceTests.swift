// LedgerForgeTests/ImportAccountChoiceTests.swift

import Testing
import Foundation
import CryptoKit
@testable import LedgerForge

@MainActor
struct ImportAccountChoiceTests {

    @Test(.globalRuntimeStateIsolation)
    func confirmedRenewalAutomaticallyRoutesAnUnimportedAuthenticStatement() async throws {
        let env = ProcessInfo.processInfo.environment
        let checkpoint = URL(fileURLWithPath: try #require(env["LEDGERFORGE_S100_LINEAGE_CHECKPOINT"]))
        #expect(SHA256.hash(data: try Data(contentsOf: checkpoint)).map { String(format: "%02x", $0) }.joined()
            == "f8f5cabcd3db34882c77ef832e44b8597f6b8ac6393aa9d032aadc49bf0ec62a")
        let originals = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at:
            URL(fileURLWithPath: try #require(env["LEDGERFORGE_S100_RETAINED_ORIGINAL_DATABASE"])))
        defer { originals.database.close() }
        let digest = try #require(env["LEDGERFORGE_S100_LINEAGE_ORIGINAL_SHA256"])
        let sourceInbox = try originals.gmailInboxRepo.load(account: try #require(try originals.gmailInboxRepo.storedAccounts().first))
        let source = try #require(sourceInbox.orderedSources.first { $0.sha256 == digest })
        let url = try #require(source.importURL)
        let bytes = try originals.gmailInboxRepo.original(sha256: digest, byteCount: source.expectedByteCount)
        let passwords = DefaultPasswordProvider(supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })
        let password = try #require(try await passwords.rememberedPasswordCandidates(for: ImportRequest(fileURL: url)).first).value
        let compare = try await CBQCreditCardPrivateAcceptanceTests().gmailComparison(bytes: bytes, url: url, password: password)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-renewal-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("qualification.sqlite")
        try FileManager.default.copyItem(at: checkpoint, to: copy)
        let sqlite = try SQLiteRepositoryProvider(path: copy.path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let workspace = try #require(try sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let before = try provider.cardRepo.snapshot(workspaceId: workspace)
        let renewal = try #require(before.relationships.first { $0.relationshipKind == "renewal" && $0.authority == "user_confirmed" })
        let accountID = renewal.liabilityAccountId
        #expect(before.continuingCardGroups(accountID: accountID).count == 2)
        let oldRows = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        let status = try provider.accountRepo.account(id: accountID)?.closedAtISO
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, accountStore: AccountStore(),
            transactionStore: TransactionStore(), importSessionStore: ImportSessionStore(), workspaceId: workspace,
            participatesInLifecycleGate: false)
        let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: originals.gmailInboxRepo) },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider,
                mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "Authentic owner review")),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
        let prepared = try await engine.prepareImport(from: url)
        defer { engine.cancelPreparedImport(prepared) }
        try compare(prepared)
        #expect(try engine.reviewPreparedImport(prepared) == .matchedExisting(accountId: accountID))
        let result = await engine.commitPreparedImport(prepared, accountChoice: nil)
        #expect(result.succeeded && result.persisted && result.hydrationOutcome == .committedAndHydrated)
        #expect(result.accountId == accountID)
        let after = try provider.cardRepo.snapshot(workspaceId: workspace)
        #expect(after.instruments == before.instruments)
        #expect(after.relationships == before.relationships)
        let newSections = after.sections.filter { !Set(before.sections.map(\.id)).contains($0.id) }
        #expect(!newSections.isEmpty)
        #expect(newSections.contains { $0.instrumentId == renewal.successorInstrumentId })
        #expect(!newSections.contains { $0.instrumentId == renewal.predecessorInstrumentId })
        // Independently follow the recorded exact observations and this actual
        // owner-confirmed renewal, including each printed section's destination.
        let priorSectionOwners = Dictionary(uniqueKeysWithValues: before.sections.map { ($0.id, $0.instrumentId) })
        for incoming in try #require(prepared.financialDocument.cardStatementEvidence).instrumentSections {
            let observation = try #require(incoming.sourceIdentityObservations.first)
            let matches = Set(before.sectionObservations.filter {
                $0.associationAuthority == "user_confirmed" && $0.observationKind == observation.kind.rawValue && $0.sourceValue == observation.value
            }.compactMap { priorSectionOwners[$0.cardStatementSectionId] })
            let expected: String
            if matches.count == 1 { expected = try #require(matches.first) }
            else {
                #expect(matches == [renewal.predecessorInstrumentId, renewal.successorInstrumentId])
                expected = renewal.successorInstrumentId
            }
            #expect(newSections.first { $0.documentScopedSectionId == incoming.documentScopedSectionID }?.instrumentId == expected)
        }
        let saved = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        let oldIDs = Set(oldRows.map(\.id))
        let oldRowsUnchanged = saved.filter { oldIDs.contains($0.id) } == oldRows
        #expect(oldRowsUnchanged)
        #expect(saved.count == oldRows.count + prepared.financialDocument.transactions.count)
        #expect(try provider.accountRepo.account(id: accountID)?.closedAtISO == status)
        #expect(after.continuingCardGroups(accountID: accountID).count == 2)
        let replay = try await engine.prepareImport(from: url)
        let repeated = await engine.commitPreparedImport(replay, accountChoice: nil)
        #expect(repeated.previousImport != nil && !repeated.persisted)
        let replayRowsUnchanged = try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == saved
        #expect(replayRowsUnchanged)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticConfirmedRenewalHasInMemoryParity() async throws {
        let env = ProcessInfo.processInfo.environment
        let checkpointURL = URL(fileURLWithPath: try #require(env["LEDGERFORGE_S100_LINEAGE_CHECKPOINT"]))
        #expect(SHA256.hash(data: try Data(contentsOf: checkpointURL)).map { String(format: "%02x", $0) }.joined()
            == "f8f5cabcd3db34882c77ef832e44b8597f6b8ac6393aa9d032aadc49bf0ec62a")
        let checkpoint = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at: checkpointURL)
        defer { checkpoint.database.close() }
        let recordedWorkspace = try #require(try checkpoint.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let recorded = try checkpoint.cardRepo.snapshot(workspaceId: recordedWorkspace)
        let renewal = try #require(recorded.relationships.first { $0.relationshipKind == "renewal" && $0.authority == "user_confirmed" })
        let accountName = try #require(try checkpoint.accountRepo.account(id: renewal.liabilityAccountId)?.name)
        let originals = try AuthenticSourceTestSupport.readOnlyRegisteredProvider(at:
            URL(fileURLWithPath: try #require(env["LEDGERFORGE_S100_RETAINED_ORIGINAL_DATABASE"])))
        defer { originals.database.close() }
        let inbox = try originals.gmailInboxRepo.load(account: try #require(try originals.gmailInboxRepo.storedAccounts().first))
        let firstDigest = "82f8d68ab132e4845b7a9c1b4fde0dc5d8d5559b547ad18186af3bcb9bb194ee"
        let bridgeDigest = "e3be5a815dfc9574e03d24ece688084bae7b04a167731efa26f4611ea8bc33ca"
        let newestDigest = try #require(env["LEDGERFORGE_S100_LINEAGE_ORIGINAL_SHA256"])
        let firstURL = try #require(inbox.orderedSources.first { $0.sha256 == firstDigest }?.importURL)
        let passwords = DefaultPasswordProvider(supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })
        let password = try #require(try await passwords.rememberedPasswordCandidates(for: ImportRequest(fileURL: firstURL)).first).value
        let provider = DatabaseProvider(inMemory: true)
        let workspace = "authentic-renewal-parity"
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false)
        let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: originals.gmailInboxRepo) },
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider,
                mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "Authentic renewal review")),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))

        func recordedSections(_ digest: String) throws -> [CardStatementSectionDTO] {
            let documents = try checkpoint.database.query(sql: "SELECT document_id FROM document_fingerprints WHERE algorithm = ? AND fingerprint = ? AND is_duplicate_authority = 1;",
                params: ["ledgerforge.source-bytes.sha256.v1", digest]) { $0.string(at: 0) }.compactMap { $0 }
            let document = try #require(documents.count == 1 ? documents.first : nil)
            let statement = try #require(recorded.statements.first { $0.documentId == document && $0.liabilityAccountId == renewal.liabilityAccountId })
            return recorded.sections.filter { $0.cardStatementId == statement.id }
        }
        func recordedOwner(_ incoming: CardSourceIdentityObservation, in sections: [CardStatementSectionDTO]) throws -> String {
            let byID = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0.instrumentId) })
            let owners = Set(recorded.sectionObservations.filter {
                $0.associationAuthority == "user_confirmed" && $0.observationKind == incoming.kind.rawValue && $0.sourceValue == incoming.value
            }.compactMap { byID[$0.cardStatementSectionId] })
            return try #require(owners.count == 1 ? owners.first : nil)
        }
        var runtimeOwners: [String: String] = [:]
        var accountID: String?
        // Actual owner-confirmation order, using exact retained original bytes.
        for digest in [firstDigest, bridgeDigest] {
            let source = try #require(inbox.orderedSources.first { $0.sha256 == digest })
            let url = try #require(source.importURL)
            let bytes = try originals.gmailInboxRepo.original(sha256: digest, byteCount: source.expectedByteCount)
            let compare = try await CBQCreditCardPrivateAcceptanceTests().gmailComparison(bytes: bytes, url: url, password: password)
            let historicalSections = try recordedSections(digest)
            let prepared = try await engine.prepareImport(from: url)
            defer { engine.cancelPreparedImport(prepared) }
            try compare(prepared)
            let evidence = try #require(prepared.financialDocument.cardStatementEvidence)
            let choice: ImportAccountChoice
            if let accountID {
                var choices: [String: ImportCardInstrumentChoice] = [:]
                for section in evidence.instrumentSections {
                    let historicalID = try recordedOwner(#require(section.sourceIdentityObservations.first), in: historicalSections)
                    if let existing = runtimeOwners[historicalID] { choices[section.documentScopedSectionID] = .reuseExistingInstrument(instrumentId: existing) }
                    else {
                        #expect(historicalID == renewal.successorInstrumentId)
                        choices[section.documentScopedSectionID] = .createNewInstrument(relationship: .renewal,
                            relatedInstrumentId: try #require(runtimeOwners[renewal.predecessorInstrumentId]))
                    }
                }
                choice = .useExistingCardLiabilityAccountSections(accountId: accountID, sectionChoices: choices)
            } else { choice = .createNewCardLiabilityAccountAndInstrument(displayName: accountName) }
            let result = await engine.commitPreparedImport(prepared, accountChoice: choice)
            #expect(result.succeeded && result.hydrationOutcome == .committedAndHydrated)
            if let accountID { #expect(result.accountId == accountID) }
            else { accountID = try #require(result.accountId) }
            let saved = try provider.cardRepo.snapshot(workspaceId: workspace)
            let statement = try #require(saved.statements.first { $0.importSessionId == result.importSessionId })
            for section in evidence.instrumentSections {
                let historicalID = try recordedOwner(#require(section.sourceIdentityObservations.first), in: historicalSections)
                let currentID = try #require(saved.sections.first { $0.cardStatementId == statement.id && $0.documentScopedSectionId == section.documentScopedSectionID }?.instrumentId)
                if let prior = runtimeOwners[historicalID] { #expect(currentID == prior) }
                runtimeOwners[historicalID] = currentID
            }
        }
        let owner = try #require(accountID)
        let before = try provider.cardRepo.snapshot(workspaceId: workspace)
        let priorRows = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        #expect(before.instruments.count == 3 && before.relationships.count == 1)
        #expect(before.relationships.first?.predecessorInstrumentId == runtimeOwners[renewal.predecessorInstrumentId])
        #expect(before.relationships.first?.successorInstrumentId == runtimeOwners[renewal.successorInstrumentId])
        let source = try #require(inbox.orderedSources.first { $0.sha256 == newestDigest })
        let url = try #require(source.importURL)
        let bytes = try originals.gmailInboxRepo.original(sha256: newestDigest, byteCount: source.expectedByteCount)
        let compare = try await CBQCreditCardPrivateAcceptanceTests().gmailComparison(bytes: bytes, url: url, password: password)
        let prepared = try await engine.prepareImport(from: url)
        defer { engine.cancelPreparedImport(prepared) }
        try compare(prepared)
        #expect(try engine.reviewPreparedImport(prepared) == .matchedExisting(accountId: owner))
        let result = await engine.commitPreparedImport(prepared, accountChoice: nil)
        #expect(result.succeeded && result.accountId == owner)
        let after = try provider.cardRepo.snapshot(workspaceId: workspace)
        #expect(after.instruments == before.instruments && after.relationships == before.relationships)
        let sectionOwners = Dictionary(uniqueKeysWithValues: before.sections.map { ($0.id, $0.instrumentId) })
        let statement = try #require(after.statements.first { $0.importSessionId == result.importSessionId })
        for section in try #require(prepared.financialDocument.cardStatementEvidence).instrumentSections {
            let observation = try #require(section.sourceIdentityObservations.first)
            let matches = Set(before.sectionObservations.filter {
                $0.associationAuthority == "user_confirmed" && $0.observationKind == observation.kind.rawValue && $0.sourceValue == observation.value
            }.compactMap { sectionOwners[$0.cardStatementSectionId] })
            let expected: String
            if matches.count == 1 { expected = try #require(matches.first) }
            else {
                #expect(matches == Set([try #require(runtimeOwners[renewal.predecessorInstrumentId]), try #require(runtimeOwners[renewal.successorInstrumentId])]))
                expected = try #require(runtimeOwners[renewal.successorInstrumentId])
            }
            #expect(after.sections.first { $0.cardStatementId == statement.id && $0.documentScopedSectionId == section.documentScopedSectionID }?.instrumentId == expected)
        }
        let savedRows = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        let oldIDs = Set(priorRows.map(\.id))
        let priorRowsUnchanged = savedRows.filter { oldIDs.contains($0.id) }.sorted { $0.id < $1.id } == priorRows.sorted { $0.id < $1.id }
        #expect(priorRowsUnchanged)
        #expect(savedRows.count == priorRows.count + prepared.transactionCount)
        let replay = try await engine.prepareImport(from: url)
        let duplicate = await engine.commitPreparedImport(replay, accountChoice: nil)
        #expect(duplicate.previousImport != nil && !duplicate.persisted)
        let duplicateRowsUnchanged = try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == savedRows
        #expect(duplicateRowsUnchanged)
    }

    @Test func confirmedCardChainsGroupOnlyUnambiguousRelationships() {
        // Source-independent graph mechanics. No card or statement fixture.
        func link(_ from: String, _ to: String, _ kind: String = "renewal", _ authority: String = "user_confirmed") -> CardInstrumentLineage.Link {
            .init(predecessor: from, successor: to, kind: kind, authority: authority)
        }
        let ids: Set<String> = ["a", "b", "c", "d"]
        let chain = CardInstrumentLineage.groups(instrumentIDs: ids, links: [link("a", "b"), link("b", "c")])
        #expect(chain.map(\.members) == [["a", "b", "c"], ["d"]])
        #expect(CardInstrumentLineage.resolve(exactMatches: ["a", "b"], groups: chain) == "b")
        #expect(CardInstrumentLineage.resolve(exactMatches: ["a"], groups: chain) == "a")
        #expect(CardInstrumentLineage.resolve(exactMatches: ["a", "d"], groups: chain) == nil)
        #expect(CardInstrumentLineage.resolve(exactMatches: [], groups: chain) == nil)
        for contradictory in [[link("a", "b"), link("a", "c")], [link("a", "b"), link("c", "b")],
                              [link("a", "b"), link("b", "a")], [link("a", "a")]] {
            let groups = CardInstrumentLineage.groups(instrumentIDs: ids, links: contradictory)
            #expect(groups.allSatisfy { $0.members.count == 1 })
            #expect(CardInstrumentLineage.resolve(exactMatches: ["a", "b"], groups: groups) == nil)
        }
        let unsupported = CardInstrumentLineage.groups(instrumentIDs: ids,
            links: [link("a", "b", "additional_concurrent"), link("a", "c", "unspecified"), link("b", "c", "renewal", "inferred"), link("c", "outside")])
        #expect(unsupported.allSatisfy { $0.members.count == 1 })
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineCardSectionReviewRetainsEstablishedLiabilityOwner() async throws {
        let environment = ProcessInfo.processInfo.environment
        let checkpoint = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_S99_IMPORT_OWNER_DATABASE"]))
        let bytes = try Data(contentsOf: checkpoint)
        #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            == environment["LEDGERFORGE_S99_IMPORT_OWNER_SHA256"])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-card-owner-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("qualification.sqlite")
        try FileManager.default.copyItem(at: checkpoint, to: copy)
        let sqlite = try SQLiteRepositoryProvider(path: copy.path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let workspace = try #require(try sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let before = try NetWorthTestSupport.financialDigest(sqlite.database)
        let inbox = try provider.gmailInboxRepo.load(account: try #require(try provider.gmailInboxRepo.storedAccounts().first))
        let source = try #require(inbox.orderedSources.first {
            $0.sha256 == "e3be5a815dfc9574e03d24ece688084bae7b04a167731efa26f4611ea8bc33ca"
        })
        let url = try #require(source.importURL)
        let original = try provider.gmailInboxRepo.original(sha256: try #require(source.sha256), byteCount: source.expectedByteCount)
        let passwords = DefaultPasswordProvider(supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })
        let password = try #require(try await passwords.rememberedPasswordCandidates(for: ImportRequest(fileURL: url)).first).value
        let compare = try await CBQCreditCardPrivateAcceptanceTests().gmailComparison(bytes: original, url: url, password: password)
        let persistence = DefaultImportPersistenceCoordinator(databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "Authentic owner review"))
        let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
        let prepared = try await engine.prepareImport(from: url)
        defer { engine.cancelPreparedImport(prepared) }
        try compare(prepared)
        let evidence = try #require(prepared.financialDocument.cardStatementEvidence)
        let observation = try #require(evidence.accountSourceIdentityObservations.first)
        let cards = try provider.cardRepo.snapshot(workspaceId: workspace)
        let owners = Set(cards.sourceObservations.filter {
            $0.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue &&
                $0.associationAuthority == "user_confirmed" &&
                $0.observationKind == observation.kind.rawValue && $0.sourceValue == observation.value
        }.map(\.subjectId))
        let owner = try #require(owners.count == 1 ? owners.first : nil)
        let review = try engine.reviewPreparedImport(prepared)
        #expect(review == .cardChoiceRequired(eligibleLiabilityAccountIds: [owner], matchedLiabilityAccountId: owner))
        #expect(review.requiresExplicitChoice)
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: nil))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review,
            choice: .createNewCardLiabilityAccountAndInstrument(displayName: "Separate account")))
        for account in try provider.accountRepo.accounts(workspaceId: workspace) where account.id != owner {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review,
                choice: .useExistingCardLiabilityAccount(accountId: account.id,
                    instrumentChoice: .createNewInstrument())))
        }
        let projection = ImportIdentityReviewUIProjection(review: review)
        #expect(projection.matchedAccountID == owner && projection.eligibleAccountIDs == [owner])
        #expect(projection.presentation?.label == "Review card sections")
        var repeatedChoices: [String: ImportCardInstrumentChoice] = [:]
        for section in evidence.instrumentSections {
            let incoming = try #require(section.sourceIdentityObservations.first)
            let destinations = Set(cards.sectionObservations.compactMap { observation -> String? in
                guard observation.associationAuthority == "user_confirmed",
                      observation.observationKind == incoming.kind.rawValue,
                      observation.sourceValue == incoming.value,
                      let recorded = cards.sections.first(where: { $0.id == observation.cardStatementSectionId }) else { return nil }
                return recorded.instrumentId
            })
            let destination = try #require(destinations.count == 1 ? destinations.first : nil)
            repeatedChoices[section.documentScopedSectionID] = .reuseExistingInstrument(instrumentId: destination)
        }
        #expect(!ImportCardInstrumentChoice.hasDistinctExistingDestinations(repeatedChoices))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review,
            choice: .useExistingCardLiabilityAccountSections(accountId: owner, sectionChoices: repeatedChoices),
            requiredCardSectionIDs: evidence.instrumentSections.map(\.documentScopedSectionID)))
        #expect(throws: ImportPersistenceCoordinationError.explicitChoiceRequired) {
            try persistence.persistValidatedImport(financialDocument: prepared.financialDocument,
                importSession: prepared.importSession, validation: prepared.validation,
                fingerprint: prepared.fingerprint,
                accountChoice: .useExistingCardLiabilityAccountSections(accountId: owner, sectionChoices: repeatedChoices),
                providerGeneration: provider.generationToken)
        }
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database) == before)
    }

    @Test func creationNamesAndExplicitRelationshipsMustBeComplete() {
        for name in ["", " \n\t"] {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .choiceRequired(eligibleAccountIds: []),
                choice: .createNewAccount(displayName: name)
            ))
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .cardChoiceRequired(eligibleLiabilityAccountIds: []),
                choice: .createNewCardLiabilityAccountAndInstrument(displayName: name)
            ))
        }
        let review = ImportIdentityReview.cardChoiceRequired(eligibleLiabilityAccountIds: ["liability"])
        let incomplete = ImportCardInstrumentChoice.createNewInstrument(relationship: .replacement)
        #expect(!incomplete.isComplete)
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccount(accountId: "liability", instrumentChoice: incomplete)
        ))
        #expect(ImportCardInstrumentChoice.createNewInstrument().isComplete)
        #expect(ImportCardInstrumentChoice.createNewInstrument(relationship: .replacement, relatedInstrumentId: "existing").isComplete)
        #expect(!ImportCardInstrumentChoice.createNewInstrument(relatedInstrumentId: "existing").isComplete)
        let zeroSectionChoice = ImportAccountChoice.useExistingCardLiabilityAccountSections(accountId: "liability", sectionChoices: [:])
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: zeroSectionChoice, requiredCardSectionIDs: []))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: zeroSectionChoice, requiredCardSectionIDs: ["section"]))
    }

    @Test func noIdentityReviewStateSelectsAnAccountAutomatically() {
        let reviews: [ImportIdentityReview] = [
            .matchedExisting(accountId: "repository-account-private"),
            .choiceRequired(eligibleAccountIds: ["candidate-account-private"]),
            .liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: ["axis-liability-account-private"]),
            .ambiguous,
            .conflict,
            .unavailable
        ]

        for review in reviews {
            #expect(ImportAccountConfirmationPolicy.initialChoice(for: review) == nil)
        }
    }

    @Test func matchedExistingDoesNotRequireAnArtificialChoice() {
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .matchedExisting(accountId: "repository-account-private"),
            choice: nil
        ))
    }

    @Test func choiceRequiredNeedsAValidExplicitChoice() {
        let review = ImportIdentityReview.choiceRequired(
            eligibleAccountIds: ["eligible-account-a", "eligible-account-b"]
        )

        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: nil
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "ineligible-account")
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "eligible-account-b")
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .createNewAccount(displayName: "Imported review account")
        ))
    }

    @Test func ambiguityAndConflictAlwaysBlockConfirmation() {
        let choices: [ImportAccountChoice?] = [
            nil,
            .useExistingAccount(accountId: "candidate-account-private"),
            .createNewAccount(displayName: "Imported review account")
        ]

        for choice in choices {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .ambiguous,
                choice: choice
            ))
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .conflict,
                choice: choice
            ))
        }
    }

    @Test func unavailablePreservesTheExistingNonIdentityConfirmationContract() {
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .unavailable,
            choice: nil
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .unavailable, choice: nil, requiresNamedCreation: true
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .unavailable, choice: .createNewAccount(displayName: "Bank account"), requiresNamedCreation: true
        ))
    }

    @Test func bankSectionChoicesRequireEveryUnresolvedSectionAndKeepSourceAccountsSeparate() {
        let sections: [BankSectionIdentityReview] = [
            BankSectionIdentityReview(
                sectionID: "section-nre",
                product: "NRE Savings",
                sourceAccountLabel: "XXXXXXXXXXX1001",
                period: nil,
                transactionCount: 0,
                identityReview: .matchedExisting(accountId: "account-nre")
            ),
            BankSectionIdentityReview(
                sectionID: "section-nro",
                product: "NRO Savings",
                sourceAccountLabel: "XXXXXXXXXXX2002",
                period: nil,
                transactionCount: 0,
                identityReview: .choiceRequired(eligibleAccountIds: ["account-nro", "account-other"])
            )
        ]

        let complete: [String: ImportBankSectionChoice] = [
            "section-nro": .useExistingAccount(accountId: "account-nro")
        ]
        #expect(ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: complete
        ))
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: [:]
        ))
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: ["section-nro": .useExistingAccount(accountId: "account-nre")]
        ))
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: ["section-nro": .createNewAccount(displayName: " \n")]
        ))
        let colliding = [
            sections[0],
            BankSectionIdentityReview(
                sectionID: "section-nro-matched",
                product: "NRO Savings",
                sourceAccountLabel: "XXXXXXXXXXX2002",
                period: nil,
                transactionCount: 0,
                identityReview: .matchedExisting(accountId: "account-nre")
            )
        ]
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: colliding,
            choices: [:]
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .bankSections(sections),
            choice: .bankSections(complete)
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: .bankSections(sections), choice: nil))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: .bankSections([]), choice: nil))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(review: .bankSections([sections[0]]), choice: nil))
    }

    @Test func cardChoiceRequiresEligibleLiabilityAccountAndCompletedSectionDecisions() {
        let review = ImportIdentityReview.cardChoiceRequired(
            eligibleLiabilityAccountIds: ["eligible-card-account"]
        )
        let completeChoices: [String: ImportCardInstrumentChoice] = [
            "instrument-section-1": .reuseExistingInstrument(instrumentId: "instrument-a"),
            "instrument-section-2": .createNewInstrument()
        ]

        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: nil))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccountSections(
                accountId: "eligible-card-account",
                sectionChoices: [:]
            )
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccountSections(
                accountId: "ineligible-card-account",
                sectionChoices: completeChoices
            )
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccountSections(
                accountId: "eligible-card-account",
                sectionChoices: completeChoices
            )
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .createNewCardLiabilityAccountAndInstrument(displayName: "Imported review card")
        ))
        let repeated: [String: ImportCardInstrumentChoice] = [
            "section-a": .reuseExistingInstrument(instrumentId: "same-recorded-card"),
            "section-b": .reuseExistingInstrument(instrumentId: "same-recorded-card")
        ]
        for state in [review, .matchedExisting(accountId: "eligible-card-account")] {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: state,
                choice: .useExistingCardLiabilityAccountSections(accountId: "eligible-card-account", sectionChoices: repeated)))
        }
        #expect(ImportCardInstrumentChoice.hasDistinctExistingDestinations([
            "section-a": .createNewInstrument(), "section-b": .createNewInstrument()
        ]))
    }

    @Test func axisLiabilityOnlyReviewUsesOrdinaryAccountChoicesWithoutAutomaticSelection() {
        let review = ImportIdentityReview.liabilityAccountChoiceRequired(
            eligibleLiabilityAccountIds: ["axis-account-a", "axis-account-b"]
        )

        #expect(review.eligibleAccountIds == ["axis-account-a", "axis-account-b"])
        #expect(review.requiresExplicitChoice)
        #expect(review.blocksConfirmation)
        #expect(ImportAccountConfirmationPolicy.initialChoice(for: review) == nil)

        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: nil))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "axis-account-b")
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .createNewAccount(displayName: "Imported review account")
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "other-institution-account")
        ))
    }

    @Test func axisLiabilityOnlyReviewRejectsEveryInstrumentOrSectionChoice() {
        let review = ImportIdentityReview.liabilityAccountChoiceRequired(
            eligibleLiabilityAccountIds: ["axis-account"]
        )
        let instrumentChoices: [ImportAccountChoice] = [
            .useExistingCardLiabilityAccount(
                accountId: "axis-account",
                instrumentChoice: .reuseExistingInstrument(instrumentId: "instrument")
            ),
            .useExistingCardLiabilityAccount(
                accountId: "axis-account",
                instrumentChoice: .createNewInstrument()
            ),
            .useExistingCardLiabilityAccountSections(
                accountId: "axis-account",
                sectionChoices: [
                    "section": .reuseExistingInstrument(instrumentId: "instrument")
                ]
            ),
            .createNewCardLiabilityAccountAndInstrument(displayName: "Imported review card")
        ]

        for choice in instrumentChoices {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: review,
                choice: choice
            ))
        }
    }

    @Test func axisLiabilityOnlyProjectionDoesNotExposeInstrumentActions() {
        let projection = ImportIdentityReviewUIProjection(
            review: .liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: ["axis-account"])
        )

        #expect(projection.eligibleAccountIDs == ["axis-account"])
        #expect(projection.presentation?.label == "Choose a liability account")
        #expect(projection.presentation?.explanation.contains("printed card number") == true)
        #expect(projection.presentation?.label.localizedCaseInsensitiveContains("instrument") == false)
    }
}
