import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var showingImporter = false
    @State private var selectedFile = "No statement imported"

    var body: some View {

        VStack(spacing: 25) {

            Text("LedgerForge")
                .font(.largeTitle)
                .bold()

            Text("Personal Accounting & Reconciliation")
                .foregroundStyle(.secondary)

            Button("Import Statement") {
                showingImporter = true
            }
            .buttonStyle(.borderedProminent)

            Divider()

            Text(selectedFile)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

        }
        .padding(30)
        .frame(minWidth: 800, minHeight: 500)

        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                .spreadsheet
            ]
        ) { result in

            switch result {

            case .success(let url):
                selectedFile = url.lastPathComponent

            case .failure(let error):
                selectedFile = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
