// LedgerForge
// DebugImportVerificationWorkspaceView.swift
// Sprint 58 DEBUG-only approved-fixture verification workspace.

#if DEBUG
import Foundation
import SwiftUI

enum DebugApprovedFixtureID: String, CaseIterable, Identifiable {
    case axisNRESourceDerived = "axis-nre-source-derived"
    case axisNROSourceFaithful = "axis-nro-source-faithful"

    var id: String { rawValue }
}

struct DebugApprovedFixture: Identifiable, Equatable {
    let id: DebugApprovedFixtureID
    let title: String
    let institution: String
    let documentFamily: String
    let format: String
    let sanitization: String
    let resourceName: String

    var provenanceSummary: String {
        "\(institution) · \(documentFamily) · \(format) · \(sanitization)"
    }
}

enum DebugImportFixtureCatalogError: Error, Equatable, LocalizedError {
    case missingApprovedResource

    var errorDescription: String? {
        "The selected approved fixture is unavailable. No import was started."
    }
}

enum DebugImportFixtureCatalog {
    static let all: [DebugApprovedFixture] = [
        DebugApprovedFixture(
            id: .axisNRESourceDerived,
            title: "Axis NRE bank-account CSV",
            institution: "Axis Bank",
            documentFamily: "NRE bank-account statement",
            format: "CSV",
            sanitization: "sanitized source-derived evidence",
            resourceName: "axis_bank_nre_private_source_semantics.csv"
        ),
        DebugApprovedFixture(
            id: .axisNROSourceFaithful,
            title: "Axis NRO bank-account CSV",
            institution: "Axis Bank",
            documentFamily: "NRO bank-account statement",
            format: "CSV",
            sanitization: "sanitized source-faithful evidence",
            resourceName: "axis_bank_nro_account_statement_baseline_csv_source_truth.csv"
        )
    ]

    static func resolve(
        _ fixture: DebugApprovedFixture,
        bundle: Bundle = .main
    ) throws -> URL {
        try resolve(fixture) { resourceName in
            let fileName = (resourceName as NSString).deletingPathExtension
            let fileExtension = (resourceName as NSString).pathExtension
            return bundle.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: "LedgerForgeDebugFixtures"
            )
        }
    }

    static func resolve(
        _ fixture: DebugApprovedFixture,
        resourceLookup: (String) -> URL?
    ) throws -> URL {
        guard let url = resourceLookup(fixture.resourceName) else {
            throw DebugImportFixtureCatalogError.missingApprovedResource
        }
        return url
    }
}

struct DebugImportFixtureLauncher {
    typealias Prepare = (URL, UUID, @escaping (ImportProgress) -> Void) async throws -> PreparedImport

    private let prepare: Prepare
    private let resolve: (DebugApprovedFixture) throws -> URL

    init(
        bundle: Bundle = .main,
        prepare: @escaping Prepare = { url, requestID, progress in
            try await ImportEngine.shared.prepareImport(
                from: url,
                requestId: requestID,
                progress: progress
            )
        }
    ) {
        self.prepare = prepare
        self.resolve = { fixture in
            try DebugImportFixtureCatalog.resolve(fixture, bundle: bundle)
        }
    }

    init(
        resourceResolver: @escaping (DebugApprovedFixture) throws -> URL,
        prepare: @escaping Prepare
    ) {
        self.prepare = prepare
        self.resolve = resourceResolver
    }

    func prepare(
        _ fixture: DebugApprovedFixture,
        requestID: UUID,
        progress: @escaping (ImportProgress) -> Void = { _ in }
    ) async throws -> PreparedImport {
        let url = try resolve(fixture)
        return try await prepare(url, requestID, progress)
    }
}

struct DebugImportVerificationWorkspaceView: View {
    let onLaunch: (DebugApprovedFixture) -> Void

    @State private var selectedFixtureID: DebugApprovedFixtureID = DebugImportFixtureCatalog.all[0].id
    @State private var resolutionMessage: String?

    var body: some View {
        LFPanel(title: "Import Verification Workspace") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Launch an approved sanitized fixture through the ordinary import preparation and confirmation flow.")
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)

                ForEach(DebugImportFixtureCatalog.all) { fixture in
                    fixtureRow(fixture)
                }

                if let resolutionMessage {
                    Text(resolutionMessage)
                        .font(.caption)
                        .foregroundStyle(LFTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func fixtureRow(_ fixture: DebugApprovedFixture) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedFixtureID == fixture.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedFixtureID == fixture.id ? LFTheme.primaryHover : LFTheme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(fixture.title)
                    .font(.subheadline.weight(.semibold))
                Text(fixture.provenanceSummary)
                    .font(.caption2)
                    .foregroundStyle(LFTheme.textSecondary)
            }

            Spacer()

            Button("Launch") {
                selectedFixtureID = fixture.id
                do {
                    _ = try DebugImportFixtureCatalog.resolve(fixture)
                    resolutionMessage = nil
                    onLaunch(fixture)
                } catch let error as DebugImportFixtureCatalogError {
                    resolutionMessage = error.localizedDescription
                } catch {
                    resolutionMessage = DebugImportFixtureCatalogError.missingApprovedResource.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 5)
    }
}
#endif
