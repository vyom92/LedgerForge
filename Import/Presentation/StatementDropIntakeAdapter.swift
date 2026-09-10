import Foundation
import UniformTypeIdentifiers

enum StatementImportFileTypes {
    static let allowed: [UTType] = [
        .commaSeparatedText,
        .pdf,
        .spreadsheet
    ]

    static func allows(_ contentType: UTType) -> Bool {
        allowed.contains { contentType.conforms(to: $0) }
    }
}

enum StatementDropIntakeError: Error, Equatable {
    case emptyPayload
    case unsupportedPayload
    case inaccessiblePayload

    var importError: ImportError {
        switch self {
        case .emptyPayload, .unsupportedPayload:
            return .unsupportedFile(extension: "")
        case .inaccessiblePayload:
            return .readerFailure(message: "A dropped file could not be accessed.")
        }
    }
}

struct StatementDropFileMetadata: Equatable {
    let isRegularFile: Bool
    let contentType: UTType?
}

struct StatementDropRequestGate: Equatable {
    private(set) var activeRequestID: UUID?

    var isActive: Bool { activeRequestID != nil }

    mutating func begin() -> UUID? {
        guard activeRequestID == nil else { return nil }
        let requestID = UUID()
        activeRequestID = requestID
        return requestID
    }

    mutating func finish(_ requestID: UUID) -> Bool {
        guard activeRequestID == requestID else { return false }
        activeRequestID = nil
        return true
    }

    mutating func invalidate() {
        activeRequestID = nil
    }
}

struct StatementDropItemProvider {
    typealias Completion = (Result<URL, StatementDropIntakeError>) -> Void

    let canLoadFileURL: Bool
    private let load: (@escaping Completion) -> Void

    init(
        canLoadFileURL: Bool,
        load: @escaping (@escaping Completion) -> Void
    ) {
        self.canLoadFileURL = canLoadFileURL
        self.load = load
    }

    init(_ provider: NSItemProvider) {
        canLoadFileURL = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            && provider.canLoadObject(ofClass: NSURL.self)
        load = { completion in
            provider.loadObject(ofClass: NSURL.self) { object, error in
                guard error == nil,
                      let object,
                      let fileURL = object as? NSURL else {
                    completion(.failure(.inaccessiblePayload))
                    return
                }
                completion(.success(fileURL as URL))
            }
        }
    }

    func loadFileURL(completion: @escaping Completion) {
        load(completion)
    }
}

@MainActor
struct StatementDropIntakeAdapter {
    typealias MetadataReader = (URL) throws -> StatementDropFileMetadata

    private let metadataReader: MetadataReader

    init(metadataReader: @escaping MetadataReader = Self.readMetadata) {
        self.metadataReader = metadataReader
    }

    func resolve(
        _ providers: [StatementDropItemProvider],
        completion: @escaping (Result<[URL], StatementDropIntakeError>) -> Void
    ) {
        guard !providers.isEmpty else {
            completion(.failure(.emptyPayload))
            return
        }
        resolve(providers, index: 0, resolvedURLs: [], completion: completion)
    }

    private func resolve(
        _ providers: [StatementDropItemProvider],
        index: Int,
        resolvedURLs: [URL],
        completion: @escaping (Result<[URL], StatementDropIntakeError>) -> Void
    ) {
        guard index < providers.count else {
            completion(.success(resolvedURLs))
            return
        }

        let provider = providers[index]
        guard provider.canLoadFileURL else {
            completion(.failure(.unsupportedPayload))
            return
        }

        provider.loadFileURL { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let url):
                    let metadata: StatementDropFileMetadata
                    do {
                        metadata = try metadataReader(url)
                    } catch {
                        completion(.failure(.inaccessiblePayload))
                        return
                    }
                    guard url.isFileURL,
                          metadata.isRegularFile,
                          let contentType = metadata.contentType,
                          StatementImportFileTypes.allows(contentType) else {
                        completion(.failure(.unsupportedPayload))
                        return
                    }
                    resolve(
                        providers,
                        index: index + 1,
                        resolvedURLs: resolvedURLs + [url],
                        completion: completion
                    )
                }
            }
        }
    }

    nonisolated private static func readMetadata(_ url: URL) throws -> StatementDropFileMetadata {
        guard url.isFileURL else { return StatementDropFileMetadata(isRegularFile: false, contentType: nil) }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey])
        return StatementDropFileMetadata(
            isRegularFile: values.isRegularFile == true,
            contentType: values.contentType
        )
    }
}
