import CryptoKit
import Foundation

nonisolated enum CompanionTransportError: Error, LocalizedError, Equatable {
    case invalid(String)
    case versionsNeedReview
    case changedDuringReview

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .versionsNeedReview: return "iCloud has different versions. Review them before continuing; your saved copy and pending edits are retained."
        case .changedDuringReview: return "The iCloud versions changed during review. Check again; no version was discarded."
        }
    }
}

nonisolated enum CompanionWriter: String, Codable, Sendable {
    case mac, phone
    var filename: String { "ledgerforge-companion-\(rawValue)-v1.json" }
}

/// One complete document is the unit of delivery. Timestamps are context only;
/// the receiver compares the session, generation and exact digest.
nonisolated struct CompanionEnvelope: Codable, Equatable, Sendable {
    static let maximumBytes = 24 * 1_024 * 1_024
    static let maximumPayloadBytes = 16 * 1_024 * 1_024
    let format: Int
    let sessionID: String
    let activationEpoch: String
    let writer: CompanionWriter
    let generation: UInt64
    let payload: Data
    let digest: String

    init(sessionID: String, activationEpoch: String, writer: CompanionWriter,
         generation: UInt64, payload: Data) throws {
        format = 1
        self.sessionID = sessionID; self.activationEpoch = activationEpoch
        self.writer = writer; self.generation = generation; self.payload = payload
        digest = Self.hash(payload)
        try validate()
    }

    func validate() throws {
        guard format == 1 else { throw CompanionTransportError.invalid("This companion file needs a newer app. Your saved copy is retained.") }
        guard UUID(uuidString: sessionID) != nil, UUID(uuidString: activationEpoch) != nil,
              generation > 0, !payload.isEmpty, payload.count <= Self.maximumPayloadBytes,
              digest == Self.hash(payload) else {
            throw CompanionTransportError.invalid("The companion file is incomplete or inconsistent. Your saved copy is retained.")
        }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(self)
        guard bytes.count <= Self.maximumBytes else { throw CompanionTransportError.invalid("The companion file is too large.") }
        return bytes
    }

    static func decode(_ bytes: Data, writer: CompanionWriter) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= maximumBytes else {
            throw CompanionTransportError.invalid("The companion file is empty or too large. Your saved copy is retained.")
        }
        let result = try JSONDecoder().decode(Self.self, from: bytes)
        try result.validate()
        guard result.writer == writer else { throw CompanionTransportError.invalid("This file belongs to the other writer.") }
        return result
    }

    /// Only exact duplicate or advancing publications within the accepted pair
    /// are eligible. A new epoch/session needs an explicit pairing decision.
    func validateSuccessor(of previous: Self?) throws -> Bool {
        try validate()
        guard let previous else { return true }
        guard writer == previous.writer, sessionID == previous.sessionID,
              activationEpoch == previous.activationEpoch else {
            throw CompanionTransportError.invalid("The Mac ledger or pairing changed. Pending edits need reconciliation before they can be sent.")
        }
        guard generation >= previous.generation else { return false }
        if generation == previous.generation {
            guard self == previous else { throw CompanionTransportError.invalid("Two different publications have the same revision. Your saved copy is retained.") }
            return false
        }
        return true
    }

    static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct CompanionFolderConnection: Codable, Equatable, Sendable {
    let bookmark: Data
    let name: String
}
nonisolated struct CompanionFolderRead: Sendable {
    let envelope: CompanionEnvelope
    let providerStatus: String?
}
nonisolated struct CompanionFileChoice: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let bytes: Data
    let envelope: CompanionEnvelope?
    let issue: String?
}

