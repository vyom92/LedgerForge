# Backup and export

<a id="packet-export-boundary-packet"></a>
<a id="packet-user-backup-restore-architecture-packet"></a>

**Owners:** [FW-P3-17](../FUTURE_WORK.MD#fw-p3-17), [FW-P3-35](../FUTURE_WORK.MD#fw-p3-35), [FW-P3-36](../SCOPE_DECISIONS.md#fw-p3-36).

Sprint 93 and [ADR-047](../ADR.md#adr-047) are accepted; the selected verified backup/restore outcome is complete. Optional export remains separate. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What evidence would prove the owner can recover the ledger, and how is optional export different?

## Current conclusion

UD-02 makes verified backup/restore required and complete structured export optional. UD-12 keeps one local ledger and device-local appearance; backup packages may be copied to an owner-chosen destination without creating sync, a live portable workspace or multiple-workspace architecture. The owner has no current app-level encryption concern; encryption is neither a parked candidate nor a recovery dependency.

The owner approved the two-member Finder package, destination-folder selection, strict current-chain compatibility, snapshot/restore-receipt identity without permanent ledger lineage, isolated verification and interruption-safe replacement. [ADR-047](../ADR.md#adr-047) is the architecture authority; no V18 is allocated. Routine product checks remain separate from the independent in-memory acceptance comparison.

### Sprint 93 accepted — 2026-09-15

**FW-P3-36 is COMPLETE** for the selected verified backup, restore and disaster-recovery outcome under accepted ADR-047 and `SPRINT_93_VERIFIED_BACKUP_RESTORE_AND_DISASTER_RECOVERY_ACCEPTED`. The owner/coordinator accepts the unchanged candidate and authorizes documentation closure/publication. [The accepted Sprint-93 record](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-93) now owns the original 2026-09-14 Debug/Release, focused-test, genuine P0/P1/P2, native, rollback/interruption, content and cleanup evidence, together with the explicitly unobserved limits. No recovery/build/test campaign is rerun during closure.

The observed source and closed snapshot had zero attachment rows/nonempty attachment BLOB payloads. Unknown future embedded payloads still require an explicit content decision; no ledger rows may be stripped. The two product backups and raw Release safety snapshot remain outside Git and the original-statement directory, unchanged during publication. Appearance preferences stay device-local and excluded; encryption remains not required/not selected. Sprint 94 is NEXT / NOT STARTED; PERSONAL-V1 remains NOT YET ADOPTED.

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

## Current disposition

The selected backup/restore outcome is accepted and publication is authorized. Strict format-1/current-chain compatibility and the recorded recovery limits remain in force. Future schema changes require an explicit backup-compatibility decision. Complete structured export is OPTIONAL / NOT SELECTED; no restore-from-export workflow is implied. Sprint 94 is NEXT / NOT STARTED and still requires its own execution authorization.

## What would invalidate this conclusion

An inconsistent WAL snapshot, unknown migration identity, missing financial projection, lost source relationship, partial activation, failure to reopen the same database or reliance on memory-only behavior invalidates recovery proof. Package/encryption/portability assumptions not explicitly approved exceed scope.
