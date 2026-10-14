// LedgerForge
// Category.swift

import Foundation

nonisolated struct Category: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let name: String
    let normalizedName: String
    let isArchived: Bool
}

nonisolated struct CategoryAssignment: Equatable, Sendable {
    let workspaceID: String
    let transactionID: String
    let categoryID: String
}

nonisolated struct CategorySnapshot: Equatable, Sendable {
    static let empty = CategorySnapshot(categories: [], assignments: [:])

    let categories: [Category]
    let assignments: [String: String]
    var automation: CategoryAutomationSnapshot? = nil
    var providerGeneration: ProviderGenerationToken? = nil

    var activeCategories: [Category] { categories.filter { !$0.isArchived } }
    var archivedCategories: [Category] { categories.filter(\.isArchived) }

    func category(forTransactionID transactionID: String) -> Category? {
        guard let categoryID = assignments[transactionID] else { return nil }
        return categories.first { $0.id == categoryID }
    }
}
