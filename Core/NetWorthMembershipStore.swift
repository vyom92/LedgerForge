import Combine

/// Installed with canonical accounts and investments before any notification.
/// Nil is unavailable, never an inferred empty exclusion set.
final class NetWorthMembershipStore: ObservableObject {
    static let shared = NetWorthMembershipStore()
    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var snapshot: NetWorthMembershipSnapshot?
    private(set) var generation: ProviderGenerationToken?

    func installWithoutObservation(_ snapshot: NetWorthMembershipSnapshot?, generation: ProviderGenerationToken?) {
        self.generation = generation
        _snapshot.installWithoutObservation(snapshot)
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        _snapshot.publishInstalledValue()
    }
}
