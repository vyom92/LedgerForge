import Foundation

enum DeveloperLogCategory { case database }

final class DeveloperConsole {
    static let shared = DeveloperConsole()
    func info(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]) {}
    func warning(_ category: DeveloperLogCategory, _ message: String, metadata: [String: String]) {}
}
