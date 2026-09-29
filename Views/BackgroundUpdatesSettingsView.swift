import SwiftUI

struct BackgroundUpdatesSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: BackgroundUpdatesSession
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
            LFPanel(title: "Background Updates", systemImage: "clock.arrow.circlepath") {
                Toggle("Enable background helper for this ledger", isOn: $draft.enabled).toggleStyle(.switch)
                Text(session.status).font(theme.typography.secondary)
                Text("Choose what is updated while LedgerForge is closed. All times are UTC and stay the same when you travel. macOS runs updates when the Mac is available; this does not wake it.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                if let next = session.nextUpdate {
                    LFInfoRow(title: "Next opportunity", value: AppDateDisplay.timestamp(next, zone: TimeZone(secondsFromGMT: 0)!), textRole: .secondary)
                }
                if !draft.enabled {
                    Text("When off, the existing foreground schedules apply. ISP holdings update on or after the fifth of the month in UTC.")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            }
            LFPanel(title: "Public rates and prices", systemImage: "arrow.triangle.2.circlepath") {
                Toggle("Al Dar currency rates", isOn: $draft.alDarCurrencyRatesEnabled)
                Toggle("Investment public prices", isOn: $draft.investmentPublicPricesEnabled)
                BackgroundClockEditor(draft: $publicClock)
                Text("Both use this schedule. Failed updates retry once after 60 seconds; successful updates and previous good values are kept.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                result(.publicReferences)
            }
            LFPanel(title: "Email statement originals", systemImage: "envelope") {
                Toggle("Collect Gmail originals", isOn: $draft.gmailCollectionEnabled)
                BackgroundClockEditor(draft: $gmailClock)
                Text("Uses the senders selected in Email Statements and collects the full missed delivery interval. New originals wait in Import Centre for your batch action.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                result(.gmailCollection)
            }
            LFPanel(title: "ISP holdings", systemImage: "link") {
                Toggle("Update Zurich ISP holdings", isOn: $draft.zurichISPHoldingsEnabled)
                BackgroundClockEditor(draft: $ispClock)
                Text("Updates current holdings once after an absence. Public FE prices use the public-prices schedule above.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                result(.zurichISP)
            }
            LFPanel(title: "Apply settings", systemImage: "checkmark.circle") {
                HStack(spacing: theme.spacing.controlGap) {
                    Button(session.isSaving ? "Saving…" : "Save background settings") {
                        if let candidate { session.save(candidate, replacing: baseline) }
                    }
                    .lfPrimaryAction().disabled(candidate == nil || !session.available || session.isSaving || !isDirty)
                    Button("Reset draft to defaults") { install(BackgroundScheduleConfiguration(), updateBaseline: false) }
                        .lfSecondaryAction().disabled(session.isSaving)
                }
                if candidate == nil {
                    Text("Choose at least one weekday or month day, and enter distinct UTC times as HH:mm, separated by commas.")
                        .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                }
                if let message = session.message { Text(message).font(theme.typography.secondary).textSelection(.enabled) }
                Button("Authorize saved connections for helper") {
                    session.save(session.configuration, replacing: session.configuration, authorizeConnections: true)
                }
                .lfSecondaryAction().disabled(!session.configuration.enabled || isDirty || session.isSaving || !session.available)
                Text("Use this action if macOS needs one-time access approval for the existing Gmail or ISP connection. Scheduled updates never show a password prompt.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .toggleStyle(.checkbox)
        .font(theme.typography.secondary)
        .onAppear { if !loaded { install(session.configuration); loaded = true } }
        .onChange(of: session.configuration) { _, value in
            // A status refresh must not overwrite an edited settings draft.
            if !isDirty || candidate == value { install(value) }
        }
    }

    @ViewBuilder private func result(_ kind: BackgroundJobKind) -> some View {
        if let record = session.jobRecords[kind] {
            if let outcome = record.outcome {
                Text(BackgroundUpdatesSession.summary(.completed(outcome)))
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
            if let date = record.completedAt {
                LFInfoRow(title: "Last attempt", value: AppDateDisplay.timestamp(date, zone: TimeZone(secondsFromGMT: 0)!), textRole: .secondary)
            }
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
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Picker("Repeat", selection: $draft.monthly) {
                Text("Selected weekdays").tag(false)
                Text("Monthly dates").tag(true)
            }.pickerStyle(.segmented).frame(maxWidth: 440)
            if draft.monthly {
                LabeledContent("Days of month") { TextField("1", text: $draft.days).frame(maxWidth: 260) }
                    .frame(maxWidth: 440)
                Text("Use days 1–31, separated by commas. Days beyond a short month's end run on its last day.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { dayButtons }
                    VStack(alignment: .leading) { dayButtons }
                }
            }
            LabeledContent("Times (UTC)") { TextField("00:00", text: $draft.times).frame(maxWidth: 340) }
                .frame(maxWidth: 540)
            Text("24-hour format · separate multiple times with commas")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
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
