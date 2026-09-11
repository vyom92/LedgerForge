import SwiftUI

/// Constructs only the selected destination. It does not own destination state or workflows.
struct AppDestinationContainer<Dashboard: View, Accounts: View, Transactions: View, Imports: View, Salary: View, Settings: View, Developer: View>: View {
    let selectedSection: AppShellSection
    private let dashboard: () -> Dashboard
    private let accounts: () -> Accounts
    private let transactions: () -> Transactions
    private let imports: () -> Imports
    private let salary: () -> Salary
    private let settings: () -> Settings
    private let developer: () -> Developer

    init(
        selectedSection: AppShellSection,
        @ViewBuilder dashboard: @escaping () -> Dashboard,
        @ViewBuilder accounts: @escaping () -> Accounts,
        @ViewBuilder transactions: @escaping () -> Transactions,
        @ViewBuilder imports: @escaping () -> Imports,
        @ViewBuilder salary: @escaping () -> Salary,
        @ViewBuilder settings: @escaping () -> Settings,
        @ViewBuilder developer: @escaping () -> Developer
    ) {
        self.selectedSection = selectedSection
        self.dashboard = dashboard
        self.accounts = accounts
        self.transactions = transactions
        self.imports = imports
        self.salary = salary
        self.settings = settings
        self.developer = developer
    }

    @ViewBuilder
    var body: some View {
        switch selectedSection {
        case .dashboard:
            dashboard()
        case .accounts:
            accounts()
        case .transactions:
            transactions()
        case .imports:
            imports()
        case .salary:
            salary()
        case .settings:
            settings()
        case .developer:
            developer()
        }
    }
}
