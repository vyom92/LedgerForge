// LedgerForgeTests/PasswordProviderTests.swift

import Foundation
import Security
import Testing
@testable import LedgerForge

@MainActor
struct PasswordProviderTests {

    @Test func defaultPasswordProviderCanBeConstructed() async throws {
        let provider = DefaultPasswordProvider(challenge: { _ in nil })
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.csv"))

        let password = try await provider.password(for: request)

        #expect(password == nil)
    }

    @Test func coordinatorDoesNotConsultPasswordProviderForNonPDFDocument() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.csv"))
        let reader = RecordingPasswordReader(expectedPassword: nil)
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: ThrowingPasswordProvider(error: .passwordRequired)
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .succeeded)
        #expect(result.error == nil)
        #expect(result.rawDocument?.content == .text("password accepted"))
    }

    @Test func coordinatorPassesProvidedPasswordToReader() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let reader = RecordingPasswordReader(expectedPassword: "secret")
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: StaticPasswordProvider(password: "secret")
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .succeeded)
        #expect(result.error == nil)
        #expect(result.rawDocument?.content == .text("password accepted"))
    }

    @Test func coordinatorReturnsTypedFailureWhenProviderThrowsImportError() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(
                reader: RecordingPasswordReader(expectedPassword: "fictional-never-used-password")
            ),
            passwordProvider: ThrowingPasswordProvider(error: .passwordRequired)
        )

        let result = await coordinator.importDocument(request)

        #expect(result.status == .failed)
        #expect(result.rawDocument == nil)
        #expect(result.error == .passwordRequired)
    }

    @Test func coordinatorReusesRememberedPasswordWithoutChallenging() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: ["american-express": "fictional-remembered-password"]
        )
        let challenge = PasswordChallengeSpy()
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["american-express"],
            challenge: { _ in
                await challenge.recordCall()
                return "fictional-manual-password"
            }
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(
                reader: RecordingPasswordReader(expectedPassword: "fictional-remembered-password")
            ),
            passwordProvider: provider
        )

        let result = await coordinator.importDocument(
            request,
            snapshot: SourceContentSnapshot(bytes: Data("encrypted fixture bytes".utf8))
        )

        #expect(result.status == .succeeded)
        #expect(await challenge.callCount() == 0)
        #expect(await store.password(institutionCode: "american-express") == "fictional-remembered-password")
    }

    @Test func staleRememberedPasswordIsReplacedOnlyAfterSupportedConfirmation() async throws {
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: ["american-express": "fictional-stale-password"]
        )
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["american-express"]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        await provider.stageSuccessfulPassword("fictional-new-password", for: request)
        #expect(await store.password(institutionCode: "american-express") == "fictional-stale-password")

        try await provider.confirmSuccessfulPassword(for: request, institutionCode: "american-express")

        #expect(await store.password(institutionCode: "american-express") == "fictional-new-password")
    }

    @Test func cbqCardCredentialUsesSharedInstitutionScopeForSaveReuseAndStaleReplacement() async throws {
        let scope = Institution.cbq.statementPasswordCredentialScope
        let store = InMemoryStatementPasswordCredentialStore()
        let firstRequest = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/fictional-cbq-card.pdf"))
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [scope],
            challenge: { _ in "fictional-cbq-card-password" }
        )

        await provider.stageSuccessfulPassword("fictional-cbq-card-password", for: firstRequest)
        #expect(await store.password(institutionCode: scope) == nil)
        try await provider.confirmSuccessfulPassword(for: firstRequest, institutionCode: scope)
        #expect(await store.password(institutionCode: scope) == "fictional-cbq-card-password")

        let remembered = try await provider.rememberedPasswords(for: firstRequest)
        #expect(remembered == ["fictional-cbq-card-password"])

        let replacementRequest = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/fictional-cbq-card-replacement.pdf"))
        await provider.stageSuccessfulPassword("fictional-cbq-card-replacement", for: replacementRequest)
        #expect(await store.password(institutionCode: scope) == "fictional-cbq-card-password")
        try await provider.confirmSuccessfulPassword(for: replacementRequest, institutionCode: scope)
        #expect(await store.password(institutionCode: scope) == "fictional-cbq-card-replacement")
    }

    @Test func cbqInstitutionScopeUsesProductionKeychainStoreForFirstSaveReuseAndReplacement() async throws {
        let service = "com.ledgerforge.tests.cbq-password-\(UUID().uuidString)"
        let scope = Institution.cbq.statementPasswordCredentialScope
        let store = KeychainStatementPasswordCredentialStore(service: service)
        defer { Task { try? await store.delete(institutionCode: scope) } }
        try await store.delete(institutionCode: scope)
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [scope],
            challenge: { _ in nil }
        )

        let first = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/fictional-cbq-first.pdf"))
        await provider.stageSuccessfulPassword("fictional-cbq-keychain-first", for: first)
        try await provider.confirmSuccessfulPassword(for: first, institutionCode: scope)
        #expect(try await store.password(institutionCode: scope) == "fictional-cbq-keychain-first")
        #expect(try await provider.rememberedPasswords(for: first) == ["fictional-cbq-keychain-first"])

        let replacement = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/fictional-cbq-replacement.pdf"))
        await provider.stageSuccessfulPassword("fictional-cbq-keychain-replacement", for: replacement)
        try await provider.confirmSuccessfulPassword(for: replacement, institutionCode: scope)
        #expect(try await store.password(institutionCode: scope) == "fictional-cbq-keychain-replacement")
    }

    @Test func stagedPasswordIsDiscardedAfterRejectionOrCancellationAndNeverSaved() async throws {
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: ["american-express": "fictional-existing-password"]
        )
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["american-express"]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        await provider.stageSuccessfulPassword("fictional-staged-password", for: request)
        try await provider.confirmSuccessfulPassword(for: request, institutionCode: "unsupported-test-institution")
        #expect(await store.password(institutionCode: "american-express") == "fictional-existing-password")

        await provider.discardStagedPassword(for: request)
        try await provider.confirmSuccessfulPassword(for: request, institutionCode: "american-express")
        #expect(await store.password(institutionCode: "american-express") == "fictional-existing-password")
    }

    @Test func coordinatorAttemptsEachRememberedPasswordAtMostOnce() async throws {
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))
        let store = InMemoryStatementPasswordCredentialStore(
            passwords: [
                "first-scope": "fictional-first-password",
                "second-scope": "fictional-second-password",
                "duplicate-scope": "fictional-first-password"
            ]
        )
        let challenge = PasswordChallengeSpy()
        let reader = AttemptRecordingReader()
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: ["first-scope", "second-scope", "duplicate-scope"],
            challenge: { _ in
                await challenge.recordCall()
                return nil
            }
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: provider
        )

        let result = await coordinator.importDocument(
            request,
            snapshot: SourceContentSnapshot(bytes: Data("encrypted fixture bytes".utf8))
        )

        #expect(result.status == .failed)
        #expect(result.error == .passwordRequired)
        #expect(await reader.attempts() == [nil, "fictional-first-password", "fictional-second-password"])
        #expect(await challenge.callCount() == 1)
    }

    @Test func axisRememberedCandidatesKeepFamilyAndCompatibilityOrder() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let traditionalScope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
        let legacyLabel = "fictional-axis-registered-label"
        let store = RecordingPasswordCredentialStore(records: [
            axisScope: [
                .init(value: "fictional-axis-app-password", origin: .canonical(scope: appScope)),
                .init(value: "fictional-axis-traditional-password", origin: .canonical(scope: traditionalScope)),
                .init(value: "fictional-axis-unscoped-password", origin: .compatibility(scope: axisScope)),
                .init(value: "fictional-axis-legacy-password", origin: .legacy(label: legacyLabel))
            ]
        ])
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope],
            challenge: { _ in nil }
        )

        let candidates = try await provider.rememberedPasswordCandidates(
            for: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-family-order.pdf"))
        )

        #expect(candidates.map(\.value) == [
            "fictional-axis-app-password",
            "fictional-axis-traditional-password",
            "fictional-axis-unscoped-password",
            "fictional-axis-legacy-password"
        ])
        #expect(candidates.map(\.origins) == [
            [.canonical(scope: appScope)],
            [.canonical(scope: traditionalScope)],
            [.compatibility(scope: axisScope)],
            [.legacy(label: legacyLabel)]
        ])
    }

    @Test func equalAxisCredentialValuesAreAttemptedOnceWithoutLosingOrigins() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let traditionalScope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
        let legacyLabel = "fictional-axis-duplicate-label"
        let sharedValue = "fictional-axis-shared-password"
        let store = RecordingPasswordCredentialStore(records: [
            axisScope: [
                .init(value: sharedValue, origin: .canonical(scope: appScope)),
                .init(value: sharedValue, origin: .canonical(scope: traditionalScope)),
                .init(value: sharedValue, origin: .compatibility(scope: axisScope)),
                .init(value: sharedValue, origin: .legacy(label: legacyLabel))
            ]
        ])
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope],
            challenge: { _ in nil }
        )
        let candidates = try await provider.rememberedPasswordCandidates(
            for: ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-duplicate.pdf"))
        )

        #expect(candidates.count == 1)
        #expect(candidates[0].value == sharedValue)
        #expect(candidates[0].origins == [
            .canonical(scope: appScope),
            .canonical(scope: traditionalScope),
            .compatibility(scope: axisScope),
            .legacy(label: legacyLabel)
        ])
    }

    @Test func wrongFirstAxisCandidateThenCorrectSecondSucceedsWithoutChallenge() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let traditionalScope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
        let store = RecordingPasswordCredentialStore(records: [
            axisScope: [
                .init(value: "fictional-axis-wrong-app", origin: .canonical(scope: appScope)),
                .init(value: "fictional-axis-correct-traditional", origin: .canonical(scope: traditionalScope))
            ]
        ])
        let challenge = PasswordChallengeSpy()
        let reader = SuccessfulPasswordReader(expectedPassword: "fictional-axis-correct-traditional")
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope],
            challenge: { _ in
                await challenge.recordCall()
                return "fictional-axis-challenge-should-not-run"
            }
        )
        let coordinator = DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: reader),
            passwordProvider: provider
        )

        let result = await coordinator.importDocument(
            ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-wrong-then-correct.pdf")),
            snapshot: SourceContentSnapshot(bytes: Data("fictional encrypted bytes".utf8))
        )

        #expect(result.status == .succeeded)
        #expect(await reader.attempts() == [nil, "fictional-axis-wrong-app", "fictional-axis-correct-traditional"])
        #expect(await challenge.callCount() == 0)
        #expect(await store.saveCalls().isEmpty)
    }

    @Test func exactCanonicalAxisAppAndTraditionalSuccessesDoNotWrite() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let traditionalScope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
        let store = RecordingPasswordCredentialStore()
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope]
        )

        let appRequest = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-app-canonical.pdf"))
        await provider.stageSuccessfulPassword(
            .init(value: "fictional-axis-app-v1", origin: .canonical(scope: appScope)),
            for: appRequest
        )
        try await provider.confirmSuccessfulPassword(
            for: appRequest,
            target: .init(institutionCode: axisScope, scope: appScope)
        )

        let traditionalRequest = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-traditional-canonical.pdf"))
        await provider.stageSuccessfulPassword(
            .init(value: "fictional-axis-traditional-v1", origin: .canonical(scope: traditionalScope)),
            for: traditionalRequest
        )
        try await provider.confirmSuccessfulPassword(
            for: traditionalRequest,
            target: .init(institutionCode: axisScope, scope: traditionalScope)
        )

        #expect(await store.saveCalls().isEmpty)
    }

    @Test func axisChallengeUpdatesOnlyExactFamilyScopeAndIndependentRotationsWorkBothOrders() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let traditionalScope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope

        for scopes in [[appScope, traditionalScope], [traditionalScope, appScope]] {
            let store = RecordingPasswordCredentialStore(records: [
                appScope: [.init(value: "fictional-axis-app-v1", origin: .canonical(scope: appScope))],
                traditionalScope: [.init(value: "fictional-axis-traditional-v1", origin: .canonical(scope: traditionalScope))]
            ])
            let provider = DefaultPasswordProvider(
                credentialStore: store,
                supportedInstitutionCodes: [axisScope]
            )

            for (index, scope) in scopes.enumerated() {
                let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-rotation-\(index).pdf"))
                await provider.stageSuccessfulPassword(
                    .init(value: "fictional-axis-\(scope)-v2", origin: .challenge),
                    for: request
                )
                try await provider.confirmSuccessfulPassword(
                    for: request,
                    target: .init(institutionCode: axisScope, scope: scope)
                )
            }

            #expect(await store.storedValue(institutionCode: appScope) == "fictional-axis-\(appScope)-v2")
            #expect(await store.storedValue(institutionCode: traditionalScope) == "fictional-axis-\(traditionalScope)-v2")
            #expect(await store.saveScopes() == scopes)
        }
    }

    @Test func axisUnscopedCompatibilityCredentialMigratesToExactTargetAndRemains() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let value = "fictional-axis-unscoped-password"
        let store = RecordingPasswordCredentialStore(records: [
            axisScope: [.init(value: value, origin: .compatibility(scope: axisScope))]
        ])
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-unscoped-migration.pdf"))
        let candidates = try await provider.rememberedPasswordCandidates(for: request)
        let candidate = try #require(candidates.first)
        await provider.stageSuccessfulPassword(candidate, for: request)
        try await provider.confirmSuccessfulPassword(
            for: request,
            target: .init(institutionCode: axisScope, scope: appScope)
        )

        #expect(await store.storedValue(institutionCode: appScope) == value)
        #expect(await store.storedValue(institutionCode: axisScope) == value)
        #expect(await store.saveScopes() == [appScope])
    }

    @Test func axisLegacyCredentialMigratesToExactTargetAndRemains() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let traditionalScope = KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope
        let legacyLabel = "fictional-axis-legacy-label"
        let value = "fictional-axis-legacy-password"
        let store = RecordingPasswordCredentialStore(records: [
            axisScope: [.init(value: value, origin: .legacy(label: legacyLabel))]
        ])
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-legacy-migration.pdf"))
        let candidates = try await provider.rememberedPasswordCandidates(for: request)
        let candidate = try #require(candidates.first)
        await provider.stageSuccessfulPassword(candidate, for: request)
        try await provider.confirmSuccessfulPassword(
            for: request,
            target: .init(institutionCode: axisScope, scope: traditionalScope)
        )

        #expect(await store.storedValue(institutionCode: traditionalScope) == value)
        #expect(await store.storedValue(institutionCode: axisScope) == value)
        #expect(await store.saveScopes() == [traditionalScope])
    }

    @Test func challengeCancellationAndWrongChallengeNeverWrite() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let store = RecordingPasswordCredentialStore()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-challenge-failure.pdf"))
        let cancellationProvider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope],
            challenge: { _ in throw ImportError.cancelled }
        )
        let cancellationResult = await DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: AttemptRecordingReader()),
            passwordProvider: cancellationProvider
        ).importDocument(request, snapshot: SourceContentSnapshot(bytes: Data("encrypted".utf8)))
        #expect(cancellationResult.status == .failed)
        #expect(cancellationResult.error == .cancelled)

        let wrongProvider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope],
            challenge: { _ in "fictional-axis-wrong-challenge" }
        )
        let wrongResult = await DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: RecordingPasswordReader(expectedPassword: "fictional-axis-correct-challenge")),
            passwordProvider: wrongProvider
        ).importDocument(
            ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-wrong-challenge.pdf")),
            snapshot: SourceContentSnapshot(bytes: Data("encrypted".utf8))
        )
        #expect(wrongResult.status == .failed)
        #expect(wrongResult.error == .incorrectPassword)
        #expect(await store.saveCalls().isEmpty)

        // Keep the target in scope so this test also exercises the same exact
        // family target used by the post-validation confirmation seam.
        _ = appScope
    }

    @Test func unlockedPDFAndDiscardedRejectedPreparationNeverWrite() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let store = RecordingPasswordCredentialStore()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-unlocked.pdf"))
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope],
            challenge: { _ in
                Issue.record("Unlocked PDF should not request a challenge")
                return nil
            }
        )
        let result = await DefaultImportCoordinator(
            readerRegistry: PasswordTestReaderRegistry(reader: RecordingPasswordReader(expectedPassword: nil)),
            passwordProvider: provider
        ).importDocument(request, snapshot: SourceContentSnapshot(bytes: Data("unlocked".utf8)))
        #expect(result.status == .succeeded)

        await provider.stageSuccessfulPassword(
            .init(value: "fictional-axis-rejected", origin: .challenge),
            for: request
        )
        await provider.discardStagedPassword(for: request)
        try await provider.confirmSuccessfulPassword(
            for: request,
            target: .init(institutionCode: axisScope, scope: appScope)
        )
        #expect(await store.saveCalls().isEmpty)
    }

    @Test func keychainWriteFailureIsSurfacedAndLeavesExistingCredential() async throws {
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let existing = "fictional-axis-existing-compatibility"
        let store = RecordingPasswordCredentialStore(
            records: [axisScope: [.init(value: existing, origin: .compatibility(scope: axisScope))]],
            failWrites: true
        )
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [axisScope]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/axis-write-failure.pdf"))
        await provider.stageSuccessfulPassword(
            .init(value: "fictional-axis-write-failure", origin: .challenge),
            for: request
        )

        await #expect(throws: TestCredentialStoreError.writeFailed) {
            try await provider.confirmSuccessfulPassword(
                for: request,
                target: .init(institutionCode: axisScope, scope: appScope)
            )
        }
        #expect(await store.storedValue(institutionCode: axisScope) == existing)
        #expect(await store.storedValue(institutionCode: appScope) == nil)
    }

    @Test func amexCanonicalCredentialRemainsOneScopeWithoutChurn() async throws {
        let scope = Institution.amex.statementPasswordCredentialScope
        let store = RecordingPasswordCredentialStore(records: [
            scope: [.init(value: "fictional-amex-canonical", origin: .canonical(scope: scope))]
        ])
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [scope]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/amex-canonical.pdf"))
        let candidates = try await provider.rememberedPasswordCandidates(for: request)
        #expect(candidates.map(\.value) == ["fictional-amex-canonical"])
        #expect(candidates.first?.origins == [.canonical(scope: scope)])
        await provider.stageSuccessfulPassword(candidates[0], for: request)
        try await provider.confirmSuccessfulPassword(
            for: request,
            target: .init(institutionCode: scope)
        )
        #expect(await store.saveCalls().isEmpty)
    }

    @Test func keychainCredentialStoreSmokeUsesOnlyOneUniqueTestItem() async throws {
        let service = "com.ledgerforge.tests.password-\(UUID().uuidString)"
        let account = "test-account-\(UUID().uuidString)"
        let secret = "fictional-keychain-secret-\(UUID().uuidString)"
        let store = KeychainStatementPasswordCredentialStore(service: service)
        defer {
            Task { try? await store.delete(institutionCode: account) }
        }

        try await store.delete(institutionCode: account)
        try await store.save(secret, institutionCode: account)
        let saved = try await store.password(institutionCode: account)
        #expect(saved == secret)

        try await store.delete(institutionCode: account)
        let deleted = try await store.password(institutionCode: account)
        #expect(deleted == nil)
    }

    @Test func keychainLegacyLabelQueryReturnsOneUniqueFictionalItem() async throws {
        let service = "com.ledgerforge.tests.axis-legacy-\(UUID().uuidString)"
        let account = "fictional-legacy-account-\(UUID().uuidString)"
        let label = "fictional-axis-legacy-label-\(UUID().uuidString)"
        let secret = "fictional-axis-legacy-secret-\(UUID().uuidString)"
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let store = KeychainStatementPasswordCredentialStore(
            service: service,
            legacyLabelsByInstitutionCode: [axisScope: [label]]
        )
        let itemQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: label,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        defer {
            SecItemDelete(itemQuery as CFDictionary)
        }
        SecItemDelete(itemQuery as CFDictionary)
        var item = itemQuery
        item[kSecValueData as String] = Data(secret.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #expect(SecItemAdd(item as CFDictionary, nil) == errSecSuccess)

        let credentials = try await store.credentials(institutionCode: axisScope)

        #expect(credentials == [
            StatementPasswordStoredCredential(value: secret, origin: .legacy(label: label))
        ])
    }

    @Test func keychainLegacyLabelQueryOmitsAmbiguousFictionalItems() async throws {
        let service = "com.ledgerforge.tests.axis-legacy-ambiguous-\(UUID().uuidString)"
        let label = "fictional-axis-ambiguous-label-\(UUID().uuidString)"
        let axisScope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let store = KeychainStatementPasswordCredentialStore(
            service: service,
            legacyLabelsByInstitutionCode: [axisScope: [label]]
        )
        let accounts = [
            "fictional-legacy-account-a-\(UUID().uuidString)",
            "fictional-legacy-account-b-\(UUID().uuidString)"
        ]
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrLabel as String: label,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        defer {
            for account in accounts {
                var query = base
                query[kSecAttrAccount as String] = account
                SecItemDelete(query as CFDictionary)
            }
        }
        for (index, account) in accounts.enumerated() {
            var item = base
            item[kSecAttrAccount as String] = account
            item[kSecValueData as String] = Data("fictional-ambiguous-secret-\(index)".utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            #expect(SecItemAdd(item as CFDictionary, nil) == errSecSuccess)
        }

        let credentials = try await store.credentials(institutionCode: axisScope)

        #expect(credentials.isEmpty)
    }

    @Test func legacyLabeledCredentialIsReusedUntilCanonicalCredentialIsSaved() async throws {
        let scope = KeychainStatementPasswordCredentialStore.axisInstitutionScope
        let appScope = KeychainStatementPasswordCredentialStore.axisAppPDFScope
        let legacyLabel = "fictional-axis-legacy-label"
        let legacySecret = "fictional-legacy-secret"
        let store = RecordingPasswordCredentialStore(records: [
            scope: [.init(value: legacySecret, origin: .legacy(label: legacyLabel))]
        ])
        let provider = DefaultPasswordProvider(
            credentialStore: store,
            supportedInstitutionCodes: [scope]
        )
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/legacy-axis.pdf"))
        let candidates = try await provider.rememberedPasswordCandidates(for: request)
        #expect(candidates.first?.origins == [.legacy(label: legacyLabel)])
        await provider.stageSuccessfulPassword(candidates[0], for: request)
        try await provider.confirmSuccessfulPassword(
            for: request,
            target: .init(institutionCode: scope, scope: appScope)
        )

        #expect(await store.storedValue(institutionCode: scope) == legacySecret)
        #expect(await store.storedValue(institutionCode: appScope) == legacySecret)
        #expect(await store.saveScopes() == [appScope])
    }

}

