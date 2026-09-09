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
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.installImportSessionsWithoutObservation(importSessions)
                self.notifyImportSessionsOfInstalledValue()
            }
        } else {
            DispatchQueue.main.async { @MainActor in
                self.installImportSessionsWithoutObservation(importSessions)
                self.notifyImportSessionsOfInstalledValue()
            }
        }
    }

    @MainActor
    func installImportSessionsWithoutObservation(_ importSessions: [RepositoryImportSession]) {
        _importSessions.installWithoutObservation(importSessions)
    }

    @MainActor
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
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.installAttemptsWithoutObservation(attempts)
                self.notifyAttemptsOfInstalledValue()
            }
        } else {
            DispatchQueue.main.async { @MainActor in
                self.installAttemptsWithoutObservation(attempts)
                self.notifyAttemptsOfInstalledValue()
            }
        }
    }

    @MainActor
    func installAttemptsWithoutObservation(_ attempts: [RepositoryImportAttempt]) {
        _attempts.installWithoutObservation(attempts)
    }
    @MainActor
    func notifyAttemptsOfInstalledValue() {
        objectWillChange.send()
        _attempts.publishInstalledValue()
    }
}
