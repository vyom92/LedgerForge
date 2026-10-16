import SwiftUI

@MainActor
struct FinancialMCPSettingsView: View {
  @Environment(\.lfTheme) private var theme
  @ObservedObject private var service = FinancialMCPController.shared
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
        "Financial MCP", subtitle: "Read LedgerForge's financial presentation in ChatGPT."
      ) {}
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
            "These choices take effect when you save. Financial MCP reads the current presentation while LedgerForge is open. It cannot edit your ledger or refresh financial data."
          )
          .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
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
          .disabled(!hasChanges || tunnel.isEmpty)
          .accessibilityIdentifier("financialMCP.save")
        }
      }
      LFPanel(title: "Service") {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
          LabeledContent("Connection", value: service.state)
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
            .accessibilityIdentifier("financialMCP.start")
            Button("Stop") { service.stop() }.disabled(!service.desired)
              .accessibilityIdentifier("financialMCP.stop")
            Button("Restart") { service.restart() }.disabled(hasChanges || service.allowed.isEmpty)
              .accessibilityIdentifier("financialMCP.restart")
            Spacer()
            Button("Save Desktop launcher…") { service.saveLauncher() }
          }
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
          }.accessibilityIdentifier("financialMCP.revoke")
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
}
