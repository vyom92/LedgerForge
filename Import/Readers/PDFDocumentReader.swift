import Foundation
import PDFKit

final class PDFDocumentReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]

    func read(request: ImportRequest, password: String?) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }

        guard let document = PDFDocument(url: request.fileURL) else {
            throw ImportError.invalidDocument(message: "Unable to open PDF document.")
        }

        if document.isLocked {
            guard let password else {
                throw ImportError.passwordRequired
            }

            guard document.unlock(withPassword: password), !document.isLocked else {
                throw ImportError.incorrectPassword
            }
        }

        guard let text = document.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidDocument(message: "PDF document contains no extractable text.")
        }

        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text(text)
        )
    }
}
