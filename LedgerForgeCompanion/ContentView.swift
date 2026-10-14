import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    let model: CompanionPhoneModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsConnection = false
    @State private var choosesFolder = false
    @State private var folderPickerFailure: String?
    @State private var conflict: CompanionPlanReviewPresentation?
    @State private var ledgerArchive: CompanionPhoneLedgerRecoveryPresentation?
    @State private var archiveFailure: String?
    @State private var confirmsFolderChange = false
    @State private var retainsVersionsForFolderChange = false
    @State private var folderVersionArchive: CompanionPhoneFolderVersionArchivePresentation?
    @State private var versionPlanArchive: CompanionPhoneLedgerRecoveryPresentation?

    var body: some View {
        CompanionPhoneShell(snapshot: model.snapshot, status: model.readStatus,
            checkDisabled: model.isChecking || model.startupFailure != nil,
            onConnection: { showsConnection = true }, onCheck: model.requestSync,
            monthlyPlanTitle: model.currentRecord.map { "Monthly Plan · " + $0.state.scope.month } ?? "Monthly Plan",
            monthlyPlanSummary: monthlyPlanSummary,
            monthlyPlanMessage: monthlyPlanSummary.isEmpty
                ? "Open Monthly Plan to review retained entries. Current totals are unavailable until entries and any pending review are complete."
                : "Calculated from this iPhone's retained entries and the last received Mac source context. Open Monthly Plan for delivery status.") {
            if let editor = model.editor, let record = model.currentRecord {
                CompanionMonthlyPlanView(editor: editor,
                    accountLabels: labels(record.anchor.context.displayAccounts ?? record.anchor.context.accounts),
                    relatedCards: labels(record.anchor.context.relatedCards), availableMonths: model.availableMonths,
                    latestAlDarQuote: record.anchor.context.latestAlDarQuote, status: model.planStatus,
                    onEdit: model.edit, onSelectMonth: model.selectMonth,
                    onReviewConflict: { if let context = model.currentRecord?.state.resolutionContext {
                        conflict = .init(context: context)
                    } else { showsConnection = true } }, sourceContext: record.anchor.context.sourceContext)
            } else {
                ContentUnavailableView {
                    Label("Monthly Plan", systemImage: "calendar")
                } description: {
                    Text(model.startupFailure ?? "Choose the same companion folder selected on your Mac, then check for its publication.")
                } actions: {
                    Button("Connection") { showsConnection = true }
                }
            }
        }
        .sheet(isPresented: $showsConnection) { connectionSheet }
        .sheet(item: $conflict) { review in
            CompanionPlanReviewView(model: model, review: review) { conflict = nil }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                model.requestSync()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
    }
    private var monthlyPlanSummary: [CompanionReadMetric] {
        guard model.planStatus.permitsCalculation, case .kept = model.planStatus.retention,
              let editor = model.editor, !editor.salaryReceiptNeedsRevalidation,
              let calculation = editor.visibleCalculation else { return [] }
        let rows: [(String, String, Money?)] = [
            ("transfer", "Available to transfer", calculation.transferablePrincipal),
            ("india", "Minimum reqd transfer", calculation.indiaFundingShortfall),
            ("balance", "Balance available", calculation.finalQARBuffer)
        ]
        return rows.map { id, label, value in
            CompanionReadMetric(id: id, label: label,
                display: value.map { MoneyFormatting.display($0) } ?? "Unavailable", exact: nil, note: nil)
        }
    }
    private func labels(_ accounts: [CompanionPlannerAccount]) -> [CompanionPlanAccountLabel] {
        accounts.map { .init(id: $0.id, title: $0.title, context: $0.context, currency: $0.currency.code) }
    }
    private var connectionSheet: some View {
        NavigationStack {
            List {
                Section("This iPhone") {
                    if let identity = model.phoneID {
                        Text("Enter this pairing code in LedgerForge on the Mac before publishing.")
                        Text(identity).font(.footnote.monospaced()).textSelection(.enabled)
                        ShareLink(item: identity) { Label("Share pairing code", systemImage: "square.and.arrow.up") }
                    }
                    if let failure = model.startupFailure { Text(failure).foregroundStyle(.red) }
                }
                Section("Companion folder") {
                    Text(model.local?.connection?.name ?? "No folder selected")
                    Button("Choose folder", systemImage: "folder") {
                        folderPickerFailure = nil
                        if model.local?.versionReview != nil { confirmsFolderChange = true }
                        else { retainsVersionsForFolderChange = false; choosesFolder = true }
                    }
                        .disabled(model.isChecking || model.startupFailure != nil)
                    if let folderPickerFailure {
                        Label(folderPickerFailure, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Button("Check now", systemImage: "arrow.clockwise") { model.requestSync() }.disabled(model.isChecking)
                    Text(model.readStatus.message).foregroundStyle(.secondary)
                    if let checked = model.local?.lastCheckedAt { LabeledContent("Last checked") { Text(checked, format: .dateTime) } }
                    Text("History-account visibility is local to this iPhone. Account inclusion and entered balances are shared plan inputs.").font(.caption).foregroundStyle(.secondary)
                    Text("A folder write means the file provider accepted the local file. An edit is acknowledged only when this phone receives the matching Mac receipt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.canReviewChangedLedger || model.local?.recoveryProgress != nil {
                    Section("Ledger recovery") {
                        if model.canReviewChangedLedger {
                            Button("Review changed Mac ledger") { model.prepareLedgerRecoveryReview() }
                                .disabled(model.isChecking || model.retentionFailure != nil)
                        }
                        if let progress = model.local?.recoveryProgress {
                            ForEach(progress.choices.keys.sorted(), id: \.self) { month in
                                Text(progress.issues[month] ?? "\(month): waiting for the new Mac ledger to acknowledge the connection before sending your reviewed merge.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if model.local?.heldEnvelope != nil || model.local?.months.values.contains(where: { $0.heldPacket != nil }) == true {
                    Section("Retained delivery") {
                        Button("Retry retained evidence") { model.retryHeldEvidence() }
                            .disabled(model.isChecking || model.retentionFailure != nil)
                        Text("Checks the same saved publication again. Your retained edits are preserved if it still needs review.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !model.ledgerArchiveIDs.isEmpty {
                    Section("Retained ledger comparisons") {
                        ForEach(Array(model.ledgerArchiveIDs.enumerated()).reversed(), id: \.element) { index, id in
                            Button("Ledger comparison \(index + 1)") {
                                do { ledgerArchive = try model.ledgerArchivePresentation(id); archiveFailure = nil }
                                catch { archiveFailure = error.localizedDescription }
                            }
                        }
                        if let archiveFailure { Text(archiveFailure).foregroundStyle(.orange) }
                    }
                }
                if !model.versionArchiveIDs.isEmpty {
                    Section("Retained folder versions") {
                        ForEach(Array(model.versionArchiveIDs.enumerated()).reversed(), id: \.element) { index, id in
                            Button("Folder version review \(index + 1)") {
                                do { folderVersionArchive = try model.versionArchivePresentation(id); archiveFailure = nil }
                                catch { archiveFailure = error.localizedDescription }
                            }
                        }
                        if let archiveFailure { Text(archiveFailure).foregroundStyle(.orange) }
                    }
                }
                if let failure = model.retentionFailure {
                    Section("Local retention failed") {
                        Text(failure).foregroundStyle(.red)
                        Text("The current text remains visible in this session. Keep the app open and retry before relying on it after restart.")
                        Button("Retry keeping edits") { model.retryRetention() }
                    }
                }
                ForEach((model.local?.months.keys.sorted() ?? []), id: \.self) { key in
                    if let hold = model.local?.months[key]?.hold { Section(key) { Text(hold).foregroundStyle(.orange) } }
                }
                if let review = model.local?.versionReview {
                    Section("Review iCloud versions") {
                        Text("All versions shown here have been retained on this iPhone. Select one complete \(review.writer == .mac ? "Mac" : "iPhone") publication; your local pending plan edits remain retained.")
                        ForEach(model.versionChoices) { choice in
                            VStack(alignment: .leading, spacing: 8) {
                                if let envelope = choice.envelope {
                                    Text("Publication \(envelope.generation)").font(.headline)
                                    Text("Reference \(choice.id.prefix(12))").font(.caption.monospaced()).foregroundStyle(.secondary)
                                    if review.writer == .mac,
                                       let phoneID = model.phoneID,
                                       let packet = try? CompanionMacPacket.decode(envelope, phoneID: phoneID) {
                                        Text("\(packet.months.count) monthly plans; Mac snapshot retained in this version.")
                                    }
                                    Button("Use this version") { model.resolveVersion(choice.id) }
                                        .disabled(model.isChecking)
                                } else { Text(choice.issue ?? "This version cannot be opened.").foregroundStyle(.secondary) }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }.navigationTitle("Connection")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsConnection = false } } }
                .sheet(item: Binding(get: { model.ledgerRecoveryPresentation }, set: { if $0 == nil { model.closeLedgerRecoveryReview() } })) { review in
                    CompanionPhoneLedgerRecoveryView(reviewID: review.id,
                        oldLedgerLabel: review.oldLedgerLabel, newLedgerLabel: review.newLedgerLabel,
                        phoneID: review.phoneID, months: review.months, isWorking: model.isChecking,
                        permitsConfirmation: model.retentionFailure == nil, statusMessage: model.readStatus.message,
                        onConfirm: { id, choices in await model.confirmLedgerRecovery(reviewID: id, choices: choices) },
                        onClose: model.closeLedgerRecoveryReview)
                }
                .confirmationDialog("Retain unresolved versions and choose another folder?", isPresented: $confirmsFolderChange, titleVisibility: .visible) {
                    Button("Retain versions and choose folder") {
                        retainsVersionsForFolderChange = true; choosesFolder = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Keep every unresolved file version and the complete current phone state in a readable local archive. The new folder will be checked separately; changing folders does not apply an old file version there.")
                }
                .sheet(item: $folderVersionArchive) { archive in
                    NavigationStack {
                        List {
                            Section {
                                Text("Unresolved \(archive.writer == .mac ? "Mac" : "iPhone") versions retained before changing folders. These alternatives are read-only and are not applied to the current folder.")
                            }
                            ForEach(archive.choices) { choice in
                                Section {
                                    if let envelope = choice.envelope {
                                        Text("Publication \(envelope.generation)").font(.headline)
                                        Button("Inspect retained plans") {
                                            do { versionPlanArchive = try model.versionArchivePlanPresentation(archiveID: archive.id, choiceID: choice.id); archiveFailure = nil }
                                            catch { archiveFailure = error.localizedDescription }
                                        }
                                    } else { Text(choice.issue ?? "This retained version cannot be decoded.") }
                                }
                            }
                            if let archiveFailure { Section { Text(archiveFailure).foregroundStyle(.orange) } }
                        }.navigationTitle("Retained file versions").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { folderVersionArchive = nil } } }
                            .sheet(item: $versionPlanArchive) { review in
                                CompanionPhoneLedgerRecoveryView(reviewID: review.id,
                                    oldLedgerLabel: review.oldLedgerLabel, newLedgerLabel: review.newLedgerLabel,
                                    phoneID: review.phoneID, months: review.months, isWorking: false,
                                    permitsConfirmation: false, statusMessage: nil, onConfirm: { _, _ in },
                                    onClose: { versionPlanArchive = nil }, recordedChoices: review.recordedChoices,
                                    introduction: "This file version was retained before choosing another folder. Its complete available plan entries remain here for inspection.")
                            }
                    }
                }
                .sheet(item: $ledgerArchive) { review in
                    CompanionPhoneLedgerRecoveryView(reviewID: review.id,
                        oldLedgerLabel: review.oldLedgerLabel, newLedgerLabel: review.newLedgerLabel,
                        phoneID: review.phoneID, months: review.months, isWorking: false,
                        permitsConfirmation: false, statusMessage: nil, onConfirm: { _, _ in },
                        onClose: { ledgerArchive = nil }, recordedChoices: review.recordedChoices)
                }
        }
        // Present from the visible Connection sheet, not its already-presenting root.
        .fileImporter(isPresented: $choosesFolder, allowedContentTypes: [.folder]) { result in
            let retaining = retainsVersionsForFolderChange
            retainsVersionsForFolderChange = false
            switch result {
            case .success(let url):
                folderPickerFailure = nil
                if retaining { model.chooseFolderRetainingVersions(url) }
                else { model.chooseFolder(url) }
            case .failure(let error):
                let failure = error as NSError
                if failure.domain != NSCocoaErrorDomain || failure.code != NSUserCancelledError {
                    folderPickerFailure = "The folder picker could not complete. " + error.localizedDescription
                }
            }
        }
    }
}

private struct CompanionPlanReviewPresentation: Identifiable {
    let id = UUID()
    let context: CompanionMerge.ResolutionContext
}

@MainActor private struct CompanionPlanReviewView: View {
    let model: CompanionPhoneModel
    let review: CompanionPlanReviewPresentation
    let close: () -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Both devices changed the same entries. Your choice applies to conflicting entries only; independent changes from both devices are kept.")
                    Text("The selected result remains pending until the Mac returns a matching receipt.")
                        .foregroundStyle(.secondary)
                }
                Section("Entries to review") {
                    ForEach(affectedNames, id: \.self) { Text($0) }
                }
                Section("Compare retained plans") {
                    NavigationLink("iPhone entries") { preview(usePhone: true) }
                    NavigationLink("Mac entries") { preview(usePhone: false) }
                }
                Section {
                    Button("Use iPhone for conflicting entries") { model.resolvePlan(expected: review.context, usePhone: true); close() }
                    Button("Use Mac for conflicting entries") { model.resolvePlan(expected: review.context, usePhone: false); close() }
                }
            }.navigationTitle("Review plan changes").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Later", action: close) } }
        }
    }
    private var affectedNames: [String] {
        guard let record = model.currentRecord else { return ["Retained monthly plan"] }
        let plans = [record.scratchpad.plan, record.anchor.scratchpad.plan]
        let labels = Dictionary((record.anchor.context.accounts + record.anchor.context.relatedCards).map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        return Set(review.context.merge.conflicts.map { conflict in
            let key = conflict.itemID
            if key == "fx" { return "Exchange rate" }
            if key.hasPrefix("scalar:") {
                return ["fixed": "Fixed pay", "variable": "Variable pay", "deductions": "Deductions", "fee": "Transfer fee", "investment": "Investment", "reserve": "Keep in CBQ"][String(key.dropFirst(7))] ?? "Monthly amount"
            }
            if key.hasPrefix("balance:") { return labels[String(key.dropFirst(8))] ?? "Account balance" }
            let id = String(key.split(separator: ":", maxSplits: 1).last ?? "")
            for plan in plans {
                if let row = plan.deductions.first(where: { $0.id == id }) { return row.label.isEmpty ? "Deduction" : row.label }
                let rowID = plan.assistance?.appliedRecurringIDs[id] ?? id
                if let row = (plan.qatarCommitments + plan.indiaCommitments).first(where: { $0.id == rowID }) { return row.label.isEmpty ? "Commitment" : row.label }
            }
            return "Monthly plan settings"
        }).sorted()
    }
    @ViewBuilder private func preview(usePhone: Bool) -> some View {
        if let record = model.currentRecord,
           let binding = try? record.anchor.binding(for: record.state.scope),
           let decoded = try? MonthlyPlanSyncAdapter.decode(document: usePhone ? review.context.local : review.context.remote, against: binding) {
            let context = record.anchor.context
            let editor = PortableMonthlyPlanEditor(scratchpad: decoded.scratchpad,
                lexicalContext: MonthlyPlanSyncAdapter.lexicalContext(from: decoded.metadata),
                accounts: context.accounts.map { .init(id: $0.id, nativeCurrency: $0.currency, isHistoryOnly: $0.isHistoryOnly) },
                allHistoryAccountIDs: context.allHistoryAccountIDs,
                // Comparison displays all retained history-linked rows; it does not change the phone's local filter.
                selectedHistoryAccountIDs: context.allHistoryAccountIDs,
                manuallyExcludedPlanningAccountIDs: context.manuallyExcludedPlanningAccountIDs,
                receipt: context.receipt?.state, receiptBasis: nil, canEdit: false)
            CompanionMonthlyPlanView(editor: editor,
                accountLabels: (context.displayAccounts ?? context.accounts).map { .init(id: $0.id, title: $0.title, context: $0.context, currency: $0.currency.code) },
                relatedCards: context.relatedCards.map { .init(id: $0.id, title: $0.title, context: $0.context, currency: $0.currency.code) },
                availableMonths: [decoded.scratchpad.plan.month], latestAlDarQuote: context.latestAlDarQuote,
                status: .init(retention: .kept, delivery: .conflict, permitsEditing: false, permitsCalculation: false),
                onEdit: { _ in }, onSelectMonth: { _ in }, onReviewConflict: nil,
                sourceContext: context.sourceContext)
                .navigationTitle(usePhone ? "iPhone entries" : "Mac entries")
        } else {
            ContentUnavailableView("Review on Mac", systemImage: "exclamationmark.circle",
                description: Text("The exact retained entries cannot be displayed against this source context. Both alternatives remain retained."))
        }
    }
}
