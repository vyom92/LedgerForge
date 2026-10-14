import SwiftUI

/// Embedded in Mac companion settings when the coordinator exposes a changed
/// ledger. The owner alone validates the new folder, retains states and pairs.
@MainActor
struct CompanionMacLedgerRecoveryView: View {
    @Environment(\.lfTheme) private var theme
    let reviewID: String
    let phoneID: String
    let previousLedgerLabel: String
    let currentLedgerLabel: String
    let isWorking: Bool
    let permitsNewFolder: Bool
    let message: String?
    let onConfirmAndChooseNewFolder: @MainActor (String, URL) async -> Void
    @State private var confirmsReview = false
    @State private var choosesFolder = false
    @State private var confirmedReviewID: String?
    @State private var pickerIssue: String?

    var body: some View {
        LFPanel(title: "Changed Mac ledger") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                LabeledContent("Previous companion ledger", value: previousLedgerLabel)
                LabeledContent("Current Mac ledger", value: currentLedgerLabel)
                LabeledContent("Same iPhone") {
                    Text(phoneID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
                Text("A restore or replacement changed this ledger. The previous companion states and pending plans remain retained.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                Text("Start an explicit comparison using a new companion folder and the same iPhone. The phone can compare its retained plans with this ledger and choose between conflicting entries. Independent changes are kept. Missing or incompatible months stay pending review.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Review changed ledger") { confirmsReview = true }
                    .disabled(isWorking || choosesFolder || !permitsNewFolder)
                if let text = pickerIssue ?? message {
                    Text(text).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog("Compare this ledger with the retained iPhone plans?", isPresented: $confirmsReview, titleVisibility: .visible) {
            Button("Continue and choose a new folder") {
                chooseRecoveryFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use \(currentLedgerLabel) with the same iPhone \(phoneID). Select a new shared folder to keep the previous publications separate. Previous database states and phone edits remain retained. Monthly plan conflicts require an explicit comparison and merge on the phone.")
        }
        .onChange(of: reviewID) { _, _ in
            confirmsReview = false; confirmedReviewID = nil
        }
    }
    private func chooseRecoveryFolder() {
        guard !isWorking, !choosesFolder, permitsNewFolder else { return }
        let reviewedID = reviewID
        confirmedReviewID = reviewedID; pickerIssue = nil; choosesFolder = true
        Task {
            defer { choosesFolder = false; confirmedReviewID = nil }
            guard let folder = await CompanionFolderPanel.select(title: "Choose New Companion Folder") else { return }
            guard confirmedReviewID == reviewedID, reviewedID == reviewID else {
                pickerIssue = "The ledger changed while choosing a folder. Review the current comparison before continuing."
                return
            }
            // The coordinator revalidates this exact pre-picker review token.
            await onConfirmAndChooseNewFolder(reviewedID, folder)
        }
    }
}
