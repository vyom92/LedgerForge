import Foundation

nonisolated enum DeveloperLogCategory: Sendable { case database }

// Stateless no-op sink shared by synchronous helper repository code.
nonisolated final class DeveloperConsole: Sendable {
    static let shared = DeveloperConsole()
    func info(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]) {}
    func warning(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]) {}
}
