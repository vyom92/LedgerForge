import Foundation

extension MonthlyPlanSyncAdapter {
    /// Exact source projection; carries no authority to edit salary links or bank facts.
    nonisolated enum ReceiptProjection: Codable, Equatable, Sendable {
        case pending
        case bankCredit(id: String, date: StatementDate, includedInBalance: Bool)
        case acknowledgedBalance
        case needsReview
        init(_ state: PayslipReceiptState) {
            switch state {
            case .pending: self = .pending
            case let .bankCredit(id, date, included): self = .bankCredit(id: id, date: date, includedInBalance: included)
            case .acknowledgedBalance: self = .acknowledgedBalance
            case .needsReview: self = .needsReview
            }
        }
        var state: PayslipReceiptState {
            switch self {
            case .pending: return .pending
            case let .bankCredit(id, date, included): return .bankCredit(id: id, date: date, includedInBalance: included)
            case .acknowledgedBalance: return .acknowledgedBalance
            case .needsReview: return .needsReview
            }
        }
    }
}
