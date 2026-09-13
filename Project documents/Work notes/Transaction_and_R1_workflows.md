# Transaction and R1 workflows

<a id="packet-sprint89-data-algebra-packet"></a>
<a id="packet-sprint89-data-algebra"></a>
<a id="packet-sprint89-native-acceptance-procedure"></a>
<a id="packet-import-preview-responsive-placement"></a>

**Owners:** [FW-P2-04](../FUTURE_WORK.MD#fw-p2-04), [FW-P2-05](../FUTURE_WORK.MD#fw-p2-05), [FW-P2-06](../FUTURE_WORK.MD#fw-p2-06), [FW-P2-07](../FUTURE_WORK.MD#fw-p2-07), [FW-P2-08](../FUTURE_WORK.MD#fw-p2-08), [FW-P2-09](../FUTURE_WORK.MD#fw-p2-09), [FW-P2-12](../FUTURE_WORK.MD#fw-p2-12), [FW-P2-40](../FUTURE_WORK.MD#fw-p2-40), [FW-P2-41](../FUTURE_WORK.MD#fw-p2-41), [FW-P2-43](../FUTURE_WORK.MD#fw-p2-43), [FW-P2-44](../FUTURE_WORK.MD#fw-p2-44), [FW-P2-46](../FUTURE_WORK.MD#fw-p2-46), [FW-P2-47](../FUTURE_WORK.MD#fw-p2-47), [FW-P2-48](../FUTURE_WORK.MD#fw-p2-48), [FW-P2-50](../FUTURE_WORK.MD#fw-p2-50), [FW-P2-52](../FUTURE_WORK.MD#fw-p2-52), [FW-P2-79](../FUTURE_WORK.MD#fw-p2-79).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Current conclusion

[Sprint 89](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89) is accepted at `038af8d9ebebe66b3f17925416821941cfa33d3d` under `SPRINT_89_TRANSACTIONS_REFERENCE_ACCEPTED`. It completed FW-P2-03 and FW-P2-53, with only the necessary Transactions portions of FW-P2-48/50. Its settled search/filter/sort/total/selection/inspector behavior and Chat-accepted focused, build, independent in-memory-oracle, no-write, native and bundle-containment evidence belong in the [accepted outcome](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89), not in this unresolved-work note.

Saved filters remain separate work: their preference scope and persistence contract are not implied by transient Sprint-89 filters. Sprint 89 does not select transfer matching, analytics, hidden FX, spending/income inference, parser/source-family work, persistence/schema changes or a formal accessibility programme.

[Sprint 90](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-90) is accepted at `619c39ec07402a63c90b646cbba9ced806f5e99d` under `SPRINT_90_DASHBOARD_NATIVE_CURRENCY_HIERARCHY_ACCEPTED`, completing FW-P2-78. Its native-currency bank/card hierarchy, saved-plan reuse, read-only activity, responsive layouts and three ordinary keyboard actions are settled; detailed acceptance and the bounded calendar-day crash correction belong in that outcome record.

## Remaining R1 and interaction boundary

FW-P2-48 and FW-P2-50 retain genuine cross-screen polish and ordinary interaction needs beyond the accepted Transactions/Dashboard portions. After Sprint 91, refresh the [SC-05A audit](../UI%20Assets/LF-UI-2026-09-R1/LF-UI-2026-09-R1_SC-05A_Cross_Screen_Conformance_Matrix.md) before selecting Sprint-92 residue, including any still-applicable P1–P6 findings; this closure consumes none of those polish findings. Neither row is completed or a formal accessibility programme. [FW-P2-52](../FUTURE_WORK.MD#fw-p2-52) remains the next prepared Appearance candidate: the Dashboard prerequisite is satisfied, while bounded preference behavior and malformed-value fallback still require entry review. Sprint 91 remains **PREPARED / NOT YET CHAT-AUTHORIZED** and unimplemented.

### DRAFT — Import Preview Responsive Placement (user feedback, 2026-09-10)

This subsection records subjective user feedback and an unaccepted layout proposal. It does not change the approved visual direction, accepted Import workflow, source interpretation or native acceptance status. The user reports heavy scrolling in the left prepared-import region while the right region beneath Validation Review has unused space. The supplied private screenshot supports broad layout geometry only; its financial/source content is neither transcribed nor published.

**Owner:** [FW-P2-48](../FUTURE_WORK.MD#fw-p2-48), including its bounded owner-usability checks. This is an unaccepted discovery proposal, not an implementation or native-acceptance claim. Coordinate with [FW-P2-67](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-88) only when a selected shell decomposition affects this composition; no sprint is selected here.

**Candidate A, preferred for a sufficiently wide window:** place the existing read-only Transaction Preview beneath Validation Review in one right-column review stack. Keep the queue, prepared statement summary, account/identity and duplicate/equivalence explanation readable at left, with confirmation/cancel/skip controls visibly available. This placement is a suggestion, not a forced rule.

**Candidate B, responsive fallback:** place one full-width/shared Transaction Preview below the summary/review split when the right-side table cannot remain readable or validation content is long. Determine the breakpoint from content fit and text size. Do not duplicate the preview or create nested unbounded scroll owners.

Both candidates preserve source order/multiplicity, prepared status, identity/account review, validation, duplicate/equivalence semantics and explicit confirmation. They introduce no editing, filtering, sorting, source reopening, new selection semantics or financial/color change. Future native acceptance must cover broad/narrow windows, long validation, useful keyboard actions, scroll/focus and existing selection, footer visibility, cancellation/confirmation, and truthful empty states. A zero-transaction statement case requires genuine authentic evidence; if absent it stays untested. No native verification is claimed by this appendix.

## Evidence and references

The complete accepted Sprint-89 evidence is preserved in the [accepted outcome](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89). The following pinned references remain historical support for unresolved Transaction/R1 work; they do not revive the settled Sprint-89 proposal or claim a current runtime pass.

- [ContentView.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/ContentView.swift#L1507); SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — contextualToolbar
- [ContentView.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/ContentView.swift#L1443) — historical monolithic shell
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L208); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — TransactionRepository
- [Project documents/ADR.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/ADR.md#L3460); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/UI%20Assets/LF-UI-2026-09-R1/ACCEPTANCE.md#L38); SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — historical TX-01 to TX-10

## Unresolved decision or blocker

Import Preview alternatives remain proposals and require owner/design acceptance before selection. Remaining cross-screen R1 polish and ordinary interaction work need accepted Sprint-91 Appearance and a refreshed SC-05A audit; accepted Sprint 90 satisfies only the Dashboard portion. Missing genuine zero-activity cases remain untested; no financial substitute may be manufactured.

## What would invalidate this conclusion

A future implementation must stop for a new approved boundary if it requires financial/source reinterpretation, persistence/schema changes, an ADR, a new design authority, or a new native interaction model. A screenshot alone cannot establish a financial-semantic defect.
