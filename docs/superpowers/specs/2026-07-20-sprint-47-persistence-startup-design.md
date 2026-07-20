# Sprint 47 Verified Persistence Startup Design

## Scope

Sprint 47 implements `FW-P0-21` and `FW-P0-24` without a schema migration. The registered chain remains V1-V4. The implementation does not repair databases, rewrite migration history, add production lifecycle operations, or change parser and financial semantics.

## Persistence authority

`DatabaseProvider` is the single atomic authority for both active repositories and `PersistenceState`:

- `verifiedSQLite` means all repositories belong to a durable SQLite provider whose open, migration-history validation, required migrations, and final validation succeeded.
- `unavailable(reason)` installs repositories that reject every read and write with one bounded `RepositoryError.persistenceUnavailable` result.
- `intentionalNonDurable(purpose)` exists only through explicit test or Debug entry points and owns the explicitly selected non-durable repositories.

No caller may mutate authoritative state independently of the repositories. `LedgerForgeApp` bootstraps and observes the provider but does not own or infer persistence state.

## Provider publication

Production bootstrap begins with the unavailable provider. It constructs `SQLiteRepositoryProvider` privately, opens the intended database, validates the registered chain, validates any persisted history, applies pending migrations, and validates the resulting V1-V4 history. Only then does it atomically assign the verified provider to `DatabaseProvider.shared`.

Any open, integrity, or migration failure leaves the unavailable provider installed. Errors are mapped to bounded privacy-safe persistence reasons; raw SQL, SQLite messages, and paths remain internal.

## Migration validation

One `MigrationChainValidator` owns the deterministic checksum and validates:

1. Registered migrations before schema mutation: nonempty chain, unique positive versions, exact ascending input order, and continuous versions starting at V1.
2. Existing persisted history before pending migrations: readable complete rows, unique versions, no future version, continuous prefix from V1, and exact version/name/checksum equality with the registered definitions.
3. Final history after migrations: one complete exact record for every registered V1-V4 migration.

A genuinely fresh empty database may create the migration metadata table and apply V1-V4. A database with application schema but missing history is not treated as fresh. The validator never repairs or normalizes inconsistent records.

Debug lifecycle backup verification calls the same persisted-history validator in final-history mode, then retains its existing required-table checks. Highest-version equality alone is insufficient.

## Unavailable behavior and workflows

Unavailable repository adapters implement every current repository protocol method and reject centrally. This covers current and future reads and writes that use the active provider, including workspace, account, transaction, import-session, import-attempt, fingerprint/event lookup, atomic history, and account metadata operations.

Import preparation checks provider state before opening the source. Confirmation checks again immediately before persistence. Hydration checks before repository reads and therefore cannot replace any runtime store when unavailable. Central repository rejection remains authoritative if a workflow check is bypassed or availability changes.

Settings, Developer Console, and application-level import/hydration presentation observe the provider-owned state and distinguish verified SQLite, intentional Debug/test memory, and unavailable persistence. Recovery guidance is bounded and contains no database path, SQL, raw SQLite error, source content, account identifier, or financial value.

## Test matrix

- Registered chain: duplicates, missing/non-contiguous versions, unsorted order, valid V1-V4.
- Persisted history: duplicate, missing lower, mismatched name/checksum, null/incomplete row, edited SQL, future version, fresh V1-V4 creation, V1/V2/V3 upgrades, V4 reopen.
- Bootstrap: open/migration/integrity failure, no memory fallback, unavailable publication, publication only after validation, verified success.
- Enforcement: repository read/write, import preparation/confirmation, account metadata, and hydration rejection without store replacement.
- Presentation/privacy: truthful Settings and Developer Console state; unavailable output omits paths, SQL, and raw SQLite errors.
- Regression: explicit memory providers, Debug temporary sessions and lifecycle backup, Sprint 45 lifecycle, Sprint 46 parent-upsert/provider parity, valid import, and valid hydration.

## Unchanged boundaries

ADR-024 remains the sole repository-to-runtime publication boundary; ADR-026 diagnostics remain structured, privacy-safe, and in memory; ADR-035 Debug lifecycle and provider-generation rules remain intact. There is no Migration V5, automatic recovery expansion, production reset/restore, repository-protocol redesign, import-pipeline redesign, category/parser work, or unrelated UI refactor.
