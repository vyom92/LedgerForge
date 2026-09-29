import Foundation

/// Owner reporting metadata. A position's financial identity and value are not
/// changed by its inclusion in the current report.
nonisolated public enum NetWorthMemberID: Hashable, Sendable, Codable {
    case account(String)
    case investmentContainer(String)

    var stableKey: String {
        switch self {
        case .account(let id): return "account:" + id
        case .investmentContainer(let id): return "container:" + id
        }
    }
}

nonisolated public struct NetWorthMembershipSnapshot: Equatable, Sendable {
    public let workspaceID: String
    public let excluded: Set<NetWorthMemberID>

    public init(workspaceID: String, excluded: Set<NetWorthMemberID>) {
        self.workspaceID = workspaceID
        self.excluded = excluded
    }

    func validate(accounts: [AccountDTO], investments: InvestmentSnapshot) throws {
        guard !workspaceID.isEmpty else { throw NetWorthMembershipError.invalidSnapshot }
        for member in excluded {
            switch member {
            case .account(let id):
                guard accounts.contains(where: {
                    $0.id == id && $0.workspaceId == workspaceID &&
                    ["bank", "credit_card"].contains($0.accountType ?? "")
                }) else { throw NetWorthMembershipError.invalidSnapshot }
            case .investmentContainer(let id):
                guard investments.containers.contains(where: {
                    $0.id == id && $0.workspaceID == workspaceID
                }) else { throw NetWorthMembershipError.invalidSnapshot }
            }
        }
    }
}

nonisolated public enum NetWorthMembershipError: Error, Equatable {
    case unavailable
    case invalidTarget
    case invalidSnapshot
}
