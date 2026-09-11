# Financial integrity and corrections

<a id="packet-chat-decision-packet"></a>

**Owners:** [FW-P0-02](../FUTURE_WORK.MD#fw-p0-02), [FW-P0-08](../FUTURE_WORK.MD#fw-p0-08), [FW-P0-11](../FUTURE_WORK.MD#fw-p0-11), [FW-P0-12](../FUTURE_WORK.MD#fw-p0-12), [FW-P0-13](../FUTURE_WORK.MD#fw-p0-13), [FW-P0-14](../FUTURE_WORK.MD#fw-p0-14), [FW-P0-15](../FUTURE_WORK.MD#fw-p0-15), [FW-P0-16](../FUTURE_WORK.MD#fw-p0-16), [FW-P0-18](../FUTURE_WORK.MD#fw-p0-18), [FW-P1-22](../FUTURE_WORK.MD#fw-p1-22), [FW-P1-23](../FUTURE_WORK.MD#fw-p1-23), [FW-P1-24](../FUTURE_WORK.MD#fw-p1-24), [FW-P1-25](../FUTURE_WORK.MD#fw-p1-25), [FW-P1-27](../FUTURE_WORK.MD#fw-p1-27), [FW-P3-02](../FUTURE_WORK.MD#fw-p3-02), [FW-P3-03](../FUTURE_WORK.MD#fw-p3-03), [FW-P3-04](../FUTURE_WORK.MD#fw-p3-04), [FW-P3-05](../FUTURE_WORK.MD#fw-p3-05).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What exact local integrity, identity or import correction can be independently proved and safely applied?

## Current conclusion

Accepted ADR-037 defines the generic financial-mutation boundary, not an executable repair family. Confirmed-import identifier enrichment is already accepted under ADR-038/Sprint 50. Historical unlink/reassignment, split, merge, duplicate repair and reversal remain separate, unaccepted capabilities. The queue preserves each ID and distinct outcome.

The proposed first integrity slice is **read-only graph verification**: selected invariant classes, opaque IDs/counts and typed findings over the genuine local graph. It would not repair, hydrate, alter migrations or invent financial values. Verification and repair are different capabilities. Candidate families compared were duplicate repair, identifier unlink/reassignment, wrong-account split, duplicate-account merge, import-session reversal and read-only integrity verification. None has an approved broad “repair everything” contract.

For a selected mutation, an independent oracle must prove the affected accounts, identifiers and observations, documents/fingerprints, import sessions, source relationships, shared transactions, categories and later-import effects. Review exact native-currency impact; obtain explicit confirmation; revalidate authoritative claims in one provider-owned transaction; preserve zero losing-path residue; hydrate canonically. Define inverse/compensation or explicit irreversibility before execution. A stale review, unknown ownership, conflict or partial failure must reject without partial publication.

Preview editing needs separate source, normalized, user and derived authority plus genuine correction evidence. Description changes cannot erase imported text. Manual account override cannot turn a weak candidate into verified identity. Duplicate-account proof must precede survivor/conflict design. Removing an import cannot delete shared truth or invalidate later imports silently. Import backfill is separately discussed in [source relationships](Source_relationships.md).

Incoming duplicate-attempt review can start with a proposed read-only typed taxonomy; it does not grant arbitrary override or historical repair. ADR-040's historical V7 partial-import readback remains supported where accepted, while new provenance-less mixed overlap remains suspended. Existing APIs include a session-filtered replacement operation, but no trusted transaction-delete, identifier detach/move, graph movement, merge or import reversal endpoint establishes a general repair. Confirmed import only attaches unowned/same-owner strong identifiers; a conflicting owner rejects the entire graph.

No new historical duplicate relation was found in the 2026-09-10 source review: the supported whole-statement relationships were already governed.

The historical Axis `axis.bank-account.csv@1` direction-risk window and its exact commit are preserved in [historical capability limits](../Archive/Accepted%20outcomes/Sprints_70-79.md#historical-capabilities-and-limitations). No current database is presumed affected and no correction is authorized by that record.

## Evidence and references

2026-09-10 read-only repository/source rounds at `adcf83f52d309ddac18d95f0321d0c0f6120dd29` and `af2d1949c6e9a73af3bb004422b72882d28195e2`. Existing acceptance is evidence for the foundations only. No affected corrupt snapshot or independently proved repair case was supplied to those rounds.

- [Database/Migrations.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/Migrations.swift#L93) — durable graph has explicit relationships
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L228); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — AccountRepository
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L248); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ImportSessionRepository
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L279); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ConfirmedImportRepository
- [Database/SQLiteConfirmedImportRepository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/SQLiteConfirmedImportRepository.swift#L182); SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — commitInsideTransaction
- [Database/SQLiteConfirmedImportRepository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/SQLiteConfirmedImportRepository.swift#L182); SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — identifier ownership
- [Database/SQLiteConfirmedImportRepository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/SQLiteConfirmedImportRepository.swift#L207); SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — account choice
- [Project documents/ADR.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/ADR.md#L3460); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/ADR.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/ADR.md#L3480); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/ADR.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/ADR.md#L4720); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-040
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3451) — trusted history correction is unapproved
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3451) — reassignment unapproved
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3451) — identifier detachment has no approved operation
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3451) — merge has no approved architecture
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3476) — identity must be preserved
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3476) — identity and provenance must be preserved
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3478) — parser-owned identity/provenance retained
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3497) — lifecycle is accepted but no concrete mutation is authorized
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3523) — no import reversal is introduced
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L4621) — no unlinking or historical repair
- [Project documents/LedgerForge_Standing_Execution_Harness_Guide.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/LedgerForge_Standing_Execution_Harness_Guide.md#L203) — private originals remain isolated
- [Services/IdentityResolver.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Services/IdentityResolver.swift#L6); SHA-256 `ca46f8c7f1a3405c68388f5d306985db036bbf70f7cf7713e104dfd5c7ebbe37` — FinancialIdentifier kind/strength/verification/provenance and redaction
- [Services/ImportPersistenceCoordinator.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Services/ImportPersistenceCoordinator.swift#L1857); SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — exactDuplicate
- [Services/ImportPersistenceCoordinator.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Services/ImportPersistenceCoordinator.swift#L1845) — outcomes are distinct

## Unresolved decision or blocker

Chat must select and approve one concrete family, proof classes, exact impact and reversal contract. For the read-only verifier, approve invariant/result scope first; an actual snapshot is needed for execution. Repository-integrity checks are optional to other repairs unless a selected contract establishes a real dependency.

## What would invalidate this conclusion

A supplied snapshot, source-proven duplicate or actual mistaken link may establish a bounded case. Any invariant that cannot be proven from the chosen graph, diagnostic need for financial values, unknown shared ownership, incomplete reversal or changed provider/migration/hydrator generation ownership invalidates the proposed boundary.
