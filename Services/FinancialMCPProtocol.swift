import CoreFoundation
import Foundation

/// Four operations, all value-only. Transport, permission and schema validation
/// run before invoking the presentation closure; no repository is accessible here.
@MainActor
enum FinancialMCPProtocol {
  enum Tool: String, CaseIterable {
    case financialStatus = "get_financial_status"
    case portfolioOverview = "get_portfolio_overview"
    case reserveStatus = "get_reserve_status"
    case planningContext = "get_planning_context"

    var title: String {
      switch self {
      case .financialStatus: "Dashboard and net worth"
      case .portfolioOverview: "Investments and Zurich ISP"
      case .reserveStatus: "Reserve targets and conditional funding"
      case .planningContext: "Monthly plans, retained entries and scenarios"
      }
    }
    var fields: String {
      switch self {
      case .financialStatus:
        "Account names and identifiers, bank balances, card amounts owed, included/excluded net-worth members, reporting totals, monthly plan summary, source dates, FX and completeness."
      case .portfolioOverview:
        "Portfolio and policy identifiers, holdings, units, cost, prices, valuation, returns, contribution and pending-allocation figures, source dates and coverage."
      case .reserveStatus:
        "Reserve names, funding-account references, targets, conditional funding, gaps, monthly contributions, availability dates and overlap warnings."
      case .planningContext:
        "Selected and saved months, salary estimates, deductions, balances, bills and notes, plan FX, calculated outputs, retained or incomplete input text, account filters and unsaved scenarios."
      }
    }
    var schema: [String: Any] {
      var properties: [String: Any] = [
        "expected_snapshot": [
          "type": "string", "maxLength": 120,
          "description":
            "Optional snapshot ID from an earlier call. A changed presentation returns an explicit error; it is never silently combined.",
        ]
      ]
      if self == .planningContext {
        properties["month"] = [
          "type": "string", "pattern": "^[0-9]{4}-(0[1-9]|1[0-2])$",
          "description":
            "Omit for the displayed editor and scenario. A specified month returns hydrated saved and retained records only, without changing the UI.",
        ]
      }
      return [
        "name": rawValue,
        "description": "Read LedgerForge's existing " + title.lowercased() + ". " + fields
          + " Missing or changing presentation is explicit. Does not refresh or save anything.",
        "inputSchema": ["type": "object", "properties": properties, "additionalProperties": false],
        "annotations": [
          "readOnlyHint": true, "destructiveHint": false, "idempotentHint": true,
          "openWorldHint": false,
        ],
      ]
    }
  }

  static func encode(_ value: Any) -> Data {
    (try? JSONSerialization.data(
      withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
  }
  static func object(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }
  static func encoded<T: Encodable>(_ value: T) throws -> Any {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return try JSONSerialization.jsonObject(with: encoder.encode(value))
  }
  static func error(_ code: String, _ message: String) -> [String: Any] {
    ["state": "unavailable", "error": code, "message": message]
  }

  static func handle(
    _ body: Data, allowed: Set<String>,
    read: (Tool, [String: String]) -> [String: Any]
  ) -> (Int, Data) {
    guard let rpc = object(body), rpc["jsonrpc"] as? String == "2.0",
      let method = rpc["method"] as? String
    else { return (400, Data()) }
    guard let id = rpc["id"] else {
      return method.hasPrefix("notifications/") ? (202, Data()) : (400, Data())
    }
    guard id is String || (id is NSNumber && CFGetTypeID(id as CFTypeRef) != CFBooleanGetTypeID())
    else { return (400, Data()) }
    func reply(_ value: Any) -> (Int, Data) {
      (200, encode(["jsonrpc": "2.0", "id": id, "result": value]))
    }
    func fail(_ code: Int, _ message: String) -> (Int, Data) {
      (200, encode(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]))
    }
    switch method {
    case "initialize":
      let params = rpc["params"] as? [String: Any] ?? [:]
      let requested = params["protocolVersion"] as? String ?? "2025-06-18"
      let supported = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
      return reply([
        "protocolVersion": supported.contains(requested) ? requested : "2025-06-18",
        "capabilities": ["tools": ["listChanged": false]],
        "serverInfo": ["name": "LedgerForge Financial MCP", "version": "1.0.0"],
      ])
    case "ping": return reply([:])
    case "tools/list": return reply(["tools": Tool.allCases.map(\.schema)])
    case "resources/list", "prompts/list":
      return reply([method == "prompts/list" ? "prompts" : "resources": []])
    case "tools/call":
      guard let params = rpc["params"] as? [String: Any], let name = params["name"] as? String,
        let tool = Tool(rawValue: name)
      else { return fail(-32602, "Unknown financial tool") }
      let raw = params["arguments"] ?? [String: Any]()
      guard let arguments = raw as? [String: String],
        Set(arguments.keys).isSubset(
          of: tool == .planningContext ? ["month", "expected_snapshot"] : ["expected_snapshot"]),
        arguments.values.allSatisfy({ $0.count <= 120 }),
        arguments["month"].map({
          $0.range(of: "^[0-9]{4}-(0[1-9]|1[0-2])$", options: .regularExpression) != nil
        }) ?? true
      else { return fail(-32602, "Invalid financial tool arguments") }
      let value =
        allowed.contains(name)
        ? read(tool, arguments)
        : error(
          "sharing_not_authorized",
          "Enable this information in LedgerForge Settings > Financial MCP.")
      return reply([
        "isError": value["error"] != nil,
        "content": [["type": "text", "text": String(decoding: encode(value), as: UTF8.self)]],
        "structuredContent": value,
      ])
    default: return fail(-32601, "Method not found")
    }
  }
}
