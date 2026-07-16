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

    static func axisCreditCardPDF(_ fileName: String) -> URL {
        axisCreditCardRoot.appendingPathComponent("PDF").appendingPathComponent("v1").appendingPathComponent(fileName)
    }

    static func axisCreditCardXLSX(_ fileName: String) -> URL {
        axisCreditCardRoot.appendingPathComponent("XLSX").appendingPathComponent("v1").appendingPathComponent(fileName)
    }

    static func axisCreditCardExpected(_ fileName: String) -> URL {
        axisCreditCardRoot.appendingPathComponent("Expected").appendingPathComponent(fileName)
    }

    static func axisCreditCardManifest(_ fileName: String) -> URL {
        axisCreditCardRoot.appendingPathComponent("Manifests").appendingPathComponent(fileName)
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

    static func cbqBankAccountPDF(_ fileName: String) -> URL {
        cbqBankAccountRoot.appendingPathComponent("PDF").appendingPathComponent("v1").appendingPathComponent(fileName)
    }

    static func cbqBankAccountExpected(_ fileName: String) -> URL {
        cbqBankAccountRoot.appendingPathComponent("Expected").appendingPathComponent(fileName)
    }

    static func cbqBankAccountManifest(_ fileName: String) -> URL {
        cbqBankAccountRoot.appendingPathComponent("Manifests").appendingPathComponent(fileName)
    }

    static func cbqCreditCardPDF(_ fileName: String, layoutVersion: String) -> URL {
        cbqCreditCardRoot.appendingPathComponent("PDF").appendingPathComponent(layoutVersion).appendingPathComponent(fileName)
    }

    static func cbqCreditCardExpected(_ fileName: String) -> URL {
        cbqCreditCardRoot.appendingPathComponent("Expected").appendingPathComponent(fileName)
    }

    static func cbqCreditCardManifest(_ fileName: String) -> URL {
        cbqCreditCardRoot.appendingPathComponent("Manifests").appendingPathComponent(fileName)
    }

    static func americanExpressCardStatementPDF(_ fileName: String) -> URL {
        americanExpressCardStatementRoot.appendingPathComponent("PDF").appendingPathComponent("v1").appendingPathComponent(fileName)
    }

    static func americanExpressCardStatementExpected(_ fileName: String) -> URL {
        americanExpressCardStatementRoot.appendingPathComponent("Expected").appendingPathComponent(fileName)
    }

    static func americanExpressCardStatementManifest(_ fileName: String) -> URL {
        americanExpressCardStatementRoot.appendingPathComponent("Manifests").appendingPathComponent(fileName)
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private static var hdfcBankAccountRoot: URL {
        fixturesRoot.appendingPathComponent("HDFC").appendingPathComponent("BankAccount")
    }

    private static var axisCreditCardRoot: URL {
        fixturesRoot.appendingPathComponent("Axis").appendingPathComponent("CreditCard")
    }

    private static var cbqBankAccountRoot: URL {
        fixturesRoot.appendingPathComponent("CBQ").appendingPathComponent("BankAccount")
    }

    private static var cbqCreditCardRoot: URL {
        fixturesRoot.appendingPathComponent("CBQ").appendingPathComponent("CreditCard")
    }

    private static var americanExpressCardStatementRoot: URL {
        fixturesRoot.appendingPathComponent("AmericanExpress").appendingPathComponent("CardStatement")
    }
}
