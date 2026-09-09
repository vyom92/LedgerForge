// LedgerForge
// CategoryStore.swift

import Combine
import Foundation

/// Runtime projection of durable category definitions and current assignments.
/// RepositoryStoreHydrator is its only producer.
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: CategorySnapshot = .empty

    init() {}

    var categories: [Category] { snapshot.categories }
    var activeCategories: [Category] { snapshot.activeCategories }
    var archivedCategories: [Category] { snapshot.archivedCategories }

    func category(forTransactionID transactionID: String) -> Category? {
        snapshot.category(forTransactionID: transactionID)
    }

    func replaceSnapshot(_ snapshot: CategorySnapshot) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.installSnapshotWithoutObservation(snapshot)
                self.notifySnapshotOfInstalledValue()
            }
        } else {
            DispatchQueue.main.async { @MainActor in
                self.installSnapshotWithoutObservation(snapshot)
                self.notifySnapshotOfInstalledValue()
            }
        }
    }


    @MainActor
    func installSnapshotWithoutObservation(_ snapshot: CategorySnapshot) {
        _snapshot.installWithoutObservation(snapshot)
    }

    @MainActor
    func notifySnapshotOfInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
