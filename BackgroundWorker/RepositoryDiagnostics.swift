import Foundation

// Repository debug-console calls have no UI in this headless executable.
// Worker lifecycle diagnostics are emitted by the entrypoint, without payloads.
nonisolated enum DeveloperLogCategory: Sendable { case database }
nonisolated final class DeveloperConsole: Sendable {
    static let shared = DeveloperConsole()
    func info(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]) {}
    func warning(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]) {}
}
