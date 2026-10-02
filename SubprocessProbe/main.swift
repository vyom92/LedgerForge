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
        if CommandLine.arguments.count == 5, CommandLine.arguments[2] == "background-lease" {
            do {
                guard let lease = try BackgroundJobLease.acquire(path: CommandLine.arguments[1], kind: .publicReferences) else {
                    exit(slot: slot, with: "contention")
                }
                withExtendedLifetime(lease) {
                    writeLine("READY")
                    guard readLine() == "GO" else { exit(slot: slot, with: "rejected") }
                    // Deliberately exit with the lease live. The kernel, rather
                    // than a Swift deinitializer or expiry guess, releases it.
                    exit(slot: slot, with: "exited-with-lease")
                }
            } catch { exit(slot: slot, with: "unavailable") }
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[2] == "authority-lock" {
            let fd = Darwin.open(CommandLine.arguments[1] + ".access.lock", O_RDWR | O_NOFOLLOW)
            guard fd >= 0 else { exit(slot: slot, with: "unavailable") }
            let obtained = flock(fd, LOCK_EX | LOCK_NB) == 0
            Darwin.close(fd)
            exit(slot: slot, with: obtained ? "acquired" : "contention")
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[2] == "authority-hold" {
            // Hold only the stable namespace lock. No SQLite open, lifecycle
            // transition, source content or financial operation occurs here.
            let fd = Darwin.open(CommandLine.arguments[1] + ".access.lock", O_RDWR | O_NOFOLLOW)
            guard fd >= 0 else { exit(slot: slot, with: "unavailable") }
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
                Darwin.close(fd)
                exit(slot: slot, with: "contention")
            }
            writeLine("READY")
            guard readLine() == "GO" else {
                Darwin.close(fd)
                exit(slot: slot, with: "rejected")
            }
            let unlocked = flock(fd, LOCK_UN) == 0
            let closed = Darwin.close(fd) == 0
            exit(slot: slot, with: unlocked && closed ? "released" : "unavailable")
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[2] == "authority-open" {
            let database = SQLiteDatabase(path: CommandLine.arguments[1])
            do { try database.open(access: .existing); database.close(); exit(slot: slot, with: "opened") }
            catch LedgerAccessError.transitionPending { exit(slot: slot, with: "pending") }
            catch { exit(slot: slot, with: "unavailable") }
        }
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

        let result: String = (try? database.withExclusiveAccess {
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
        }) ?? "retryable-contention"
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
