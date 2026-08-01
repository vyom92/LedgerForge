import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ImportLifecycleTests {

    @Test(.globalRuntimeStateIsolation)
    func approvedAxisPreparationEmitsOrderedNamedStagesWithoutSourceEvidence() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let engine = ImportEngine(
            importPersistenceCoordinator: PreparationOnlyPersistenceCoordinator(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
        let requestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        var progress: [ImportProgress] = []

        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv"),
            requestId: requestID
        ) { progress.append($0) }
        defer { engine.cancelPreparedImport(prepared) }

        #expect(prepared.validation.passed)
        #expect(progress.map(\.requestId) == Array(repeating: requestID, count: 7))
        #expect(progress.map(\.phase) == [
            .openingSource,
            .detectingInstitution,
            .classifyingStatement,
            .selectingParser,
            .parsingFinancialContent,
            .validatingPreparedContent,
            .preparingConfirmationPreview
        ])
        #expect(progress.allSatisfy { $0.completedUnitCount == 0 && $0.totalUnitCount == 0 })

        let presentedProgress = progress.map { $0.phase.userFacingTitle }.joined(separator: "|")
        for prohibited in ["axis_bank_nre", "Account No", "UPI", "private"] {
            #expect(!presentedProgress.localizedCaseInsensitiveContains(prohibited))
        }
    }

    @Test func taskOwnerSupersedesReleasesAndCancelsOnlyTheCurrentPreparation() async {
        let owner = ImportPreparationTaskOwner()
        let probe = ImportLifecycleCancellationProbe()

        let firstID = owner.start { _ in
            await probe.markFirstOperationReadyToObserveCancellation()
            do {
                try await Task.sleep(for: .seconds(10))
            } catch is CancellationError {
                await probe.markFirstCancellationObserved()
            } catch {
                Issue.record("Unexpected preparation task error: \(error.localizedDescription)")
            }
        }
        await probe.waitForFirstOperationToBeReady()

        let secondID = owner.start { _ in }
        await probe.waitForFirstCancellation()

        #expect(firstID != secondID)
        #expect(!owner.isCurrent(firstID))
        #expect(owner.isCurrent(secondID))

        owner.finish(firstID)
        #expect(owner.isCurrent(secondID))

        owner.finish(secondID)
        #expect(owner.activeOperationID == nil)

        owner.cancel()
        owner.cancel()
        #expect(owner.activeOperationID == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func preparedSourceSupersessionConsumesOnlyTheOldSnapshotWithoutRecordingRejection() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = SupersessionPersistenceProbe()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { ProviderGenerationToken() },
            forcedHydration: {
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
            },
            rejectedAttemptHydration: {}
        )
        let source = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")

        let sourceA = try await engine.prepareImport(from: source)
        engine.cancelPreparedImport(sourceA)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try sourceA.sourceSnapshot.withBytes { $0 }
        }

        let sourceB = try await engine.prepareImport(from: source)
        #expect(sourceA.id != sourceB.id)
        let supersededResult = await engine.commitPreparedImport(sourceA)

        #expect(supersededResult.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(supersededResult.recoveryRoute == .unavailable)
        #expect(persistence.persistInvocationCount == 0)
        #expect(persistence.rejectionInvocationCount == 0)
        #expect(try sourceB.sourceSnapshot.withBytes { !$0.isEmpty })

        let replacementResult = await engine.commitPreparedImport(sourceB)

        #expect(replacementResult.persisted)
        #expect(replacementResult.recoveryRoute == .none)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.rejectionInvocationCount == 0)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try sourceB.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test func resultRecoveryDefaultsUnavailableAndIgnoresHostileErrorText() {
        for message in [
            ImportPersistenceCoordinationError.retryableContention.localizedDescription,
            ImportPersistenceCoordinationError.persistenceUnavailable.localizedDescription
        ] {
            let result = ImportEngineResult(
                fileName: "Selected document",
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: message
            )

            #expect(result.recoveryRoute == .unavailable)
        }
    }

    @Test func typedPersistenceFailuresSelectBoundedRecoveryWithoutAutomaticWork() async {
        let cases: [(ImportPersistenceCoordinationError, ImportAccountOutcome, ConfirmedImportRecoveryRoute)] = [
            (.retryableContention, .unavailable, .prepareAgain(.persistenceContention)),
            (.persistenceUnavailable, .unavailable, .prepareAgain(.persistenceUnavailable)),
            (.staleProviderGeneration, .staleProviderGeneration, .prepareAgain(.staleProviderGeneration)),
            (.reviewedPartialPlanStale, .unavailable, .prepareAgain(.reviewedPartialPlanStale)),
            (.explicitChoiceRequired, .choiceRequired, .reviewRequired(.accountChoiceRequired)),
            (.selectedAccountUnavailable, .staleAccountChoice, .reviewRequired(.accountChoiceStale)),
            (.selectedAccountWorkspaceMismatch, .staleAccountChoice, .reviewRequired(.accountChoiceStale)),
            (.selectedAccountAlreadyIdentified, .staleAccountChoice, .reviewRequired(.accountChoiceStale)),
            (.staleIdentityDecision, .staleAccountChoice, .reviewRequired(.accountChoiceStale)),
            (.ambiguousIdentity, .identityAmbiguous, .reviewRequired(.identityAmbiguous)),
            (.conflictingIdentity, .identityConflict, .reviewRequired(.identityConflict)),
            (.identifierOwnershipConflict, .identifierOwnershipConflict, .reviewRequired(.identifierOwnershipConflict)),
            (.repositoryIntegrityConflict, .unavailable, .reviewRequired(.repositoryIntegrityConflict))
        ]

        for (error, accountOutcome, expectedRoute) in cases {
            let persistence = RecoveryPersistenceProbe(
                error: ImportPersistenceCommitFailure(
                    originalError: error,
                    importAttemptId: "attempt-rejected",
                    accountOutcome: accountOutcome
                )
            )
            var acquisitionCount = 0
            let engine = ImportEngine(
                sourceSnapshotAcquirer: { _ in
                    acquisitionCount += 1
                    return SourceContentSnapshot(bytes: Data("unexpected".utf8))
                },
                importPersistenceCoordinator: persistence,
                developerConsole: DeveloperConsole(),
                persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
                rejectedAttemptHydration: {}
            )
            let prepared = recoveryPreparedImport()

            let result = await engine.commitPreparedImport(prepared)

            #expect(result.recoveryRoute == expectedRoute)
            #expect(!result.persisted)
            #expect(persistence.persistInvocationCount == 1)
            #expect(acquisitionCount == 0)
            #expect(throws: SourceContentSnapshotError.invalidated) {
                try prepared.sourceSnapshot.withBytes { $0 }
            }
        }
    }

    @Test func completedDuplicateAndEveryTransactionBlockHaveExplicitRoutes() async {
        let previous = PreviouslyImportedStatement(
            importSessionId: "prior-session",
            completedAtISO: "2026-07-29T00:00:00Z",
            transactionCount: 1,
            accountId: nil,
            accountDisplayName: nil
        )
        let cases: [(ImportPersistenceResult, ConfirmedImportRecoveryRoute)] = [
            (
                ImportPersistenceResult(
                    persisted: true,
                    workspaceId: "workspace",
                    accountId: "account",
                    importSessionId: "session",
                    transactionCount: 1
                ),
                .none
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    previousImport: previous
                ),
                .reviewRequired(.exactStatementDuplicate)
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    transactionEventBlock: .existing(count: 1)
                ),
                .reviewRequired(.transactionEventBlock)
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    transactionEventBlock: .repeatedIncoming(count: 1)
                ),
                .reviewRequired(.transactionEventBlock)
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    transactionEventBlock: .ownershipConflict
                ),
                .reviewRequired(.transactionEventBlock)
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    transactionEventBlock: .repositoryIntegrityConflict
                ),
                .reviewRequired(.repositoryIntegrityConflict)
            ),
            (
                ImportPersistenceResult(
                    persisted: true,
                    workspaceId: "workspace",
                    accountId: "account",
                    importSessionId: "session",
                    transactionCount: 1,
                    previousImport: previous
                ),
                .unavailable
            ),
            (
                ImportPersistenceResult(
                    persisted: true,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: "session",
                    transactionCount: 1,
                    accountOutcome: .choiceRequired
                ),
                .unavailable
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    previousImport: previous,
                    transactionEventBlock: .ownershipConflict
                ),
                .unavailable
            ),
            (
                ImportPersistenceResult(
                    persisted: false,
                    workspaceId: "workspace",
                    accountId: nil,
                    importSessionId: nil,
                    transactionCount: 1,
                    previousImport: previous,
                    accountOutcome: .staleAccountChoice
                ),
                .unavailable
            )
        ]

        for (persistenceResult, expectedRoute) in cases {
            let persistence = RecoveryPersistenceProbe(result: persistenceResult)
            let engine = ImportEngine(
                importPersistenceCoordinator: persistence,
                developerConsole: DeveloperConsole(),
                persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
                forcedHydration: { recoveryHydrationResult() },
                rejectedAttemptHydration: {}
            )
            let prepared = recoveryPreparedImport()

            let result = await engine.commitPreparedImport(prepared)

            #expect(result.recoveryRoute == expectedRoute)
            #expect(persistence.persistInvocationCount == 1)
            #expect(throws: SourceContentSnapshotError.invalidated) {
                try prepared.sourceSnapshot.withBytes { $0 }
            }
        }
    }

    @Test func validationSnapshotIntegrityInvalidContractAndHostileErrorsFailClosed() async {
        let validationPersistence = RecoveryPersistenceProbe(result: .skipped)
        let validationEngine = ImportEngine(
            importPersistenceCoordinator: validationPersistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
        let invalidValidation = ImportValidator.validate(transactions: [])
        let validationPrepared = recoveryPreparedImport(validation: invalidValidation)
        let validationResult = await validationEngine.commitPreparedImport(validationPrepared)

        #expect(validationResult.recoveryRoute == .reviewRequired(.validationFailed))
        #expect(validationPersistence.persistInvocationCount == 0)

        let integrityPersistence = RecoveryPersistenceProbe(result: .skipped)
        let integrityEngine = ImportEngine(
            importPersistenceCoordinator: integrityPersistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            rejectedAttemptHydration: {}
        )
        let integrityPrepared = recoveryPreparedImport()
        integrityPrepared.sourceSnapshot.invalidate()
        let integrityResult = await integrityEngine.commitPreparedImport(integrityPrepared)

        #expect(integrityResult.recoveryRoute == .prepareAgain(.sourceSnapshotIntegrityFailed))
        #expect(integrityPersistence.persistInvocationCount == 0)

        let contractPersistence = RecoveryPersistenceProbe(result: .skipped)
        let contractEngine = ImportEngine(
            importPersistenceCoordinator: contractPersistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
        let expectedRawFingerprint = ExactStatementFingerprint(text: "recovery")
        let structurallyValidMalformedSet = PreparedDocumentFingerprintSet(
            fingerprints: [
                VersionedDocumentFingerprint(
                    algorithm: expectedRawFingerprint.algorithm,
                    digest: expectedRawFingerprint.digest,
                    byteCount: expectedRawFingerprint.byteCount,
                    isDuplicateAuthority: true
                )
            ]
        )
        #expect(structurallyValidMalformedSet.isValid)
        for fingerprintSet in [
            PreparedDocumentFingerprintSet(fingerprints: []),
            structurallyValidMalformedSet
        ] {
            let contractPrepared = recoveryPreparedImport(fingerprintSet: fingerprintSet)
            let contractResult = await contractEngine.commitPreparedImport(contractPrepared)

            #expect(contractResult.recoveryRoute == .unavailable)
        }
        #expect(contractPersistence.persistInvocationCount == 0)

        let failClosedFailures: [(any Error, ImportAccountOutcome)] = [
            (ImportPersistenceCoordinationError.invalidFingerprint, .staleProviderGeneration),
            (ImportPersistenceCoordinationError.ineligibleIdentifierSet, .staleAccountChoice),
            (ImportPersistenceCoordinationError.unclassified, .choiceRequired),
            (ImportPersistenceCoordinationError.retryableContention, .matchedExisting),
            (HostileRecoveryError(errorDescription: "Persistence is busy. Retry confirmation."), .choiceRequired)
        ]
        for (error, accountOutcome) in failClosedFailures {
            let failClosedPersistence = RecoveryPersistenceProbe(
                error: ImportPersistenceCommitFailure(
                    originalError: error,
                    importAttemptId: "attempt-rejected",
                    accountOutcome: accountOutcome
                )
            )
            let failClosedEngine = ImportEngine(
                importPersistenceCoordinator: failClosedPersistence,
                developerConsole: DeveloperConsole(),
                persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
                rejectedAttemptHydration: {}
            )
            let failClosedPrepared = recoveryPreparedImport()

            let failClosedResult = await failClosedEngine.commitPreparedImport(failClosedPrepared)

            #expect(failClosedResult.recoveryRoute == .unavailable)
            #expect(failClosedPersistence.persistInvocationCount == 1)
        }

        for message in [
            ImportPersistenceCoordinationError.retryableContention.localizedDescription,
            ImportPersistenceCoordinationError.persistenceUnavailable.localizedDescription
        ] {
            let hostilePersistence = RecoveryPersistenceProbe(
                error: HostileRecoveryError(errorDescription: message)
            )
            let hostileEngine = ImportEngine(
                importPersistenceCoordinator: hostilePersistence,
                developerConsole: DeveloperConsole(),
                persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
            )
            let hostilePrepared = recoveryPreparedImport()

            let hostileResult = await hostileEngine.commitPreparedImport(hostilePrepared)

            #expect(hostileResult.errorMessage == "The confirmed import could not be completed.")
            #expect(!hostileResult.errorMessage!.contains(message))
            #expect(hostileResult.recoveryRoute == .unavailable)
            #expect(hostilePersistence.persistInvocationCount == 1)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func prepareAgainUsesOrdinaryURLPreparationWithFreshIdentityAndEvidence() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let sourceURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let sourceBytes = try Data(contentsOf: sourceURL)
        let failure = ImportPersistenceCommitFailure(
            originalError: ImportPersistenceCoordinationError.retryableContention,
            importAttemptId: "attempt-prepare-again",
            accountOutcome: .unavailable
        )
        let persistence = RecoveryPersistenceProbe(error: failure)
        var acquisitionCount = 0
        let engine = ImportEngine(
            sourceSnapshotAcquirer: { requestedURL in
                #expect(requestedURL == sourceURL)
                acquisitionCount += 1
                var bytes = sourceBytes
                if acquisitionCount > 1 {
                    bytes.append(contentsOf: Data("\n".utf8))
                }
                return SourceContentSnapshot(bytes: bytes)
            },
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { DatabaseProvider.shared.generationToken },
            forcedHydration: { recoveryHydrationResult() },
            rejectedAttemptHydration: {}
        )

        let consumed = try await engine.prepareImport(from: sourceURL)
        let consumedSnapshotID = consumed.sourceSnapshot.id
        let consumedSourceFingerprint = consumed.sourceSnapshot.sourceByteFingerprint
        let consumedFingerprintSet = consumed.fingerprintSet
        let failed = await engine.commitPreparedImport(
            consumed,
            accountChoice: .createNewAccount
        )

        #expect(failed.recoveryRoute == .prepareAgain(.persistenceContention))
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.receivedAccountChoices == [.createNewAccount])
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try consumed.sourceSnapshot.withBytes { $0 }
        }

        let presentation = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: failed.recoveryRoute
            )
        )
        let action = try #require(presentation.primaryAction)
        let executor = ConfirmedImportRecoveryActionExecutor()
        var freshPreparedImport: PreparedImport?
        let execution = await executor.execute(
            action,
            sourceURL: sourceURL,
            retryCanonicalReconciliation: { false },
            requestOrdinaryPreparation: { url in
                do {
                    freshPreparedImport = try await engine.prepareImport(from: url)
                    return true
                } catch {
                    Issue.record("Fresh ordinary preparation failed: \(error.localizedDescription)")
                    return false
                }
            }
        )
        let fresh = try #require(freshPreparedImport)

        #expect(execution == .preparationRequested)
        #expect(action == .prepareAgain)
        #expect(acquisitionCount == 2)
        #expect(fresh.id != consumed.id)
        #expect(fresh.sourceSnapshot.id != consumedSnapshotID)
        #expect(fresh.sourceSnapshot.sourceByteFingerprint != consumedSourceFingerprint)
        #expect(fresh.fingerprintSet != consumedFingerprintSet)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.receivedAccountChoices == [.createNewAccount])

        let explicitlyConfirmed = await engine.commitPreparedImport(
            fresh,
            accountChoice: nil
        )

        #expect(explicitlyConfirmed.recoveryRoute == .prepareAgain(.persistenceContention))
        #expect(persistence.persistInvocationCount == 2)
        #expect(persistence.receivedAccountChoices == [.createNewAccount, nil])
    }

    @Test func prepareAgainWithoutRetainedURLExposesNoActionOrPreparation() async throws {
        let presentation = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: .prepareAgain(.persistenceUnavailable)
            )
        )
        let executor = ConfirmedImportRecoveryActionExecutor()
        var reconciliationCount = 0
        var preparationCount = 0

        let execution = await executor.execute(
            .prepareAgain,
            sourceURL: nil,
            retryCanonicalReconciliation: {
                reconciliationCount += 1
                return true
            },
            requestOrdinaryPreparation: { _ in
                preparationCount += 1
                return true
            }
        )

        #expect(presentation.availablePrimaryAction(hasSourceURL: false) == nil)
        #expect(execution == .unavailable)
        #expect(reconciliationCount == 0)
        #expect(preparationCount == 0)
    }

    @Test func recoveryActionExecutorRejectsConcurrentDoubleInvocation() async {
        let executor = ConfirmedImportRecoveryActionExecutor()
        let probe = RecoveryActionConcurrencyProbe()
        let sourceURL = URL(fileURLWithPath: "/retained-source.csv")

        let first = Task { @MainActor in
            await executor.execute(
                .prepareAgain,
                sourceURL: sourceURL,
                retryCanonicalReconciliation: { false },
                requestOrdinaryPreparation: { _ in
                    await probe.beginAndWaitForRelease()
                    return true
                }
            )
        }
        await probe.waitUntilFirstRequestBegins()

        let second = await executor.execute(
            .prepareAgain,
            sourceURL: sourceURL,
            retryCanonicalReconciliation: { false },
            requestOrdinaryPreparation: { _ in
                await probe.beginAndWaitForRelease()
                return true
            }
        )
        await probe.releaseFirstRequest()
        let firstResult = await first.value
        let counts = await probe.counts()

        #expect(firstResult == .preparationRequested)
        #expect(second == .unavailable)
        #expect(counts.invocationCount == 1)
        #expect(counts.maximumActiveCount == 1)
    }

