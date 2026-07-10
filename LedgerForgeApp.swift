//
//  LedgerForgeApp.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import SwiftUI

@main
struct LedgerForgeApp: App {
    init() {
        Self.configurePersistence()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func configurePersistence() {
        DeveloperConsole.shared.log("Persistence bootstrap not yet connected. DatabaseProvider is still using its configured repository provider.")
    }
}
