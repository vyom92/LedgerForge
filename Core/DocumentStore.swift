//
//  DocumentStore.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


// LedgerForge
// DocumentStore.swift
// Version: 0.0.5

import Foundation
import Combine

final class DocumentStore: ObservableObject {

    static let shared = DocumentStore()

    @Published private(set) var rows: [String] = []

    private init() {}

    func update(with text: String) {

        DispatchQueue.main.async {
            self.rows = text.components(separatedBy: .newlines)
        }

    }

    func clear() {

        DispatchQueue.main.async {
            self.rows.removeAll()
        }

    }
}
