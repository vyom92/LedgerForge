import SwiftUI

/// View-local choice only. The recovery owner validates the exact review token,
/// performs the merge, retains both states, and changes pairing atomically.
nonisolated enum CompanionRecoverySide: String, Codable, Equatable, Sendable { case phone, mac, retainForReview }

@MainActor
struct CompanionRecoveryPlanPresentation {
    let editor: PortableMonthlyPlanEditor
    let accountLabels: [CompanionPlanAccountLabel]
    let relatedCards: [CompanionPlanAccountLabel]
    let sourceContext: String

    /// A comparison must expose retained history-linked rows without changing
    /// the real editor's local visibility or deriving any new financial values.
    var readOnlyEditor: PortableMonthlyPlanEditor {
        PortableMonthlyPlanEditor(scratchpad: editor.scratchpad, lexicalContext: editor.lexicalContext,
            accounts: editor.accounts, allHistoryAccountIDs: editor.allHistoryAccountIDs,
            selectedHistoryAccountIDs: editor.allHistoryAccountIDs,
            manuallyExcludedPlanningAccountIDs: editor.manuallyExcludedPlanningAccountIDs,
            receipt: editor.receipt, receiptBasis: editor.receiptBasis, canEdit: false)
    }
}

@MainActor
struct CompanionRecoveryMonthPresentation: Identifiable {
    enum Readiness: Equatable {
        case independentChanges
        case chooseConflicts
        case held(String)
    }
    /// Stable review-owned month identifier; no ID is inferred by the view.
    let id: String
    let title: String
    let readiness: Readiness
    let conflictingEntryNames: [String]
    let oldPhone: CompanionRecoveryPlanPresentation?
    let newMac: CompanionRecoveryPlanPresentation?
    /// For unavailable or incompatible decoding, the owner provides precise
    /// wording. A missing presentation never becomes an empty/zero plan.
    let phoneIssue: String?
    let macIssue: String?
}

/// Presented from Connection > Review changed Mac ledger. No transport or
/// retained-state mutation occurs here; callbacks are the sole action boundary.
@MainActor
struct CompanionPhoneLedgerRecoveryView: View {
    let reviewID: String
    let oldLedgerLabel: String
    let newLedgerLabel: String
    let phoneID: String
    let months: [CompanionRecoveryMonthPresentation]
    let isWorking: Bool
    let permitsConfirmation: Bool
    let statusMessage: String?
    let onConfirm: @MainActor (String, [String: CompanionRecoverySide]) async -> Void
    let onClose: @MainActor () -> Void
    /// Archive mode supplies the exact previously recorded choices and sets
    /// permitsConfirmation to false; this view then exposes no mutation actions.
    var recordedChoices: [String: CompanionRecoverySide] = [:]
    var introduction = "The Mac ledger changed after a restore or replacement. Your previous iPhone plans and the new Mac plans are both retained."
    @State private var choices: [String: CompanionRecoverySide] = [:]
    @State private var confirmsLedger = false

