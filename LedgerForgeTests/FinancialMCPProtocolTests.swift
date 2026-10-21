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

  @Test func advertisesFourCompatibleReadsAndOneBoundedWriteWithoutReading() throws {
    var reads = 0
    let response = FinancialMCPProtocol.handle(request("tools/list"), allowed: names) { _, _ in
      reads += 1
      return [:]
    }
    let rpc = try #require(FinancialMCPProtocol.object(response.1))
    let result = try #require(rpc["result"] as? [String: Any])
    let tools = try #require(result["tools"] as? [[String: Any]])
    #expect(response.0 == 200)
    #expect(Set(tools.compactMap { $0["name"] as? String }) == names.union([FinancialMCPProtocol.planningWriteToolName]))
    #expect(tools.count == 5)
    #expect(reads == 0)
    for tool in tools where names.contains(tool["name"] as? String ?? "") {
      let annotations = try #require(tool["annotations"] as? [String: Bool])
      #expect(annotations["readOnlyHint"] == true)
      #expect(annotations["destructiveHint"] == false)
      let schema = try #require(tool["inputSchema"] as? [String: Any])
      #expect(schema["additionalProperties"] as? Bool == false)
    }
    let writeTool = try #require(tools.first { $0["name"] as? String == FinancialMCPProtocol.planningWriteToolName })
    let writeAnnotations = try #require(writeTool["annotations"] as? [String: Bool])
    #expect(writeAnnotations["readOnlyHint"] == false)
    #expect(writeAnnotations["destructiveHint"] == true)
    #expect(writeAnnotations["idempotentHint"] == true)
    let writeSchema = try #require(writeTool["inputSchema"] as? [String: Any])
    #expect(writeSchema["additionalProperties"] as? Bool == false)
    #expect(Set(writeSchema["required"] as? [String] ?? []) == ["request_id", "workspace_id", "month", "plan_id", "expected_write_revision", "changes"])
  }

  private func validPlanningArguments() -> [String: Any] {
    [
      "request_id": "68cb8090-3f23-4bca-97d8-7c6b60023f63",
      "workspace_id": "workspace-id", "month": "2026-11", "plan_id": "plan-id",
      "expected_write_revision": "planning-write-v1:" + String(repeating: "1", count: 64),
      "changes": [[
        "type": "monthly_amount", "field": "keep_in_cbq",
        "amount": ["currency": "QAR", "decimal": "2000.00"],
      ]],
    ]
  }

  @Test func writeIsDefaultDeniedThenDispatchesOnlyAnExactTypedRequest() throws {
    let body = request("tools/call", params: [
      "name": FinancialMCPProtocol.planningWriteToolName,
      "arguments": validPlanningArguments(),
    ])
    var writes = 0
    let denied = FinancialMCPProtocol.handle(body, allowed: names, write: { _ in
      writes += 1
      return [:]
    }) { _, _ in Issue.record("Write unexpectedly reached read presentation"); return [:] }
    let deniedResult = try #require(FinancialMCPProtocol.object(denied.1)?["result"] as? [String: Any])
    let deniedValue = try #require(deniedResult["structuredContent"] as? [String: Any])
    #expect(deniedResult["isError"] as? Bool == true)
    #expect(deniedValue["error"] as? String == "planning_write_not_authorized")
    #expect(writes == 0)

    let withoutPlanningRead = FinancialMCPProtocol.handle(
      body, allowed: names.subtracting([FinancialMCPProtocol.Tool.planningContext.rawValue]),
      writeAllowed: true, write: { _ in writes += 1; return [:] }
    ) { _, _ in Issue.record("Write unexpectedly reached read presentation"); return [:] }
    let withoutPlanningReadResult = try #require(FinancialMCPProtocol.object(withoutPlanningRead.1)?["result"] as? [String: Any])
    let withoutPlanningReadValue = try #require(withoutPlanningReadResult["structuredContent"] as? [String: Any])
    #expect(withoutPlanningReadValue["error"] as? String == "planning_write_not_authorized")
    #expect(writes == 0)

    let allowed = FinancialMCPProtocol.handle(body, allowed: names, writeAllowed: true, write: { parsed in
      writes += 1
      #expect(parsed.requestID == "68cb8090-3f23-4bca-97d8-7c6b60023f63")
      #expect(parsed.month.canonical == "2026-11")
      return ["outcome": "applied", "committed": true]
    }) { _, _ in Issue.record("Write unexpectedly reached read presentation"); return [:] }
    let allowedResult = try #require(FinancialMCPProtocol.object(allowed.1)?["result"] as? [String: Any])
    #expect(allowedResult["isError"] as? Bool == false)
    #expect(writes == 1)
  }

  @Test func malformedPlanningArgumentsNeverReachWriteHandler() {
    let baseline = validPlanningArguments()
    var cases: [[String: Any]] = []
    var unknownTop = baseline
    unknownTop["surprise"] = true
    cases.append(unknownTop)
    var unknownNested = baseline
    unknownNested["changes"] = [[
      "type": "monthly_amount", "field": "keep_in_cbq",
      "amount": ["currency": "QAR", "decimal": "2000.00", "extra": "x"],
    ]]
    cases.append(unknownNested)
    var wrongRevision = baseline
    wrongRevision["expected_write_revision"] = "snapshot-id"
    cases.append(wrongRevision)
    var noChanges = baseline
    noChanges["changes"] = []
    cases.append(noChanges)
    var calls = 0
    for arguments in cases {
      let body = request("tools/call", params: [
        "name": FinancialMCPProtocol.planningWriteToolName, "arguments": arguments,
      ])
      let result = FinancialMCPProtocol.handle(body, allowed: names, writeAllowed: true, write: { _ in
        calls += 1
        return [:]
      }) { _, _ in Issue.record("Malformed write unexpectedly reached read presentation"); return [:] }
      #expect(FinancialMCPProtocol.object(result.1)?["error"] != nil)
    }
    #expect(calls == 0)
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

  @Test func authenticatedControllerWriteUsesSeparateEphemeralGrantAndInjectedHandler() throws {
    let scope = "LedgerForge.FinancialMCP.write-qualification." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: scope))
    let controller = FinancialMCPController(defaults: defaults, credentialService: scope)
    defer {
      controller.revoke()
      defaults.removePersistentDomain(forName: scope)
    }
    try controller.configure(
      tunnel: "tunnel_qualification", key: "",
      permissions: [FinancialMCPProtocol.Tool.planningContext.rawValue])
    controller.endpoint = try FinancialMCPLocalHTTP()
    controller.desired = true
    controller.localToken = "isolated-test-token"
    var writes = 0
    controller.planningWriteHandler = { change in
      writes += 1
      return ["outcome": "applied", "committed": true, "request_id": change.requestID]
    }
    let body = request("tools/call", params: [
      "name": FinancialMCPProtocol.planningWriteToolName,
      "arguments": validPlanningArguments(),
    ])
    func call(token: String) -> (Int, Data) {
      controller.mcp(FinancialMCPRequest(
        method: "POST", path: "/mcp", headers: ["authorization": "Bearer " + token], body: body))
    }
    #expect(call(token: "wrong-token").0 == 401)
    let denied = call(token: "isolated-test-token")
    let deniedResult = try #require(FinancialMCPProtocol.object(denied.1)?["result"] as? [String: Any])
    let deniedValue = try #require(deniedResult["structuredContent"] as? [String: Any])
    #expect(deniedValue["error"] as? String == "planning_write_not_authorized")
    #expect(writes == 0)
    controller.setPlanningWriteEnabled(true)
    #expect(defaults.bool(forKey: "FinancialMCP.planningWriteEnabled"))
    let allowed = call(token: "isolated-test-token")
    let allowedResult = try #require(FinancialMCPProtocol.object(allowed.1)?["result"] as? [String: Any])
    let allowedValue = try #require(allowedResult["structuredContent"] as? [String: Any])
    #expect(allowedValue["outcome"] as? String == "applied")
    #expect(writes == 1)
    controller.revoke()
    #expect(!controller.planningWriteEnabled)
    #expect(!defaults.bool(forKey: "FinancialMCP.planningWriteEnabled"))
  }
}
