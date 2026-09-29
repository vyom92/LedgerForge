import Combine
import Foundation

nonisolated enum ReportingCurrency: String, CaseIterable, Identifiable, Sendable {
    case usd = "USD", inr = "INR", qar = "QAR"
    var id: String { rawValue }
}

/// Presentation only. The one app-owned instance is shared by every window;
/// these choices never enter a ledger snapshot or backup.
@MainActor
final class ReportingCurrencyPreferences: ObservableObject {
    static let shared = ReportingCurrencyPreferences()
    static let key = "LedgerForge.reporting.visibleCurrencies.v1"
    @Published private(set) var currencies: [ReportingCurrency]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currencies = Self.validated(defaults.object(forKey: Self.key))
    }

    static func validated(_ raw: Any?) -> [ReportingCurrency] {
        guard let tokens = raw as? [String], !tokens.isEmpty,
              Set(tokens).count == tokens.count,
              tokens.allSatisfy({ ReportingCurrency(rawValue: $0) != nil }) else { return [.usd, .inr] }
        return ReportingCurrency.allCases.filter { tokens.contains($0.rawValue) }
    }

    func setVisible(_ visible: Bool, currency: ReportingCurrency) {
        var selected = Set(currencies)
        if visible { selected.insert(currency) } else { selected.remove(currency) }
        guard !selected.isEmpty else { return }
        let updated = ReportingCurrency.allCases.filter { selected.contains($0) }
        guard updated != currencies else { return }
        defaults.set(updated.map(\.rawValue), forKey: Self.key)
        currencies = updated
    }
}
