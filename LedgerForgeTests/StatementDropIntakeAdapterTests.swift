import Foundation
import Testing
import UniformTypeIdentifiers
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct StatementDropIntakeAdapterTests {
    @Test func resolvesEveryProviderSeriallyInReceivedOrder() async {
        let sourceURLs = [
            URL(fileURLWithPath: "/tmp/opaque-drop-a"),
            URL(fileURLWithPath: "/tmp/opaque-drop-b"),
            URL(fileURLWithPath: "/tmp/opaque-drop-c")
        ]
        let contentTypes: [URL: UTType] = [
            sourceURLs[0]: .pdf,
            sourceURLs[1]: .commaSeparatedText,
            sourceURLs[2]: .spreadsheet
        ]
        var loadOrder: [Int] = []
        let providers = sourceURLs.enumerated().map { index, url in
            StatementDropItemProvider(canLoadFileURL: true) { completion in
                loadOrder.append(index)
                completion(.success(url))
            }
        }
        let adapter = StatementDropIntakeAdapter { url in
            StatementDropFileMetadata(
                isRegularFile: true,
                contentType: contentTypes[url]
            )
        }

        let result = await resolve(adapter, providers)

        #expect(loadOrder == [0, 1, 2])
        switch result {
        case .success(let resolvedURLs):
            #expect(resolvedURLs == sourceURLs)
        case .failure(let error):
            Issue.record("Expected ordered drop resolution, received \(error).")
        }
    }

    @Test func unsupportedProviderFailsTheWholeDropWithoutLoadingLaterMembers() async {
        let firstURL = URL(fileURLWithPath: "/tmp/opaque-supported-first")
        var loadOrder: [Int] = []
        let providers = [
            StatementDropItemProvider(canLoadFileURL: true) { completion in
                loadOrder.append(0)
                completion(.success(firstURL))
            },
            StatementDropItemProvider(canLoadFileURL: false) { _ in
                loadOrder.append(1)
            },
            StatementDropItemProvider(canLoadFileURL: true) { completion in
                loadOrder.append(2)
                completion(.success(URL(fileURLWithPath: "/tmp/opaque-never-loaded")))
            }
        ]
        let adapter = StatementDropIntakeAdapter { _ in
            StatementDropFileMetadata(isRegularFile: true, contentType: .pdf)
        }

        let result = await resolve(adapter, providers)

        #expect(loadOrder == [0])
        switch result {
        case .success:
            Issue.record("An unsupported member must reject the entire drop.")
        case .failure(let error):
            #expect(error == .unsupportedPayload)
        }
    }

    @Test func inaccessibleProviderFailsTheWholeDrop() async {
        let providers = [
            StatementDropItemProvider(canLoadFileURL: true) { completion in
                completion(.success(URL(fileURLWithPath: "/tmp/opaque-accessible")))
            },
            StatementDropItemProvider(canLoadFileURL: true) { completion in
                completion(.failure(.inaccessiblePayload))
            }
        ]
        var metadataReadCount = 0
        let adapter = StatementDropIntakeAdapter { _ in
            metadataReadCount += 1
            return StatementDropFileMetadata(isRegularFile: true, contentType: .spreadsheet)
        }

        let result = await resolve(adapter, providers)

        #expect(metadataReadCount == 1)
        switch result {
        case .success:
            Issue.record("An inaccessible member must reject the entire drop.")
        case .failure(let error):
            #expect(error == .inaccessiblePayload)
        }
    }

    @Test func metadataMustDescribeARegularAllowedFile() async {
        let url = URL(fileURLWithPath: "/tmp/opaque-metadata")
        let provider = StatementDropItemProvider(canLoadFileURL: true) { completion in
            completion(.success(url))
        }
        let nonRegularAdapter = StatementDropIntakeAdapter { _ in
            StatementDropFileMetadata(isRegularFile: false, contentType: .pdf)
        }
        let unsupportedTypeAdapter = StatementDropIntakeAdapter { _ in
            StatementDropFileMetadata(isRegularFile: true, contentType: .plainText)
        }

        let nonRegularResult = await resolve(nonRegularAdapter, [provider])
        let unsupportedTypeResult = await resolve(unsupportedTypeAdapter, [provider])

        assertUnsupported(nonRegularResult)
        assertUnsupported(unsupportedTypeResult)
    }

    @Test func obsoleteRequestCompletionCannotBecomeAcceptedIntake() async {
        let url = URL(fileURLWithPath: "/tmp/opaque-delayed-drop")
        var deferredCompletion: StatementDropItemProvider.Completion?
        let provider = StatementDropItemProvider(canLoadFileURL: true) { completion in
            deferredCompletion = completion
        }
        let adapter = StatementDropIntakeAdapter { _ in
            StatementDropFileMetadata(isRegularFile: true, contentType: .commaSeparatedText)
        }
        var gate = StatementDropRequestGate()
        let requestID = gate.begin()
        var didComplete = false
        var acceptedURLs: [URL]?

        adapter.resolve([provider]) { result in
            didComplete = true
            guard let requestID, gate.finish(requestID) else { return }
            if case .success(let urls) = result {
                acceptedURLs = urls
            }
        }
        #expect(deferredCompletion != nil)

        gate.invalidate()
        deferredCompletion?(.success(url))
        await waitUntil { didComplete }

        #expect(!gate.isActive)
        #expect(acceptedURLs == nil)
    }

    @Test func resolvedDropAndPickerArraysUseTheSameOrderedCoordinatorIntake() async {
        let sourceURLs = [
            URL(fileURLWithPath: "/tmp/opaque-common-route-a"),
            URL(fileURLWithPath: "/tmp/opaque-common-route-b"),
            URL(fileURLWithPath: "/tmp/opaque-common-route-a")
        ]
        let providers = sourceURLs.map { url in
            StatementDropItemProvider(canLoadFileURL: true) { completion in
                completion(.success(url))
            }
        }
        let adapter = StatementDropIntakeAdapter { _ in
            StatementDropFileMetadata(isRegularFile: true, contentType: .pdf)
        }
        let dropResult = await resolve(adapter, providers)
        let resolvedDropURLs: [URL]
        switch dropResult {
        case .success(let urls):
            resolvedDropURLs = urls
        case .failure(let error):
            Issue.record("Expected opaque drop mechanics to resolve, received \(error).")
            return
        }

        let dropProbe = DropCoordinatorProbe()
        let dropCoordinator = makeCoordinator(dropProbe)
        let pickerProbe = DropCoordinatorProbe()
        let pickerCoordinator = makeCoordinator(pickerProbe)
        #expect(dropCoordinator.enqueueSources(resolvedDropURLs))
        #expect(pickerCoordinator.enqueueSources(sourceURLs))
        await waitUntil {
            dropProbe.prepareCallCount == 1 && pickerProbe.prepareCallCount == 1
        }

        #expect(dropCoordinator.items.map(\.sourceURL) == sourceURLs)
        #expect(pickerCoordinator.items.map(\.sourceURL) == sourceURLs)
        #expect(dropCoordinator.items.map(\.queuePosition) == [0, 1, 2])
        #expect(pickerCoordinator.items.map(\.queuePosition) == [0, 1, 2])
        #expect(Set(dropCoordinator.items.map(\.id)).count == 3)
        #expect(Set(pickerCoordinator.items.map(\.id)).count == 3)
        #expect(dropCoordinator.items.map(\.phase) == [.preparing, .pending, .pending])
        #expect(pickerCoordinator.items.map(\.phase) == [.preparing, .pending, .pending])

        dropCoordinator.cancelBatch()
        pickerCoordinator.cancelBatch()
        let dropLatePreparation = DropOpaquePreparation()
        let pickerLatePreparation = DropOpaquePreparation()
        dropProbe.resume(with: dropLatePreparation)
        pickerProbe.resume(with: pickerLatePreparation)
        await waitUntil {
            !dropCoordinator.isPreparationDraining && !pickerCoordinator.isPreparationDraining
        }
        #expect(dropProbe.cancelledPreparationIDs == [dropLatePreparation.id])
        #expect(pickerProbe.cancelledPreparationIDs == [pickerLatePreparation.id])
    }

    private func resolve(
        _ adapter: StatementDropIntakeAdapter,
        _ providers: [StatementDropItemProvider]
    ) async -> Result<[URL], StatementDropIntakeError> {
        await withCheckedContinuation { continuation in
            adapter.resolve(providers) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func assertUnsupported(
        _ result: Result<[URL], StatementDropIntakeError>
    ) {
        switch result {
        case .success:
            Issue.record("Invalid metadata must reject the entire drop.")
        case .failure(let error):
            #expect(error == .unsupportedPayload)
        }
    }

    private func waitUntil(
        timeoutIterations: Int = 500,
        _ condition: () -> Bool
    ) async {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for drop intake completion.")
    }

    private func makeCoordinator(
        _ probe: DropCoordinatorProbe
    ) -> ImportCentreCoordinator<DropOpaquePreparation> {
        ImportCentreCoordinator(
            dependencies: .init(
                prepare: { _, _, _ in try await probe.prepare() },
                review: { _ in
                    ImportCentreReviewState(
                        identityReview: .unavailable,
                        initialAccountChoice: nil,
                        partialReview: .ordinaryFullImport,
                        validationPassed: true
                    )
                },
                refreshPartialReview: { _, _ in .ordinaryFullImport },
                commit: { _, _, _ in
                    ImportOutcomePresentation(result: ImportEngineResult(
                        fileName: "opaque",
                        transactionCount: 0,
                        validationPassed: true,
                        persisted: true,
                        errorMessage: nil
                    ))
                },
                cancelPreparation: { probe.cancel($0) },
                cancelPasswordChallenge: {},
                failureSummary: { _ in
                    ImportFailureSummary(
                        stage: .documentPreparation,
                        family: .unknown,
                        explanation: "Opaque drop preparation failed.",
                        guidance: "Retry the source-independent operation."
                    )
                },
                isRetryablePreparationFailure: { _ in false }
            )
        )
    }
}

private struct DropOpaquePreparation: ImportCentrePreparation {
    let id = UUID()
}

@MainActor
private final class DropCoordinatorProbe {
    private(set) var prepareCallCount = 0
    private(set) var cancelledPreparationIDs: [UUID] = []
    private var continuation: CheckedContinuation<DropOpaquePreparation, Never>?

    func prepare() async throws -> DropOpaquePreparation {
        prepareCallCount += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func resume(with preparation: DropOpaquePreparation) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: preparation)
    }

    func cancel(_ preparation: DropOpaquePreparation) {
        cancelledPreparationIDs.append(preparation.id)
    }
}
