import SwiftUI

/// Stable, source-independent progress for a confirmed statement batch.
/// Commands remain in ContentView's existing footer; this view only reports
/// the current run and never scrolls or changes its surrounding layout.
struct ImportBatchRunView: View {
    @Environment(\.lfTheme) private var theme

    let total: Int
    let completed: Int
    let currentPosition: Int?
    let currentFileName: String
    let statusText: String
    let importedCount: Int
    let duplicateCount: Int

    private var resolved: Int { min(max(completed, 0), max(total, 0)) }
    private var progressTotal: Int { max(total, 1) }
    private var positionText: String {
        if let currentPosition, total > 0 {
            return "Statement \(min(max(currentPosition, 1), total)) of \(total)"
        }
        return total > 0 ? "\(resolved) of \(total) statements complete" : "Preparing statements"
    }
    private var currentStatementText: String {
        let name = currentFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Preparing the next statement" : name
    }

    var body: some View {
        LFPanel(title: "Importing statements", systemImage: "arrow.down.doc") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                    Text(positionText)
                        .font(theme.typography.formBody.weight(.semibold))
                        .monospacedDigit()
                    Spacer(minLength: theme.spacing.controlGap)
                    Text("\(resolved) complete")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                        .monospacedDigit()
                }

                ProgressView(value: Double(resolved), total: Double(progressTotal))
                    .progressViewStyle(.linear)
                    .tint(theme.palette.accent)
                    .controlSize(.regular)
                    .accessibilityLabel("Batch progress")
                    .accessibilityValue("\(resolved) of \(max(total, 0)) statements resolved")

                HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                    Image(systemName: "doc.text")
                        .font(theme.typography.formHeading)
                        .foregroundStyle(theme.palette.secondaryText)
                        .frame(width: 18, alignment: .leading)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(currentStatementText)
                            .font(theme.typography.formBody.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .accessibilityLabel("Current statement: \(currentStatementText)")
                        Text(statusText)
                            .font(theme.typography.formCaption)
                            .foregroundStyle(theme.palette.secondaryText)
                            .lineLimit(2, reservesSpace: true)
                    }
                }

                Divider().overlay(theme.palette.divider)

                HStack(spacing: theme.spacing.sectionGap) {
                    outcomeCount(title: "Imported", value: importedCount, color: LFTheme.success)
                    outcomeCount(title: "Previously imported", value: duplicateCount, color: theme.palette.secondaryText)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Batch outcomes: \(importedCount) imported, \(duplicateCount) previously imported")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Statement batch progress")
    }

    @ViewBuilder
    private func outcomeCount(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: theme.spacing.small) {
            Text("\(max(value, 0))")
                .font(theme.typography.formBody.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(theme.typography.formCaption)
                .foregroundStyle(theme.palette.secondaryText)
        }
    }
}
