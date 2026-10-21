import SwiftUI

@MainActor
struct FinancialMCPSettingsView: View {
  @Environment(\.lfTheme) private var theme
  @ObservedObject private var service = FinancialMCPController.shared
  var availableWidth: CGFloat = 0
  @State private var tunnel = ""
  @State private var key = ""
  @State private var permissions = Set<String>()
  @State private var message: String?

  private var hasChanges: Bool {
    tunnel != service.tunnelID || !key.isEmpty || permissions != service.allowed
  }

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
      LFSettingsPageHeader(
        "Financial MCP", subtitle: "Share financial context and allow explicit Budget Planning writes from ChatGPT."
      ) {}
      LFSettingsColumns(availableWidth: availableWidth) {
        sharingPanel
      } trailing: {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
          planningWritePanel
          connectionPanel
          servicePanel
        }
      }
      if let text = message ?? (service.lastFailure.isEmpty ? nil : service.lastFailure) {
        Text(text).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
          .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(
            "financialMCP.message")
      }
    }
    .font(theme.typography.body).foregroundStyle(theme.palette.primaryText)
    .onAppear {
      _ = service.consumeSettingsRequest()
      tunnel = service.tunnelID
      permissions = service.allowed
    }
  }

  private var sharingPanel: some View {
    LFPanel(title: "Information to share") {
      VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
        ForEach(FinancialMCPProtocol.Tool.allCases, id: \.rawValue) { tool in
          VStack(alignment: .leading, spacing: 4) {
            Toggle(
              tool.title,
              isOn: Binding(
                get: { permissions.contains(tool.rawValue) },
                set: {
                  if $0 {
                    permissions.insert(tool.rawValue)
                  } else {
                    permissions.remove(tool.rawValue)
                  }
                }
              )
            )
            .toggleStyle(.checkbox)
            .accessibilityIdentifier("financialMCP.permission." + tool.rawValue)
            Text(tool.fields).font(theme.typography.caption)
              .foregroundStyle(theme.palette.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Text(
          "These read choices take effect when you save. Financial MCP reads the current presentation while LedgerForge is open. Reads do not refresh or save financial data."
        )
        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var planningWritePanel: some View {
    LFPanel(title: "Budget Planning writes") {
      VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
        Toggle(
          "Allow direct Budget Planning writes from ChatGPT",
          isOn: Binding(
            get: { service.planningWriteEnabled },
            set: { service.setPlanningWriteEnabled($0) }
          )
        )
        .toggleStyle(.checkbox)
        .accessibilityIdentifier("financialMCP.planningWriteEnabled")
        Text(
          "Off by default. Also enable Monthly plans sharing to use this. ChatGPT can save exact changes to existing monthly plans after you explicitly ask it to write them. LedgerForge checks the plan revision and requested changes, then saves them directly without another approval step. Planning transfers and investments are instructions, not actual transactions or orders."
        )
        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var connectionPanel: some View {
    LFPanel(title: "ChatGPT connection") {
      VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
        LabeledContent("Tunnel ID") {
          TextField("tunnel_…", text: $tunnel).textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("financialMCP.tunnel")
        }
        LabeledContent("Runtime key") {
          SecureField("Leave blank to keep the saved key", text: $key).textFieldStyle(
            .roundedBorder
          )
          .accessibilityIdentifier("financialMCP.key")
        }
        Text(
          "The runtime key is stored in Keychain. Saving a connection stops the service so you can review the selected information before starting it."
        )
        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        Button("Save connection and sharing choices") {
          do {
            try service.configure(
              tunnel: tunnel.trimmingCharacters(in: .whitespacesAndNewlines),
              key: key.trimmingCharacters(in: .whitespacesAndNewlines), permissions: permissions)
            tunnel = service.tunnelID
            key = ""
            message = "Saved. Start the service when ready."
          } catch { message = error.localizedDescription }
        }
        .lfPrimaryAction()
        .disabled(!hasChanges || tunnel.isEmpty)
        .accessibilityIdentifier("financialMCP.save")
      }
    }
  }

  private var servicePanel: some View {
    LFPanel(title: "Service") {
      VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
        LabeledContent("Connection") {
          let status: LFConnectionStatus = service.state == "Connected" ? .connected :
              (!service.lastFailure.isEmpty && service.desired ? .error : .disconnected)
          Text(status.rawValue).foregroundStyle(status.color)
        }
          .accessibilityIdentifier("financialMCP.status")
        LabeledContent("Last financial request", value: service.lastInvocation)
        Toggle(
          "Start Financial MCP when LedgerForge launches",
          isOn: Binding(
            get: { service.enabled }, set: { service.setEnabled($0) }
          )
        ).toggleStyle(.checkbox).disabled(hasChanges || service.allowed.isEmpty)
        HStack {
          Button("Start") { service.start() }.disabled(
            hasChanges || service.allowed.isEmpty || service.desired
          )
          .lfConnectAction().accessibilityIdentifier("financialMCP.start")
          Button("Stop") { service.stop() }.lfDisconnectAction().disabled(!service.desired)
            .accessibilityIdentifier("financialMCP.stop")
          Button("Restart") { service.restart() }.disabled(hasChanges || service.allowed.isEmpty)
            .lfSecondaryAction().accessibilityIdentifier("financialMCP.restart")
        }
        Button("Save Desktop launcher…") { service.saveLauncher() }.lfSecondaryAction()
        Text(
          "Connected confirms the tunnel can reach OpenAI. The last request shows when ChatGPT has called a financial tool. Quitting LedgerForge stops the service and tunnel."
        )
        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        Button("Revoke access", role: .destructive) {
          let removed = service.revoke()
          permissions = []
          key = ""
          message =
            removed
            ? "Access revoked. Sharing choices and the saved runtime key have been removed."
            : service.lastFailure
        }.lfDisconnectAction().accessibilityIdentifier("financialMCP.revoke")
      }
    }
  }
}
