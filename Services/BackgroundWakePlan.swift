import Foundation

/// Operational target survives short-lived worker exits, outside the backup.
nonisolated struct BackgroundWakePlan: Codable, Equatable, Sendable {
    let enrollmentRevision: UUID
    let target: Date
}
nonisolated struct BackgroundWakePlanStore: Sendable {
    let enrollmentStore: BackgroundEnrollmentStore
    private var url: URL { enrollmentStore.url.deletingLastPathComponent().appendingPathComponent("wake.json") }
    func load(for enrollment: BackgroundEnrollment) throws -> BackgroundWakePlan? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count <= 4_096 else { throw LedgerAccessError.incompatible }
        let value = try JSONDecoder().decode(BackgroundWakePlan.self, from: data)
        guard value.target.timeIntervalSince1970.isFinite else { throw LedgerAccessError.incompatible }
        return value.enrollmentRevision == enrollment.revision ? value : nil
    }
    func save(target: Date, enrollment: BackgroundEnrollment) throws {
        guard target.timeIntervalSince1970.isFinite else { throw LedgerAccessError.incompatible }
        try enrollmentStore.withValid(enrollment) {
            try JSONEncoder().encode(BackgroundWakePlan(enrollmentRevision: enrollment.revision, target: target))
                .write(to: url, options: .atomic)
        }
    }
}
