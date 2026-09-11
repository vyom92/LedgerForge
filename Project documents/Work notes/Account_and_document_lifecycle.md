# Account and document lifecycle

<a id="packet-account-lifecycle-packet"></a>
<a id="packet-document-library-packet"></a>

**Owners:** [FW-P2-01](../FUTURE_WORK.MD#fw-p2-01), [FW-P2-30](../FUTURE_WORK.MD#fw-p2-30), [FW-P2-31](../FUTURE_WORK.MD#fw-p2-31), [FW-P2-32](../FUTURE_WORK.MD#fw-p2-32), [FW-P2-33](../FUTURE_WORK.MD#fw-p2-33), [FW-P2-34](../FUTURE_WORK.MD#fw-p2-34), [FW-P2-35](../FUTURE_WORK.MD#fw-p2-35), [FW-P2-36](../FUTURE_WORK.MD#fw-p2-36), [FW-P2-37](../FUTURE_WORK.MD#fw-p2-37), [FW-P2-38](../FUTURE_WORK.MD#fw-p2-38), [FW-P2-54](../FUTURE_WORK.MD#fw-p2-54).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What account metadata/lifecycle or document access behavior should the owner be able to control?

## Current conclusion

Repository discovery found schema `AccountStatus` values active/archived/closed and historical `closed_at` capacity, but DTO/repository query/hydrator publication did not establish the proposed account lifecycle. Queries primarily expose name/ID behavior. Schema capacity is not an implemented workflow.

Targeted account display-name mutation is already accepted; the open metadata card concerns its broader remainder. A smallest additional metadata slice proposes one owner-selected field with validation, DTO/provider mapping and canonical reload while preserving immutable identity. Notes, custom colour/icon, institution logos, groups/favourites/order are separate owner choices, not implied by metadata editing. Logos need permitted assets, exact mapping and neutral fallback; they are not financial identity evidence.

Archive/restore, hide and close are distinct operations. Approve transitions, whether new imports may target each state, visibility/navigation and financial totals, closure date/source, post-closure imports and restoration. Hiding cannot silently change net-worth membership. Imported history and identifiers remain intact unless a separately approved financial mutation requires more.

The proposed document library can start with existing metadata and relationships: safe display labels, source type/profile, date/coverage only where known, account/session links and truthful full/duplicate/partial/legacy-unknown outcomes. It must not invent a complete file archive or treat a fingerprint as a live file URL. Current durable metadata has no retained-original or security-scoped bookmark authority.

Reopening is a separate unresolved choice: metadata-only browsing; owner reauthorization with fingerprint checking; or explicitly approved retained bytes and access/retention architecture. No selected option or stored originals are implied. Metadata-only browsing was proposed as the smallest boundary with no migration; that is a recommendation, not accepted architecture. Read-only navigation must preserve missing/legacy facts rather than borrow an unrelated session label for a document.

## Evidence and references

2026-09-10 repository discovery at the two pinned refs. Accepted ADR-008/024/033/037/038 and exact source-document binding remain controlling. No local financial original or database was opened for this refactor.

- [Core/DocumentStore.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Core/DocumentStore.swift#L16); SHA-256 `f4bb0ff9bb28d34154d38216130b32e730757b27054a881e17250aa7776c9aec` — DocumentStore
- [Database/DTOs.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/DTOs.swift#L351); SHA-256 `3d481ce8c1d69cbef77687587628a5d8764922fe2d8a4bcd88c7cb4b0ecfd6b3` — AccountDTO
- [Database/DTOs.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/DTOs.swift#L351) — DTO does not carry status.
- [Database/Migrations.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Migrations.swift#L150); SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — accounts.closed_at
- [Database/Migrations.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/Migrations.swift#L150) — closed_at schema capacity.
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L248); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ImportSessionRepository
- [Database/SQLiteRepositoryProvider.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/SQLiteRepositoryProvider.swift#L1920); SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — account and accounts queries
- [Database/SQLiteRepositoryProvider.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/SQLiteRepositoryProvider.swift#L1921) — closed_at omitted.
- [Database/SQLiteRepositoryProvider.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/SQLiteRepositoryProvider.swift#L1937) — Current order is name/id.
- [LedgerForgeTests/TransactionListViewModelTests.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/LedgerForgeTests/TransactionListViewModelTests.swift#L65); SHA-256 `30c938da8a204989e27b1b070a352b8bd784cf111ef01dd2b04f6dd3f8f3641f` — detail provenance presentation tests
- [Models/Account.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Models/Account.swift#L18); SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountStatus and status field
- [Models/Account.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Models/Account.swift#L18) — Status values do not settle hide semantics.
- [Models/Account.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Models/Account.swift#L18) — In-memory model capacity.
- [Models/Account.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Models/Account.swift#L18) — active/archived/closed enum exists.
- [Services/RepositoryStoreHydrator.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Services/RepositoryStoreHydrator.swift#L348); SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — canonical account hydration
- [Services/RepositoryStoreHydrator.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Services/RepositoryStoreHydrator.swift#L1936) — status not hydrated.
- [ViewModels/TransactionListViewModel.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/ViewModels/TransactionListViewModel.swift#L120); SHA-256 `7e2dbde244295009d00df9cf6f6f5606f2e123374c912c346df4b07936b1cbd9` — detailPresentation(for:)

## Unresolved decision or blocker

Owner product choice and an approved metadata/lifecycle or file-access contract remain missing. Do not bundle all account features, file retention and repair into one mutation.

## What would invalidate this conclusion

Current DTO/provider/hydrator evidence proving an already implemented workflow, or a new explicit owner field/access decision, changes the scope. Unknown identity, totals impact, retention authority or stale file fingerprint falsifies a proposed safe operation.