#if DEBUG
    @Test(.globalRuntimeStateIsolation)
    func prepareAgainPreservesDebugPreparationAcknowledgementBeforeSourceAccess() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let generation = ProviderGenerationToken()
        let gate = DevelopmentProfileAcknowledgementGate(
            stateProvider: {
                DevelopmentProfileAcknowledgementState(
                    providerGeneration: generation,
                    profileKind: .persistentDebug
                )
            }
        )
        var acquisitionCount = 0
        let engine = ImportEngine(
            sourceSnapshotAcquirer: { _ in
                acquisitionCount += 1
                throw SourceContentSnapshotError.acquisitionFailed
            },
            importPersistenceCoordinator: PreparationOnlyPersistenceCoordinator(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { generation },
            developmentProfileAcknowledgementGate: gate
        )
        let presentation = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: .prepareAgain(.staleProviderGeneration)
            )
        )
        let executor = ConfirmedImportRecoveryActionExecutor()
        let sourceURL = URL(fileURLWithPath: "/not-opened.csv")
        var acknowledgementRequired = false

        let execution = await executor.execute(
            try #require(
                presentation.availablePrimaryAction(hasSourceURL: true)
            ),
            sourceURL: sourceURL,
            retryCanonicalReconciliation: { false },
            requestOrdinaryPreparation: { url in
                do {
                    _ = try await engine.prepareImport(from: url)
                    Issue.record("Expected acknowledgement requirement")
                    return true
                } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired {
                    acknowledgementRequired = true
                    return false
                } catch {
                    Issue.record("Unexpected error: \(error.localizedDescription)")
                    return false
                }
            }
        )

        #expect(execution == .unavailable)
        #expect(acknowledgementRequired)
        #expect(acquisitionCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func directPreparationRequiresAcknowledgementBeforeSourceAcquisition() async {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let generation = ProviderGenerationToken()
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: generation,
            profileKind: .persistentDebug
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        var acquisitionCount = 0
        let engine = ImportEngine(
            sourceSnapshotAcquirer: { _ in
                acquisitionCount += 1
                throw SourceContentSnapshotError.acquisitionFailed
            },
            importPersistenceCoordinator: PreparationOnlyPersistenceCoordinator(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { generation },
            developmentProfileAcknowledgementGate: gate
        )

        do {
            _ = try await engine.prepareImport(from: URL(fileURLWithPath: "/not-opened.csv"))
            Issue.record("Expected acknowledgement requirement")
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired {
            // Expected typed, pre-I/O result.
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(acquisitionCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func directConfirmationRequiresFreshGenerationAcknowledgementWithoutConsumingPreview() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let firstGeneration = ProviderGenerationToken()
        var currentGeneration = firstGeneration
        var state = DevelopmentProfileAcknowledgementState(
            providerGeneration: firstGeneration,
            profileKind: .current
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let persistence = SupersessionPersistenceProbe()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { currentGeneration },
            developmentProfileAcknowledgementGate: gate
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        defer { engine.cancelPreparedImport(prepared) }

        let secondGeneration = ProviderGenerationToken()
        currentGeneration = secondGeneration
        state = DevelopmentProfileAcknowledgementState(
            providerGeneration: secondGeneration,
            profileKind: .temporarySession
        )

        let result = await engine.commitPreparedImport(prepared)

        #expect(result.developmentProtectedActionOutcome == .acknowledgementRequired)
        #expect(result.recoveryRoute == .unavailable)
        #expect(!result.persisted)
        #expect(persistence.persistInvocationCount == 0)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })
    }

    @Test(.globalRuntimeStateIsolation)
    func profileSwitchInvalidationConsumesPreparedImportBeforeProviderUseWithoutAuditWrite() async throws {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        let persistence = SupersessionPersistenceProbe()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { DatabaseProvider.shared.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(didHydrate: true, accountCount: 0, transactionCount: 0)
            },
            rejectedAttemptHydration: {}
        )
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )

        let barrier = DevelopmentDatabaseActivityGate.shared.beginProfileSwitch {
            engine.invalidatePreparedImportsForProfileSwitch($0)
        }
        guard case .acquired(let invalidation) = barrier else {
            Issue.record("Expected prepared import to drain into exclusive ownership")
            return
        }
        defer { DevelopmentDatabaseActivityGate.shared.finishExclusive(providerChanged: false) }

        #expect(invalidation.invalidatedCount == 1)
        #expect(!DevelopmentDatabaseActivityGate.shared.hasActiveOperations)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
        #expect(throws: DevelopmentDatabaseActivityError.self) {
            _ = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite)
        }

        let result = await engine.commitPreparedImport(prepared)

        #expect(result.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(result.recoveryRoute == .unavailable)
        #expect(!result.persisted)
        #expect(persistence.persistInvocationCount == 0)
        #expect(persistence.rejectionInvocationCount == 0)
    }
