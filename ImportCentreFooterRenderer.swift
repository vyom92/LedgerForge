import SwiftUI

/// Import footer presentation. The root still owns all coordinator commands and task lifetimes.
struct ImportCentreFooterRenderer: View {
    let importState: ImportPresentationState
    let confirmationLabel: String
    let confirmationIsDisabled: (PreparedImport) -> Bool
    let confirm: (PreparedImport) -> Void
    let retryPreparation: () -> Void
    let viewTransactions: () -> Void

    var body: some View {
        Group {
            switch ImportFooterPresentation.presentation(for: importState) {
            case .confirmation(let preparedImport):
                Button {
                    confirm(preparedImport)
                } label: {
                    Label(confirmationLabel, systemImage: "checkmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .disabled(confirmationIsDisabled(preparedImport))
            case .importing:
                Label("Importing", systemImage: "hourglass")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LFTheme.textSecondary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(LFTheme.surface.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .retryPreparation:
                Button(action: retryPreparation) {
                    Label("Retry Preparation", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            case .viewTransactions:
                Button(action: viewTransactions) {
                    Label("View Transactions", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            case .none:
                EmptyView()
            }
        }
    }
}
