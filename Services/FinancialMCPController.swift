import AppKit
import Combine
import Darwin
import Foundation
import Network
import Security

private func mcpEncoded(_ value: Any) -> Data { FinancialMCPProtocol.encode(value) }
private func mcpJSON(_ value: Data) -> [String: Any]? { FinancialMCPProtocol.object(value) }
struct FinancialMCPRequest {
  let method: String
  let path: String
  let headers: [String: String]
  let body: Data
}
@MainActor
final class FinancialMCPLocalHTTP {
  let listener: NWListener
  var connections: [UUID: NWConnection] = [:]
  var handler: ((FinancialMCPRequest) -> (Int, Data))?
  var onReady: ((UInt16) -> Void)?
  var onFailure: (() -> Void)?
  init(port: UInt16 = 0) throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(
      host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
    listener = try NWListener(using: parameters)
    listener.newConnectionHandler = { [weak self] conn in
      MainActor.assumeIsolated {
        guard let self = self else { return }
        guard self.connections.count < 32 else {
          conn.cancel()
          return
        }
        let id = UUID()
        self.connections[id] = conn
        conn.start(queue: .main)
        self.receive(conn, id, Data())
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
          if self?.connections[id] != nil {
            conn.cancel()
            self?.connections[id] = nil
          }
        }
      }
    }
    listener.stateUpdateHandler = { [weak self] state in
      MainActor.assumeIsolated {
        if case .ready = state, let self = self, let port = self.listener.port {
          self.onReady?(port.rawValue)
        } else if case .failed = state {
          self?.onFailure?()
        }
      }
    }
  }
  func start() { listener.start(queue: .main) }
  func stop() {
    listener.cancel()
    connections.values.forEach { $0.cancel() }
    connections.removeAll()
  }
  func receive(_ conn: NWConnection, _ id: UUID, _ prior: Data) {
    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
      [weak self] data, _, complete, error in
      MainActor.assumeIsolated {
        guard let self = self else { return }
        var all = prior
        if let data = data { all.append(data) }
        if all.count > 65536 {
          self.respond(conn, id, 413, Data())
          return
        }
        guard let split = all.range(of: Data("\r\n\r\n".utf8)) else {
          if complete || error != nil {
            conn.cancel()
            self.connections[id] = nil
          } else {
            self.receive(conn, id, all)
          }
          return
        }
        let head = String(decoding: all[..<split.lowerBound], as: UTF8.self).components(
          separatedBy: "\r\n")
        let first = head[0].split(separator: " ")
        guard first.count >= 2 else {
          self.respond(conn, id, 400, Data())
          return
        }
        var headers: [String: String] = [:]
        for line in head.dropFirst() {
          let pair = line.split(separator: ":", maxSplits: 1)
          if pair.count == 2 {
            let key = String(pair[0]).lowercased()
            guard headers[key] == nil else {
              self.respond(conn, id, 400, Data())
              return
            }
            headers[key] = pair[1].trimmingCharacters(in: .whitespaces)
          }
        }
        if headers["transfer-encoding"] != nil {
          self.respond(conn, id, 400, Data())
          return
        }
        let size = Int(headers["content-length"] ?? "0") ?? -1
        if size < 0 || size > 60000 {
          self.respond(conn, id, 413, Data())
          return
        }
        let body = all[split.upperBound...]
        if body.count < size {
          if complete { self.respond(conn, id, 400, Data()) } else { self.receive(conn, id, all) }
          return
        }
        let request = FinancialMCPRequest(
          method: String(first[0]), path: String(first[1]), headers: headers,
          body: Data(body.prefix(size)))
        let reply = self.handler?(request) ?? (503, Data())
        self.respond(conn, id, reply.0, reply.1)
      }
    }
  }
  func respond(_ c: NWConnection, _ id: UUID, _ status: Int, _ body: Data) {
    let labels = [
      200: "OK", 202: "Accepted", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden",
      404: "Not Found", 405: "Method Not Allowed", 409: "Conflict", 413: "Too Large",
      503: "Unavailable",
    ]
    let header =
      "HTTP/1.1 \(status) \(labels[status] ?? "Error")\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
    c.send(
      content: Data(header.utf8) + body,
      completion: .contentProcessed { [weak self] _ in
        Task { @MainActor in
          c.cancel()
          self?.connections[id] = nil
        }
      })
  }
}

