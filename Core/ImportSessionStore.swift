// LedgerForge
// ImportSessionStore.swift

import Foundation
import Combine

/// Runtime destination for repository-backed import-session summaries.
/// RepositoryStoreHydrator is its only producer.
final class ImportSessionStore: ObservableObject {

    static let shared = ImportSessionStore()

    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var importSessions: [RepositoryImportSession] = []

    init() {}

    func replaceImportSessions(_ importSessions: [RepositoryImportSession]) {
        let update = {
            self.installImportSessionsWithoutObservation(importSessions)
            self.notifyImportSessionsOfInstalledValue()
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    func installImportSessionsWithoutObservation(_ importSessions: [RepositoryImportSession]) {
        _importSessions.installWithoutObservation(importSessions)
    }

    func notifyImportSessionsOfInstalledValue() {
        objectWillChange.send()
        _importSessions.publishInstalledValue()
    }
}

/// Runtime destination for durable import-attempt summaries. RepositoryStoreHydrator
/// is its only producer, preserving the persistence-to-runtime boundary.
final class ImportAttemptStore: ObservableObject {
    static let shared = ImportAttemptStore()
    let objectWillChange = ObservableObjectPublisher()
    @ObserverAtomicPublished private(set) var attempts: [RepositoryImportAttempt] = []
    init() {}
    func replaceAttempts(_ attempts: [RepositoryImportAttempt]) {
        let update = {
            self.installAttemptsWithoutObservation(attempts)
            self.notifyAttemptsOfInstalledValue()
        }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }

    func installAttemptsWithoutObservation(_ attempts: [RepositoryImportAttempt]) {
        _attempts.installWithoutObservation(attempts)
    }
    func notifyAttemptsOfInstalledValue() {
        objectWillChange.send()
        _attempts.publishInstalledValue()
    }
}
