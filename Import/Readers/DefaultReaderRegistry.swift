// Import/Readers/DefaultReaderRegistry.swift
// Concrete reader registry for the Unified Import Framework.

import Foundation

final class DefaultReaderRegistry: ImportFramework.ReaderRegistry {
    private let readers: [any ImportFramework.DocumentReader]

    init(readers: [any ImportFramework.DocumentReader] = [CSVDocumentReaderAdapter()]) {
        self.readers = readers
    }

    func reader(for request: ImportRequest) async -> (any ImportFramework.DocumentReader)? {
        readers.first { reader in
            reader.supportedFileExtensions.contains(request.fileExtension)
        }
    }

    func requiredReader(for request: ImportRequest) async throws -> any ImportFramework.DocumentReader {
        guard let reader = await reader(for: request) else {
            throw ImportError.readerUnavailable(extension: request.fileExtension)
        }

        return reader
    }
}
