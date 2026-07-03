import Foundation

final class CSVReader: DocumentReader {

    func read(from url: URL) throws -> String {

        let didAccess = url.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try String(contentsOf: url, encoding: .utf8)

    }

}
