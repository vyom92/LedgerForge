// Import/Readers/CSVDocumentReaderAdapter.swift
// Bridges the legacy CSVReader into the Unified Import Framework reader contract.

import Foundation

final class CSVDocumentReaderAdapter: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["csv"]

    func read(request: ImportRequest, password: String?) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }

        do {
            let text = try CSVReader().read(from: request.fileURL)
            return RawDocument(
                sourceURL: request.fileURL,
                fileName: request.fileName,
                fileExtension: request.fileExtension,
                content: .text(text)
            )
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.readerFailure(message: error.localizedDescription)
        }
    }
}
