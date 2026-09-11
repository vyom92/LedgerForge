# Backup and export

<a id="packet-export-boundary-packet"></a>
<a id="packet-user-backup-restore-architecture-packet"></a>

**Owners:** [FW-P3-17](../FUTURE_WORK.MD#fw-p3-17), [FW-P3-35](../FUTURE_WORK.MD#fw-p3-35), [FW-P3-36](../FUTURE_WORK.MD#fw-p3-36).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What evidence would prove the owner can recover the ledger, and how is optional export different?

## Current conclusion

UD-02 makes verified backup/restore required and complete structured export optional. UD-12 keeps one local ledger and device-local appearance; backup packages may be copied to an owner-chosen destination without creating sync, a live portable workspace or multiple-workspace architecture. The owner has no current app-level encryption concern; encryption is neither a parked candidate nor a recovery dependency.

The proposed backup package contains `ledger.sqlite` plus a manifest with format version, build/migration identities, schema, opaque ledger identity, creation time, file size/hash and explicit content exclusions. Manifest metadata should not duplicate financial values. It excludes credentials, original statements, diagnostic records and appearance preferences; reporting configuration needs its own approved financial ownership boundary. This is a proposal, not an accepted backup schema.

SQLite/WAL consistency requires an approved online-backup or checked-close snapshot. Current DEBUG fixed-identity tooling does not establish a Release/user backup product. Proposed restore verifies a task-owned isolated copy first: package/hash/compatibility, migration identities, integrity and foreign keys plus an independent financial projection. Activation must quiesce operations, invalidate stale generations, check close, preserve the current canonical database, swap the verified candidate and prove canonical hydration and same-database relaunch. Failure must restore the previous valid state or remain explicitly unavailable; never silently start empty. Nonempty-current protection and explicit owner confirmation are required by the proposed contract. A non-durable In-Memory mechanism cannot prove durable restore.

Complete structured export is a one-way logical product, not a restorable database. Its proposed versioned output needs stable IDs/relationships, native Money and civil dates, order/multiplicity, counts, closure and explicit omissions. Atomic output/cancellation must leave no partial published artifact. Spreadsheet-bound text needs literal-safe encoding. Exclude credentials, originals and diagnostics; no automatic import/restore promise. A selected report CSV needs its own bounded schema rather than assuming complete export. Both export items remain optional and parked under the recorded decision.

## Evidence and references

Owner UD-02 recorded 2026-09-10, UD-12 scope reset 2026-09-11; read-only SQLite/DEBUG tooling review in the 2026-09-10 backup/export packets. No database or Keychain was opened, backup created or restore executed by this refactor.

- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L201); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/SQLiteDatabase.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/SQLiteDatabase.swift#L109); SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — createBackup; checkpointAndClose
- [Database/SQLiteDatabase.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/SQLiteDatabase.swift#L90) — WAL, SQLite online backup and checked close exist.
- [Database/SQLiteRepositoryProvider.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/SQLiteRepositoryProvider.swift#L1381); SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — createAndVerifyBackup; restorePersistentDebugBackup
- [LedgerForgeTests/MigrationChainIntegrityTests.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/LedgerForgeTests/MigrationChainIntegrityTests.swift#L253); SHA-256 `6ad68d2dd32d041fe1224e644c3d067d3539ecfb63dd53793560e22f3d854688` — empty historical prefixes and fail-closed history tests
- [LedgerForgeTests/MigrationIdentityLockTests.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/LedgerForgeTests/MigrationIdentityLockTests.swift#L1); SHA-256 `722c49a26a6785be7c4d537973d0a2790fc84b162d310e04ed399e6fdd0fcae9` — independent identity lock and drift detection
- [Services/RepositoryStoreHydrator.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Services/RepositoryStoreHydrator.swift#L209); SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()

## Unresolved decision or blocker

Chat must approve backup contents, snapshot/integrity/compatibility policy, isolated verification, activation/rollback and independent restore drill. A genuine source-backed persistent candidate and exact provider ownership are required for acceptance. Optional export remains unselected.

## What would invalidate this conclusion

An inconsistent WAL snapshot, unknown migration identity, missing financial projection, lost source relationship, partial activation, failure to reopen the same database or reliance on memory-only behavior invalidates recovery proof. Package/encryption/portability assumptions not explicitly approved exceed scope.
