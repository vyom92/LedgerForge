import Combine
import Foundation

final class SalaryStore: ObservableObject {
    static let shared = SalaryStore()

    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var statements: [SalaryStatement] = []

    init() {}

    func installWithoutObservation(_ value: [SalaryStatement]) {
        _statements.installWithoutObservation(value)
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        _statements.publishInstalledValue()
    }
}

final class FundingPlanStore: ObservableObject {
    static let shared = FundingPlanStore()

    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var plans: [FundingPlan] = []

    init() {}

    func installWithoutObservation(_ value: [FundingPlan]) {
        _plans.installWithoutObservation(value)
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        _plans.publishInstalledValue()
    }

    func plan(for month: SelectedStatementMonth, workspaceID: String = "default-workspace") -> FundingPlan? {
        plans.first { $0.workspaceID == workspaceID && $0.month == month }
    }
}
