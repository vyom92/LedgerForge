#!/usr/bin/env python3
"""Sprint-93 acceptance only: typed logical comparisons retained entirely in RAM.

Run with an existing current SQLite path. Send one JSON command per stdin line:
{"action":"capture"}, {"action":"compare"}, {"action":"differentiate"},
{"action":"package","path":"...ledgerforgebackup"}, {"action":"check-package"},
or {"action":"quit"}. No row contents, identifiers or private digests are emitted.
No SQLite connection survives a command and this process never writes a file.
"""
import collections
import hashlib
import json
import pathlib
import plistlib
import sqlite3
import struct
import sys


def cell(value):
    if value is None:
        return ("null",)
    if isinstance(value, int):
        return ("integer", value)
    if isinstance(value, float):
        return ("real", struct.pack(">d", value))
    if isinstance(value, bytes):
        return ("blob", value)
    return ("text", value)


def snapshot(path, closed_snapshot=False):
    uri = pathlib.Path(path).resolve().as_uri() + "?mode=ro"
    if closed_snapshot:
        uri += "&immutable=1"
    db = sqlite3.connect(uri, uri=True)
    try:
        db.execute("PRAGMA query_only=ON")
        db.execute("BEGIN")
        schema = tuple(db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name"))
        tables = {}
        for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
            quoted = '"' + name.replace('"', '""') + '"'
            columns = tuple(db.execute("PRAGMA table_xinfo(" + quoted + ")"))
            rows = collections.Counter(tuple(cell(x) for x in row) for row in db.execute("SELECT * FROM " + quoted))
            tables[name] = (columns, rows)
        pragmas = tuple(db.execute("PRAGMA user_version")) + tuple(db.execute("PRAGMA application_id"))
        return schema, tables, pragmas
    finally:
        db.rollback()
        db.close()


def compare(before, after):
    names_before, names_after = set(before[1]), set(after[1])
    changed = sum(before[1][name] != after[1][name] for name in names_before & names_after)
    missing = extra = changed_records = 0
    for name in names_before | names_after:
        if name not in names_after:
            missing += sum(before[1][name][1].values())
            continue
        if name not in names_before:
            extra += sum(after[1][name][1].values())
            continue
        columns, old = before[1][name]
        new_columns, new = after[1][name]
        pk = [i for i, col in enumerate(columns) if col[5] > 0]
        if columns == new_columns and pk:
            def grouped(rows):
                result = collections.defaultdict(collections.Counter)
                for row, count in rows.items():
                    result[tuple(row[i] for i in pk)][row] += count
                return result
            old_keys, new_keys = grouped(old), grouped(new)
            missing += sum(sum(old_keys[k].values()) for k in old_keys.keys() - new_keys.keys())
            extra += sum(sum(new_keys[k].values()) for k in new_keys.keys() - old_keys.keys())
            changed_records += sum(old_keys[k] != new_keys[k] for k in old_keys.keys() & new_keys.keys())
        else:
            missing += sum((old - new).values())
            extra += sum((new - old).values())
    return {"equal": before == after, "missing_tables": len(names_before - names_after),
            "extra_tables": len(names_after - names_before), "changed_tables": changed,
            "missing_records": missing, "extra_records": extra, "changed_records": changed_records,
            "schema_equal": before[0] == after[0], "sqlite_metadata_equal": before[2] == after[2],
            "table_count": len(after[1]),
            "sqlite_managed_tables": sum(n.startswith("sqlite_") for n in after[1])}


def differentiation(before, after):
    if before[0] != after[0] or before[2] != after[2] or set(before[1]) != set(after[1]):
        return False
    if any(before[1][n] != after[1][n] for n in before[1] if n != "accounts"):
        return False
    cols, rows = before[1]["accounts"]
    other_cols, other_rows = after[1]["accounts"]
    if cols != other_cols:
        return False
    removed, added = list((rows - other_rows).elements()), list((other_rows - rows).elements())
    if len(removed) != 1 or len(added) != 1:
        return False
    index = next(i for i, col in enumerate(cols) if col[1] == "name")
    old, new = removed[0], added[0]
    return (old[index][0] == new[index][0] == "text" and
            new[index][1] == old[index][1] + " [restore check]" and
            all(a == b for i, (a, b) in enumerate(zip(old, new)) if i != index))


def package_identity(path):
    root = pathlib.Path(path)
    if root.is_symlink() or not root.is_dir() or {p.name for p in root.iterdir()} != {"ledger.sqlite", "manifest.json"}:
        raise ValueError("structure")
    result = []
    for name in ("ledger.sqlite", "manifest.json"):
        p = root / name
        if p.is_symlink() or not p.is_file():
            raise ValueError("structure")
        digest = hashlib.sha256()
        with p.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1048576), b""):
                digest.update(chunk)
        result.append((name, p.stat().st_size, digest.digest()))
    manifest = json.loads((root / "manifest.json").read_bytes())
    if manifest["database"]["sha256"] != result[0][2].hex() or manifest["database"]["byteSize"] != result[0][1]:
        raise ValueError("payload")
    return tuple(result)


def main():
    current = sys.argv[1]
    preference_path = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
    def preferences():
        if preference_path is None:
            return None
        values = plistlib.loads(preference_path.read_bytes()) if preference_path.exists() else {}
        return {k: values.get(k) for k in ("LedgerForge.appearance.darkOverrides", "developmentDatabase.rememberedProfile", "developmentDatabase.rememberedMigrationSourceVersion")}
    initial_preferences = preferences()
    baseline = None
    package = None
    package_before = None
    for line in sys.stdin:
        try:
            command = json.loads(line)
            action = command["action"]
            if action == "quit":
                print(json.dumps({"verifier_exited": True}), flush=True)
                return
            if action == "capture":
                if baseline is not None:
                    raise ValueError("baseline already retained")
                baseline = snapshot(current)
                answer = {"captured_in_ram": True, "table_count": len(baseline[1]), "handles_closed": True}
            elif action == "compare":
                answer = compare(baseline, snapshot(command.get("path", current)))
                answer["handles_closed"] = True
            elif action == "differentiate":
                answer = {"only_one_account_name_suffix_changed": differentiation(baseline, snapshot(current)), "handles_closed": True}
            elif action == "package":
                package = command["path"]
                package_before = package_identity(package)
                answer = {"package_hash_manifest_match": True, "package_logical_equals_baseline": snapshot(pathlib.Path(package) / "ledger.sqlite", closed_snapshot=True) == baseline}
            elif action == "check-package":
                answer = {"selected_package_unchanged": package_identity(package) == package_before}
            elif action == "check-preferences":
                answer = {"saved_appearance_and_profile_preferences_equal": preferences() == initial_preferences}
            else:
                raise ValueError("unsupported command")
            print(json.dumps(answer, sort_keys=True), flush=True)
        except Exception:
            # Deliberately omit exception arguments: SQLite or row values must
            # never turn an assertion/error into a private evidence file.
            print(json.dumps({"verification_error": True}), flush=True)


if __name__ == "__main__":
    main()
