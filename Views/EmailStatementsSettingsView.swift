import SwiftUI
import UniformTypeIdentifiers

struct EmailStatementsSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: GmailIntakeSession
    let availableWidth: CGFloat
    let openImportCentre: () -> Void
    @State private var selectingClient = false
    @State private var configurationMessage: String?
    @State private var editingSender = false
    @State private var originalSender: String?
    @State private var senderAddress = ""
    @State private var senderError: String?
    @State private var replacingScan = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFSettingsPageHeader("Email Statements", subtitle: "Collect originals from the senders and received dates you select.") {
                Button("Open Import Centre", action: openImportCentre).lfSecondaryAction()
            }
            connectionPanel
            LFSettingsColumns(availableWidth: availableWidth, leadingFraction: 0.58, minimumWidth: 1040) {
                sendersPanel
            } trailing: {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    datesPanel
                    collectionControls
                }
            }
            collectionProgress
            if let message = session.message {
                Text(message).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("emailStatements.status")
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Text("Removing a sender keeps saved originals.")
                Text("Collection retrieves originals; review and import them in Import Centre.")
                DisclosureGroup("Collection and storage details") {
                    Text("Originals and intake receipts are retained with your ledger and included in LedgerForge backups. Gmail messages and labels are unchanged. IBKR and Zurich ISP use their existing separate paths.")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, theme.spacing.small)
                }
            }
            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
        .foregroundStyle(theme.palette.primaryText)
        .environment(\.timeZone, TimeZone(identifier: session.timeZoneIdentifier) ?? .gmt)
        .sheet(isPresented: $editingSender) { [originalSender] in
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                Text(originalSender == nil ? "Add sender" : "Edit sender").font(theme.typography.rowTitle)
                TextField("Email address", text: $senderAddress).textFieldStyle(.roundedBorder)
                    .onSubmit(saveSender)
                if let senderError { Text(senderError).font(theme.typography.secondary).foregroundStyle(LFTheme.warning) }
                HStack {
                    Spacer()
                    Button("Cancel") { editingSender = false }.keyboardShortcut(.cancelAction)
                    Button("Save", action: saveSender).keyboardShortcut(.defaultAction)
                }
            }
            .padding(theme.spacing.pagePadding).frame(width: 440)
        }
        .confirmationDialog("Start a new collection?", isPresented: $replacingScan) {
            Button("Fetch selected senders") { session.collectSelectedRange(replaceIncomplete: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved originals and receipts will remain. This replaces the unfinished scan with your selected senders and dates; the old scan will not count as complete.")
        }
        .fileImporter(isPresented: $selectingClient, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0, size <= 32_768 else { throw GmailIntakeError.configurationRequired }
                let data = try Data(contentsOf: url)
                _ = try GmailDesktopClient.read(data)
                configurationMessage = nil
                session.connect(configuration: data)
            } catch {
                configurationMessage = "Choose the existing Desktop OAuth client JSON used for this Gmail connection."
            }
        }
    }


    private var connectionPanel: some View {
        LFPanel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: theme.spacing.sectionGap) {
                    connectionIdentity
                    Spacer(minLength: theme.spacing.sectionGap)
                    connectionControls
                }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    connectionIdentity
                    connectionControls
                }
            }
            if let configurationMessage {
                Text(configurationMessage).font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var connectionIdentity: some View {
        HStack(alignment: .top, spacing: theme.spacing.controlGap) {
            Image(systemName: "envelope").font(theme.typography.sectionIcon)
                .foregroundStyle(theme.palette.secondaryText).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                if let account = session.account {
                    Text(account).font(theme.typography.rowTitle).textSelection(.enabled)
                }
                Text(session.connectionSummary).font(theme.typography.secondary)
                    .foregroundStyle(session.isConnected ? theme.palette.secondaryText : LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var connectionControls: some View {
        if !session.isCollecting {
            if session.needsClientConfiguration {
                Button("Select existing OAuth client…") { selectingClient = true }.lfSecondaryAction()
            } else if session.needsAuthorization {
                Button("Reconnect in browser…") { session.connect(reauthorize: true) }
                    .lfSecondaryAction().disabled(session.isChecking)
            } else {
                Button(session.isConnected ? "Check connection" : "Use saved connection", systemImage: "link") {
                    session.connect()
                }
                .lfSecondaryAction().disabled(session.isChecking)
            }
        }
    }

    private var sendersPanel: some View {
        LFPanel(title: "Senders", trailing: AnyView(Text("\(session.selectedSenders.count) / \(session.senderRules.count) selected")
            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText))) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.spacing.small) {
                    ForEach(session.senderRules) { rule in
                        HStack(spacing: theme.spacing.controlGap) {
                            Toggle("Include \(rule.address)", isOn: Binding(
                                get: { rule.isSelected },
                                set: { session.selectSender(rule.address, selected: $0) }))
                                .toggleStyle(.checkbox).labelsHidden()
                            Button { session.selectedSenderAddress = rule.address } label: {
                                Text(rule.address).font(theme.typography.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(LFPlainActionStyle())
                            .accessibilityLabel("Select sender \(rule.address) for editing")
                        }
                        .padding(theme.spacing.small)
                        .background(session.selectedSenderAddress == rule.address ? theme.palette.accent.opacity(0.14) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                        if rule.id != session.senderRules.last?.id { Divider().overlay(theme.palette.divider) }
                    }
                }
            }
            .frame(height: max(260, theme.typography.size(.body) * 16))
            .disabled(!session.canEditSenders)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) { senderControls }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) { senderControls }
            }
        }
    }

    @ViewBuilder private var senderControls: some View {
        Button("Add sender…", systemImage: "plus") {
            originalSender = nil; senderAddress = ""; senderError = nil; editingSender = true
        }.lfSecondaryAction().disabled(!session.canEditSenders)
        Button("Edit sender…") {
            originalSender = session.selectedSenderAddress
            senderAddress = originalSender ?? ""; senderError = nil; editingSender = true
        }.lfSecondaryAction().disabled(!session.canEditSenders || session.selectedSenderAddress == nil)
        Button("Remove sender", action: session.removeSelectedSender)
            .lfSecondaryAction().disabled(!session.canEditSenders || session.selectedSenderAddress == nil)
    }

    private var datesPanel: some View {
        LFPanel(title: "Email delivery dates") {
            Toggle("All available history", isOn: $session.allHistory).toggleStyle(.checkbox)
                .font(theme.typography.body)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.sectionGap) { dateControls }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) { dateControls }
            }
            .disabled(session.allHistory)
            Picker("Timezone", selection: $session.timeZoneIdentifier) {
                Text("UTC").tag("UTC")
                Text("Qatar · UTC+03:00").tag("Asia/Qatar")
            }
            .font(theme.typography.secondary).tint(theme.palette.primaryText)
            Text("Both calendar days are included. Collection uses the email's received time and stops at a fixed time when it starts.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let covered = session.completedThroughForSelection {
                Divider().overlay(theme.palette.divider)
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text("Last complete interval for these senders ended")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    Text(AppDateDisplay.timestamp(covered, zone: TimeZone(secondsFromGMT: 0)!))
                        .font(theme.typography.rowTitle)
                }
            }
            if let scan = session.inbox?.activeScan {
                Text("An incomplete collection for \(scan.interval.senders.count) senders is saved through \(AppDateDisplay.timestamp(scan.interval.until, zone: TimeZone(secondsFromGMT: 0)!)). Resume uses that saved sender selection.")
                    .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(session.isCollecting)
    }

    @ViewBuilder private var dateControls: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("From").foregroundStyle(theme.palette.secondaryText)
            DatePicker("From", selection: $session.fromDate, displayedComponents: .date)
                .datePickerStyle(.field).labelsHidden().accessibilityLabel("From")
        }
        .font(theme.typography.secondary)
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("To").foregroundStyle(theme.palette.secondaryText)
            DatePicker("To", selection: $session.throughDate, displayedComponents: .date)
                .datePickerStyle(.field).labelsHidden().accessibilityLabel("To")
        }
        .font(theme.typography.secondary)
    }

    @ViewBuilder private var collectionControls: some View {
        if session.isCollecting {
            Button("Stop collection", action: session.cancelCollection).lfSecondaryAction()
        } else {
            Button("Fetch selected senders", systemImage: "tray.and.arrow.down") {
                if session.inbox?.activeScan != nil { replacingScan = true }
                else { session.collectSelectedRange() }
            }
            .buttonStyle(LFActionButtonStyle(kind: .primary, wide: true))
            .disabled(!session.canStartCollection).accessibilityIdentifier("emailStatements.collect")
            if session.inbox?.activeScan != nil {
                Button("Resume collection", action: session.resumeCollection)
                    .buttonStyle(LFActionButtonStyle(kind: .secondary, wide: true)).disabled(!session.canCollect)
            } else if session.completedThroughForSelection != nil {
                Button("Collect since last complete", action: session.collectIncremental)
                    .buttonStyle(LFActionButtonStyle(kind: .secondary, wide: true)).disabled(!session.canStartCollection)
            }
        }
    }

    @ViewBuilder private var collectionProgress: some View {
        if session.isCollecting || session.progress.isComplete {
            LFPanel(title: session.isCollecting ? "Collecting originals" : "Collection saved", systemImage: "tray.and.arrow.down") {
                if session.isCollecting { ProgressView().controlSize(.small) }
                Text("\(session.progress.accountedMessages) messages accounted for · \(session.progress.downloadedOriginals) originals saved · \(session.progress.reusedOriginals) reused")
                    .font(theme.typography.secondary).monospacedDigit()
                if session.progress.unavailableOriginals > 0 {
                    Text("\(session.progress.unavailableOriginals) originals unavailable or held at collection.")
                        .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                }
            }
        }
    }

    private func saveSender() {
        do {
            try session.saveSender(senderAddress, replacing: originalSender)
            editingSender = false
        } catch { senderError = error.localizedDescription }
    }

}

struct EmailInboxQueueView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: GmailIntakeSession

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack {
                Label("Email originals", systemImage: "tray.full").font(theme.typography.rowTitle)
                Spacer()
                Text(session.isReconciled
                     ? "\(session.sources.count) retained · \(session.batchSources.count) awaiting import"
                     : (session.reconciliationError == nil ? "Checking imported originals…" : "Import check unavailable"))
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
            if let error = session.reconciliationError {
                Text(error).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                Button("Retry import check") { Task { await session.reloadInbox() } }.lfSecondaryAction()
            }
            List(selection: $session.selectedSourceID) {
                ForEach(session.sources) { source in
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(source.displayName).font(theme.typography.secondary).lineLimit(2)
                        Text("\(source.family.displayName) · \(session.status(for: source))")
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        Text("Received \(AppDateDisplay.timestamp(Date(timeIntervalSince1970: Double(source.receivedMilliseconds) / 1_000)))")
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, theme.spacing.small)
                    .contentShape(Rectangle())
                    .tag(source.id)
                    .accessibilityLabel("\(source.displayName), \(session.status(for: source))")
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(height: 280)
            .accessibilityIdentifier("emailOriginals.list")
        }
    }
}
