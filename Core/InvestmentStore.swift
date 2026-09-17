import Combine

final class InvestmentStore: ObservableObject {
    static let shared = InvestmentStore()
    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: InvestmentSnapshot = .empty
    private(set) var generation: ProviderGenerationToken?
    weak var priceSession: InvestmentPriceSession?
    weak var ispSession: ZurichISPSyncSession?

    func installWithoutObservation(_ snapshot: InvestmentSnapshot, generation: ProviderGenerationToken?) {
        self.generation = generation
        _snapshot.installWithoutObservation(snapshot)
        priceSession?.installWithoutObservation(snapshot, generation: generation)
        ispSession?.installWithoutObservation(snapshot, generation: generation)
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
        priceSession?.notifyInstalledValue()
        ispSession?.notifyInstalledValue()
    }
}
