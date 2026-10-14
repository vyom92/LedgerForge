import Combine

/// A canonical hydration projection. Nil explicitly means unavailable; an
/// empty snapshot is a readable ledger with no owner-created tags.
final class TransactionTagStore: ObservableObject {
    static let shared = TransactionTagStore()
    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: TransactionTagSnapshot?
    private(set) var generation: ProviderGenerationToken?

    func installWithoutObservation(_ snapshot: TransactionTagSnapshot?, generation: ProviderGenerationToken?) {
        self.generation = generation
        _snapshot.installWithoutObservation(snapshot)
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
