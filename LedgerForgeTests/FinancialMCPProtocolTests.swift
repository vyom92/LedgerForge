import Foundation
import Testing

@testable import LedgerForge

/// Nonfinancial protocol and access-boundary tests. No statement or financial DTO fixtures.
@MainActor
struct FinancialMCPProtocolTests {
  private let names = Set([
    "get_financial_status", "get_portfolio_overview", "get_reserve_status", "get_planning_context",
  ])

  private func request(_ method: String, params: [String: Any] = [:]) -> Data {
    FinancialMCPProtocol.encode([
      "jsonrpc": "2.0", "id": "qualification", "method": method, "params": params,
    ])
  }

  @Test func advertisesExactlyFourReadOnlyOperationsWithoutReading() throws {
    var reads = 0
    let response = FinancialMCPProtocol.handle(request("tools/list"), allowed: names) { _, _ in
      reads += 1
      return [:]
    }
    let rpc = try #require(FinancialMCPProtocol.object(response.1))
    let result = try #require(rpc["result"] as? [String: Any])
    let tools = try #require(result["tools"] as? [[String: Any]])
    #expect(response.0 == 200)
    #expect(Set(tools.compactMap { $0["name"] as? String }) == names)
    #expect(reads == 0)
    for tool in tools {
      let annotations = try #require(tool["annotations"] as? [String: Bool])
      #expect(annotations["readOnlyHint"] == true)
      #expect(annotations["destructiveHint"] == false)
      let schema = try #require(tool["inputSchema"] as? [String: Any])
      #expect(schema["additionalProperties"] as? Bool == false)
    }
  }

  @Test(arguments: FinancialMCPProtocol.Tool.allCases)
  func permissionIsCheckedBeforeReadingAndRevocationTakesEffect(tool: FinancialMCPProtocol.Tool)
    throws
  {
    var reads = 0
    let body = request("tools/call", params: ["name": tool.rawValue, "arguments": [:]])
    let permitted = FinancialMCPProtocol.handle(body, allowed: [tool.rawValue]) { _, _ in
      reads += 1
      return ["state": "nonfinancial_marker"]
    }
    #expect(permitted.0 == 200)
    #expect(reads == 1)
    let revoked = FinancialMCPProtocol.handle(body, allowed: []) { _, _ in
      reads += 1
      return [:]
    }
    let result = try #require(FinancialMCPProtocol.object(revoked.1)?["result"] as? [String: Any])
    let value = try #require(result["structuredContent"] as? [String: Any])
    #expect(result["isError"] as? Bool == true)
    #expect(value["error"] as? String == "sharing_not_authorized")
    #expect(reads == 1)
  }

  @Test func mutationUnknownToolAndMalformedArgumentsNeverReachPresentation() throws {
    let cases: [(String, [String: Any])] = [
      ("tools/call", ["name": "save_plan"]),
      ("tools/call", ["name": "get_financial_status", "arguments": ["refresh": true]]),
      ("tools/call", ["name": "get_financial_status", "arguments": ["month": "2026-10"]]),
      ("tools/call", ["name": "get_planning_context", "arguments": ["month": "2026-13"]]),
      ("tools/call", ["name": "get_planning_context", "arguments": ["expected_snapshot": 3]]),
      (
        "tools/call",
        [
          "name": "get_planning_context",
          "arguments": ["expected_snapshot": String(repeating: "x", count: 121)],
        ]
      ),
      ("tools/call", ["name": "get_planning_context", "arguments": ["unexpected": "value"]]),
      ("tools/call", ["name": "get_planning_context", "arguments": []]),
      ("resources/write", [:]),
    ]
    var reads = 0
    for (method, params) in cases {
      let response = FinancialMCPProtocol.handle(request(method, params: params), allowed: names) {
        _, _ in
        reads += 1
        return [:]
      }
      #expect(FinancialMCPProtocol.object(response.1)?["error"] != nil)
    }
    #expect(reads == 0)
  }

  @Test func rejectedSnapshotsAreExplicitToolErrors() throws {
    let response = FinancialMCPProtocol.handle(
      request(
        "tools/call",
        params: [
          "name": "get_planning_context", "arguments": ["expected_snapshot": "previous"],
        ]), allowed: names
    ) { _, arguments in
      #expect(arguments["expected_snapshot"] == "previous")
      return FinancialMCPProtocol.error("snapshot_changed", "Read again")
    }
    let result = try #require(FinancialMCPProtocol.object(response.1)?["result"] as? [String: Any])
    #expect(result["isError"] as? Bool == true)
    let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    let textual = try #require(FinancialMCPProtocol.object(Data(text.utf8)))
    let structured = try #require(result["structuredContent"] as? [String: Any])
    #expect(FinancialMCPProtocol.encode(textual) == FinancialMCPProtocol.encode(structured))
    #expect(structured["error"] as? String == "snapshot_changed")
  }

  @Test func invalidRPCAndNotificationsDoNotRead() {
    var reads = 0
    for body in [
      Data("invalid".utf8), request("tools/call", params: [:]),
      FinancialMCPProtocol.encode(["jsonrpc": "2.0", "id": true, "method": "tools/list"]),
    ] {
      _ = FinancialMCPProtocol.handle(body, allowed: names) { _, _ in
        reads += 1
        return [:]
      }
    }
    let notification = FinancialMCPProtocol.handle(
      FinancialMCPProtocol.encode([
        "jsonrpc": "2.0", "method": "notifications/initialized",
      ]), allowed: names
    ) { _, _ in
      reads += 1
      return [:]
    }
    #expect(notification.0 == 202)
    #expect(reads == 0)
  }

  @Test(.globalRuntimeStateIsolation)
  func anUnavailableProviderReturnsNoFinancialValues() {
    let presentation = FinancialMCPPresentation()
    for tool in FinancialMCPProtocol.Tool.allCases {
      let value = presentation.read(tool, arguments: [:])
      #expect(value["error"] as? String == "provider_unavailable")
      #expect(value.keys.sorted() == ["error", "message", "state"])
    }
  }

  @Test func keychainRoundTripAndRevocationUseAnIsolatedCredentialScope() throws {
    let scope = "LedgerForge.FinancialMCP.qualification." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: scope))
    let controller = FinancialMCPController(defaults: defaults, credentialService: scope)
    defer {
      controller.revoke()
      defaults.removePersistentDomain(forName: scope)
    }
    let key = "nonfinancial-qualification-" + UUID().uuidString
    try controller.configure(tunnel: "tunnel_qualification", key: key, permissions: names)
    #expect(controller.runtimeKey() == key)
    #expect(controller.allowed == names)
    #expect(!String(describing: defaults.persistentDomain(forName: scope)).contains(key))
    #expect(
      !String(decoding: FinancialMCPProtocol.encode(controller.status()), as: UTF8.self).contains(
        key))
    #expect(controller.revoke())
    #expect(controller.runtimeKey() == nil)
    #expect(controller.allowed.isEmpty)
    #expect(controller.localPort == 0)
    #expect(!controller.enabled)
  }
}
