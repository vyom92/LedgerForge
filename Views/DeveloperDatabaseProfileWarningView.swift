// LedgerForge
// DeveloperDatabaseProfileWarningView.swift

#if DEBUG
import SwiftUI

struct DeveloperDatabaseProfileWarningPresentation: Equatable {
    let title: String
    let detail: String
    let sourceSchema: String?
    let currentSchema: String
    let accessibilityLabel: String

    init?(profile: DevelopmentDatabaseProfileDescriptor) {
        guard profile.kind != .current else { return nil }
        title = "\(profile.displayName) Active"
        detail = "Changes affect the selected development profile."
        sourceSchema = profile.migrationSourceVersion.map { "Source schema V\($0)" }
        currentSchema = "Current schema V\(profile.verifiedCurrentSchemaVersion)"
        let sourceText = sourceSchema.map { ". \($0)" } ?? ""
        accessibilityLabel = "\(title). \(detail)\(sourceText). \(currentSchema)."
    }
}

struct DeveloperDatabaseProfileWarningView: View {
    let presentation: DeveloperDatabaseProfileWarningPresentation

    init?(profile: DevelopmentDatabaseProfileDescriptor) {
        guard let presentation = DeveloperDatabaseProfileWarningPresentation(profile: profile) else {
            return nil
        }
        self.presentation = presentation
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LFTheme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }

            Spacer()

            if let sourceSchema = presentation.sourceSchema {
                Text(sourceSchema)
                    .font(.caption.weight(.medium))
            }
            Text(presentation.currentSchema)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(LFTheme.warning.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle().fill(LFTheme.warning.opacity(0.35)).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
#endif
