import SwiftUI

/// Import footer presentation. The root still owns all coordinator commands and task lifetimes.
struct ImportCentreFooterRenderer: View {
    @Environment(\.lfTheme) private var theme
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
                        .font(theme.typography.formBody.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(theme.palette.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                        .contentShape(RoundedRectangle(cornerRadius: theme.radius.control))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .disabled(confirmationIsDisabled(preparedImport))
            case .importing:
                Label("Importing", systemImage: "hourglass")
                    .labelStyle(.titleAndIcon)
                    .font(theme.typography.formBody.weight(.semibold))
                    .foregroundStyle(theme.palette.secondaryText)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(theme.palette.controlSurface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
            case .retryPreparation:
                Button(action: retryPreparation) {
                    Label("Retry Preparation", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(theme.typography.formBody.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(theme.palette.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            case .viewTransactions:
                Button(action: viewTransactions) {
                    Label("View Transactions", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(theme.typography.formBody.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(theme.palette.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                        .contentShape(RoundedRectangle(cornerRadius: theme.radius.control))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            case .none:
                EmptyView()
            }
        }
    }
}