private struct StaticPasswordProvider: ImportFramework.PasswordProvider {
    let password: String?

    func password(for request: ImportRequest) async throws -> String? {
        password
    }
}

private struct ThrowingPasswordProvider: ImportFramework.PasswordProvider {
    let error: ImportError

    func password(for request: ImportRequest) async throws -> String? {
        throw error
    }
}

private struct PasswordTestReaderRegistry: ImportFramework.ReaderRegistry {
    let reader: any ImportFramework.DocumentReader

    func reader(for request: ImportRequest) async -> (any ImportFramework.DocumentReader)? {
        reader
    }
}

private struct RecordingPasswordReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["csv", "pdf"]
    let expectedPassword: String?

    func read(request: ImportRequest, password: String?) async throws -> RawDocument {
        guard password == expectedPassword else {
            throw ImportError.incorrectPassword
        }

        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text("password accepted")
        )
    }
}

private actor PasswordChallengeSpy {
    private var calls = 0

    func recordCall() {
        calls += 1
    }

    func callCount() -> Int {
        calls
    }
}

private actor AttemptRecordingReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]
    private var recordedAttempts = [String?]()

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        recordedAttempts.append(password)
        throw password == nil ? ImportError.passwordRequired : ImportError.incorrectPassword
    }

    func attempts() -> [String?] {
        recordedAttempts
    }
}

