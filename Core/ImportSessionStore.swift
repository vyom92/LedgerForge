// LedgerForge
// ImportSessionStore.swift

import Foundation
import Combine

/// Runtime destination for repository-backed import-session summaries.
/// RepositoryStoreHydrator is its only producer.
final class ImportSessionStore: ObservableObject {

    static let shared = ImportSessionStore()

    @Published private(set) var importSessions: [RepositoryImportSession] = []

    init() {}

    func replaceImportSessions(_ importSessions: [RepositoryImportSession]) {
        let update = {
            self.importSessions = importSessions
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
}

/// Runtime destination for durable import-attempt summaries. RepositoryStoreHydrator
/// is its only producer, preserving the persistence-to-runtime boundary.
final class ImportAttemptStore: ObservableObject {
    static let shared = ImportAttemptStore()
    @Published private(set) var attempts: [RepositoryImportAttempt] = []
    init() {}
    func replaceAttempts(_ attempts: [RepositoryImportAttempt]) {
        let update = { self.attempts = attempts }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }
}
