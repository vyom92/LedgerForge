import SwiftUI

struct IBKRFlexSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: IBKRFlexSyncSession
    @ObservedObject var backgroundUpdates: BackgroundUpdatesSession
    var availableWidth: CGFloat = 0
    @State private var token = ""
    @State private var query = ""
    @State private var account = ""
    @State private var expiry = ""
    @State private var confirmedScope = false
    @State private var weekly = true
    @State private var weekday = 2
    @State private var hour = 6
    @State private var loaded = false

    private var entered: IBKRFlexCredentials {
        .init(token: token, queryID: query, expectedAccountID: account,
              ownerReportedExpiry: expiry.isEmpty ? nil : expiry, summaryUnfilteredOwnerConfirmed: confirmedScope)
    }
    private var canConnect: Bool {
        !session.isBusy && !backgroundUpdates.isSaving && session.isConnectionAvailable && confirmedScope && !query.isEmpty && !account.isEmpty
            && (!token.isEmpty || session.accountID != nil)
    }
    private var scheduleDirty: Bool {
        weekly != backgroundUpdates.configuration.ibkrFlexHoldingsEnabled
            || .selectedWeekdays(weekdays: [weekday], timesUTC: [hour * 60]) != backgroundUpdates.configuration.ibkrFlexRule
    }
    private var readingWidth: CGFloat { theme.typography.size(.body) * 40 }
    private var factColumns: [GridItem] {
        [GridItem(.adaptive(minimum: max(260, theme.typography.size(.body) * 18)),
                  spacing: theme.spacing.sectionGap, alignment: .leading)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFSettingsPageHeader("IBKR connection", subtitle: "Holdings and prices from your Flex report, as of its report date.")
            connectionSummaryPanel
            LFSettingsColumns(availableWidth: availableWidth, leadingFraction: 0.64, minimumWidth: 1040) {
                setupPanel
            } trailing: {
                weeklyPanel
            }
        }
        .font(theme.typography.body)
        .foregroundStyle(theme.palette.primaryText)
        .textFieldStyle(.roundedBorder)
        .onAppear {
            if !loaded { installMetadata(); installSchedule(); loaded = true }
        }
        .onChange(of: session.accountID) { _, _ in if token.isEmpty { installMetadata() } }
        .onChange(of: session.completedConnectionID) { _, value in
            guard value != nil else { return }
            token = ""; installMetadata()
        }
        .onDisappear { token = "" }
    }

    private var connectionSummaryPanel: some View {
        LFPanel {
            Text(session.connectionSummary).font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                    connectionFacts
                    VStack(alignment: .trailing, spacing: theme.spacing.small) { refreshActions }
                }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    connectionFacts
                    refreshActions
                }
            }
            if session.accountID != nil || session.expiry != nil {
                DisclosureGroup("Saved connection details") {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        if let account = session.accountID {
                            LabeledContent("Account", value: account)
                            LabeledContent("Query ID", value: session.queryID ?? "Unavailable")
                        }
                        if let expiry = session.expiry {
                            LabeledContent("Token expiry · entered at setup", value: expiry)
                        }
                    }
                    .font(theme.typography.secondary).textSelection(.enabled)
                    .padding(.top, theme.spacing.small)
                }
                .font(theme.typography.secondary)
            }
            if session.isBusy { ProgressView().controlSize(.small) }
            if let message = session.message {
                Text(message).font(theme.typography.body).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled).id(message).accessibilityIdentifier("ibkr.status")
            }
        }
    }

    private var setupPanel: some View {
        LFPanel(title: session.accountID == nil ? "Set up Flex" : "Replace token or query") {
                supportingText("Create or renew your token in IBKR Client Portal, then paste it here. LedgerForge checks the new connection before replacing the saved one.")
                entryField("Flex token") {
                    SecureField(session.accountID == nil ? "Enter token" : "Blank keeps the saved token", text: $token)
                        .accessibilityIdentifier("ibkr.token")
                }
                LazyVGrid(columns: factColumns, alignment: .leading, spacing: theme.spacing.sectionGap) {
                    entryField("Query ID") {
                        TextField("Activity Flex Query ID", text: $query).accessibilityIdentifier("ibkr.query")
                    }
                    entryField("Account ID") {
                        TextField("IBKR account", text: $account).accessibilityIdentifier("ibkr.account")
                    }
                }.frame(maxWidth: readingWidth, alignment: .leading)
                entryField("Token expiry (optional)") {
                    TextField("Date shown in IBKR Client Portal", text: $expiry)
                }
                Toggle("My query includes all Open Positions, Summary only, with no holding filters.", isOn: $confirmedScope)
                    .toggleStyle(.checkbox)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: readingWidth, alignment: .leading)
                reportSetupInstructions
                ViewThatFits(in: .horizontal) {
                    HStack { connectionActions }
                    VStack(alignment: .leading) { connectionActions }
                }
        }
    }

    private var weeklyPanel: some View {
        LFPanel(title: "Weekly refresh") {
                Toggle("Refresh IBKR automatically every week", isOn: $weekly).toggleStyle(.switch)
                    .accessibilityIdentifier("ibkr.weekly")
                ViewThatFits(in: .horizontal) {
                    HStack { scheduleFields }
                    VStack(alignment: .leading) { scheduleFields }
                }
                supportingText(backgroundUpdates.activeSchedule
                     ? "Updates can run even when LedgerForge is closed. If your Mac misses a scheduled update, it checks once when available again."
                     : "Weekly updates run while LedgerForge is open. Enable Background Updates to also update while the app is closed.")
                Button("Apply IBKR schedule") { saveSchedule() }
                    .lfSecondaryAction().disabled(!scheduleDirty || backgroundUpdates.isSaving || session.accountID == nil)
                    .accessibilityIdentifier("ibkr.applySchedule")
                if let message = backgroundUpdates.message { supportingText(message) }
                supportingText("Email statements are a backup. They won’t overwrite holdings updated by this connection.")
        }
    }

    private var connectionFacts: some View {
        LazyVGrid(columns: factColumns, alignment: .leading, spacing: theme.spacing.sectionGap) {
            if let date = session.reportDate {
                connectionFact("Report date", value: InvestmentPriceDates.display(date))
                connectionFact("Holdings", value: String(session.positionCount))
            }
            if let fetched = session.lastSuccessfulFetch {
                connectionFact("Last updated", value: AppDateDisplay.timestamp(fetched, zone: .current))
            }
        }
        .frame(maxWidth: theme.typography.size(.body) * 60, alignment: .leading)
    }

    private func connectionFact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.body).foregroundStyle(theme.palette.secondaryText)
            Text(value).font(theme.typography.rowTitle).textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func entryField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.secondary)
            content().font(theme.typography.body).accessibilityLabel(title)
        }
        .frame(maxWidth: readingWidth, alignment: .leading)
    }

    private func supportingText(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.body)
            .foregroundStyle(theme.palette.secondaryText)
            .lineSpacing(theme.spacing.micro)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: readingWidth, alignment: .leading)
    }

    private var reportSetupInstructions: some View {
        DisclosureGroup("Report setup instructions") {
            VStack(alignment: .leading, spacing: theme.spacing.rowGap) {
                supportingText("In IBKR Client Portal, create an Activity Flex Query with these settings:")
                Text("Format: XML\nPeriod: Last Business Day\nOpen Positions: Summary only\nHolding filters: none")
                    .lineSpacing(theme.spacing.micro)
                Text("Required report fields").font(theme.typography.rowTitle)
                supportingText("Identification: account ID, currency, symbol, description, conid, ISIN, security ID and type, listing exchange, asset category and subcategory.")
                supportingText("Values: report date, quantity, multiplier, mark price, position value, cost basis price and money, and unrealized P/L.")
                supportingText("Structure: side and level of detail.")
            }
            .padding(.top, theme.spacing.rowGap)
        }
        .frame(maxWidth: readingWidth, alignment: .leading)
    }

    @ViewBuilder private var refreshActions: some View {
        Button("Refresh now", systemImage: "arrow.clockwise") { session.refresh() }.lfSecondaryAction()
            .disabled(session.isBusy || backgroundUpdates.isSaving || !session.isConnectionAvailable).accessibilityIdentifier("ibkr.refresh")
        if session.canCancel { Button("Cancel") { session.cancel() }.lfSecondaryAction() }
        if session.accountID != nil {
            Button("Disconnect") {
                weekly = false
                saveSchedule { saved in if saved { session.disconnect() } }
            }.lfSecondaryAction().disabled(session.isBusy || backgroundUpdates.isSaving)
        }
    }
    @ViewBuilder private var connectionActions: some View {
        Button(session.accountID == nil ? "Connect and update holdings" : "Verify and save connection") {
            session.connect(entered)
        }.lfPrimaryAction().disabled(!canConnect).accessibilityIdentifier("ibkr.connect")
        if session.accountID == nil {
            Button("Use saved proof token") { session.useSavedProofToken() }
                .lfSecondaryAction().disabled(session.isBusy || backgroundUpdates.isSaving || !session.isConnectionAvailable)
                .accessibilityIdentifier("ibkr.useSavedToken")
        }
        Link("Open IBKR Client Portal", destination: URL(string: "https://www.interactivebrokers.com/sso/Login")!)
    }
    @ViewBuilder private var scheduleFields: some View {
        Picker("Day (UTC)", selection: $weekday) {
            Text("Monday").tag(2); Text("Tuesday").tag(3); Text("Wednesday").tag(4)
            Text("Thursday").tag(5); Text("Friday").tag(6); Text("Saturday").tag(7); Text("Sunday").tag(1)
        }.tint(theme.palette.primaryText).frame(maxWidth: 270)
        Picker("Time (UTC)", selection: $hour) {
            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
        }.tint(theme.palette.primaryText).frame(maxWidth: 220)
    }
    private func installMetadata() {
        query = session.queryID ?? query; account = session.accountID ?? account; expiry = session.expiry ?? expiry
        if session.accountID != nil { confirmedScope = true }
    }
    private func installSchedule() {
        let value = backgroundUpdates.configuration
        // First connection defaults to the weekly behavior requested by the owner.
        weekly = session.accountID == nil ? true : value.ibkrFlexHoldingsEnabled
        if case let .selectedWeekdays(days, minutes) = value.ibkrFlexRule,
           days.count == 1, minutes.count == 1 { weekday = days.first!; hour = minutes[0] / 60 }
    }
    private func saveSchedule(completion: ((Bool) -> Void)? = nil) {
        guard scheduleDirty else { completion?(true); return }
        backgroundUpdates.saveIBKRSchedule(enabled: weekly,
            rule: .selectedWeekdays(weekdays: [weekday], timesUTC: [hour * 60]),
            replacing: backgroundUpdates.configuration, completion: completion)
    }
}
