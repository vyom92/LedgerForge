"""Support for validate.sh durable-startup; not an alternative build/test runner."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import sqlite3
import subprocess
import sys
import time


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(app, output):
    app = Path(app).resolve(strict=True)
    output = Path(output).resolve(strict=True)
    markers = ("LEDGERFORGE_TEST_HOST", "LEDGERFORGE_RUN_HOST", "LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE")
    require(not any(key in os.environ for key in markers), "Durable startup rejects memory/test/namespace markers")
    require(subprocess.run(["/usr/bin/pgrep", "-x", "LedgerForge"], stdout=subprocess.DEVNULL).returncode == 1,
            "Quit the existing LedgerForge process before durable startup acceptance")
    with (app / "Contents/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    require(info.get("CFBundleIdentifier") == "com.vyom.LedgerForge", "Unexpected application identity")
    executable = (app / "Contents/MacOS" / info["CFBundleExecutable"]).resolve(strict=True)
    identity = json.loads((app / "Contents/Resources/LedgerForgeBuildIdentity.json").read_text())
    require(identity["configuration"] == "Debug" and identity["worktree"] in ("clean", "dirty"), "Build identity unavailable")
    database = (Path.home() / "Library/Containers/com.vyom.LedgerForge/Data/Library/Application Support/LedgerForge/Development/ledgerforge-development.sqlite").resolve()
    require(database.is_file(), "Current Database must already exist; recovery is a separate explicit decision")
    environment = dict(os.environ, LEDGERFORGE_DURABLE_STARTUP_PROBE="1")
    def database_set():
        return {suffix or "main": hashlib.sha256(Path(str(database) + suffix).read_bytes()).hexdigest()
                if Path(str(database) + suffix).exists() else None for suffix in ("", "-wal", "-shm")}
    evidence = []
    for launch in (1, 2):
        log = output / f"durable-launch-{launch}.log"
        with log.open("w") as stream:
            process = subprocess.Popen([str(executable)], env=environment, stdout=stream, stderr=subprocess.STDOUT)
        try:
            signal = None
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                require(process.poll() is None, "Application exited before startup acceptance")
                lines = [line.removeprefix("LEDGERFORGE_DURABLE_STARTUP ") for line in log.read_text(errors="replace").splitlines()
                         if line.startswith("LEDGERFORGE_DURABLE_STARTUP ")]
                if lines:
                    require(len(lines) == 1, "Ambiguous startup completion signal")
                    signal = json.loads(lines[0])
                    break
                time.sleep(0.2)
            require(signal is not None, "No provider-and-hydration completion signal; a live PID is insufficient")
            require(signal["executable"] == str(executable) and signal["database"] == str(database), "Binary or database target mismatch")
            require(signal["provider"] == "verifiedSQLite" and signal["hydration"] == "complete" and signal["profile"] == "current", "Non-durable or incomplete startup")
            require(all(signal[key] == value for key, value in identity.items()), "Runtime identity differs from actual built bundle")
            subprocess.run(["/usr/bin/osascript", "-e", 'on run argv\n tell application (item 1 of argv) to quit\nend run', str(app)], check=True, timeout=15, stdout=subprocess.DEVNULL)
            require(process.wait(timeout=15) == 0, "Application did not quit cleanly")
            with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as connection:
                records = connection.execute("SELECT version,name,checksum,applied_at FROM schema_migrations ORDER BY version").fetchall()
                require(connection.execute("PRAGMA integrity_check").fetchone() == ("ok",), "SQLite integrity check failed")
                require(connection.execute("PRAGMA foreign_key_check").fetchall() == [], "Foreign-key integrity failed")
            connection.close()
            evidence.append(dict(launch=launch, pid=process.pid, signal=signal, migrations=records,
                                 database_sha256=hashlib.sha256(database.read_bytes()).hexdigest(), database_set=database_set()))
        finally:
            if process.poll() is None:
                # Only this helper's child; failure cleanup never resets or removes a database.
                process.terminate()
                process.wait(timeout=15)
    require(evidence[0]["migrations"] == evidence[1]["migrations"], "Migration history changed across relaunch")
    require(evidence[0]["database_sha256"] == evidence[1]["database_sha256"], "Database changed during startup/relaunch")
    require(evidence[0]["database_set"] == evidence[1]["database_set"], "Database file set changed across relaunch")
    result = dict(status="passed", app=str(app), executable_sha256=hashlib.sha256(executable.read_bytes()).hexdigest(),
                  debug_dylib_sha256=hashlib.sha256((app / "Contents/MacOS/LedgerForge.debug.dylib").read_bytes()).hexdigest(), launches=evidence)
    (output / "durable-startup.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Durable startup passed: verified SQLite, canonical hydration, clean quit, same-database relaunch")


if __name__ == "__main__":
    try:
        run(sys.argv[1], sys.argv[2])
    except Exception as error:
        print("durable-startup: " + str(error), file=sys.stderr)
        sys.exit(1)