#endif
}

private actor ImportLifecycleCancellationProbe {
    private var firstOperationReady = false
    private var firstCancellationObserved = false
    private var firstOperationReadyContinuation: CheckedContinuation<Void, Never>?
    private var firstCancellationContinuation: CheckedContinuation<Void, Never>?

    func markFirstOperationReadyToObserveCancellation() {
        firstOperationReady = true
        firstOperationReadyContinuation?.resume()
        firstOperationReadyContinuation = nil
    }

    func waitForFirstOperationToBeReady() async {
        guard !firstOperationReady else { return }
        await withCheckedContinuation { continuation in
            firstOperationReadyContinuation = continuation
        }
    }

    func markFirstCancellationObserved() {
        firstCancellationObserved = true
        firstCancellationContinuation?.resume()
        firstCancellationContinuation = nil
    }

    func waitForFirstCancellation() async {
        guard !firstCancellationObserved else { return }
        await withCheckedContinuation { continuation in
            firstCancellationContinuation = continuation
        }
    }
}

private actor RecoveryActionConcurrencyProbe {
    private var invocationCount = 0
    private var activeCount = 0
    private var maximumActiveCount = 0
    private var firstRequestBegan = false
    private var released = false
    private var firstRequestContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func beginAndWaitForRelease() async {
        invocationCount += 1
        activeCount += 1
        maximumActiveCount = max(maximumActiveCount, activeCount)
        firstRequestBegan = true
        firstRequestContinuation?.resume()
        firstRequestContinuation = nil

        if !released {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        activeCount -= 1
    }

    func waitUntilFirstRequestBegins() async {
        guard !firstRequestBegan else { return }
        await withCheckedContinuation { continuation in
            firstRequestContinuation = continuation
        }
    }

    func releaseFirstRequest() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func counts() -> (invocationCount: Int, maximumActiveCount: Int) {
        (invocationCount, maximumActiveCount)
    }
}

private final class PreparationOnlyPersistenceCoordinator: ImportPersistenceCoordinating {
    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }
}

