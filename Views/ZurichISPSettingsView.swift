import SwiftUI

struct ZurichISPSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: ZurichISPSyncSession
    @ObservedObject var backgroundUpdates: BackgroundUpdatesSession
    @State private var username = ""
    @State private var password = ""
    @State private var memorablePIN = ""
    @State private var editsConnection = false
    @State private var editsName = false
    @State private var credentialName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            Text("ISP Account").font(theme.typography.formHeading)
            Text("Current Zurich holdings, with statement import available as a backup.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            LFPanel(title: session.username == nil ? "Connect your account" : "Zurich connection", systemImage: "link") {
                Text(session.connectionSummary).font(theme.typography.rowTitle)
                if let connectedUsername = session.username {
                    LabeledContent("Saved credential", value: session.credentialLabel ?? ZurichISPCredentialStore.defaultLabel)
                    LabeledContent("Username", value: connectedUsername)
                    Text("Login password and memorable PIN are saved together in Keychain.")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: theme.spacing.controlGap) { connectionActions }
                        VStack(alignment: .leading, spacing: theme.spacing.small) { connectionActions }
                    }
                    if editsName {
                        HStack(spacing: theme.spacing.controlGap) {
                            TextField("Credential name", text: $credentialName)
                            Button("Save name") { session.renameCredential(to: credentialName); editsName = false }
                                .lfSecondaryAction().disabled(credentialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.frame(maxWidth: 460).textFieldStyle(.roundedBorder)
                    }
                }
                if session.username == nil || editsConnection {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        TextField("Username", text: $username)
                        LFPasswordField("Password", text: $password)
                        LFPasswordField("Memorable PIN", text: $memorablePIN)
                        if session.username != nil {
                            Text("Leave password or PIN blank to keep the saved value.")
                                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        }
                        Button("Connect and fetch holdings", systemImage: "link") {
                            let credentials = ZurichISPCredentials(username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password, memorablePIN: memorablePIN)
                            editsConnection = true
                            if session.username == nil { session.connect(credentials) }
                            else { session.replaceCredentials(credentials) }
                        }
                        .lfPrimaryAction()
                        .disabled(session.isBusy || username.isEmpty || (session.username == nil && (password.isEmpty || memorablePIN.isEmpty)))
                        if session.username == nil {
                            Button("Move saved Zurich connection", systemImage: "key") { session.usePilotConnection() }
                                .lfSecondaryAction().disabled(session.isBusy)
                            Text("Moves the saved Zurich login into LedgerForge’s Keychain group after verifying the saved connection and a complete holdings fetch.")
                                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 460, alignment: .leading)
                    .disabled(session.isBusy)
                }
                if session.isBusy {
                    HStack(spacing: theme.spacing.controlGap) {
                        ProgressView().controlSize(.small)
                        Button("Cancel") { session.cancel() }.lfSecondaryAction()
                    }
                }
                if let message = session.message {
                    Text(message).font(theme.typography.secondary)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
            .disabled(!session.isConnectionAvailable)
            LFPanel(title: "Holdings updates", systemImage: "calendar") {
                Text(backgroundUpdates.activeSchedule
                     ? "Schedule in Background Updates"
                     : "Monthly on the 5th · UTC").font(theme.typography.rowTitle)
                Text(backgroundUpdates.activeSchedule
                     ? "Uses the ISP schedule and enabled scope saved in Background Updates. Previous holdings stay visible if an update fails."
                     : "Checks at the first opportunity the app is active on or after the 5th. A missed check is caught up on launch or wake. Previous holdings stay visible if an update fails.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                if let fetched = session.lastSuccessfulFetch {
                    LabeledContent("Last successful holdings fetch", value: AppDateDisplay.timestamp(fetched, zone: TimeZone(secondsFromGMT: 0)!))
                    LabeledContent("Portal valuation date", value: session.sourceValuationDates.map(InvestmentPriceDates.display).joined(separator: " · "))
                }
                Text("Public FE fund prices refresh separately in Live FX. Portal valuation dates and successful fetch times describe different events.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
            SalaryISPVerificationSettings(session: session, backgroundUpdates: backgroundUpdates)
        }
        .foregroundStyle(theme.palette.primaryText)
        .onAppear { username = session.username ?? "" }
        .onChange(of: session.completedConnectionID) { _, completed in
            guard completed != nil else { return }
            password = ""; memorablePIN = ""; editsConnection = false
        }
    }

    @ViewBuilder private var connectionActions: some View {
        Button("Fetch ISP holdings", systemImage: "arrow.clockwise") { session.fetchHoldings() }
            .lfPrimaryAction().disabled(session.isBusy)
        Button("Check connection") { session.checkConnection() }.lfSecondaryAction().disabled(session.isBusy)
        Button("Replace password or PIN") { editsConnection.toggle() }.lfSecondaryAction().disabled(session.isBusy)
        Button("Rename") { credentialName = session.credentialLabel ?? ZurichISPCredentialStore.defaultLabel; editsName.toggle() }
            .lfSecondaryAction().disabled(session.isBusy)
        Button("Disconnect") { session.disconnect() }.lfSecondaryAction().disabled(session.isBusy)
    }
}

private struct SalaryISPVerificationSettings: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject private var intelligence = FinancialIntelligenceStore.shared
    @ObservedObject var session: ZurichISPSyncSession
    @ObservedObject var backgroundUpdates: BackgroundUpdatesSession
    @State private var enabled = false
    @State private var time = "00:00"
    @State private var baseline: IntelligencePreferences?
    @State private var generation: ProviderGenerationToken?
    @State private var message: String?
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pending: (() -> Void)?
#endif

    var body: some View {
        LFPanel(title: "After salary is received", systemImage: "checkmark.circle") {
            Toggle("Check ISP after a recognized bank salary credit", isOn: $enabled)
            HStack {
                Text("Daily check · UTC")
                TextField("HH:mm", text: $time).textFieldStyle(.roundedBorder).frame(width: 90).accessibilityLabel("Salary ISP check time in UTC")
                Button("Save check settings", action: save).lfSecondaryAction()
                    .disabled(intelligence.snapshot == nil || generation != intelligence.generation)
            }
            Text(backgroundUpdates.activeSchedule ? "Uses the existing background service and ISP connection." : "Checks while LedgerForge is open. This switch does not enable the background service.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text("One daily opportunity; a qualifying manual or monthly fetch is reused. An unverified update is flagged 10 calendar days after the bank credit and remains checkable until dismissed. Travel does not change the UTC schedule.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if intelligence.snapshot?.salaries.isEmpty ?? true {
                Text("No recognized bank salary credits are awaiting review. Select your regular-salary rules in Budget Planning → Salary assistance.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            ForEach((intelligence.snapshot?.salaries ?? []).sorted { $0.financialDate > $1.financialDate }) { salary in
                VStack(alignment: .leading, spacing: 7) {
                    Divider()
                    HStack {
                        Text("Salary received \(salary.financialDate)").font(theme.typography.body.weight(.semibold))
                        Spacer()
                        Text(status(salary)).foregroundStyle(flagged(salary) ? LFTheme.warning : theme.palette.secondaryText)
                        Button(salary.ispState == .dismissed ? "Revisit" : "Dismiss check") {
                            change {
                                guard let generation else { throw FinancialIntelligenceError.unavailable }
                                var value = salary
                                value.ispState = salary.ispState == .dismissed ? .unverified : .dismissed
                                try FinancialIntelligenceCoordinator().applyPlanning(.salary(value, replacing: salary), generation: generation)
                            }
                        }.lfSecondaryAction()
                    }
                    Text(salary.ispExplanation).font(theme.typography.secondary).textSelection(.enabled)
                    if let fetched = salary.ispLastFetchAt { Text("Shared fetch: \(AppDateDisplay.isoTimestamp(fetched, zone: TimeZone(secondsFromGMT: 0)!))").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
                    if let threshold = SalaryISPVerification.threshold(salary) { Text("Review threshold: \(AppDateDisplay.date(threshold, zone: TimeZone(secondsFromGMT: 0)!)) · UTC").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
                }
            }
            Text("A holdings update or cumulative contribution change alone cannot prove which salary funded it. The check never creates units or acquisition cost.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            if let message { Text(message).foregroundStyle(LFTheme.warning) }
        }
        .onAppear { reloadDraft() }
#if DEBUG
        .alert(DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pending = nil } })) {
                Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                    if let challenge { _ = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) }
                    let action = pending; pending = nil; challenge = nil; action?()
                }
                Button("Cancel", role: .cancel) { pending = nil; challenge = nil }
            } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }
    private func flagged(_ salary: SalaryAssistance) -> Bool {
        ![.verified, .dismissed].contains(salary.ispState) && SalaryISPVerification.threshold(salary).map { $0 <= Date() } == true
    }
    private func status(_ salary: SalaryAssistance) -> String {
        if salary.ispState == .dismissed { return "Dismissed" }
        if salary.ispState == .verified { return "Verified" }
        return flagged(salary) ? "Unverified · review due" : "Contribution unverified"
    }
    private func reloadDraft() {
        baseline = intelligence.snapshot?.preferences; generation = intelligence.generation
        enabled = baseline?.salaryISPEnabled ?? false
        let minute = baseline?.salaryISPMinuteUTC ?? 0
        time = String(format: "%02d:%02d", minute / 60, minute % 60)
    }
    private func save() {
        change {
            let parts = time.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0...23).contains(hour), (0...59).contains(minute),
                  let metadata = intelligence.snapshot, let generation else { throw BackgroundScheduleError.invalidConfiguration }
            var value = baseline ?? .init(workspaceID: metadata.workspaceID)
            value.salaryISPEnabled = enabled; value.salaryISPMinuteUTC = hour * 60 + minute
            try FinancialIntelligenceCoordinator().applyPlanning(.preferences(value, replacing: baseline), generation: generation)
            baseline = value; message = "Check settings saved."
            backgroundUpdates.reload()
        }
    }
    private func change(_ operation: @escaping () throws -> Void) {
        do { try operation(); message = nil }
        catch {
#if DEBUG
            if case DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) = error {
                challenge = value; pending = { change(operation) }; return
            }
#endif
            message = error.localizedDescription
        }
    }
}
