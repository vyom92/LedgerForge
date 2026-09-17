import SwiftUI

struct ZurichISPSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: ZurichISPSyncSession
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
                        SecureField("Password", text: $password)
                        SecureField("Memorable PIN", text: $memorablePIN)
                        if session.username != nil {
                            Text("Leave password or PIN blank to keep the saved value.")
                                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        }
                        Button("Connect and fetch holdings", systemImage: "link") {
                            let credentials = ZurichISPCredentials(username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password, memorablePIN: memorablePIN)
                            if session.username == nil { session.connect(credentials) }
                            else { session.replaceCredentials(credentials) }
                            password = ""; memorablePIN = ""; editsConnection = false
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
            LFPanel(title: "Holdings updates", systemImage: "calendar") {
                Text("Monthly on the 5th · UTC").font(theme.typography.rowTitle)
                Text("Checks at the first opportunity the app is active on or after the 5th. A missed check is caught up on launch or wake. Previous holdings stay visible if an update fails.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                if let fetched = session.lastSuccessfulFetch {
                    LabeledContent("Last successful holdings fetch", value: fetched.formatted(.iso8601))
                    LabeledContent("Portal valuation date", value: session.sourceValuationDates.map(InvestmentPriceDates.display).joined(separator: " · "))
                }
                Text("Public FE fund prices refresh separately in Live FX. Portal valuation dates and successful fetch times describe different events.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .foregroundStyle(theme.palette.primaryText)
        .onAppear { username = session.username ?? "" }
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
