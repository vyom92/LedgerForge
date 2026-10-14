import SwiftUI

@main @MainActor
struct LedgerForgeCompanionApp: App {
    @State private var model = CompanionPhoneModel(
        directory: URL.applicationSupportDirectory.appendingPathComponent("LedgerForgeCompanion", isDirectory: true))

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