/// The sole app-lifetime owner. The launcher only addresses its authenticated
/// control listener. No financial payload or tunnel response is logged to disk.
@MainActor
final class FinancialMCPController: NSObject, ObservableObject {
  static let shared = FinancialMCPController()
  let instance = UUID().uuidString
  let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("FinancialMCP", isDirectory: true)
  let defaults: UserDefaults
  private let credentialServiceOverride: String?

  init(defaults: UserDefaults = .standard, credentialService: String? = nil) {
    self.defaults = defaults
    self.credentialServiceOverride = credentialService
    super.init()
  }
  let environment = ProcessInfo.processInfo.environment
  var lockFD: Int32 = -1
  var endpoint: FinancialMCPLocalHTTP?
  var control: FinancialMCPLocalHTTP?
  var guardian: Process?
  var keepalive: Pipe?
  var generation = 0
  var desired = false
  @Published private(set) var enabled = false
  @Published private(set) var state = "Disabled"
  @Published private(set) var allowed = Set<String>()
  @Published private(set) var tunnelID = ""
  @Published private(set) var lastFailure = ""
  @Published private(set) var lastInvocation = "None this session"
  var localPort: UInt16 = 0
  var controlPort: UInt16 = 0
  var localToken = ""
  var controlToken = ""
  var tunnelHealth = ""
  var retries = 0
  var epoch = 0
  var retry: DispatchWorkItem?
  @Published private(set) var tunnelReady = false
  var healthTimer: Timer?
  var healthFailures = 0
  var helperStarted: Date?
  var lastPollSuccess: TimeInterval = 0
  private var healthInFlight = false
  private var activated = false
  var healthFile: URL { base.appendingPathComponent("health-\(instance)-\(generation).url") }
  var noTunnel: Bool {
    #if DEBUG
      environment["LEDGERFORGE_MCP_LOCAL_ONLY"] == "1"
    #else
      false
    #endif
  }
  private var credentialService: String {
    credentialServiceOverride
      ?? ((Bundle.main.bundleIdentifier ?? "com.vyom.LedgerForge") + ".financial-mcp.runtime")
  }
  private var credentialQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: credentialService,
      kSecAttrAccount as String: "runtime",
    ]
  }
  func runtimeKey() -> String? {
    #if DEBUG
      if let key = environment["LEDGERFORGE_MCP_RUNTIME_KEY"], !key.isEmpty { return key }
    #endif
    var query = credentialQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
  func configure(tunnel: String, key: String, permissions: Set<String>) throws {
    guard tunnel.range(of: "^tunnel_[a-zA-Z0-9]+$", options: .regularExpression) != nil,
      permissions.isSubset(of: Set(FinancialMCPProtocol.Tool.allCases.map(\.rawValue)))
    else {
      throw NSError(
        domain: "FinancialMCP", code: 1,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Enter the dedicated tunnel ID and select permitted information."
        ])
    }
    stop()
    if !key.isEmpty {
      let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8)]
      let updated = SecItemUpdate(credentialQuery as CFDictionary, attributes as CFDictionary)
      var status = updated
      if updated == errSecItemNotFound {
        var query = credentialQuery.merging(attributes) { _, new in new }
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        status = SecItemAdd(query as CFDictionary, nil)
      }
      guard status == errSecSuccess else {
        throw NSError(
          domain: NSOSStatusErrorDomain, code: Int(status),
          userInfo: [
            NSLocalizedDescriptionKey:
              "The runtime key could not be stored in Keychain (\(status))."
          ])
      }
    }
    tunnelID = tunnel
    allowed = permissions
    defaults.set(tunnel, forKey: "FinancialMCP.tunnelID")
    defaults.set(permissions.sorted(), forKey: "FinancialMCP.allowedTools")
    saveStatus()
  }
  @discardableResult
  func revoke() -> Bool {
    stop()
    enabled = false
    allowed = []
    defaults.set(false, forKey: "FinancialMCP.enabled")
    defaults.removeObject(forKey: "FinancialMCP.allowedTools")
    let status = SecItemDelete(credentialQuery as CFDictionary)
    let removed = status == errSecSuccess || status == errSecItemNotFound
    lastFailure =
      removed
      ? ""
      : "Sharing stopped. Unlock Keychain and revoke again to remove the saved key (\(status))."
    state = "Disabled"
    saveStatus()
    return removed
  }
  func setEnabled(_ value: Bool) {
    enabled = value
    defaults.set(value, forKey: "FinancialMCP.enabled")
    if value { start() } else { stop(final: "Disabled") }
  }
  func activate() {
    guard !activated, environment["LEDGERFORGE_TEST_HOST"] != "1" else { return }
    activated = true
    do {
      try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
      try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: base.path)
      lockFD = open(base.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, 0o600)
      guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
        if lockFD >= 0 {
          close(lockFD)
          lockFD = -1
        }
        activated = false
        state = "Unavailable"
        lastFailure = "Another app instance owns Financial MCP."
        return
      }
      _ = fcntl(lockFD, F_SETFD, FD_CLOEXEC)
      controlToken = UUID().uuidString + UUID().uuidString
      enabled = defaults.bool(forKey: "FinancialMCP.enabled")
      allowed = Set(defaults.stringArray(forKey: "FinancialMCP.allowedTools") ?? [])
      tunnelID = defaults.string(forKey: "FinancialMCP.tunnelID") ?? ""
      control = try FinancialMCPLocalHTTP()
      control?.handler = { [weak self] request in self?.controlRequest(request) ?? (503, Data()) }
      control?.onFailure = { [weak self] in
        guard let self else { return }
        self.stop(final: "Unavailable")
        self.control?.stop()
        self.control = nil
        self.controlPort = 0
        self.lastFailure =
          "The local control listener could not start. Reopen LedgerForge to retry."
        self.saveStatus()
      }
      control?.onReady = { [weak self] port in
        self?.controlPort = port
        self?.saveStatus()
      }
      control?.start()
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
      NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
      healthTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.checkHealth() }
      }
      if enabled { start() } else { saveStatus() }
    } catch {
      state = "Failed"
      lastFailure = "Financial MCP control could not start."
    }
  }
  func terminate() {
    stop()
    control?.stop()
    control = nil
    healthTimer?.invalidate()
    healthTimer = nil
    if lockFD >= 0 {
      try? FileManager.default.removeItem(at: base.appendingPathComponent("private-state.json"))
    }
    if lockFD >= 0 {
      close(lockFD)
      lockFD = -1
    }
  }
  func start() {
    guard activated, lockFD >= 0, control != nil else {
      lastFailure = "Financial MCP control is unavailable."
      return
    }
    guard !allowed.isEmpty else {
      state = "Disabled"
      lastFailure = "Select information to share in Settings first."
      saveStatus()
      return
    }
    if desired && endpoint != nil { return }
    desired = true
    retries = 0
    lastFailure = ""
    begin()
  }
  func begin() {
    guard desired, endpoint == nil, guardian == nil else { return }
    epoch += 1
    let thisEpoch = epoch
    generation += 1
    state = "Starting"
    localToken = UUID().uuidString + UUID().uuidString
    tunnelReady = false
    lastInvocation = "None this session"
    lastPollSuccess = 0
    do {
      let ep = try FinancialMCPLocalHTTP()
      endpoint = ep
      ep.handler = { [weak self] request in self?.mcp(request) ?? (503, Data()) }
      ep.onFailure = { [weak self] in
        guard let self, self.epoch == thisEpoch, self.desired else { return }
        self.fail("Financial endpoint listener failed", recover: true)
      }
      ep.onReady = { [weak self] port in
        guard let self = self, self.epoch == thisEpoch, self.desired else { return }
        self.localPort = port
        self.state = "Local Ready"
        self.event("endpoint_ready", ["port": Int(port), "generation": self.generation])
        self.saveStatus()
        if !self.noTunnel { self.launchTunnel(thisEpoch) }
      }
      ep.start()
      saveStatus()
    } catch { fail("Listener startup failed", recover: true) }
  }
  func launchTunnel(_ thisEpoch: Int) {
    guard !tunnelID.isEmpty, let runtimeKey = runtimeKey(), !runtimeKey.isEmpty else {
      fail("Tunnel credentials unavailable", recover: false)
      return
    }
    let childURL = Bundle.main.bundleURL.appendingPathComponent(
      "Contents/Helpers/FinancialMCPGuardian")
    let tunnelURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/tunnel-client")
    let profile = base.appendingPathComponent("financial-mcp.yaml")
    let profileData: [String: Any] = [
      "config_version": 1,
      "control_plane": [
        "base_url": "https://api.openai.com", "tunnel_id": tunnelID,
        "api_key": "env:CONTROL_PLANE_API_KEY",
      ], "mcp": ["server_urls": [["channel": "main", "url": "http://127.0.0.1:\(localPort)/mcp"]]],
      "health": ["listen_addr": "127.0.0.1:0", "url_file": healthFile.path],
      "log": ["level": "info", "format": "json"],
    ]
    do { try mcpEncoded(profileData).write(to: profile, options: .atomic) } catch {
      fail("Cannot save dedicated tunnel profile", recover: false)
      return
    }
    let p = Process()
    p.executableURL = childURL
    p.arguments = [
      String(getpid()), tunnelURL.path, "run", "--profile-file", profile.path,
      "--control-plane.poll-timeout", "5s", "--mcp.extra-headers",
      "Authorization: env:LEDGERFORGE_MCP_AUTHORIZATION", "--mcp.discovery-extra-headers",
      "Authorization: env:LEDGERFORGE_MCP_AUTHORIZATION",
    ]
    #if DEBUG
      if let proxy = environment["LEDGERFORGE_MCP_CONTROL_PROXY"],
        proxy.hasPrefix("http://127.0.0.1:")
      {
        p.arguments! += ["--control-plane.http-proxy", proxy]
      }
    #endif
    p.environment = [
      "CONTROL_PLANE_API_KEY": runtimeKey, "LEDGERFORGE_MCP_AUTHORIZATION": "Bearer \(localToken)",
    ]
    let pipe = Pipe()
    p.standardInput = pipe
    keepalive = pipe
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    p.terminationHandler = { [weak self] ended in
      DispatchQueue.main.async {
        // This group was created by our guardian; clean surviving helper members even if it was killed.
        kill(-ended.processIdentifier, SIGKILL)
        guard let self = self, self.epoch == thisEpoch else { return }
        self.guardian = nil
        self.keepalive = nil
        if self.desired { self.fail("Tunnel process exited", recover: true) }
      }
    }
    do {
      try p.run()
      guardian = p
      try? pipe.fileHandleForReading.close()
      state = "Connecting"
      helperStarted = Date()
      healthFailures = 0
      event("guardian_started", ["pid": p.processIdentifier])
      saveStatus()
    } catch {
      guardian = nil
      keepalive = nil
      fail("Helper startup failed", recover: true)
    }
  }
  func checkHealth() {
    guard desired, !noTunnel, guardian?.isRunning == true, !healthInFlight else { return }
    guard
      let text = try? String(contentsOf: healthFile, encoding: .utf8).trimmingCharacters(
        in: .whitespacesAndNewlines),
      let url = URL(string: text), url.host == "127.0.0.1", url.scheme == "http"
    else {
      if let started = helperStarted, Date().timeIntervalSince(started) > 15 {
        fail("Tunnel startup timeout", recover: true)
      }
      return
    }
    tunnelHealth = text
    let thisEpoch = epoch
    healthInFlight = true
    Task { @MainActor [weak self] in
      guard let self else { return }
      defer { self.healthInFlight = false }
      var readyRequest = URLRequest(url: url.appendingPathComponent("readyz"))
      readyRequest.timeoutInterval = 1.5
      let readyResponse = try? await URLSession.shared.data(for: readyRequest)
      var metricsRequest = URLRequest(url: url.appendingPathComponent("metrics"))
      metricsRequest.timeoutInterval = 1.5
      let metricsResponse = try? await URLSession.shared.data(for: metricsRequest)
      guard self.epoch == thisEpoch, self.desired else { return }
      let ready = (readyResponse?.1 as? HTTPURLResponse)?.statusCode == 200
      let metrics = String(decoding: metricsResponse?.0 ?? Data(), as: UTF8.self)
      let line = metrics.split(separator: "\n").first {
        $0.hasPrefix("commands_poll_last_successful_timestamp_seconds{")
      }
      let last = line.flatMap { $0.split(separator: " ").last }.flatMap { Double($0) } ?? 0
      self.lastPollSuccess = last
      let ok = ready && last > 0 && Date().timeIntervalSince1970 - last <= 15
      self.tunnelReady = ok
      if ok {
        self.state = "Connected"
        self.healthFailures = 0
      } else if last == 0, let started = self.helperStarted, Date().timeIntervalSince(started) < 15
      {
        self.state = "Connecting"
      } else {
        self.healthFailures += 1
        self.state = "Recovering"
        if self.healthFailures >= 15 {
          self.fail("Tunnel polling/readiness timeout", recover: true)
          return
        }
      }
      self.saveStatus()
    }
  }
  func fail(_ reason: String, recover: Bool) {
    lastFailure = reason
    shutdownTransport()
    event("failure", ["reason": reason, "retries": retries])
    if recover && desired && retries < 3 {
      let delay = [1, 2, 4][retries]
      retries += 1
      state = "Recovering"
      let current = epoch
      let item = DispatchWorkItem { [weak self] in
        guard let self = self, self.desired, self.epoch == current else { return }
        self.begin()
      }
      retry = item
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: item)
    } else {
      state = "Failed"
    }
    saveStatus()
  }
  func shutdownTransport() {
    epoch += 1
    retry?.cancel()
    retry = nil
    endpoint?.stop()
    endpoint = nil
    localPort = 0
    tunnelReady = false
    tunnelHealth = ""
    try? keepalive?.fileHandleForWriting.close()
    keepalive = nil
    if let p = guardian, p.isRunning {
      p.terminate()
      let until = Date().addingTimeInterval(2)
      while p.isRunning && Date() < until { usleep(10000) }
      if p.isRunning {
        kill(-p.processIdentifier, SIGKILL)
        kill(p.processIdentifier, SIGKILL)
      }
    }
    guardian = nil
    localToken = ""
  }
  func stop(final: String = "Stopped") {
    desired = false
    state = "Stopping"
    shutdownTransport()
    state = final
    event("stopped")
    saveStatus()
  }
  func restart() {
    stop()
    start()
  }
  @objc func willSleep() {
    event("system_will_sleep")
    if desired {
      shutdownTransport()
      state = "Recovering"
      saveStatus()
    }
  }
  @objc func didWake() {
    event("system_did_wake")
    if desired {
      retries = 0
      begin()
    }
  }
  func event(_ name: String, _ values: [String: Any] = [:]) {
    // Deliberately no request/response body, financial data or credentials in logs.
  }
  func status() -> [String: Any] {
    [
      "instance": instance, "pid": Int(getpid()), "generation": generation, "state": state,
      "desired": desired, "enabledOnLaunch": enabled, "allowedTools": allowed.sorted(),
      "localPort": Int(localPort), "controlPort": Int(controlPort),
      "guardianPID": Int(guardian?.processIdentifier ?? 0), "tunnelReady": tunnelReady,
      "lastPollSuccess": lastPollSuccess, "lastInvocation": lastInvocation,
      "retryCount": retries, "failure": lastFailure, "localOnly": noTunnel,
    ]
  }
  func saveStatus() {
    guard activated, lockFD >= 0 else { return }
    var value = status()
    value["controlToken"] = controlToken
    // The data-plane token is never written to the launcher's discovery file.
    #if DEBUG
      if environment["LEDGERFORGE_MCP_QUALIFICATION"] == "1" { value["localToken"] = localToken }
    #endif
    let target = base.appendingPathComponent("private-state.json")
    try? mcpEncoded(value).write(to: target, options: .atomic)
    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
  }
  private var settingsRequested = false
  var hasSettingsRequest: Bool { settingsRequested }
  func consumeSettingsRequest() -> Bool {
    defer { settingsRequested = false }
    return settingsRequested
  }
  func showSettings() {
    settingsRequested = true
    NotificationCenter.default.post(name: .financialMCPSettings, object: nil)
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible }) {
      window.makeKeyAndOrderFront(nil)
    } else {
      // Reopen this application's existing WindowGroup after the last window
      // was closed. The pending route is consumed by the new ContentView.
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.createsNewApplicationInstance = false
      configuration.activates = true
      NSWorkspace.shared.openApplication(
        at: Bundle.main.bundleURL, configuration: configuration,
        completionHandler: { _, _ in
          Task { @MainActor in
            NotificationCenter.default.post(name: .financialMCPSettings, object: nil)
          }
        })
    }
  }
  func controlRequest(_ request: FinancialMCPRequest) -> (Int, Data) {
    guard request.headers["authorization"] == "Bearer \(controlToken)",
      request.headers["origin"] == nil
    else { return (401, Data()) }
    if request.method == "GET", request.path == "/status" { return (200, mcpEncoded(status())) }
    guard request.method == "POST", let body = mcpJSON(request.body),
      body["instance"] as? String == instance
    else { return (409, mcpEncoded(["error": "stale instance"])) }
    switch request.path {
    case "/start": start()
    case "/stop": stop()
    case "/restart": restart()
    case "/enable": setEnabled(body["enabled"] as? Bool == true)
    case "/revoke": revoke()
    case "/settings": showSettings()
    default: return (404, Data())
    }
    saveStatus()
    return (200, mcpEncoded(status()))
  }
  func mcp(_ request: FinancialMCPRequest) -> (Int, Data) {
    guard request.path == "/mcp" else { return (404, Data()) }
    guard !localToken.isEmpty, request.headers["authorization"] == "Bearer \(localToken)",
      request.headers["origin"] == nil
    else { return (401, Data()) }
    guard desired, endpoint != nil else { return (503, Data()) }
    guard request.method == "POST" else { return (405, Data()) }
    return FinancialMCPProtocol.handle(request.body, allowed: allowed) { tool, arguments in
      let result = FinancialMCPPresentation.shared.read(tool, arguments: arguments)
      self.lastInvocation =
        tool.rawValue + " · " + (result["error"] == nil ? "returned" : "unavailable") + " · "
        + ISO8601DateFormatter().string(from: Date())
      self.saveStatus()
      return result
    }
  }
  func saveLauncher() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "LedgerForge Financial MCP.command"
    panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    panel.begin { response in
      guard response == .OK, let url = panel.url,
        let script = Bundle.main.url(forResource: "financial_mcp_control", withExtension: "py")
      else { return }
      func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
      }
      let text =
        "#!/bin/zsh\nexec /usr/bin/python3 " + quoted(script.path) + " --state "
        + quoted(self.base.appendingPathComponent("private-state.json").path) + " \"$@\"\n"
      do {
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
      } catch { self.lastFailure = "The launcher could not be saved." }
    }
  }
}

extension Notification.Name {
  static let financialMCPSettings = Notification.Name("LedgerForge.financialMCP.settings")
}
