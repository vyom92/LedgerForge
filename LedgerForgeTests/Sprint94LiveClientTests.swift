import Foundation
import XCTest
@testable import LedgerForge

/// Explicitly selected, owner-authorized single sample only. A task-owned
/// reservation prevents a runner retry from sending a second request.
final class Sprint94LiveClientTests: XCTestCase {
    func testOneApprovedPublicSample() async throws {
        guard let reservation = ProcessInfo.processInfo.environment["LEDGERFORGE_S94_LIVE_REQUEST_RESERVATION"],
              let id = UUID(uuidString: reservation) else {
            throw XCTSkip("Live sample requires a separate owner-authorized invocation.")
        }
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s94-live-\(id.uuidString).reserved")
        try Data("One approved Sprint 94 public sample reserved".utf8).write(to: marker, options: .withoutOverwriting)
        let amount = try Money(canonicalDecimal: "100.00", currency: "QAR")
        let reference = try await AlDarCurrentReferenceProvider().fetch(submittedQAR: amount)
        XCTAssertEqual(reference.submittedQAR, amount)
        XCTAssertTrue(reference.returnedINR.decimal > 0)
        XCTAssertFalse(reference.fetchedAtISO.isEmpty)
    }
}
