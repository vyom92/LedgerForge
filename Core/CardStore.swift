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

extension CardStoreSnapshot {
    func continuingCardGroups(accountID: String) -> [CardInstrumentLineage.Group] {
        CardInstrumentLineage.groups(instrumentIDs: Set(instruments.filter { $0.liabilityAccountID == accountID }.map(\.id)),
            links: relationships.filter { $0.liabilityAccountID == accountID }.map {
                .init(predecessor: $0.predecessorInstrumentID, successor: $0.successorInstrumentID,
                      kind: $0.kind.rawValue, authority: $0.authority)
            })
    }

    func instrumentForSelection(group: CardInstrumentLineage.Group, observation: CardSourceIdentityObservation?) -> String? {
        let memberIDs = Set(group.members)
        let matches = Set(statements.flatMap(\.sections).filter { section in
            memberIDs.contains(section.instrumentID) && observation.map { section.sourceObservations.contains($0) } == true
        }.map(\.instrumentID))
        return matches.isEmpty ? group.terminal : CardInstrumentLineage.resolve(exactMatches: matches, groups: [group])
    }
}
