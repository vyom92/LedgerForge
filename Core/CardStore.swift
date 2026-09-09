import Combine
import Foundation

/// Canonical runtime owner for hydrated durable credit-card state.
final class CardStore: ObservableObject {
    static let shared = CardStore()

    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: CardStoreSnapshot = .empty

    init() {}

    func replaceSnapshot(_ snapshot: CardStoreSnapshot) {
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
    func installSnapshotWithoutObservation(_ snapshot: CardStoreSnapshot) {
        _snapshot.installWithoutObservation(snapshot)
    }

    @MainActor
    func notifySnapshotOfInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
