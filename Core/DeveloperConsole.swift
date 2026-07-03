// LedgerForge
// DeveloperConsole.swift
// Version: 0.0.3

import Foundation
import Combine

final class DeveloperConsole: ObservableObject {

    static let shared = DeveloperConsole()

    @Published private(set) var messages: [String] = []

    private init() {}

    func log(_ message: String) {
        DispatchQueue.main.async {
            self.messages.append(message)
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.messages.removeAll()
        }
    }
}