    private var requiredChoices: [String] {
        months.filter { $0.readiness != .independentChanges }.map(\.id)
    }
    private func selectedChoice(for monthID: String) -> CompanionRecoverySide? {
        permitsConfirmation ? (choices[monthID] ?? recordedChoices[monthID]) : recordedChoices[monthID]
    }
    private var canConfirm: Bool {
        permitsConfirmation && !isWorking && months.allSatisfy { month in
            switch month.readiness {
            case .independentChanges: return true
            case .chooseConflicts:
                return selectedChoice(for: month.id) == .phone || selectedChoice(for: month.id) == .mac
            case .held: return selectedChoice(for: month.id) == .retainForReview
            }
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Ledger comparison") {
                    LabeledContent("Retained iPhone ledger", value: oldLedgerLabel)
                    LabeledContent("New Mac ledger", value: newLedgerLabel)
                    Text(introduction)
                    Text(permitsConfirmation
                        ? "Compare the plans below. Independent changes can be merged; entries changed differently on both sides need your choice."
                        : "Inspect the complete retained entries below. This archive is read-only; opening it does not apply a file version or change the current ledger.")
                        .foregroundStyle(.secondary)
                }
                ForEach(months) { month in
                    Section(month.title) {
                        readiness(month)
                        if let plan = month.oldPhone {
                            NavigationLink("Retained iPhone plan") {
                                planPreview(plan, title: "Retained iPhone plan")
                            }
                        } else {
                            Label(month.phoneIssue ?? "The retained iPhone plan is unavailable for comparison.", systemImage: "exclamationmark.circle")
                        }
                        if let plan = month.newMac {
                            NavigationLink("New Mac plan") {
                                planPreview(plan, title: "New Mac plan")
                            }
                        } else {
                            Label(month.macIssue ?? "This month is missing from the new Mac ledger. The retained iPhone plan has not been discarded.", systemImage: "exclamationmark.circle")
                        }
                        if month.readiness == .chooseConflicts {
                            ForEach(Array(month.conflictingEntryNames.enumerated()), id: \.offset) { _, name in
                                Text(name).font(.subheadline)
                            }
                            if permitsConfirmation {
                            Button {
                                choices[month.id] = .phone
                            } label: {
                                choiceLabel("Use iPhone for conflicting entries", selected: selectedChoice(for: month.id) == .phone)
                            }.disabled(isWorking)
                            Button {
                                choices[month.id] = .mac
                            } label: {
                                choiceLabel("Use Mac for conflicting entries", selected: selectedChoice(for: month.id) == .mac)
                            }.disabled(isWorking)
                            } else if let selected = selectedChoice(for: month.id) {
                                Text(selected == .phone ? "Recorded choice: iPhone conflicting entries" : "Recorded choice: Mac conflicting entries")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("This choice applies only to conflicting entries in this month. Independent changes from both plans are kept.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if case .held = month.readiness {
                            if permitsConfirmation {
                                Button {
                                    choices[month.id] = .retainForReview
                                } label: {
                                    choiceLabel("Keep this iPhone plan for later review; use Mac plan if available",
                                        selected: selectedChoice(for: month.id) == .retainForReview)
                                }.disabled(isWorking)
                                Text("This month will not be forced into a merge. Its complete previous iPhone state will remain available from Connection for later review. The new Mac plan will be used if one is available.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if selectedChoice(for: month.id) == .retainForReview {
                                Text("Recorded choice: retain the complete iPhone plan for later review and use the Mac plan if available.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let statusMessage { Section { Text(statusMessage).foregroundStyle(.secondary) } }
                if permitsConfirmation {
                    Section {
                        Button("Confirm ledger and merge reviewed plans") { confirmsLedger = true }
                            .disabled(!canConfirm)
                        Text("Choose how to handle every conflicting or held month. Compatible plans will merge; plans kept for later review will remain available from Connection. Choosing above does not change the pairing. Confirmation applies this exact review to the new Mac ledger; delivery and Mac acknowledgement remain separate steps.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("Retained comparison archive. Both previous states and the recorded choices remain available here for review.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Review changed ledger").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(permitsConfirmation ? "Later" : "Done", action: onClose).disabled(isWorking)
                }
                if isWorking { ToolbarItem(placement: .confirmationAction) { ProgressView() } }
            }
        }
        .onChange(of: reviewID) { _, _ in choices = [:]; confirmsLedger = false }
        .onChange(of: permitsConfirmation) { _, allowed in
            if !allowed { choices = [:]; confirmsLedger = false }
        }
        .confirmationDialog("Use the new Mac ledger for this iPhone?", isPresented: $confirmsLedger, titleVisibility: .visible) {
            Button("Confirm reviewed merge") {
                let reviewedID = reviewID
                let reviewedChoices = Dictionary(uniqueKeysWithValues: requiredChoices.compactMap { id in
                    selectedChoice(for: id).map { (id, $0) }
                })
                Task { await onConfirm(reviewedID, reviewedChoices) }
            }.disabled(!canConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Change the companion from \(oldLedgerLabel) to \(newLedgerLabel) for iPhone \(phoneID). Apply the reviewed month choices and retain both previous states. Months kept for later review remain available from Connection; use their Mac plan if available. Current totals remain subject to the new ledger's source and salary-receipt checks.")
        }
    }
    @ViewBuilder private func readiness(_ month: CompanionRecoveryMonthPresentation) -> some View {
        switch month.readiness {
        case .independentChanges:
            Label("Independent changes can be merged", systemImage: "arrow.triangle.merge")
        case .chooseConflicts:
            Label("Conflicting entries need your choice", systemImage: "arrow.left.arrow.right")
        case .held(let message):
            Label("Review required", systemImage: "exclamationmark.circle")
            Text(message).foregroundStyle(.secondary)
        }
    }
    private func choiceLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if selected { Image(systemName: "checkmark").accessibilityLabel("Selected") }
        }.accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func planPreview(_ plan: CompanionRecoveryPlanPresentation, title: String) -> some View {
        VStack(spacing: 0) {
            if !plan.sourceContext.isEmpty {
                Text(plan.sourceContext).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            CompanionMonthlyPlanView(editor: plan.readOnlyEditor,
                accountLabels: plan.accountLabels, relatedCards: plan.relatedCards,
                availableMonths: [plan.editor.plan.month], latestAlDarQuote: nil,
                status: .init(retention: .kept, delivery: .conflict, permitsEditing: false, permitsCalculation: false),
                onEdit: { _ in }, onSelectMonth: { _ in }, onReviewConflict: nil)
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
