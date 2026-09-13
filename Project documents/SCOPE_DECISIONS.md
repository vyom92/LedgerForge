# Scope decisions

## Current personal-app scope

LedgerForge is the owner's private, single-user, offline-first MacBook application: a nicer replacement for the Budget Analysis sheet, bringing truthful bank, card and investment statement data into one place for personal transactions, spending and planning. It is not a public/commercial platform. Financial/source truth, durable persistence, deterministic behavior, explicit control and recoverability remain binding.

The adopted personal outcome includes supported authentic imports, practical R1 UI, verified backup/restore, current Salary/This Month Al Dar with manual override, current holdings/valuation, current FX/net worth and a small private source-support matrix. Complete export is optional. **PERSONAL-V1: NOT YET ADOPTED.** Scope decisions are not architecture or implementation acceptance; see [current state](PROJECT_STATE.md), [open work](FUTURE_WORK.MD) and [ADRs](ADR.md).

## Settled product decisions

<a id="source-processing-decision"></a>
### Source processing — owner clarification, 2026-09-11 (current)

The owner explicitly permits **in-memory processing only** of authentic originals in `/Users/vyom/Documents/Ledger Forge`, prohibits **all derived financial evidence files on disk**, and clarifies **“Keep app database; prohibit derived evidence files.”** The normal financial database remains permitted. Do not write copied/decrypted/extracted/reconstructed statement files, source-oracle records or derived financial validation artifacts. Independent source interpretation/oracle comparison remains required in memory; missing proof is still a blocker, never a reason to invent inputs or weaken financial acceptance. Historical copy/oracle-artifact permissions are superseded for new work. Existing historical artifacts are not deleted or retroactively reclassified by this documentation task.

This rule changes documentation authority only. Existing validation scripts/tests and artifact behavior were not changed or certified against it. Before a future financial run, establish that its processing and outputs comply; stop if the required evidence cannot be produced within the rule. The app's ordinary database and the settled user backup/restore product requirement are distinct from development/validation evidence files; no backup implementation is accepted here.