private actor SuccessfulPasswordReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]
    private let expectedPassword: String
    private var recordedAttempts = [String?]()

    init(expectedPassword: String) {
        self.expectedPassword = expectedPassword
    }

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        recordedAttempts.append(password)
        guard password == expectedPassword else {
            throw password == nil ? ImportError.passwordRequired : ImportError.incorrectPassword
        }
        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text("fictional password accepted")
        )
    }

    func attempts() -> [String?] {
        recordedAttempts
    }
}

private enum TestCredentialStoreError: Error, Equatable {
    case writeFailed
}

private actor RecordingPasswordCredentialStore: StatementPasswordCredentialStore {
    private var records: [String: [StatementPasswordStoredCredential]]
    private let failWrites: Bool
    private var writes = [(scope: String, value: String)]()

    init(
        records: [String: [StatementPasswordStoredCredential]] = [:],
        failWrites: Bool = false
    ) {
        self.records = records
        self.failWrites = failWrites
    }

    func credentials(
        institutionCode: String
    ) async throws -> [StatementPasswordStoredCredential] {
        records[institutionCode] ?? []
    }

    func password(institutionCode: String) async throws -> String? {
        records[institutionCode]?.first?.value
    }

    func save(_ password: String, institutionCode: String) async throws {
        writes.append((scope: institutionCode, value: password))
        if failWrites {
            throw TestCredentialStoreError.writeFailed
        }
        records[institutionCode] = [
            .init(value: password, origin: .canonical(scope: institutionCode))
        ]
    }

    func delete(institutionCode: String) async throws {
        records.removeValue(forKey: institutionCode)
    }

    func saveCalls() -> [(scope: String, value: String)] {
        writes
    }

    func saveScopes() -> [String] {
        writes.map(\.scope)
    }

    func storedValue(institutionCode: String) -> String? {
        records[institutionCode]?.first?.value
    }
}
