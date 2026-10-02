import Foundation

/// Presentation and exact-observation routing over already confirmed card
/// relationships. Members and their source ownership remain immutable.
nonisolated enum CardInstrumentLineage {
    struct Link: Hashable, Sendable {
        let predecessor: String
        let successor: String
        let kind: String
        let authority: String
    }

    struct Group: Equatable, Sendable, Identifiable {
        let members: [String]
        var id: String { members[0] }
        var terminal: String { members[members.count - 1] }
    }

    /// Only a complete, unbranched, acyclic chain forms one continuing card.
    /// Unrelated, concurrent, or contradictory records stay separate choices.
    static func groups(instrumentIDs: Set<String>, links: [Link]) -> [Group] {
        let links = Set(links.filter {
            $0.authority == "user_confirmed" && ["replacement", "renewal", "upgrade"].contains($0.kind)
                && instrumentIDs.contains($0.predecessor) && instrumentIDs.contains($0.successor)
        })
        var next: [String: Set<String>] = [:], previous: [String: Set<String>] = [:]
        for link in links {
            next[link.predecessor, default: []].insert(link.successor)
            previous[link.successor, default: []].insert(link.predecessor)
        }
        var remaining = instrumentIDs, result: [Group] = []
        while let seed = remaining.sorted().first {
            var component: Set<String> = [], pending = [seed]
            while let id = pending.popLast() {
                guard component.insert(id).inserted else { continue }
                pending.append(contentsOf: next[id, default: []].union(previous[id, default: []]).subtracting(component))
            }
            remaining.subtract(component)
            let roots = component.filter { previous[$0, default: []].isEmpty }
            let isChain = roots.count == 1 && component.allSatisfy {
                next[$0, default: []].count <= 1 && previous[$0, default: []].count <= 1
            }
            var ordered: [String] = []
            if isChain, let root = roots.first {
                var cursor: String? = root
                while let id = cursor, !ordered.contains(id) {
                    ordered.append(id); cursor = next[id]?.first
                }
            }
            if ordered.count == component.count {
                result.append(.init(members: ordered))
            } else {
                result.append(contentsOf: component.sorted().map { .init(members: [$0]) })
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    /// Never chooses an unmatched descendant or infers currentness from dates.
    static func resolve(exactMatches: Set<String>, groups: [Group]) -> String? {
        if exactMatches.count == 1 { return exactMatches.first }
        guard !exactMatches.isEmpty,
              let group = groups.first(where: { exactMatches.isSubset(of: Set($0.members)) }) else { return nil }
        return group.members.reversed().first(where: exactMatches.contains)
    }
}

extension CardRepositorySnapshotDTO {
    nonisolated func continuingCardGroups(accountID: String) -> [CardInstrumentLineage.Group] {
        CardInstrumentLineage.groups(instrumentIDs: Set(instruments.filter { $0.liabilityAccountId == accountID }.map(\.id)),
            links: relationships.filter { $0.liabilityAccountId == accountID }.map {
                .init(predecessor: $0.predecessorInstrumentId, successor: $0.successorInstrumentId,
                      kind: $0.relationshipKind, authority: $0.authority)
            })
    }

    nonisolated func confirmedInstrumentMatches(accountID: String, kind: String, value: String) -> Set<String> {
        let eligible = Set(instruments.filter { $0.liabilityAccountId == accountID }.map(\.id))
        let sectionOwners = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0.instrumentId) })
        return Set(sectionObservations.compactMap {
            guard $0.associationAuthority == "user_confirmed", $0.observationKind == kind, $0.sourceValue == value,
                  let id = sectionOwners[$0.cardStatementSectionId], eligible.contains(id) else { return nil }
            return id
        })
    }

    nonisolated func resolvedConfirmedInstrument(accountID: String, kind: String, value: String) -> String? {
        CardInstrumentLineage.resolve(exactMatches: confirmedInstrumentMatches(accountID: accountID, kind: kind, value: value),
            groups: continuingCardGroups(accountID: accountID))
    }
}
