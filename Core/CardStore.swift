import Combine
import Foundation

/// Canonical runtime owner for hydrated durable credit-card state.
final class CardStore: ObservableObject {
    static let shared = CardStore()

    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: CardStoreSnapshot = .empty

    init() {}

    func replaceSnapshot(_ snapshot: CardStoreSnapshot) {
        let update = {
            self.installSnapshotWithoutObservation(snapshot)
            self.notifySnapshotOfInstalledValue()
        }
        if Thread.isMainThread { update() }
        else { DispatchQueue.main.async(execute: update) }
    }

    func installSnapshotWithoutObservation(_ snapshot: CardStoreSnapshot) {
        _snapshot.installWithoutObservation(snapshot)
    }

    func notifySnapshotOfInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