private final class SupersessionPersistenceProbe: ImportPersistenceCoordinating {
    private(set) var persistInvocationCount = 0
    private(set) var rejectionInvocationCount = 0

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        persistInvocationCount += 1
        return ImportPersistenceResult(
            persisted: true,
            workspaceId: "workspace",
            accountId: "account",
            importSessionId: importSession.id.uuidString,
            transactionCount: financialDocument.transactions.count
        )
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }

    func recordSourceSnapshotRejection(_ kind: SourceSnapshotRejectionKind) -> SourceSnapshotRejectionRecord {
        rejectionInvocationCount += 1
        return .auditWriteUnavailable
    }
}

private struct HostileRecoveryError: LocalizedError {
    let errorDescription: String?
}

private final class RecoveryPersistenceProbe: ImportPersistenceCoordinating {
    private let operation: () throws -> ImportPersistenceResult
    private(set) var persistInvocationCount = 0
    private(set) var receivedAccountChoices: [ImportAccountChoice?] = []

    init(result: ImportPersistenceResult) {
        self.operation = { result }
    }

    init(error: any Error) {
        self.operation = { throw error }
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        persistInvocationCount += 1
        return try operation()
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        persistInvocationCount += 1
        receivedAccountChoices.append(accountChoice)
        return try operation()
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }
}

