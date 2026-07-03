import Foundation

final class ImportEngine {

    static let shared = ImportEngine()

    private init() { }

    func importFile(from url: URL) {
        DeveloperConsole.shared.clear()
        DeveloperConsole.shared.log("Import requested")
        DeveloperConsole.shared.log(url.path)

        do {

            let reader = CSVReader()

            let contents = try reader.read(from: url)

            let analyzer = CSVAnalyzer()

            let document = analyzer.analyze(
                text: contents,
                fileURL: url
            )

            DeveloperConsole.shared.log("========== DOCUMENT ==========")
            DeveloperConsole.shared.log("File: \(document.filename)")
            DeveloperConsole.shared.log("Rows: \(document.rowCount)")
            DeveloperConsole.shared.log("Header Row: \(document.headerRow ?? -1)")
            DeveloperConsole.shared.log("Columns: \(document.columnCount)")
            DeveloperConsole.shared.log("Delimiter: \(document.delimiter ?? "?")")
            DeveloperConsole.shared.log("First Transaction Row: \(document.firstTransactionRow ?? -1)")
            DeveloperConsole.shared.log("Encoding: \(document.encoding ?? "Unknown")")
            DeveloperConsole.shared.log("==============================")

        }

        catch {

            DeveloperConsole.shared.log(error.localizedDescription)

        }

    }

}
