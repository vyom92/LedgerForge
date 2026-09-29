import Combine

/// Published with the canonical source graph; unavailable is distinct from an
/// empty, readable metadata set. Derived charts never write this store.
final class FinancialIntelligenceStore: ObservableObject {
    static let shared = FinancialIntelligenceStore()
    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: FinancialIntelligenceSnapshot?
    private(set) var sources: FinancialSourceContext = .empty
    private(set) var revision: UInt64 = 0
    private(set) var generation: ProviderGenerationToken?

    func installWithoutObservation(_ snapshot: FinancialIntelligenceSnapshot?, generation: ProviderGenerationToken?, sources: FinancialSourceContext = .empty) {
        self.generation = generation
        self.sources = sources
        revision &+= 1
        _snapshot.installWithoutObservation(snapshot)
    }
    func notifyInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
