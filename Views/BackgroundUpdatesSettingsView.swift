import SwiftUI

struct BackgroundUpdatesSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: BackgroundUpdatesSession
    var availableWidth: CGFloat = 0
    @State private var baseline = BackgroundScheduleConfiguration()
    @State private var draft = BackgroundScheduleConfiguration()
    @State private var publicClock = BackgroundClockDraft(BackgroundScheduleConfiguration.defaultPublicRule)
    @State private var gmailClock = BackgroundClockDraft(BackgroundScheduleConfiguration.defaultGmailRule)
    @State private var ispClock = BackgroundClockDraft(BackgroundScheduleConfiguration.defaultISPRule)
    @State private var loaded = false

    private var candidate: BackgroundScheduleConfiguration? {
        guard let publicRule = publicClock.rule, let gmailRule = gmailClock.rule, let ispRule = ispClock.rule else { return nil }
        var value = draft
        value.publicReferencesRule = publicRule; value.gmailRule = gmailRule; value.zurichISPRule = ispRule
        return try? value.validated()
    }
    private var isDirty: Bool { candidate != baseline }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFSettingsPageHeader("Background Updates", subtitle: "Schedules stay in UTC when you travel.") {
                Toggle("Enable helper for this ledger", isOn: $draft.enabled)
                    .toggleStyle(.switch)
                    .font(theme.typography.secondary)
                    .accessibilityLabel("Enable background helper for this ledger")
            }
            runtimePanel
            LFSettingsColumns(availableWidth: availableWidth, minimumWidth: 1040) {
                publicPanel
            } trailing: {
                emailPanel
            }
            Text("New email originals wait in Import Centre for your batch action.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            LFSettingsColumns(availableWidth: availableWidth, minimumWidth: 1040) {
                ispPanel
            } trailing: {
                ibkrPanel
            }
            applyPanel
        }
        .toggleStyle(.checkbox)
        .font(theme.typography.body)
        .foregroundStyle(theme.palette.primaryText)
        .onAppear { if !loaded { install(session.configuration); loaded = true } }
        .onChange(of: session.configuration) { _, value in
            // A status refresh must not overwrite an edited settings draft.
            if !isDirty || candidate == value { install(value) }
        }
    }

    private var runtimePanel: some View {
        LFPanel(contentSpacing: theme.spacing.controlGap) {
            Text(session.status)
                .font(theme.typography.rowTitle)
                .foregroundStyle(session.activeSchedule ? LFTheme.success
                    : (session.configuration.enabled ? LFTheme.warning : theme.palette.secondaryText))
            Text("Runs when this Mac is available; it does not wake the Mac.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if let next = session.nextUpdate {
                LFInfoRow(title: "Next opportunity", value: AppDateDisplay.timestamp(next, zone: TimeZone(secondsFromGMT: 0)!), textRole: .secondary)
            }
            if !session.configuration.enabled {
                Text("When off, the existing foreground schedules apply. ISP holdings update on or after the fifth of the month in UTC.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private var publicPanel: some View {
        LFPanel(title: "Public rates and prices") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Toggle("Al Dar currency rates", isOn: $draft.alDarCurrencyRatesEnabled)
                Toggle("Investment public prices", isOn: $draft.investmentPublicPricesEnabled)
            }
            BackgroundClockEditor(draft: $publicClock)
            DisclosureGroup("Retry & retained-value details") {
                Text("Both use this schedule. Failed updates retry once after 60 seconds; successful updates and previous good values are kept.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .padding(.top, theme.spacing.small)
            }
            .font(theme.typography.secondary)
            result(.publicReferences)
        }
    }

    private var emailPanel: some View {
        LFPanel(title: "Email statement originals") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Toggle("Collect Gmail originals", isOn: $draft.gmailCollectionEnabled)
                Text("Uses senders selected in Email Statements.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            BackgroundClockEditor(draft: $gmailClock)
            DisclosureGroup("Collection details") {
                Text("Collects the full missed delivery interval. New originals wait in Import Centre for your batch action.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .padding(.top, theme.spacing.small)
            }
            .font(theme.typography.secondary)
            result(.gmailCollection)
        }
    }

    private var ispPanel: some View {
        LFPanel(title: "ISP holdings") {
            Toggle("Update Zurich ISP holdings", isOn: $draft.zurichISPHoldingsEnabled)
            BackgroundClockEditor(draft: $ispClock)
            Text("Updates current holdings once after an absence. Public FE prices use the public-prices schedule above.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            result(.zurichISP)
        }
    }

    private var ibkrPanel: some View {
        LFPanel(title: "IBKR Flex holdings") {
            Toggle("Update IBKR holdings weekly", isOn: $draft.ibkrFlexHoldingsEnabled)
            Text("Set the weekly day and time, replace the token or refresh manually in IBKR Settings.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            result(.ibkrFlex)
        }
    }

    private var applyPanel: some View {
        LFPanel(title: "Apply settings") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) { saveActions }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) { saveActions }
            }
            if candidate == nil {
                Text("Choose at least one weekday or month day, and enter distinct UTC times as HH:mm, separated by commas.")
                    .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
            }
            if let message = session.message {
                Text(message).font(theme.typography.secondary).textSelection(.enabled)
            }
            DisclosureGroup("Helper connection access") {
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    Button("Authorize saved connections for helper") {
                        session.save(session.configuration, replacing: session.configuration, authorizeConnections: true)
                    }
                    .lfSecondaryAction().disabled(!session.configuration.enabled || isDirty || session.isSaving || !session.available)
                    Text("Use this action if macOS needs one-time access approval for the existing Gmail, ISP or IBKR connection. Scheduled updates never show a password prompt.")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
                .padding(.top, theme.spacing.small)
            }
            .font(theme.typography.secondary)
        }
    }

    @ViewBuilder private var saveActions: some View {
        Button(session.isSaving ? "Saving…" : "Save background settings") {
            if let candidate { session.save(candidate, replacing: baseline) }
        }
        .lfPrimaryAction().disabled(candidate == nil || !session.available || session.isSaving || !isDirty)
        Button("Reset draft to defaults") { install(BackgroundScheduleConfiguration(), updateBaseline: false) }
            .lfSecondaryAction().disabled(session.isSaving)
    }

    @ViewBuilder private func result(_ kind: BackgroundJobKind) -> some View {
        if let record = session.jobRecords[kind] {
            if record.outcome != nil || record.completedAt != nil { Divider() }
            if let outcome = record.outcome {
                Text(BackgroundUpdatesSession.summary(.completed(outcome), kind: kind))
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(outcomeColor(outcome))
            }
            if let date = record.completedAt {
                LFInfoRow(title: "Last attempt", value: AppDateDisplay.timestamp(date, zone: TimeZone(secondsFromGMT: 0)!), textRole: .secondary)
            }
        }
    }

    private func outcomeColor(_ outcome: BackgroundJobCompletion) -> Color {
        switch outcome {
        case .installedCache, .collectedNativeReceipts, .committedCurrentHoldings:
            LFTheme.success
        case .retryPending, .failedFinal, .refusedNoCoverage, .refusedCredentialInteraction:
            LFTheme.warning
        }
    }

    private func install(_ value: BackgroundScheduleConfiguration, updateBaseline: Bool = true) {
        if updateBaseline { baseline = value }
        draft = value; publicClock = .init(value.publicReferencesRule)
        gmailClock = .init(value.gmailRule); ispClock = .init(value.zurichISPRule)
    }
}