private func recoveryPreparedImport(
    validation suppliedValidation: ImportValidationResult? = nil,
    fingerprintSet: PreparedDocumentFingerprintSet? = nil
) -> PreparedImport {
    let transaction = Transaction(
        statementDate: try! StatementDate(canonical: "2027-03-13"),
        description: "Recovery fixture",
        debit: nil,
        credit: 10,
        amount: 10,
        balance: 10,
        currency: "INR",
        account: "Fixture",
        sourceBank: "Fixture",
        sourceFile: "recovery.csv",
        statementTimezoneEvidence: .iana("Asia/Kolkata"),
        sourceProvenance: [
            TransactionSourceProvenance(
                normalizedDocumentID: "recovery-normalized-document",
                normalizedRowID: "recovery-normalized-row-1",
                sourceOrdinal: 1,
                normalizedRecordDigest: String.normalizedRecordDigest(values: ["recovery", "1"]),
                parserProfileID: AxisBankAccountParser.profileID,
                parserProfileVersion: AxisBankAccountParser.profileVersion
            )
        ]
    )
    let document = FinancialDocument(
        sourceDocument: Document(
            filename: "recovery.csv",
            url: URL(fileURLWithPath: "/tmp/recovery.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_804_896_000)
        ),
        metadata: DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1
        ),
        parserName: "Recovery fixture",
        bookedCurrency: try! CurrencyCode("INR"),
        transactions: [transaction],
        selectionReasons: ["Fixture"],
        createdAt: Date(timeIntervalSince1970: 1_804_896_000)
    )
    let validation = suppliedValidation ?? ImportValidator.validate(financialDocument: document)
    let session = ImportSession(
        fileName: "recovery.csv",
        institution: .axis,
        documentType: .bankAccount,
        parserName: "Recovery fixture",
        transactionCount: 1,
        validation: validation
    )
    return PreparedImport(
        sourceURL: document.sourceDocument.url,
        rawContents: "recovery",
        fileName: "recovery.csv",
        detectedInstitution: .axis,
        detectedDocumentType: .bankAccount,
        parserName: "Recovery fixture",
        financialDocument: document,
        validation: validation,
        importSession: session,
        fingerprintSet: fingerprintSet
    )
}

private func recoveryHydrationResult() -> RepositoryStoreHydrationResult {
    RepositoryStoreHydrationResult(
        didHydrate: true,
        accountCount: 1,
        transactionCount: 1,
        importSessionCount: 1,
        importAttemptCount: 1
    )
}
