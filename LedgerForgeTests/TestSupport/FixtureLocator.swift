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

    static func hdfcBankAccountPDF(_ fileName: String) -> URL {
        hdfcBankAccountRoot.appendingPathComponent("PDF").appendingPathComponent("v1").appendingPathComponent(fileName)
    }

    static func hdfcBankAccountXLS(_ fileName: String) -> URL {
        hdfcBankAccountRoot.appendingPathComponent("XLS").appendingPathComponent("v1").appendingPathComponent(fileName)
    }

    static func hdfcBankAccountExpected(_ fileName: String) -> URL {
        hdfcBankAccountRoot.appendingPathComponent("Expected").appendingPathComponent(fileName)
    }

    static func hdfcBankAccountManifest(_ fileName: String) -> URL {
        hdfcBankAccountRoot.appendingPathComponent("Manifests").appendingPathComponent(fileName)
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private static var hdfcBankAccountRoot: URL {
        fixturesRoot.appendingPathComponent("HDFC").appendingPathComponent("BankAccount")
    }
}
