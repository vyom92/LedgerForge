import Combine

final class InvestmentStore: ObservableObject {
    static let shared = InvestmentStore()
    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: InvestmentSnapshot = .empty
    private(set) var generation: ProviderGenerationToken?

    func installWithoutObservation(_ snapshot: InvestmentSnapshot, generation: ProviderGenerationToken?) {
        self.generation = generation
        _snapshot.installWithoutObservation(snapshot)
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
