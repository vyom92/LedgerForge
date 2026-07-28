import Foundation
import PDFKit

final class PDFDocumentReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["pdf"]

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        guard supportedFileExtensions.contains(request.fileExtension) else {
            throw ImportError.unsupportedFile(extension: request.fileExtension)
        }

        let text = try snapshot.withBytes { bytes in
            guard let document = PDFDocument(data: bytes) else {
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
            return text
        }

        return RawDocument(
            sourceURL: request.fileURL,
            fileName: request.fileName,
            fileExtension: request.fileExtension,
            content: .text(text)
        )
    }
}
