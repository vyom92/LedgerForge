import Foundation
import Darwin

private struct ProbeResult: Codable {
    let slot: String
    let pid: Int32
    let result: String
}

/// Test-target-only process protocol for nonfinancial SQLite mechanics.
/// Authentic import acceptance is exercised by the ordinary application
/// pipeline; this helper never fabricates a statement or accepted import graph.
struct LedgerForgeSubprocessProbe {
    static func run() {
        let slot = CommandLine.arguments.count >= 5 ? CommandLine.arguments[4] : "unknown"
        guard CommandLine.arguments.count == 5,
              CommandLine.arguments[2] == "unique" else {
            exit(slot: slot, with: "unavailable")
        }
        let database = SQLiteDatabase(path: CommandLine.arguments[1])
        do {
            try database.open()
        } catch {
            exit(slot: slot, with: "unavailable")
        }
        writeLine("READY")
        guard readLine() == "GO" else { exit(slot: slot, with: "rejected") }

        let result: String = database.withExclusiveAccess {
            do {
                try database.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                try database.executePrepared(
                    sql: "INSERT INTO subprocess_mechanics_launches(slot) VALUES(?);",
                    params: [slot]
                )
                try database.executePrepared(
                    sql: "INSERT INTO subprocess_mechanics_keys(name,payload) VALUES(?,?);",
                    params: ["shared-key", CommandLine.arguments[3]]
                )
                try database.execute(sql: "COMMIT;")
                return "committed"
            } catch let SQLiteDatabaseError.execution(error) {
                try? database.execute(sql: "ROLLBACK;")
                if error.isRetryableContention {
                    return "retryable-contention"
                } else if error.isUniqueConstraint {
                    return "unique-conflict"
                } else {
                    return "rejected"
                }
            } catch {
                try? database.execute(sql: "ROLLBACK;")
                return "rejected"
            }
        }
        database.close()
        exit(slot: slot, with: result)
    }

    private static func exit(slot: String, with result: String) -> Never {
        let payload = ProbeResult(slot: slot, pid: ProcessInfo.processInfo.processIdentifier, result: result)
        let data = try! JSONEncoder().encode(payload)
        FileHandle.standardOutput.write(data + Data([10]))
        Darwin.exit(0)
    }

    private static func writeLine(_ line: String) {
        FileHandle.standardOutput.write(Data(line.utf8) + Data([10]))
    }
}

LedgerForgeSubprocessProbe.run()