/// Directory-provider I/O is synchronous on its own actor, never under the
/// financial transaction lock. No Mobile Documents path or iCloud entitlement.
actor CompanionFolderTransport {
    private var selected: URL?
    private var holdsScope = false

    func select(_ url: URL) throws -> CompanionFolderConnection {
        guard url.startAccessingSecurityScopedResource() else {
            throw CompanionTransportError.invalid("Folder access was not granted. Choose the folder again; saved data is retained.")
        }
        do {
            guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                throw CompanionTransportError.invalid("Choose the companion folder.")
            }
            #if os(macOS)
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmark = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            release()
            selected = url; holdsScope = true
            return .init(bookmark: bookmark, name: url.lastPathComponent)
        } catch {
            url.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    func restore(_ connection: CompanionFolderConnection) throws -> CompanionFolderConnection {
        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
        #else
        let options: URL.BookmarkResolutionOptions = [.withoutUI, .withoutImplicitStartAccessing]
        #endif
        let url = try URL(resolvingBookmarkData: connection.bookmark, options: options,
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        return try select(url)
    }

    func release() {
        if holdsScope { selected?.stopAccessingSecurityScopedResource() }
        selected = nil; holdsScope = false
    }

    private func file(_ writer: CompanionWriter) throws -> URL {
        guard let selected, holdsScope else { throw CompanionTransportError.invalid("Choose the companion folder. Saved data and pending edits are retained.") }
        return selected.appendingPathComponent(writer.filename, isDirectory: false)
    }

    private func requireNoConflict(_ url: URL) throws {
        guard (NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).isEmpty else {
            throw CompanionTransportError.versionsNeedReview
        }
    }

    private func readBounded(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: CompanionEnvelope.maximumBytes + 1) ?? Data()
        guard bytes.count <= CompanionEnvelope.maximumBytes else { throw CompanionTransportError.invalid("The companion file is too large. Saved data is retained.") }
        return bytes
    }

    func publish(_ envelope: CompanionEnvelope) throws {
        let bytes = try envelope.encoded()
        let url = try file(envelope.writer)
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                try requireNoConflict(coordinated)
                if FileManager.default.fileExists(atPath: coordinated.path) {
                    let existing = try CompanionEnvelope.decode(readBounded(coordinated), writer: envelope.writer)
                    guard envelope.sessionID == existing.sessionID, envelope.activationEpoch == existing.activationEpoch else {
                        throw CompanionTransportError.invalid("This folder already contains a different pairing. Its publication was preserved; choose the intended companion folder.")
                    }
                    guard envelope.generation >= existing.generation else {
                        throw CompanionTransportError.invalid("A newer publication is already in this folder. The retained local state needs review.")
                    }
                    _ = try envelope.validateSuccessor(of: existing)
                }
                try bytes.write(to: coordinated, options: .atomic)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CompanionTransportError.invalid("The file provider did not complete the write.") }
        try result.get()
    }

    func read(_ writer: CompanionWriter) throws -> CompanionFolderRead {
        let url = try file(writer)
        var coordinationError: NSError?
        var result: Result<CompanionFolderRead, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                try requireNoConflict(coordinated)
                let bytes = try readBounded(coordinated)
                let value = try CompanionEnvelope.decode(bytes, writer: writer)
                let status = try coordinated.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus?.rawValue
                return .init(envelope: value, providerStatus: status)
            }
        }
        do {
            if let coordinationError { throw coordinationError }
            guard let result else { throw CompanionTransportError.invalid("The file provider did not complete the read.") }
            return try result.get()
        } catch {
            let failure = error as NSError
            // FileHandle reports absent files as Cocoa 4; other Foundation readers use 260.
            // Normalize only this read's exact absence so a first pairing can publish.
            if failure.domain == NSCocoaErrorDomain && failure.code == NSFileNoSuchFileError {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError,
                    userInfo: [NSUnderlyingErrorKey: failure, NSFilePathErrorKey: url.path])
            }
            throw error
        }
    }

    /// Reads every provider version without marking or discarding any version.
    /// The caller retains these exact bytes locally before offering a choice.
    func conflictingChoices(_ writer: CompanionWriter) throws -> [CompanionFileChoice] {
        let url = try file(writer)
        guard !(NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).isEmpty else { return [] }
        var coordinationError: NSError?
        var result: Result<[CompanionFileChoice], Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                guard !(NSFileVersion.unresolvedConflictVersionsOfItem(at: coordinated) ?? []).isEmpty else { return [] }
                return try choices(at: coordinated, writer: writer)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CompanionTransportError.invalid("The file provider did not return its versions.") }
        return try result.get()
    }

    private func choices(at url: URL, writer: CompanionWriter) throws -> [CompanionFileChoice] {
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        guard conflicts.count <= 16 else { throw CompanionTransportError.invalid("There are too many iCloud versions for an automatic review. Saved data is retained.") }
        let urls = [url] + conflicts.map(\.url)
        var values: [String: CompanionFileChoice] = [:]
        for candidate in urls {
            let bytes = try readBounded(candidate)
            let id = CompanionEnvelope.hash(bytes)
            do {
                values[id] = .init(id: id, bytes: bytes,
                    envelope: try CompanionEnvelope.decode(bytes, writer: writer), issue: nil)
            } catch {
                // A bounded malformed version must not hide valid alternatives.
                // Its exact bytes remain available for local retention/review.
                values[id] = .init(id: id, bytes: bytes, envelope: nil,
                    issue: "This version is incomplete or uses an unsupported format.")
            }
        }
        return values.values.sorted { $0.id < $1.id }
    }

    /// Call only for an explicit owner choice after retaining ALL presented
    /// versions locally. Recheck the exact choice set under file coordination.
    func resolveVersions(writer: CompanionWriter, selectedID: String,
                         retainedChoices: [CompanionFileChoice],
                         lastAccepted: CompanionEnvelope?) throws {
        let expected = retainedChoices.sorted { $0.id < $1.id }
        guard !expected.isEmpty, Set(expected.map(\.id)).count == expected.count,
              expected.allSatisfy({ $0.id == CompanionEnvelope.hash($0.bytes) }),
              let chosen = expected.first(where: { $0.id == selectedID }),
              let envelope = chosen.envelope else {
            throw CompanionTransportError.changedDuringReview
        }
        _ = try envelope.validateSuccessor(of: lastAccepted)
        guard envelope.writer == writer,
              lastAccepted.map({ envelope.generation >= $0.generation }) ?? true else {
            throw CompanionTransportError.invalid("This version is older than the saved copy. Keep the saved copy or reconcile the change on its originating device.")
        }
        let url = try file(writer)
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                guard try choices(at: coordinated, writer: writer) == expected else {
                    throw CompanionTransportError.changedDuringReview
                }
                let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: coordinated) ?? []
                try chosen.bytes.write(to: coordinated, options: .atomic)
                // Retain provider versions; resolving does not purge history.
                for conflict in conflicts { conflict.isResolved = true }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CompanionTransportError.invalid("The file provider did not complete the choice.") }
        try result.get()
    }
}

/// The caller changes its accepted in-memory state only after this succeeds.
/// UI text may remain visible after failure but must be labelled unsaved and
/// may not be published until this exact state is retained successfully.
nonisolated enum CompanionLocalFile {
    static func load<Value: Decodable>(_ type: Value.Type, at url: URL,
                                      maximumBytes: Int = 48 * 1_024 * 1_024) throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let bytes = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard bytes.count <= maximumBytes else { throw CompanionTransportError.invalid("The saved companion state is too large. It has been retained for recovery.") }
        return try JSONDecoder().decode(type, from: bytes)
    }

    static func save<Value: Encodable>(_ value: Value, to url: URL,
                                      maximumBytes: Int = 48 * 1_024 * 1_024) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(value)
        guard bytes.count <= maximumBytes else { throw CompanionTransportError.invalid("The companion state is too large to save.") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
    }
}
