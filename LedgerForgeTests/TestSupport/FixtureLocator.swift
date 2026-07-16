import Foundation

enum FixtureLocator {
    static var fixturesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    static func axisCSV(_ fileName: String) -> URL {
        fixturesRoot
            .appendingPathComponent("Axis")
            .appendingPathComponent("CSV")
            .appendingPathComponent(fileName)
    }

    static func axisPDF(_ fileName: String) -> URL {
        fixturesRoot
            .appendingPathComponent("Axis")
            .appendingPathComponent("PDF")
            .appendingPathComponent(fileName)
    }

    static func axisExpected(_ fileName: String) -> URL {
        fixturesRoot
            .appendingPathComponent("Axis")
            .appendingPathComponent("Expected")
            .appendingPathComponent(fileName)
    }

    static func axisXLS(_ fileName: String) -> URL {
        fixturesRoot.appendingPathComponent("Axis").appendingPathComponent("XLS").appendingPathComponent(fileName)
    }

    static func axisManifest(_ fileName: String) -> URL {
        fixturesRoot.appendingPathComponent("Axis").appendingPathComponent("Manifests").appendingPathComponent(fileName)
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