Order follows [Guide rule C](Project_Guide.md#documentation-order): known decision date descending; same-date natural UD-ID display order when no decision sequence is recorded; undated decisions last. “Undated” does not mean new. Quoted owner direction below is preserved from the scope-reset record; status identifies supersession.

**Documentation intake clarification — owner-authorized task, 2026-09-11 (current).** Record ideas, defects, features and useful maintenance. Any one concrete personal-workflow, correctness/recovery, authentic-source or day-to-day convenience/appearance ground establishes relevance. A convenience or appearance idea need not solve a financial safety problem. Distinguish owner requests, reported defects, verified findings and contributor proposals. Capture is not approval, readiness, scheduling or execution. Preserve meaningful rejection reasons; parked personal ideas are not rejected categories. This supersedes the former conjunctive “workflow AND financial problem” test without reopening any rejected capability.

| ID | Owner direction | Status / authority | Decision date |
| --- | --- | --- | --- |
| <a id="ud-12"></a>UD-12 | LedgerForge is private, personal, single-user and macOS-local. Exclude hypothetical commercial/platform work; reopen only by a new explicit owner decision naming a real need. Retain FW-P0-18 and FW-P1-30/34/35/38/39/39A only for single-user MacBook workflows; remove unselected source placeholders and app-level encryption (no current concern). Preserve design images and explicitly ignore rejected caption portions. | CURRENT — explicit scope reset and clarifications, 2026-09-11; simple local appearance, required backup/restore, Sprint-100 personal adoption verification; no architecture or product implementation accepted; explicit owner direction retained from scope reset | 2026-09-11 |
| <a id="ud-02"></a>UD-02 | Require backup/restore; keep complete export optional | CURRENT, subject to latest UD-09/10 scope; explicit owner direction retained from scope reset | 2026-09-10 |
| <a id="ud-06"></a>UD-06 | Use reviewable suggestions first (Recommended) | CURRENT, subject to latest UD-09/10 scope; explicit owner direction retained from scope reset | 2026-09-10 |
| <a id="ud-09"></a>UD-09 | i do not need qar to inr historical. its sole purpose is to estimate how much i will get in inr end of the month based on the monthly salary/budget calculator. if needed i can manually override my own fx rate on live/current rate | CURRENT, subject to latest UD-09/10 scope; explicit owner direction retained from scope reset | 2026-09-10 |
| <a id="ud-10"></a>UD-10 | same with inr to usd. i just need current estimation of net worth in different currencies. not a basket of historical conversions | CURRENT, subject to latest UD-09/10 scope; explicit owner direction retained from scope reset | 2026-09-10 |
| Direct-plan mutual funds | Use Direct-plan holdings, never assume Regular-plan; exact scheme/ISIN/plan/option required | Current; explicit owner investment clarification | 2026-09-09 |
| <a id="ud-01"></a>UD-01 | Propose current holdings first; keep history and performance gated | CURRENT, subject to latest UD-09/10 scope; explicit owner direction retained from scope reset | Undated in decision record |
| <a id="ud-03"></a>UD-03 | Include appearance preferences when moving/restoring a workspace | SUPERSEDED by UD-12; historical decision only; explicit owner direction retained from scope reset | Undated in decision record |
| <a id="ud-04"></a>UD-04 | Require current and historical conversion together | SUPERSEDED by UD-10; chronological evidence only; explicit owner direction retained from scope reset | Undated in decision record |
| <a id="ud-05"></a>UD-05 | 1 January 2021 onward is sufficient | SUPERSEDED by UD-10; chronological evidence only; explicit owner direction retained from scope reset | Undated in decision record |
| <a id="ud-07"></a>UD-07 | Just to clarify https://www.aldarexchange.com/aldarportal/Home is the source of any qar to inr conversion as that gives actual transfer rate. only for inr to usd or qar to usd you can use market sources | NARROWED by UD-09/10; chronological scope only; explicit owner direction retained from scope reset | Undated in decision record |
| <a id="ud-08"></a>UD-08 | Use a direct market INR→USD rate | CURRENT, subject to latest UD-09/10 scope; explicit owner direction retained from scope reset | Undated in decision record |
| <a id="ud-11"></a>UD-11 | Fix Sprint 100 as certification only; require the settled pre-100 outcomes, including bounded current Al Dar, current holdings/valuation and current FX/net worth | Milestone and personal outcomes retained; terminology/program scope SUPERSEDED by UD-12; explicit owner direction retained from scope reset | Undated in decision record |

The former Zurich 0.75 multiplier is retired; its retirement date is not established here and no replacement vesting factor is inferred. No fixed FX haircut is approved. See [holdings evidence](Work%20notes/Holdings_and_valuation.md) and [current Al Dar](Work%20notes/Salary_and_current_AlDar.md).

## Rejected work

<a id="rejected-private-personal-scope"></a>
Each row records **NOT REQUIRED-DO NOT CONSIDER**, not a parked candidate. It cannot enter sprint triage, block retained work or be rediscovered under a new name. Reopening requires a new explicit owner decision naming the exact capability and real personal need. A covered rejection needs a link; a genuinely new material rejection gets one short durable reason, not a research campaign.

All rows below belong to the explicit 2026-09-11 scope reset and subsequent same-task owner clarifications. Exact within-day decision sequence is not recorded for every ID, so natural former-ID order is a display tie-break under Guide rule C.

| Topic / former ID | Decision | Reason and retained boundary | Authority / date |
| --- | --- | --- | --- |
| <a id="fw-p0-20"></a>`FW-P0-20` — Additional Transaction-Event Evidence Families | **NOT REQUIRED-DO NOT CONSIDER** | no selected new evidence or concrete owner workflow; accepted source facts, existing regression duties and financial-safety rules remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-01"></a>`FW-P1-01` — Additional Axis Bank-Account Parser Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-02"></a>`FW-P1-02` — Additional HDFC Parser Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-03"></a>`FW-P1-03` — Additional CBQ Parser Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-04"></a>`FW-P1-04` — Additional Credit-Card Parser Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-05"></a>`FW-P1-05` — Additional Salary, Brokerage, Fund, Insurance, Tax and Government Document Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-06"></a>`FW-P1-06` — Parser Framework Expansion | **NOT REQUIRED-DO NOT CONSIDER** | minimum shared changes remain possible only when proven necessary by a real selected authentic source. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-07"></a>`FW-P1-07` — Statement Learning Mode and Profile Library | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-08"></a>`FW-P1-08` — AI-Assisted Column Detection | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-09"></a>`FW-P1-09` — Remaining Credit-Card Financial Semantics | **NOT REQUIRED-DO NOT CONSIDER** | no selected new evidence or concrete owner workflow; accepted source facts, existing regression duties and financial-safety rules remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-10"></a>`FW-P1-10` — Additional Native-Text PDF Statement Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-11"></a>`FW-P1-11` — Additional Password-Protected PDF Families | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-12"></a>`FW-P1-12` — Additional Credential Profile and Password-Storage Capabilities | **NOT REQUIRED-DO NOT CONSIDER** | existing exact Keychain-supported families remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-13"></a>`FW-P1-13` — Additional Per-File Credential Override Policy | **NOT REQUIRED-DO NOT CONSIDER** | existing exact Keychain-supported families remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-14"></a>`FW-P1-14` — Additional XLS/XLSX Source Families and Spreadsheet Capabilities | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-15"></a>`FW-P1-15` — TXT Statement Support | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-16"></a>`FW-P1-16` — Additional Cross-Format Financial Relationships | **NOT REQUIRED-DO NOT CONSIDER** | no selected new evidence or concrete owner workflow; accepted source facts, existing regression duties and financial-safety rules remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-17"></a>`FW-P1-17` — OCR Fallback | **NOT REQUIRED-DO NOT CONSIDER** | no additional authentic owner source selected; actual supported-source facts/corpus gaps remain authoritative. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-29"></a>`FW-P1-29` — Better Validation Guidance | **NOT REQUIRED-DO NOT CONSIDER** | accepted useful diagnostics/guidance remain; owner-retained local workflows are separately narrowed. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-31"></a>`FW-P1-31` — Repository Inspector | **NOT REQUIRED-DO NOT CONSIDER** | accepted useful diagnostics/guidance remain; owner-retained local workflows are separately narrowed. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-32"></a>`FW-P1-32` — Development SQLite Browser | **NOT REQUIRED-DO NOT CONSIDER** | accepted useful diagnostics/guidance remain; owner-retained local workflows are separately narrowed. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-33"></a>`FW-P1-33` — Import-Session Inspector | **NOT REQUIRED-DO NOT CONSIDER** | accepted useful diagnostics/guidance remain; owner-retained local workflows are separately narrowed. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-36"></a>`FW-P1-36` — Diagnostic Export | **NOT REQUIRED-DO NOT CONSIDER** | accepted useful diagnostics/guidance remain; owner-retained local workflows are separately narrowed. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p1-37"></a>`FW-P1-37` — Better Developer Diagnostics and Failure Summaries | **NOT REQUIRED-DO NOT CONSIDER** | accepted useful diagnostics/guidance remain; owner-retained local workflows are separately narrowed. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-45"></a>`FW-P2-45` — Improved Global Search | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-49"></a>`FW-P2-49` — R1 Native Accessibility Closure | **NOT REQUIRED-DO NOT CONSIDER** | ordinary readable, unclipped, usable native interaction and harmless existing semantics remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-51"></a>`FW-P2-51` — Startup, Runtime and Import Performance Optimization | **NOT REQUIRED-DO NOT CONSIDER** | a later actual measurable defect receives its own bounded cause/fix. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-56"></a>`FW-P2-56` — Development Performance Profiling | **NOT REQUIRED-DO NOT CONSIDER** | a later actual measurable defect receives its own bounded cause/fix. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-63"></a>`FW-P2-63` — Additional Cross-Format Authentic-Source Semantic-Parity Tests | **NOT REQUIRED-DO NOT CONSIDER** | no selected new evidence or concrete owner workflow; accepted source facts, existing regression duties and financial-safety rules remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-64"></a>`FW-P2-64` — Large-Statement and Long-Running Import Tests | **NOT REQUIRED-DO NOT CONSIDER** | no selected new evidence or concrete owner workflow; accepted source facts, existing regression duties and financial-safety rules remain. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-69"></a>`FW-P2-69` — Remaining macOS CI and UI Smoke Validation | **NOT REQUIRED-DO NOT CONSIDER** | no concrete CI/UI-smoke/distribution objective; accepted repository-owned local build/test/run validation remains intact. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p2-70"></a>`FW-P2-70` — Remaining macOS Target and Distribution Metadata Hardening | **NOT REQUIRED-DO NOT CONSIDER** | keep only local build/signing/sandbox requirements needed on the owner’s Mac. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-37"></a>`FW-P3-37` — Optional Encrypted Sync | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-38"></a>`FW-P3-38` — Open API and External Integrations | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-39"></a>`FW-P3-39` — External Import Plugin Architecture | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-40"></a>`FW-P3-40` — Multiple Workspaces and Independent Ledgers | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-41"></a>`FW-P3-41` — Portable Workspace Folder | **NOT REQUIRED-DO NOT CONSIDER** | verified backup packages may be saved/copied to an owner-chosen destination; no live workspace architecture. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-42"></a>`FW-P3-42` — Cross-Platform Desktop Strategy | **NOT REQUIRED-DO NOT CONSIDER** | Individual rationale not recorded; excluded by the explicit private-personal scope reset. Do not infer a broader rejection by keyword. | Owner scope reset / clarifications, 2026-09-11 |
| <a id="fw-p3-43"></a>`FW-P3-43` — Local-Data Encryption at Rest | **NOT REQUIRED-DO NOT CONSIDER** | owner states no current disclosure/encryption concern; no parked candidate or backup dependency. | Owner scope reset / clarifications, 2026-09-11 |

Retained exceptions are explicit: FW-P0-18 and FW-P1-30/34/35/38/39/39A remain useful single-user MacBook candidates; FW-P0-19 keeps only the three existing Axis-bank groups. Existing Developer Console, exact supported Keychain behavior, local build/signing/sandbox needs, tooltips/readability and harmless native SwiftUI semantics remain. Rejected formal VoiceOver qualification does not reject those behaviors. Preserve design PNG bytes and ignore only the [exact superseded captions](UI%20Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md#ignored-caption-portions).

## Consolidation and completed-ID references

Order inherits Guide rule D: former ID in natural ascending order. IDs are never reused. Completed scope is historical; remaining scope stays in the open queue.

| Former ID | Destination / meaning |
| --- | --- |
| <a id="fw-p2-03"></a>FW-P2-03 | Completed by [accepted Sprint 89](Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89). |
| <a id="fw-p2-53"></a>FW-P2-53 | Completed by [accepted Sprint 89](Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89). |
| <a id="fw-p2-55"></a>FW-P2-55 | Consolidated into [FW-P2-52](FUTURE_WORK.MD#fw-p2-52), simple device-local appearance. Theme-engine machinery is removed, not deferred. |
| <a id="fw-p2-67"></a>FW-P2-67 | Completed by [accepted Sprint 88](Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-88). |
| <a id="fw-p2-74"></a>FW-P2-74 | Completed by [accepted Sprint 85](Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-85). |
| <a id="fw-p2-75"></a>FW-P2-75 | Completed by [accepted Sprint 86](Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-86). |
| <a id="fw-p2-76"></a>FW-P2-76 | Completed by [accepted Sprint 87](Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-87). |
| <a id="fw-p2-78"></a>FW-P2-78 | Completed by [accepted Sprint 90](Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-90), R1 Dashboard Native-Currency Hierarchy. |
