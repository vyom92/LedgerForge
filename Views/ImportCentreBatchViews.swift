import SwiftUI

struct ImportBatchQueueItemPresentation: Identifiable, Equatable {
    let id: UUID
    let position: Int
    let total: Int
    let fileName: String
    let status: String
    let iconName: String
    let tone: ImportOutcomeTone
    let isActive: Bool
    let isPresented: Bool
    let isOutcomeNavigable: Bool

    @MainActor
    init<Preparation: ImportCentrePreparation>(
        item: ImportCentreCoordinator<Preparation>.Item,
        total: Int,
        activeItemID: UUID?,
        presentedItemID: UUID?,
        permitsOutcomeNavigation: Bool
    ) {
        id = item.id
        position = item.queuePosition + 1
        self.total = total
        fileName = item.displayFileName
        isActive = item.id == activeItemID
        isPresented = item.id == presentedItemID
        isOutcomeNavigable = permitsOutcomeNavigation && item.outcome != nil

        switch item.phase {
        case .pending:
            status = "Pending"
            iconName = "clock"
            tone = .warning
        case .preparing, .awaitingReview:
            status = item.progress.phase.userFacingTitle
            iconName = "hourglass"
            tone = .warning
        case .awaitingConfirmation:
            status = "Awaiting confirmation"
            iconName = "checkmark.circle"
            tone = .warning
        case .validationFailed:
            status = "Validation failed"
            iconName = "xmark.octagon.fill"
            tone = .danger
        case .committing:
            status = "Importing confirmed statement"
            iconName = "lock.fill"
            tone = .warning
        case .completed:
            switch item.completionDisposition {
            case .committed:
                status = "Imported"
                iconName = "checkmark.circle.fill"
                tone = .success
            case .reconciliationRequired:
                status = "Saved — reconciliation required"
                iconName = "arrow.triangle.2.circlepath.circle.fill"
                tone = .warning
            case .exactDuplicate:
                status = "Previously imported"
                iconName = "checkmark.circle.fill"
                tone = .warning
            case .transactionEventBlocked:
                status = "Statement blocked"
                iconName = "exclamationmark.triangle.fill"
                tone = .warning
            case .rejected, .none:
                status = "Not imported"
                iconName = "xmark.octagon.fill"
                tone = .danger
            }
        case .skipped:
            status = "Skipped"
            iconName = "forward.fill"
            tone = .warning
        case .cancelled:
            status = "Not processed"
            iconName = "slash.circle"
            tone = .warning
        case .failed:
            status = "Preparation failed"
            iconName = "exclamationmark.triangle.fill"
            tone = .danger
        }
    }
}

struct ImportBatchSummaryPresentation: Equatable {
    let totalSelected: Int
    let committedCount: Int
    let exactDuplicateCount: Int
    let transactionEventBlockedCount: Int
    let rejectedCount: Int
    let failedPreparationCount: Int
    let skippedCount: Int
    let cancelledOrNotProcessedCount: Int
    let reconciliationRequiredCount: Int

    @MainActor
    init<Preparation: ImportCentrePreparation>(
        _ summary: ImportCentreCoordinator<Preparation>.BatchSummary
    ) {
        totalSelected = summary.totalSelected
        committedCount = summary.committedCount
        exactDuplicateCount = summary.exactDuplicateCount
        transactionEventBlockedCount = summary.transactionEventBlockedCount
        rejectedCount = summary.rejectedCount
        failedPreparationCount = summary.failedPreparationCount
        skippedCount = summary.skippedCount
        cancelledOrNotProcessedCount = summary.cancelledOrNotProcessedCount
        reconciliationRequiredCount = summary.reconciliationRequiredCount
    }
}

struct ImportBatchProgressView: View {
    @Environment(\.lfTheme) private var theme
    let activePosition: Int?
    let total: Int
    let terminalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let activePosition {
                    Text("Statement \(activePosition) of \(total)")
                        .font(theme.typography.formBody.weight(.semibold))
                } else {
                    Text("Batch complete")
                        .font(theme.typography.formBody.weight(.semibold))
                }
                Spacer()
                Text("\(terminalCount) of \(total) resolved")
                    .font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            ProgressView(value: Double(terminalCount), total: Double(max(total, 1)))
                .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ImportBatchQueueView: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    let items: [ImportBatchQueueItemPresentation]
    let onSelectOutcome: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ordered Queue")
                .font(theme.typography.formHeading)
            ForEach(items) { item in
                Button {
                    onSelectOutcome(item.id)
                } label: {
                    HStack(spacing: 10) {
                        Text("\(item.position)")
                            .font(theme.typography.formCaption.weight(.semibold))
                            .frame(width: 24, height: 24)
                            .background(item.isActive ? theme.interaction.dataBadge : theme.palette.controlSurface)
                            .clipShape(Circle())
                        Image(systemName: item.iconName)
                            .foregroundStyle(item.tone.color)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.fileName)
                                .font(theme.typography.formCaption.weight(.semibold))
                                .lineLimit(1)
                            Text(item.status)
                                .font(theme.typography.finePrint)
                                .foregroundStyle(theme.palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        if item.isPresented && item.isOutcomeNavigable {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(theme.palette.accentHover)
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.interaction.dataRow(selected: item.isActive, active: appearsActive))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(item.isActive ? theme.palette.tableBorder : theme.palette.divider, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(LFPlainActionStyle())
                .disabled(!item.isOutcomeNavigable)
                .accessibilityLabel("Statement \(item.position) of \(item.total), \(item.fileName), \(item.status)")
                .accessibilityHint(item.isOutcomeNavigable ? "Shows this completed outcome" : "")
            }
        }
    }
}

struct ImportBatchSummaryView: View {
    @Environment(\.lfTheme) private var theme
    let summary: ImportBatchSummaryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Batch Summary")
                .font(theme.typography.formHeading)
            summaryRow("Selected", value: summary.totalSelected)
            summaryRow("Imported", value: summary.committedCount)
            summaryRow("Previously imported", value: summary.exactDuplicateCount)
            summaryRow("Statement blocked", value: summary.transactionEventBlockedCount)
            summaryRow("Rejected", value: summary.rejectedCount)
            summaryRow("Preparation failed", value: summary.failedPreparationCount)
            summaryRow("Skipped", value: summary.skippedCount)
            summaryRow("Cancelled / not processed", value: summary.cancelledOrNotProcessedCount)
            if summary.reconciliationRequiredCount > 0 {
                summaryRow("Reconciliation required", value: summary.reconciliationRequiredCount)
            }
            Text("Counts describe batch outcomes. They do not total or reinterpret financial data.")
                .font(theme.typography.finePrint)
                .foregroundStyle(theme.palette.secondaryText)
        }
        .padding(12)
        .background(theme.palette.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private func summaryRow(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.formCaption)
            Spacer()
            Text("\(value)")
                .font(theme.typography.formCaption.weight(.semibold))
                .monospacedDigit()
        }
    }
}
