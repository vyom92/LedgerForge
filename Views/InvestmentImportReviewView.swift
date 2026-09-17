import SwiftUI

struct InvestmentImportReviewView: View {
    @Environment(\.lfTheme) private var theme
    let preparation: PreparedImport
    let updateChoices: (InvestmentImportChoices) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            if let plan = preparation.investmentPlan {
                ForEach(plan.evidence.scopes.filter { scope in
                    scope.positions.contains { $0.units.value > 0 }
                        || preparation.investmentReview?.changes.contains { $0.scopeKey == scope.key } == true
                }, id: \.key) { scope in
                    HStack(alignment: .firstTextBaseline) {
                        Text(scope.displayName).font(theme.typography.formHeading)
                        if !scope.displayName.contains(scope.identity) {
                            Text(scope.identity).font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                        }
                        Spacer()
                        Text(scope.holdingsDate).font(theme.typography.formBody)
                    }
                }
                if let review = preparation.investmentReview {
                    HStack(spacing: theme.spacing.sectionGap) {
                        ForEach(InvestmentChangeKind.allCases, id: \.self) { kind in
                            Text("\(kind.rawValue) \(review.count(kind))").font(theme.typography.formBody)
                        }
                    }
                    ForEach(review.mappingQuestions) { question in
                        Picker(question.label, selection: Binding<String>(get: { "" }, set: { target in
                            guard !target.isEmpty else { return }
                            var choices = plan.choices
                            choices.replaceSameDateScopes = []
                            switch question.kind {
                            case .container:
                                if target == "new" { choices.newContainerScopes.insert(question.scopeKey) }
                                else { choices.containerTargets[question.scopeKey] = target }
                            case .instrument:
                                if target == "new" { choices.newInstrumentKeys.insert(question.id) }
                                else { choices.instrumentTargets[question.id] = target }
                            }
                            updateChoices(choices)
                        })) {
                            Text("Choose the position to update").tag("")
                            Text("Add separately").tag("new")
                            ForEach(question.candidates, id: \.id) { Text($0.label).tag($0.id) }
                        }.pickerStyle(.menu)
                    }
                    if !plan.choices.containerTargets.isEmpty || !plan.choices.instrumentTargets.isEmpty
                        || !plan.choices.newContainerScopes.isEmpty || !plan.choices.newInstrumentKeys.isEmpty {
                        HStack {
                            Text("Mappings chosen for this update").font(theme.typography.formCaption)
                            Button("Change mappings") { updateChoices(.init()) }
                        }
                    }
                    ForEach(plan.evidence.scopes.filter { review.sameDateConflictScopes.contains($0.key) || plan.choices.replaceSameDateScopes.contains($0.key) }, id: \.key) { scope in
                        Toggle("Use this statement’s holdings for \(scope.displayName) on \(scope.holdingsDate)", isOn: Binding(
                            get: { plan.choices.replaceSameDateScopes.contains(scope.key) },
                            set: { enabled in
                                var choices = plan.choices
                                if enabled { choices.replaceSameDateScopes.insert(scope.key) }
                                else { choices.replaceSameDateScopes.remove(scope.key) }
                                updateChoices(choices)
                            }))
                    }
                    Grid(alignment: .center, horizontalSpacing: theme.spacing.controlGap, verticalSpacing: theme.spacing.small) {
                        GridRow {
                            Text("Change"); Text("Investment"); Text("Units"); Text("Currency"); Text("Avg Cost"); Text("Total Cost")
                        }.font(theme.typography.formCaption.weight(.semibold))
                        ForEach(review.changes) { change in
                            GridRow(alignment: .top) {
                                Text(change.kind.rawValue)
                                VStack(alignment: .center, spacing: theme.spacing.micro) {
                                    Text(change.name)
                                    if plan.evidence.scopes.count > 1 { Text(change.portfolio).foregroundStyle(theme.palette.secondaryText) }
                                }
                                value(before: change.before?.units, after: change.after?.units, change: change)
                                Text(change.after?.currency ?? change.before?.currency ?? "Unavailable")
                                value(before: change.before?.averageCost, after: change.after?.averageCost, change: change)
                                value(before: change.before?.totalCost, after: change.after?.totalCost, change: change)
                            }
                        }
                    }.font(theme.typography.formCaption).multilineTextAlignment(.center)
                    Text(plan.evidence.excludedSectionDescription)
                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                }
            }
            if let error = preparation.investmentReviewError {
                Text(error).font(theme.typography.formBody).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func value(before: InvestmentDecimal?, after: InvestmentDecimal?, change: InvestmentChange) -> some View {
        VStack(alignment: .center, spacing: theme.spacing.micro) {
            if change.kind == .updated, before != after {
                Text(before?.sourceText ?? "Unavailable").foregroundStyle(theme.palette.secondaryText)
            }
            Text((change.kind == .removed ? before : after)?.sourceText ?? "Unavailable")
        }.monospacedDigit().fixedSize(horizontal: true, vertical: false)
    }
}
