import Testing
@testable import LedgerForge

#if DEBUG
@Suite("Developer database profile presentation")
@MainActor
struct DeveloperDatabaseProfilePresentationTests {
    @Test
    func currentHasNoWarningOrResetControl() {
        let profile = descriptor(kind: .current)
        #expect(DeveloperDatabaseProfileWarningPresentation(profile: profile) == nil)
        #expect(profile.resetActionLabel == nil)
    }

    @Test(arguments: [
        DevelopmentDatabaseProfileKind.persistentDebug,
        .temporarySession,
        .migrationSandbox
    ])
    func everyNonCurrentProfileHasBoundedWarning(_ kind: DevelopmentDatabaseProfileKind) {
        let profile = descriptor(kind: kind, sourceVersion: kind == .migrationSandbox ? 3 : nil)
        let presentation = DeveloperDatabaseProfileWarningPresentation(profile: profile)

        #expect(presentation != nil)
        #expect(presentation?.title.contains(profile.displayName) == true)
        #expect(presentation?.currentSchema == "Current schema V16")
        #expect(kind == .migrationSandbox
            ? presentation?.sourceSchema == "Source schema V3"
            : presentation?.sourceSchema == nil)

        let text = [
            presentation?.title,
            presentation?.detail,
            presentation?.sourceSchema,
            presentation?.currentSchema,
            presentation?.accessibilityLabel
        ].compactMap { $0 }.joined(separator: " ")
        #expect(!text.contains("/"))
        #expect(!text.lowercased().contains("sqlite"))
        #expect(!text.lowercased().contains("uuid"))
        #expect(!text.lowercased().contains("token"))
    }

    @Test
    func controlsExposeExactSafeLabelsAndHistoricalVersions() {
        #expect(DevelopmentDatabaseProfileKind.allCases.map(\.displayName) == [
            "Current Database",
            "Persistent Debug Database",
            "Temporary Session",
            "Migration Sandbox"
        ])
        #expect(DevelopmentDatabaseProfile.registeredHistoricalSourceVersions == Array(1...15))
        #expect(descriptor(kind: .persistentDebug).resetActionLabel == "Reset Debug Database")
        #expect(descriptor(kind: .temporarySession).resetActionLabel == "Start Fresh Temporary Session")
        #expect(descriptor(kind: .migrationSandbox, sourceVersion: 8).resetActionLabel == "Recreate Sandbox from selected source version")
        #expect(descriptor(kind: .migrationSandbox, sourceVersion: 8).sourceSchemaLabel == "V8")
        #expect(descriptor(kind: .migrationSandbox, sourceVersion: 14).currentSchemaLabel == "V16")
    }

    private func descriptor(
        kind: DevelopmentDatabaseProfileKind,
        sourceVersion: Int? = nil
    ) -> DevelopmentDatabaseProfileDescriptor {
        let persistenceClassification: DevelopmentDatabaseProfilePersistenceClassification
        switch kind {
        case .current: persistenceClassification = .stableCurrent
        case .persistentDebug: persistenceClassification = .stableDevelopment
        case .temporarySession: persistenceClassification = .processOwnedTemporary
        case .migrationSandbox: persistenceClassification = .processOwnedMigrationSandbox
        }
        return DevelopmentDatabaseProfileDescriptor(
            kind: kind,
            displayName: kind.displayName,
            persistenceClassification: persistenceClassification,
            canReset: kind != .current,
            migrationSourceVersion: sourceVersion,
            verifiedCurrentSchemaVersion: 16
        )
    }
}
#endif
