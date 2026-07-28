import Foundation

final class CSVReader: DocumentReader {

    func read(from url: URL) throws -> String {

        let didAccess = url.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try read(data: Data(contentsOf: url))

    }

    func read(data: Data) throws -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }

}