private struct BackgroundClockDraft {
    var monthly = false
    var weekdays = BackgroundScheduleConfiguration.allWeekdays
    var days = "1"
    var times: String
    init(_ rule: BackgroundScheduleRule) {
        let minutes: [Int]
        switch rule {
        case let .selectedWeekdays(selected, values): weekdays = selected; minutes = values
        case let .monthly(selected, values): monthly = true; days = selected.map(String.init).joined(separator: ", "); minutes = values
        }
        times = minutes.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }.joined(separator: ", ")
    }
    var rule: BackgroundScheduleRule? {
        let tokens = times.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let values = tokens.compactMap { token -> Int? in
            let pieces = token.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count == 2, pieces[0].count == 2, pieces[1].count == 2,
                  let hour = Int(pieces[0]), let minute = Int(pieces[1]), (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return hour * 60 + minute
        }
        guard values.count == tokens.count, !values.isEmpty, Set(values).count == values.count else { return nil }
        if monthly {
            let dayTokens = days.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            let dayValues = dayTokens.compactMap(Int.init)
            guard dayValues.count == dayTokens.count, !dayValues.isEmpty, Set(dayValues).count == dayValues.count,
                  dayValues.allSatisfy({ (1...31).contains($0) }) else { return nil }
            return .monthly(daysUTC: dayValues.sorted(), timesUTC: values.sorted())
        }
        guard !weekdays.isEmpty else { return nil }
        return .selectedWeekdays(weekdays: weekdays, timesUTC: values.sorted())
    }
}

private struct BackgroundClockEditor: View {
    @Environment(\.lfTheme) private var theme
    @Binding var draft: BackgroundClockDraft
    private let weekdays = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Text("Repeat").font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                Picker("Repeat", selection: $draft.monthly) {
                    Text("Selected weekdays").tag(false)
                    Text("Monthly dates").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Schedule repetition")
            }
            if draft.monthly {
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text("Days of month").font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText)
                    TextField("1", text: $draft.days).accessibilityLabel("Days of month")
                    Text("Use days 1–31, separated by commas. Days beyond a short month's end run on its last day.")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: max(56, theme.typography.size(.secondary) * 4.3)), alignment: .leading)],
                          alignment: .leading, spacing: theme.spacing.controlGap) {
                    dayButtons
                }
                .font(theme.typography.secondary)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Text("Times · UTC").font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                TextField("00:00", text: $draft.times).accessibilityLabel("Times in UTC")
                Text("24-hour times · separate multiple times with commas")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .textFieldStyle(.roundedBorder)
    }
    @ViewBuilder private var dayButtons: some View {
        ForEach(weekdays, id: \.0) { day, name in
            Toggle(name, isOn: Binding(get: { draft.weekdays.contains(day) }, set: { selected in
                if selected { draft.weekdays.insert(day) } else { draft.weekdays.remove(day) }
            })).toggleStyle(.checkbox).accessibilityLabel("Run on \(name), UTC")
        }
    }
}
