// LedgerForge
// CategoryStore.swift

import Combine
import Foundation

/// Runtime projection of durable category definitions and current assignments.
/// RepositoryStoreHydrator is its only producer.
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    @Published private(set) var snapshot: CategorySnapshot = .empty

    init() {}

    var categories: [Category] { snapshot.categories }
    var activeCategories: [Category] { snapshot.activeCategories }
    var archivedCategories: [Category] { snapshot.archivedCategories }

    func category(forTransactionID transactionID: String) -> Category? {
        snapshot.category(forTransactionID: transactionID)
    }

    func replaceSnapshot(_ snapshot: CategorySnapshot) {
        let update = { self.snapshot = snapshot }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
}
