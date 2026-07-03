// LedgerForge
// DeveloperConsoleView.swift
// Version: 0.0.3

import SwiftUI

struct DeveloperConsoleView: View {

    @ObservedObject var console = DeveloperConsole.shared

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Developer Console")
                .font(.headline)

            Divider()

            ScrollView {

                LazyVStack(alignment: .leading, spacing: 6) {

                    ForEach(console.messages, id: \.self) { message in

                        Text(message)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity,
                                   alignment: .leading)

                    }

                }

            }

        }
        .padding()
    }
}

#Preview {
    DeveloperConsoleView()
}
