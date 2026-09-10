# LedgerForge Future Work

## Process authority

Execution, recovery, Git/worktree safety, evidence handling and material-finding intake are governed by `AGENTS.md`, `Project_Guide.md` and `LedgerForge_Standing_Execution_Harness_Guide.md`.

`FUTURE_WORK.MD` owns the canonical unscheduled queue. It does not duplicate executor mechanics and it does not authorize implementation.

## Purpose

This document is the canonical planning queue for LedgerForge work that is not yet authorized for execution.

It records:

- product feature candidates;
- architectural follow-up work;
- verified bugs;
- maintenance work;
- technical debt;
- engineering-quality improvements;
- product ideas;
- research topics.

It exists so future work is selected from a recorded, evidence-based queue rather than reconstructed from conversations or inferred from incomplete project history.

Completed and verified work belongs in:

`Project documents/PROJECT_STATE.md`

Architectural decisions belong in:

`Project documents/ADR.md`

Execution is authorized only by the complete Chat-approved prompt supplied directly in the current conversation. Reports are returned directly in chat; verified durable facts belong in their subject authorities and Git history.

Items selected for execution must be removed from this document or narrowed to the portion that remains unscheduled.

---

## Authority

This document is a planning queue, not an implementation contract.

An item appearing here means only that the work has been recorded for future consideration.

It does not mean that the item:

- is approved for implementation;
- has been assigned a sprint number;
- will be selected next;
- has completed repository discovery;
- has an approved architecture;
- can be implemented independently of its dependencies.

No future sprint number may be assigned in this document.

A work item becomes executable only when Chat supplies one complete approved prompt to the explicitly authorized execution surface for that task.

---

## Full Candidate Verification Audit

**Audit date:** 2026-09-09
**Original audit baseline:** `main@a560312db5900645779a499016e13f0c87e81435`
**Sprint-81 queue-closure update:** 2026-09-10 at `main@13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`
**Sprint-82 queue-closure update:** 2026-09-10 at `main@d239f939088b67e5a90c65117f08592891be17bb`
**Sprint-83 queue-closure update:** 2026-09-10 at `main@adcf83f52d309ddac18d95f0321d0c0f6120dd29` (implementation parent `057d70b6f39929735401d5211cd180db162c94cc`)
**Active candidate count after Sprint-83 acceptance closure:** 151
**Current migration:** V17
**Current source/reliability architecture:** ADR-046 complete-authentic-corpus authority
**Current design authority:** `LF-UI-2026-09-R1` for its bounded scope
**Latest accepted numbered implementation:** Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop
**Latest accepted numbered discovery:** Sprint 80 — `SWIFT6_READINESS_COMPLETE`
**Personal-v1:** UNDECLARED / NOT CERTIFIED

The Sprint-83 closure mechanically re-enumerated every active `FW-*` heading: 151 candidates, 151 unique IDs, no duplicate IDs and no malformed candidate headings. The original audit reconciled candidates against `PROJECT_STATE.md`, the current 80–89 roadmap, the Standing Harness, relevant accepted ADRs, Product Vision, R1 design authority and current repository evidence where documentation was insufficient.

Reconciliation outcomes:

- `FW-P2-72` is removed from the active queue because Sprint 81 completed and Chat accepted the PR-1 staging/runtime-publication ownership seam at implementation commit `13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`.
- `FW-P1-19` is removed from the active queue because Sprint 82 completed and Chat accepted the serial Unified Import Centre foundation at implementation commit `d239f939088b67e5a90c65117f08592891be17bb`. Its serial coordinator, per-item identity/state ownership, cancelled-task draining, explicit confirmation, shared production ownership, duplicate/recovery preservation and no-parallel-preparation evidence are recorded in `PROJECT_STATE.md` and the current roadmap.
- `FW-P1-20` and `FW-P1-21` are removed from the active queue because Sprint 83 completed and Chat accepted serial batch import and multi-file picker/drag-and-drop at implementation commit `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. Single and multi-file intake share the serial queue with independent review, explicit confirmation, failure isolation and truthful per-file outcomes. Parallel preparation remains unscheduled research under the existing `FW-P2-51`; Sprint 84 (`FW-P2-73`) is the next planned position and is not selected.
- `FW-P0-25` is removed from the active queue because the unnumbered 127-carrier authentic-corpus reset is technically accepted and complete; newly supplied recurring sources remain governed cumulatively by ADR-046.
- Compound historical statuses are normalized to the defined planning vocabulary. Completed slices remain concise body notes while titles and statuses describe only remaining unscheduled work.
- Exact source-family support remains exact. HDFC whole-statement PDF/XLS equivalence, Axis-card PDF/XLSX equivalence and CBQ current-account source lineage are separate accepted contracts; none is generalized to another institution, financial family or format.
- The accepted reset establishes engineering format-neutral semantic parity for the registered Axis-bank carriers. It does not establish a durable Axis-bank cross-format duplicate/equivalence or supporting-source suppression contract.
- The accepted 127-carrier campaign supplies the current engineering authentic-corpus regression matrix. `FW-P2-61` therefore retains only matrix maintenance/user-facing durability work rather than claiming that the matrix is absent.
- R1 design approval is settled, while native Transactions, Dashboard, appearance and cross-screen conformance remain implementation work.
- `FW-P0-26`, `FW-P2-78` and `FW-P2-79` were mechanically proven unused before being added.

The former 2026-08-01 audit is historical context only. Its Sprint-65-era counts, fixture assumptions and support snapshots are not current planning authority.

### Current statement-dependent acceptance rule

For statement-dependent financial behavior, the complete registered authentic corpus is authority. No synthetic, generated, sanitized, reconstructed, representative, reduced, mutated or hand-authored financial statement may be used at any stage. Production parser output is never its own sole oracle. Private gates fail closed when required evidence is unavailable. A material source/parser/persistence/financial-semantic correction invalidates prior green evidence for the affected candidate boundary, which must be frozen and retested. Exact support never generalizes by institution name, file format, transaction count, page count or layout similarity.

### Roadmap relationship

`FUTURE_WORK.MD` remains the canonical queue. The current and prepared roadmaps may assign non-executable planning positions to recorded queue IDs, but roadmap placement does not remove the candidate, authorize implementation or override P0 → P1 → P2 → P3 triage. A candidate leaves this queue only when a Chat-approved execution selection consumes it or when accepted evidence proves its active boundary fully complete.

---

## Planning Principles

Future work is ordered by:

1. priority;
2. dependency readiness;
3. architectural safety;
4. product value;
5. scope coherence.

Priority and readiness are separate.

A high-priority candidate may remain blocked by unfinished dependencies, missing authentic source evidence, unresolved architecture or insufficient repository evidence.

Several related candidates may be combined into one sprint when repository discovery shows that they:

- produce one coherent user or architectural outcome;
- share the same architectural boundary;
- depend on each other to be useful or safe;
- can be validated through one bounded acceptance plan.

Candidates should remain separate when combining them would:

- cross unrelated product outcomes;
- mix unrelated persistence, parser, UI and domain changes;
- require multiple unresolved architecture decisions;
- make implementation or validation unreasonably broad;
- prevent the result from being accepted independently.

The unit of sprint planning is one coherent outcome, not one backlog bullet.

---

## Priority Definitions

### P0 — Integrity and Safety

Work required to protect financial correctness, durable identity, privacy, persistence integrity or recoverability.

### P1 — Core Product Capability

Major work that expands supported accounts, institutions, formats, import workflows or essential product operations.

### P2 — Workflow and Experience

Important transaction, account, developer, usability and engineering-quality improvements.

### P3 — Later Product Expansion

Analytics, investments, multi-currency and ecosystem capabilities that depend on a mature core platform.

---

## Status Definitions

### Ready for discovery

Dependencies appear satisfied and the candidate may be considered during planning. Targeted Work discovery is used when current repository evidence is insufficient, stale or unable to establish a safe implementation boundary.

### Candidate

Recorded and potentially valuable, but not necessarily the next planning target.

### Blocked

A named dependency, architecture decision, authentic source-evidence boundary or preceding capability is missing.

### Ready for planning

The named dependencies and architecture are accepted, and the candidate may be prepared for a future implementation prompt after any explicit break or sequencing boundary. This status does not authorize implementation or assign a sprint.

### Bug

Verified behaviour that is incorrect and should be corrected.

### Maintenance

Bounded engineering or developer-workflow upkeep.

### Research

The problem is recorded, but architecture or product direction is not yet approved.

### Idea

A possible future direction without planning commitment.

---

## Sprint Selection Procedure

After a completed increment is verified and accepted:

1. Read `PROJECT_STATE.md` and establish the verified repository baseline.

2. Review this document from the highest priority downward.

3. Exclude candidates whose dependencies remain unsatisfied.

4. Identify the highest-priority dependency-ready problems.

5. Determine whether related candidates may form one coherent sprint outcome.

6. When repository evidence is insufficient or the candidate’s implementation boundary is uncertain, send Work a read-only evidence-discovery task.

7. Work records:

   - verified current behaviour;
   - relevant production and test surfaces;
   - architectural constraints;
   - missing decisions;
   - risks;
   - whether candidates should combine or split.

8. Chat reviews the discovery report and relevant architecture evidence.

9. Chat selects one bounded sprint outcome.

10. Create or update an ADR when the selected work requires a new architectural decision.

11. Chat supplies one complete execution prompt to the explicitly authorized execution surface for that task.

12. Remove promoted work from this document.

No candidate is selected merely because it appears first. Dependencies, evidence, risk and user value remain controlling factors.

---

## Upcoming-Work Reporting Rule

When reporting future work:

- identify the latest verified state from `PROJECT_STATE.md`;
- describe future work only using candidates recorded here;
- distinguish Ready for discovery, Candidate, Blocked, Ready for planning, Bug, Maintenance, Research and Idea;
- do not assign sprint numbers inside this queue; planning positions belong only to the applicable roadmap and remain non-executable;
- do not describe a candidate as approved implementation;
- clearly label any new suggestion that has not yet been added to this document.

A valid statement is:

> Candidate `<ID>` is recorded as `<Status>` with the dependencies listed in this document.

An invalid statement is:

> The next sprint will implement `<candidate>`.

A roadmap may forecast a sprint planning position, but the second statement becomes executable only after Chat reruns priority/dependency triage and supplies a complete execution prompt.

---

# P0 — Financial Integrity and Persistence Safety

## FW-P0-02 — Historical Duplicate Review and Repair

**Status:** Ready for discovery  
**Shared prerequisites:** Sprint 40 overlap evidence, Sprint 41 bounded transaction-event ownership, ADR-037 acceptance and post-Sprint-45 lifecycle revalidation are complete.  
**Implementation dependency:** Selection and approval of one concrete historical duplicate-repair family contract.

Provide safe review and correction for duplicate transactions already present in durable history.

Targeted discovery may now define one bounded repair family, including:

- independently provable duplicate evidence;
- duplicate-candidate review;
- explanation of matching evidence;
- import-session and source provenance;
- exact native-currency financial-impact preview;
- explicit user confirmation;
- one provider-owned atomic mutation;
- privacy-safe audit evidence;
- family-specific reversal, compensation or explicit irreversibility.

Historical data must never be silently changed. Discovery does not authorize implementation or broad historical cleanup.

**May combine with:** `FW-P1-25` and `FW-P2-12` only if discovery proves that prospective duplicate review and one historical repair family share a single bounded review and acceptance boundary.

---

## FW-P0-08 — Data-Integrity Verification and Repair

**Status:** Ready for discovery  
**Shared prerequisites:** ADR-037 acceptance and post-Sprint-45 lifecycle revalidation are complete.  
**Implementation dependency:** Selection and approval of one concrete verification or repair family.

Provide privacy-safe verification for:

- broken account relationships;
- missing import sessions;
- orphaned documents or fingerprints;
- identifier conflicts;
- duplicated transactions;
- incomplete imports;
- inconsistent completion states.

The Axis direction-audit family has no retained affected historical database currently identified. No detection or repair run is presently authorized. If a concrete affected database is supplied, the subfamily must first perform read-only detection against durable parser provenance and independently provable source arithmetic; any repair then requires exact impact preview, explicit authorization, provider-owned atomic mutation and recoverability or explicit irreversibility. The Sprint 55A source-truth restoration performed no historical mutation.

Targeted discovery must select one independently verifiable family and define whether the first increment is read-only verification or an explicit repair. Repair actions must be previewed, authorized, atomic and recoverable or explicitly irreversible.

This candidate is not implementation-ready as one broad “repair everything” operation.

---

# P0 — Financial Identity Safety

## FW-P0-11 — Manual Account Linking and Unlinking

**Status:** Blocked
**Depends on:** Accepted ADR-037 and independently approved linking, unlinking and identifier-detachment semantics

The account-outcome explanation prerequisite was completed by Sprint 61. The remaining blocker is independently approved linking, unlinking and identifier-detachment semantics under ADR-037; this candidate is not implementation-ready.

Allow explicit manual linking and unlinking beyond the current bounded account-choice workflow.

Required protections include:

- immutable repository account identity;
- explicit confirmation;
- identifier conflict detection;
- impact preview;
- preservation of transactions and import provenance;
- no identity decisions based solely on filenames, labels or display metadata.

---

## FW-P0-12 — Identifier Backfill Policy

**Status:** Blocked
**Architecture:** ADR-038 accepted in Sprint 49
**Implementation:** Confirmed-import enrichment and observation slice completed by Sprint 50; broader policy remains pending
**Depends on:** Separate future decisions for identifier correction, reassignment and historical repair

Sprint 49 approved the confirmed-import portion of identifier enrichment. When parser-produced strong verified identifiers uniquely resolve one existing account, existing same-account identifiers are idempotently accepted and additional eligible identifiers may be attached automatically only when each is unowned or already owned by that resolved account. Conflicting ownership rejects the complete import, and attachment occurs only as part of a successful provider-owned atomic confirmed import.

ADR-029 remains authoritative for `noMatch`: the user must explicitly choose an eligible unseeded existing account or creation of a new account, no account may be selected automatically, and the choice must be revalidated inside the provider transaction.

Sprint 50 implemented durable identifier ownership and accepted-import observation provenance for successful confirmed imports. Each bounded observation relates identifier ownership to its accepted import session, accepted document, parser provenance and account-association authority; transaction-time ownership enforcement is active, and historical observations are not invented.

The following work remains open and separately gated:

- unlinking;
- reassignment;
- incorrect-link recovery;
- historical backfill;
- repair of contradictory existing ownership.

The completed confirmed-import concurrency slice and this enrichment slice were combined only because they share one atomic confirmation boundary. Identifier-management workflows outside successful confirmed import do not become part of that operation and remain independently governed.

---

## FW-P0-13 — Incorrect-Link Recovery and Account Split

**Status:** Blocked
**Depends on:** `FW-P0-11`, Accepted ADR-037, and independently approved split and relationship-movement rules

Recover when transactions, import sessions or identifiers were attached to the wrong account.

Candidate outcomes include:

- moving an import session;
- detaching an incorrect identifier;
- separating incorrectly combined history;
- restoring previous relationships;
- recalculating affected account presentation safely.

No automatic account split is permitted.

---

## FW-P0-14 — Duplicate-Account Review

**Status:** Blocked
**Depends on:** `FW-P0-11`

Present accounts that may represent the same real financial account.

The review must distinguish:

- verified shared identity;
- weak similarity;
- overlapping transaction history;
- coincidental display metadata.

Weak evidence must never establish identity automatically.

---

## FW-P0-15 — Manual Account Merge

**Status:** Blocked
**Depends on:** `FW-P0-14`, Accepted ADR-037, and independently approved survivor-identity, conflict and merge policy

Provide a previewed manual merge that preserves:

- one selected immutable account identity;
- valid transactions;
- import-session provenance;
- verified identifiers;
- account metadata;
- rollback protection.

All conflicts must be surfaced before any write.

---

# P0 — Additional Integrity Foundations

## FW-P0-16 — Reversible Financial-Mutation Foundation

**Status:** Candidate
**Discovery:** Complete
**ADR-037:** Accepted
**Post-Sprint-45 lifecycle revalidation:** Complete
**Planning state:** Architecture accepted
**Implementation state:** Gated
**Selected strategy:** Strategy A — contract-first architecture
**Schema state:** No migration authorized
**Depends on:** Independent selection of a concrete mutation family before source-level contracts

Discovery completed against commit `fe1f109bb8a1b9d425187869e91eefe98f4e5bb8` with a clean worktree and no repository changes. General architecture discovery is complete. Focused provider-lifecycle revalidation against the final Sprint 45 design is complete, and ADR-037 is Accepted. No executable mutation is authorized.

### Executive planning verdict

- GO for architecture planning.
- NO-GO for financial-mutation implementation.
- Strategy A is selected: architecture and domain contracts first.
- No executable mutation is authorized.
- No generic audit ledger is authorized.
- No schema migration is authorized.
- No source-level placeholder protocol is required merely to record the architecture.

### Approved shared architecture direction

1. authoritative repository snapshot;
2. immutable deterministic typed mutation plan;
3. read-only review;
4. single-use authorization bound to plan digest, scoped precondition token and provider generation;
5. transaction-time authoritative revalidation;
6. one provider-owned atomic execution boundary;
7. family writes and successful audit committed together;
8. one forced canonical `RepositoryStoreHydrator` reconciliation;
9. reversal as a new family-specific authorized mutation, compensation, or explicit irreversibility.

The shared foundation owns lifecycle, plan envelope, determinism, digest and precondition binding, provider-generation binding, authorization lifecycle, the atomic-execution requirement, successful-audit atomicity, reconciliation outcomes, privacy boundaries, provider parity and reversal classification.

Each concrete mutation family still owns affected records, financial meaning, conflict policy, write set, exact impact, audit payload, inverse or compensation, schema, UI and family-specific tests. The shared architecture does not authorize any family.

### Mandatory implementation prerequisites

1. A production-capable opaque provider generation must exist.
2. Planning/read activity leasing must exist.
3. A process-local authorization lifecycle must be approved.
4. One provider-owned atomic financial-mutation executor must exist.
5. A concrete mutation family must be independently selected.
6. The family must define exact affected state and conflict scope.
7. Exact native-currency impact must be computable.
8. Family writes and successful audit must share one provider transaction.
9. `reconciliation-blocked` behavior and a hydration-retry path must exist.
10. SQLite and In-Memory parity must be provable.
11. Family-specific reversal, compensation or irreversibility must be explicit.
12. Privacy-safe family audit and restoration material must be approved.
13. Family schema, migration and UI contracts must be independently approved.

### Stop conditions

> No financial mutation may become executable unless one provider-owned transaction can revalidate the exact reviewed plan, apply every family-specific write, atomically record successful audit evidence, return provider-equivalent outcomes, and support a proven family-specific inverse, compensation contract, or explicit irreversibility.

> If affected records, exact impact, precondition scope, identity provenance, provider generation, privacy-safe audit evidence, or canonical reconciliation cannot be proven, the operation remains non-executable. Best-effort financial mutation is prohibited.

### Explicit exclusions

`FW-P0-16` does not implement or authorize:

- account merge or split;
- identifier detachment or reassignment;
- transaction deletion or movement;
- import-session reversal;
- duplicate or historical repair;
- bulk transaction mutation;
- generic or backup-based undo;
- mutation UI;
- a generic mutation ledger or arbitrary JSON audit;
- persistent mutation diagnostics;
- a migration;
- an executable repository protocol.

### Sprint 45 relationship

Sprint 45 delivered Debug-only activity exclusion, provider-wrapper invalidation, provider replacement, backup, migration recreation, recovery and forced-hydration infrastructure. Focused revalidation is complete. That infrastructure informs but remains outside production financial-mutation semantics. Database reset or restore invalidates outstanding plans and authorizations; backup and restore are not record-level reversal.

---

## FW-P0-18 — Workspace-Scoped Fingerprint Uniqueness

**Status:** Blocked
**Discovery:** Complete
**Depends on:** An approved `FW-P3-40` multiple-workspace architecture that explicitly decides fingerprint scope

Define exact-statement fingerprint ownership when one LedgerForge database contains more than one independent workspace.

The design must determine:

- whether exact-content uniqueness is workspace-scoped or database-wide;
- schema and migration requirements;
- treatment of identical source content imported into independent workspaces;
- conflict and migration behavior for existing database-wide fingerprints;
- privacy and diagnostic boundaries.

Fingerprint scope is a subdecision of the future multiple-workspace architecture. `FW-P0-18` must not be treated as an independent prerequisite that blocks discovery of `FW-P3-40`, because doing so creates a circular dependency.

The source digest must remain derived from source evidence rather than being altered merely to encode workspace identity.

No schema change is authorized until workspace identity, isolation and migration semantics are approved.

---

## FW-P0-19 — Remaining Cross-Format Statement Duplicate Identity

**Status:** Blocked
**Depends on:** an independently source-proven representation pair and an accepted family-specific identity/equivalence contract beyond the completed HDFC, Axis-card and CBQ-lineage boundaries

**Completed boundary:** ADR-042 establishes exact whole-statement HDFC PDF/XLS equivalence. ADR-044 establishes exact Axis credit-card representation-neutral financial equivalence for the accepted PDF/XLSX family. ADR-043 separately establishes exact reviewed CBQ current-account source lineage; it is not generic equivalence.

**Remaining boundary:** The accepted 127-carrier reset proves format-neutral Axis-bank semantic parity as engineering regression evidence, but no accepted ADR establishes durable Axis-bank cross-format duplicate identity, equivalent-supporting-source suppression or authoritative-source replacement. Axis-bank relationship semantics, additional institution/format pairs, same-format byte-distinct semantic identity, source replacement and unapproved partial-overlap families remain separately source-gated.

Any future relationship must distinguish exact-content duplicates, multiple representations of one statement, revised statements, overlapping statements and coincidentally similar transaction sets. It must use complete relevant authentic-source evidence and an independent architecture-aware source oracle. Filename, count, page or layout similarity is never authority.

---

## FW-P0-20 — Additional Transaction-Event Evidence Families

**Status:** Research
**Depends on:** Authentic overlapping source evidence for each proposed family and family-specific deterministic reference, subtype, reuse, conflict and privacy semantics

Investigate additional transaction-event evidence families without expanding the bounded Axis UPI authority prematurely. Possible families include:

- IMPS;
- NEFT;
- e-commerce or card events;
- unstructured references;
- reversal;
- refund.

Each family may require a separate ADR and implementation increment. No family may reuse the Axis UPI algorithm identifier. Stable-looking tokens alone are insufficient; date, amount, narration, balance, filename and row position remain weak evidence. Missing evidence does not prove novelty, and no historical backfill is implied.

---

## FW-P0-26 — Personal-v1 Adoption Certification Gate

**Status:** Blocked
**Depends on:** completion or explicit Chat deferral of every product boundary classified as pre-v1, including the adopted import, recoverability, export and support-documentation boundaries

Personal-v1 may not be declared merely because current automated tests are green. Certification fails closed and must freeze the exact adopted product candidate.

Applicable evidence must include at minimum:

- current complete authentic-source corpus certification;
- exact supported-source documentation;
- Release build and canonical TestPlan;
- import workflow/manual acceptance;
- password/credential-path acceptance where relevant;
- single-file and batch intake as actually adopted;
- duplicate and rejection semantics;
- durable persistence and migration integrity;
- SQLite/In-Memory parity where applicable;
- close/reopen/relaunch/hydration;
- user-owned backup creation, integrity verification and restore drill;
- privacy/residue review;
- structured/user data export;
- supported institution/source matrix;
- manual period/account reconciliation;
- defined parallel comparison against the existing Budget Analysis workbook or its agreed successor oracle for the applicable planning/analytics boundary;
- documented limitations and source-uncertified cases.

Absent authentic cases remain uncertified and must not be manufactured. Certification does not require every Product Vision feature; it requires every feature Chat explicitly classifies as pre-v1 before the certification attempt. Personal-v1 remains undeclared until Chat explicitly accepts this gate.

---

# P1 — Institution and Parser Expansion

## FW-P1-01 — Additional Axis Bank-Account Parser Families

**Status:** Candidate
**Depends on:** complete registered authentic Axis corpora for each materially distinct new or changed bank-account source-family semantic contract

**Completed boundary:** Current accepted Axis bank-account support already covers the source-proven CSV, PDF and legacy-XLS families recorded in `PROJECT_STATE.md`, with the accepted 127-carrier reset providing current ADR-046 reliability certification for the registered corpus. Sprint 78B separately owns the exact Axis credit-card PDF/XLSX family.

**Remaining boundary:** Only additional or materially changed Axis bank-account families remain here, including new historical layouts, account products or source contracts not already covered by current accepted profiles. No new family inherits support from existing Axis profiles.

Each future family requires complete authentic-corpus inventory, independently derived source truth, explicit semantic projection, deterministic routing/profile selection and complete affected-corpus regression. The prohibited synthetic/sanitized financial-fixture retirement is already complete and is not future work.

---

## FW-P1-02 — Additional HDFC Parser Families

**Status:** Candidate
**Depends on:** complete authentic HDFC evidence for one selected new or changed source-family contract

**Completed boundary:** Exact `hdfc.bank-account.xls@1` and `hdfc.bank-account.pdf@1` bank-account support is accepted, including ADR-042 whole-statement PDF/XLS equivalence and current complete-corpus reliability certification under ADR-046.

**Remaining boundary:** HDFC CSV, XLSX, credit-card families, changed bank layouts and any additional source-format relationship remain unsupported until independently source-proven. Existing HDFC PDF/XLS support does not generalize by institution name or structural similarity.

---

## FW-P1-03 — Additional CBQ Parser Families

**Status:** Candidate
**Depends on:** complete authentic CBQ evidence for one selected new or changed bank/card source-family contract

**Completed boundary:** The exact current-account XLS/history-PDF/monthly-PDF family is accepted under ADR-043 source lineage, and exact `cbq.credit-card.pdf@1` v1/v2 is accepted as a separate card family. The accepted unnumbered reset recertified the complete registered CBQ corpora and closed the July compatibility defect for that corpus.

**Remaining boundary:** Only new or materially changed CBQ bank/card layouts, formats or financial families remain. Bank and card domains stay independent. XLSX, OCR/image-only sources and any unapproved card equivalence or identity behavior require their own source and architecture authority.

The prohibited historical synthetic financial-source artifacts were retired by the accepted reset and are not remaining work.

---

## FW-P1-04 — Additional Credit-Card Parser Families

**Status:** Ready for discovery
**Depends on:** a selected remaining authentic card source family plus its exact liability, identity, reconciliation and source-format contract

**Completed boundary:** Exact Amex PDF, CBQ encrypted PDF v1/v2 and Axis PDF/XLSX families are accepted over the shared card-liability architecture, with current complete-corpus reliability certification under ADR-046. The shared domain does not create generic issuer support.

**Remaining boundary:** HDFC card, materially changed Amex/CBQ/Axis card layouts and every other issuer/layout remain separate source-family work. Discovery may compare authentic-source-backed candidates, but each requires independent posted-amount/currency/order/summary/identity truth, deterministic account-versus-instrument semantics, persistence/relaunch evidence and exact exclusions.

The accepted reset completed retirement of prohibited synthetic financial-source artifacts; no fixture-retirement task remains here.

---

## FW-P1-05 — Additional Salary, Brokerage, Fund, Insurance, Tax and Government Document Families

**Status:** Research
**Depends on:** domain-model and product-scope decisions plus authentic source evidence for the selected financial family

**Completed boundary:** Sprint 79 accepted exact `qatar-airways.salary.pdf@1` salary actuals and the dedicated salary/funding-planner domain under ADR-045. That accepted employer/profile is no longer future work.

**Remaining boundary:** Other employers/payroll layouts, brokerage statements, mutual-fund statements, insurance documents, tax documents and government financial records remain separate research/source domains. No family may inherit support from the Qatar Airways salary profile or be forced into the bank/card transaction model merely for implementation convenience.

---

## FW-P1-06 — Parser Framework Expansion

**Status:** Ready for planning
**Depends on:** Existing reader, parser-selection and `FinancialDocument` boundaries

**Narrow parser-authoritative profile-provenance slice completed 2026-07-23:** Sprint 53 makes the production persistence mapper consume exactly one nonempty profile ID/version pair produced by parser transaction provenance and fail before writes when it is missing, malformed or conflicting. Historical `axis.nre.csv` version `1` remains readable unchanged. Reusable profile architecture, broader CSV grammar, other layouts, formats and institutions remain open.

Expand the internal parser framework so additional institutions, statement families and layout versions can be added without creating parallel import pipelines.

The framework must implement the accepted Import Profile direction rather than scattering institution-specific assumptions across unrelated components.

Candidate outcomes include:

- reusable Import Profiles;
- Import Profile versioning;
- deterministic layout recognition that resolves mandatory semantic roles from unique, exact normalized headers rather than fixed column positions, and fails closed for missing, duplicate, ambiguous or unsupported roles;
- explicit support for historical and changed layouts;
- shared complete-authentic-corpus regression conventions plus separate non-source unit-test conventions, including independent source oracles that do not use the production parser as their sole authority;
- bounded source-evidence contracts;
- parser-family organization by institution and document type.

Remaining CSV-grammar gap: targeted discovery must define deterministic handling for quoted delimiters, escaped quotes, embedded line breaks, line-ending variants, empty fields and malformed records while preserving source-row evidence. The current framework and historical fixtures do not establish broader CSV grammar or production support; the affected authentic corpus must do so.

Readers remain responsible for source-format extraction.

Parsers remain responsible for financial interpretation.

This candidate concerns internal application architecture. External third-party plugins remain governed separately by `FW-P3-39`.

---

## FW-P1-07 — Statement Learning Mode and Profile Library

**Status:** Research
**Depends on:** `FW-P1-06`, approved Import Profile semantics and privacy boundaries

Investigate an offline-first workflow that helps LedgerForge recognize new or changed statement layouts while preserving deterministic parsing.

Candidate outcomes include:

- a versioned local Import Profile library;
- explicit profile provenance and compatibility information;
- user-reviewed profile creation or refinement;
- registration of authentic source evidence and independent oracle/projection metadata; synthetic financial-source fixture generation is prohibited at every stage;
- compatibility with historical layouts;
- rollback to an earlier profile version;
- clear separation between learned suggestions and production-approved parser behaviour.

Learning must never silently promote an unreviewed profile into trusted financial parsing.

---

## FW-P1-08 — AI-Assisted Column Detection

**Status:** Research
**Depends on:** `FW-P1-06`, editable import provenance and deterministic validation boundaries

Investigate AI-assisted suggestions for identifying dates, descriptions, debit, credit, amount, currency and balance columns in unsupported tabular statements.

Any assistance must remain:

- advisory;
- reviewable;
- explainable;
- local or explicitly opt-in where external processing would be required;
- validated before persistence;
- unable to override approved deterministic parser behaviour.

The original source structure and every user-approved mapping must remain inspectable.

---

## FW-P1-09 — Remaining Credit-Card Financial Semantics

**Status:** Candidate
**Depends on:** exact authentic source evidence and accepted architecture for the selected additional card semantic

**Completed boundary:** The accepted Amex, CBQ and Axis card profiles already preserve card-liability effects, account/instrument boundaries where source-proven, exact source observations, family reconciliation, provider-owned persistence and hydration. The July CBQ compatibility defect is closed for the registered corpus by the accepted reset. Axis representation equivalence remains governed by ADR-044.

**Remaining boundary:** Rewards, payment allocation, bank-card payment matching, refund/reversal matching, installments/loans, calculated FX, fee/markup/tax contracts, manual merge/split and any new card semantic remain separate future work. Axis Active-Loans/EMI metadata remains excluded from historical card transactions unless later authentic evidence and architecture prove a dedicated model.

Card-liability effects remain distinct from bank debit/credit semantics. Missing rates, taxes, fees or ownership evidence remain missing rather than inferred.

---

# P1 — Import Format Expansion

## FW-P1-10 — Additional Native-Text PDF Statement Families

**Status:** Candidate
**Depends on:** complete authentic evidence for one selected new or changed native-text PDF financial source family

**Completed boundary:** Existing accepted PDF profiles across current Axis, HDFC, CBQ, Amex and Qatar salary families are recorded in `PROJECT_STATE.md` and currently certified against their registered authentic corpora under ADR-046.

**Remaining boundary:** Only new or materially changed native-text PDF families not already covered by accepted source contracts remain here. Encrypted credential policy remains under `FW-P1-11` through `FW-P1-13`; OCR/image-only sources remain under `FW-P1-17`; cross-format identity/equivalence remains under `FW-P0-19` and `FW-P1-16`.

No generic PDF support claim is authorized.

---

## FW-P1-11 — Additional Password-Protected PDF Families

**Status:** Candidate
**Depends on:** an authentic encrypted source family whose credential scope and supported profile can be proven exactly

**Completed boundary:** The shared immutable-snapshot unlock flow is accepted for the exact encrypted Amex, CBQ and Axis credit-card PDF families, including separate Axis App/traditional credential scopes.

**Remaining boundary:** Other institutions or materially changed encrypted layouts require separate exact source, credential-family and parser acceptance. Arbitrary encrypted PDFs, owner-password/permissions variants, OCR and generic encrypted-document support are not implied.

Readers remain credential-policy agnostic and must not own UI, Keychain or institution semantics.

---

## FW-P1-12 — Additional Credential Profile and Password-Storage Capabilities

**Status:** Research
**Depends on:** an approved product need beyond the accepted exact Keychain credential-family boundary

**Completed boundary:** Namespaced macOS Keychain storage is accepted for the proven Amex, CBQ and separate Axis credit-card credential families, with persistence only after supported-profile unlock/parse/validation and no password material in SQLite, source evidence or diagnostics.

**Remaining boundary:** Generic credential-profile lifecycle, password-pattern derivation or any broader credential product is not currently approved. Optional cloud/sync behavior, if ever selected, remains separately governed by the later encryption/sync architecture rather than being implied by current Keychain support.

---

## FW-P1-13 — Additional Per-File Credential Override Policy

**Status:** Candidate
**Depends on:** an explicit user/product decision for a non-persistent or per-file override beyond the accepted remembered-family challenge flow

**Completed boundary:** Exact supported encrypted PDF families already provide secure user challenge and safe replacement of the proven credential-family item only after successful unlock, supported parsing and validation.

**Remaining boundary:** A use-once/non-persistent credential choice and any genuinely different per-file override semantics remain unimplemented. Cancellation, failed candidates and unsupported unlocked content must never persist a credential.

---

## FW-P1-14 — Additional XLS/XLSX Source Families and Spreadsheet Capabilities

**Status:** Candidate
**Depends on:** complete authentic evidence for one selected additional spreadsheet family or an independently approved broader spreadsheet capability

**Completed boundary:** Accepted spreadsheet support already covers the exact Axis bank XLS, HDFC bank XLS, CBQ current-account XLS and Axis-card XLSX source contracts through the ordinary import path. The accepted 127-carrier reset recertified the registered families under ADR-046.

**Remaining boundary:** Other spreadsheet source families, new HDFC/CBQ/Axis layouts, generic OOXML mapping, formulas, macros, password workflows, unsupported worksheet structures and user-authored mappings remain separate work. Existing readers do not imply generic XLS or XLSX support.

---

## FW-P1-15 — TXT Statement Support

**Status:** Idea
**Depends on:** Supplied authentic TXT financial sources and an independently derived source-truth/semantic-projection boundary

Support deterministic text statements through the existing pipeline.

---

## FW-P1-16 — Additional Cross-Format Financial Relationships

**Status:** Blocked
**Depends on:** one exact unimplemented representation relationship with complete authentic source truth and an accepted family-specific equivalence/lineage contract

**Completed boundary:** ADR-042 owns exact HDFC whole-statement PDF/XLS equivalence. ADR-043 owns the separate exact CBQ current-account lineage model. ADR-044 owns exact Axis credit-card PDF/XLSX representation equivalence. The accepted reset additionally establishes format-neutral semantic parity across the registered Axis-bank carriers as engineering evidence.

**Remaining boundary:** Axis-bank durable cross-format duplicate/equivalence behavior is not accepted merely because semantic parity tests pass. Additional card/format families, same-format equivalence, generic partial overlap, source replacement and every other representation relationship require separate source and architecture approval.

This item concerns source-family financial relationships, while `FW-P0-19` owns durable duplicate-identity consequences. Neither authorizes fuzzy matching.

---

## FW-P1-17 — OCR Fallback

**Status:** Research
**Depends on:** Production PDF support and approved human-review boundaries

Investigate scanned or image-only statements.

OCR output remains untrusted until deterministic parsing and validation succeed.

---

---

# P1 — Import Workflow

## FW-P1-22 — Editable Import Preview

**Status:** Blocked
**Depends on:** An approved correction and provenance model

Allow bounded correction before persistence without obscuring the distinction between:

- imported source values;
- normalized values;
- user corrections;
- derived financial values.

Every correction must remain explainable and auditable.

---

## FW-P1-23 — Import Correction Workflow

**Status:** Blocked
**Depends on:** `FW-P1-22` and durable correction provenance

Provide deterministic correction and revalidation before persistence.

---

## FW-P1-24 — Account-Match Review and Manual Override

**Status:** Blocked
**Depends on:** Identity explanation and manual linking policies

Extend account choice beyond the bounded no-match workflow while preserving verified identity ownership and explicit user control.

---

## FW-P1-25 — Duplicate-Import Review and Management

**Status:** Ready for discovery
**Depends on:** Approved durable-attempt-history supported outcomes plus broader duplicate-management semantics

Retain future work for duplicate override, broader duplicate management, partial-import families, ambiguous or speculative duplicate candidates and historical duplicate repair. The former Sprint 56 contiguous-prefix/later-suffix Axis family is suspended because its synthetic overlap fixture lacks immutable source lineage; mixed overlap now fails closed as unsupported evidence.

ADR-040 and Migration V7 retain the implemented reviewed-plan, transaction, durable-disposition and hydration structures, including strict readback of any historical state. Reauthorizing a production partial family requires new immutable source lineage and independent balance/event evidence; no current synthetic fixture can supply that authority. Retain arbitrary override, fuzzy candidates, interleaved or unsupported evidence, other institutions/formats/event families, historical duplicate cleanup and repair, and deletion/reversal for separate architecture and acceptance.

---

## FW-P1-27 — Delete or Reverse an Import Session

**Status:** Ready for discovery  
**Shared prerequisites:** ADR-037 acceptance and post-Sprint-45 lifecycle revalidation are complete.  
**Implementation dependency:** Selection and approval of one import-session reversal family contract and exact impact preview.

Safely reverse one accepted import without damaging unrelated account history.

Targeted discovery must define:

- the exact session-owned records and shared relationships;
- treatment of accounts, identifiers, observations, documents, fingerprints and overlapping transactions;
- native-currency impact;
- effect on later imports and account presentation;
- immutable reviewed plan and authorization;
- one provider-owned atomic operation;
- successful audit evidence;
- reversal of the reversal, compensation or explicit irreversibility;
- provider parity, hydration and relaunch behavior.

Discovery does not authorize deletion, broad rollback or backup-based undo.

---

## FW-P1-29 — Better Validation Guidance

**Status:** Ready for planning
**Depends on:** Existing validation pipeline

Provide broader validation education outside the confirmed-import immediate-result and recovery panel while preserving detailed developer diagnostics separately.

Sprint 58 completed bounded privacy-safe preparation-failure summaries. Sprint 66 completed typed, privacy-safe confirmed-import recovery and review guidance for validation failure, exact duplicate, transaction-event block, account-choice review, stale account choice, identity ambiguity or conflict, identifier-ownership conflict and repository-integrity conflict; unknown, malformed, hostile and otherwise unavailable states fail closed.

Retain only broader validation education and unsupported-result guidance outside those completed confirmed-import result surfaces. Do not duplicate Sprint 66 recovery actions, expose raw diagnostics or infer mutation authority from error text.

---

## FW-P1-29A — Historical Backfill Import Workflow

**Status:** Blocked
**Depends on:** Mature duplicate handling, statement continuity and reversible repair foundations

Support deliberate import of older financial history without corrupting current account continuity or duplicating already represented activity.

Candidate outcomes include:

- account-scoped historical import ranges;
- clear distinction between backfill and ordinary current-period importing;
- statement coverage previews;
- overlap and gap explanation;
- controlled handling of legacy un-fingerprinted history;
- impact preview before persistence;
- provenance identifying each backfill source;
- cancellation and failure isolation.

Historical backfill must not assume that older statements are complete or that import order determines final financial truth.

---

# P1 — Verified Bugs and Developer Maintenance

## FW-P1-30 — Granular Development Database Reset

**Status:** Blocked
**Depends on:** Separate approved selective-mutation semantics built on ADR-035

Candidate reset operations include:

- transactions only;
- import sessions only;
- financial identity only;
- repository financial data;

Each operation must clearly state what is retained and removed.

ADR-035 and Sprint 45 Phase A provide the reusable canonical lifecycle, activity-gate, provider-generation, backup and recovery boundary. This candidate covers only selective data-domain mutations, which remain unapproved and must not be inferred from whole-database reset.

---

## FW-P1-31 — Repository Inspector

**Status:** Candidate
**Depends on:** Privacy-safe developer presentation

---

## FW-P1-32 — Development SQLite Browser

**Status:** Research
**Depends on:** Development-only access and privacy controls

---

## FW-P1-33 — Import-Session Inspector

**Status:** Candidate
**Depends on:** Implemented durable import-attempt-history foundation and an approved developer-inspection privacy boundary

---

## FW-P1-34 — Parser and Source-Evidence Inspector

**Status:** Research
**Depends on:** Privacy-safe source-evidence redaction

Source inspection must never expose passwords or unredacted financial identifiers.

---

## FW-P1-35 — Duplicate and Identity-Conflict Inspector

**Status:** Blocked
**Depends on:** Approved duplicate and conflict semantics

---

## FW-P1-36 — Diagnostic Export

**Status:** Candidate
**Depends on:** Privacy filtering and explicit user action

---

## FW-P1-37 — Better Developer Diagnostics and Failure Summaries

**Status:** Ready for planning
**Depends on:** Existing structured diagnostic system

Sprint 58 completed bounded privacy-safe preparation-failure summaries and the Developer Console integration related to the approved fixture workflow. Retain only broader structured diagnostics work not completed by that slice.

The Chat-accepted unnumbered startup/monthly-planner package on 2026-09-09 additionally completed typed migration/provider/hydration/save failure summaries, causal references, safe next actions, bounded chronological Copy All metadata and truthful unavailable/non-current presentation. See [PROJECT_STATE.md](PROJECT_STATE.md). These slices are no longer queued here; broader structured diagnostics remain future work. Persistent diagnostic history and an import timeline are not completed or authorized by this closure.

---

## FW-P1-38 — Import Inspector and Validation Timeline

**Status:** Blocked
**Depends on:** A separate approved diagnostic-history and timeline architecture

Provide development-only inspection of an import’s progression through:

- source reading;
- institution detection;
- statement classification;
- parser selection;
- financial parsing;
- validation;
- user confirmation;
- duplicate evaluation;
- account decision;
- persistence;
- hydration.

The inspector may include a validation timeline showing issues and outcomes in deterministic order.

It must not expose:

- passwords;
- raw financial identifiers;
- unrestricted source fragments;
- production-only sensitive information.

This candidate remains separate from the user-facing durable import-attempt history and is not promoted by the approved sprint.

---

## FW-P1-39 — Development Database Maintenance Utilities

**Status:** Research
**Depends on:** Separate safety, mutation and validation contracts for each maintenance operation

Investigate safe development-only utilities for:

- opening the active database folder;
- exporting a SQLite snapshot;
- database vacuum or optimization;
- repository rebuild;
- balance recalculation;
- search reindexing.

Each operation requires an explicit safety contract, scope description and validation strategy.

ADR-035 and Sprint 45 Phase A already own canonical Debug identity, exclusive lifecycle activity, provider generations, checked close, coordinated SQLite/WAL/SHM handling, verified lifecycle backup and automatic recovery. Those delivered lifecycle responsibilities are not part of this research item; no snapshot export, vacuum, optimization, repository rebuild, recalculation, reindexing or repair utility was implemented.

No maintenance operation may silently alter trusted financial history or run against an active import without safe coordination.

Production user-facing repair remains governed by `FW-P0-08`.

---

## FW-P1-39A — Persistent Developer Diagnostic History

**Status:** Research
**Depends on:** A new ADR replacing or extending ADR-026’s in-memory-only diagnostic constraint

Investigate an optional development-only diagnostic history that survives relaunch.

The design must define:

- explicit enablement and retention limits;
- privacy filtering;
- log rotation and deletion;
- separation from repository financial truth;
- protection from passwords, raw financial identifiers and unrestricted source fragments;
- export compatibility;
- deterministic ordering and schema evolution.

Persistent diagnostics must not become an application persistence mechanism or a substitute for import-session audit history.

---

# P2 — Transaction Experience and Reconciliation

## FW-P2-01 — Source-Document Reopening

**Status:** Candidate
**Depends on:** Approved document-library and source-retention architecture

Sprint 67A corrected the completed read-only transaction-detail presentation so source-document metadata is bound to the transaction's exact durable imported-document record; import-session display labels are not document authority.

Only source-document reopening, browsing or library behavior remains here. It requires a separately approved architecture and privacy boundary; filenames, raw source bytes, paths and display labels must not become durable identity.

---

## FW-P2-03 — Advanced Transaction Search

**Status:** Ready for planning
**Depends on:** Stable transaction fields

**Owning design authority:** `UI_UX_v1.0_Frozen.md` and `UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md`.

Expand the global repository-backed Transactions experience with bounded search/filtering over supported displayed fields and authoritative transaction semantics:

- account, institution, bank/card family, currency, period/date, financial-effect/direction and category filters;
- amount/institution filtering only where the displayed authoritative fields support it;
- AND across filter groups and OR within a multi-select group;
- visible active scope, clear-filters behavior and deterministic no-match presentation;
- immutable account identity and no fuzzy financial inference;
- search only over supported displayed/searchable fields rather than hidden identifiers or source fragments.

The global Transactions store remains the authority; filtering is presentation scope, not a new transaction repository.

**Designer-1 observation / evidence gap — 2026-09-09:** one reviewed screenshot appeared to show internally inconsistent INR inflow/outflow/net colouring. Classification: **OBSERVATION / EVIDENCE GAP, NOT VERIFIED FINANCIAL DEFECT**. Before any calculation or financial-colour semantic change, run targeted source/runtime verification. Do not infer stored-data corruption or create a P0 defect without proof.

## FW-P2-04 — Saved Transaction Filters

**Status:** Blocked
**Depends on:** `FW-P2-03`

---

## FW-P2-05 — Transaction Multi-Selection

**Status:** Candidate
**Depends on:** Approved bulk-action boundaries

---

## FW-P2-06 — Bulk Transaction Actions

**Status:** Blocked
**Depends on:** `FW-P2-05`, Accepted ADR-037, and an independently approved contract for each concrete bulk-action family

Potential actions include notes, categories, rules and safe deletion or exclusion.

---

## FW-P2-07 — Delete Transactions by Import Session

**Status:** Blocked
**Depends on:** Approved `FW-P1-27` import-session reversal

---

## FW-P2-08 — Undo Support

**Status:** Research
**Depends on:** Family-specific reversible repository history; ADR-037 rejects universal application undo

---

## FW-P2-09 — Transaction Notes

**Status:** Candidate
**Depends on:** Targeted transaction metadata mutation

---

## FW-P2-10 — Transfer Matching Between Owned Accounts

**Status:** Ready for discovery  
**Shared prerequisites:** Sprint 40 evidence is complete, and Sprint 53 verifies distinct durable identity for multiple supported owned accounts.  
**Implementation dependency:** Independently provable transfer evidence and a reversible family-specific matching contract. Non-source canonical-transaction test values may exercise the algorithm, but financial-source fixtures cannot establish ingestion support.

Match both sides of owned-account transfers without counting them as new income or expense.

Targeted discovery must define:

- independently provable transfer evidence;
- same-currency and future cross-currency boundaries;
- one-to-one, split and fee-bearing cases;
- date and amount tolerances, if any;
- conflict and ambiguity handling;
- explanation and user review;
- durable relationship provenance;
- unmatch or correction semantics;
- interaction with duplicate-event evidence and reconciliation.

Weak similarity must never create a transfer relationship automatically.

---

## FW-P2-11 — Reconciliation Workflow

**Status:** Blocked
**Depends on:** `FW-P2-10` and transaction provenance

---

## FW-P2-12 — Duplicate-Transaction Review

**Status:** Ready for discovery
**Depends on:** Completed Sprint 40 overlap evidence and Sprint 41 bounded transaction-event enforcement

Retain future work for speculative duplicate-transaction candidates, unsupported transaction-event families, historical duplicate review and repair, and workflows requiring reversible mutation. The approved durable-attempt-history increment explains supported Axis UPI transaction-event blocking only.

---

# P2 — Categories, Rules and Automation

## FW-P2-21 — Deterministic Categorization Rules

**Status:** Ready for discovery
**Depends on:** Sprint 57 durable category foundation — complete

Sprint 57 completed the manual category foundation with additive Migration V8, durable user-created categories, manual single-transaction classification, SQLite/In-Memory parity, canonical hydration and bounded Settings/transaction UI. It did not implement automatic classification or any rule behavior.

Discovery for this candidate must preserve imported transaction immutability, manual assignments, explicit user control and explainability. It must not infer implementation authority from the completed category foundation.

---

## FW-P2-22 — Explainable Rule Results

**Status:** Blocked
**Depends on:** `FW-P2-21`

Every automatic categorization must explain the rule that produced it.

---

## FW-P2-23 — Rule Priority and Conflict Handling

**Status:** Blocked
**Depends on:** `FW-P2-21`

---

## FW-P2-24 — User Corrections as Reusable Rules

**Status:** Blocked
**Depends on:** `FW-P2-21` through `FW-P2-23`

---

## FW-P2-25 — Merchant and Payee Normalization

**Status:** Blocked
**Depends on:** Stable correction and provenance rules

The original imported transaction description must remain preserved.

---

## FW-P2-26 — Recurring Transaction and Subscription Detection

**Status:** Blocked
**Depends on:** Reliable duplicate handling and normalized payee evidence

---

## FW-P2-27 — Automatic Transaction Classification

**Status:** Blocked
**Depends on:** Category, rule, normalization and explanation foundations

Deterministic rules take precedence over AI-assisted suggestions.

---

## FW-P2-28 — Smart Deterministic Alerts

**Status:** Blocked
**Depends on:** Categorization, recurring detection or another approved rule source

---

## FW-P2-29 — Explainable Rules Engine v2

**Status:** Blocked
**Depends on:** Stable category, transaction, account, provenance and reversible-action models

Define a general deterministic rules engine for explainable financial automation beyond categorization alone.

Candidate capabilities may include:

- multi-condition rules;
- explicit priority and conflict resolution;
- dry-run previews;
- account, transaction, merchant, amount, date and recurrence predicates;
- actions that never alter original imported financial truth;
- complete reasoning and provenance for every result;
- user-controlled enablement, disabling and rollback;
- testable rule versioning.

Rules must remain deterministic before any AI-assisted suggestion layer is considered.

---

# P2 — Account Lifecycle and Presentation

## FW-P2-30 — Broader Account Metadata Editing

**Status:** Candidate
**Depends on:** Existing targeted display-name mutation

Define the targeted repository mutation, validation and hydration foundation required for editable account metadata beyond display name while preserving immutable account identity, identifiers, sessions and transactions.

Field-specific product work remains separately tracked in `FW-P2-31`, `FW-P2-32` and `FW-P2-36`.

---

## FW-P2-31 — Account Notes

**Status:** Blocked
**Depends on:** `FW-P2-30`

---

## FW-P2-32 — Account Colour and Icon Customization

**Status:** Candidate
**Depends on:** Stable account presentation model

---

## FW-P2-33 — Institution Logos

**Status:** Candidate
**Depends on:** Approved asset and institution-mapping strategy

---

## FW-P2-34 — Archive and Restore Account

**Status:** Ready for discovery
**Depends on:** Existing targeted account-mutation and repository-identity foundations

Discovery must define account lifecycle semantics, visibility effects and restoration behaviour.

Archiving must not delete financial history.

---

## FW-P2-35 — Hide Account Without Deleting History

**Status:** Candidate
**Depends on:** Account visibility semantics

---

## FW-P2-36 — Close-Account Status and Closure Date

**Status:** Blocked
**Depends on:** `FW-P2-30`

---

## FW-P2-37 — Account Grouping, Ordering and Favourites

**Status:** Candidate
**Depends on:** Stable complete-account collection

Support user-defined or deterministic grouping while preserving immutable account identity and complete account visibility.

Sprint 68A removes an inert star only; it does not implement favourites or change this candidate.

---

## FW-P2-38 — Full Account Transaction-History Navigation

**Status:** Ready for planning
**Depends on:** Existing account-scoped activity foundation

---

# P2 — User Experience

## FW-P2-40 — Remaining User-Facing Terminology Cleanup

**Status:** Candidate
**Depends on:** stable affected R1 screens

**Completed boundary:** Accepted UI work removed/contextualized several misleading internal terms, including replacing the standalone Salary Truth-classes panel with contextual provenance.

**Remaining boundary:** Only genuinely remaining developer/repository terminology on R1-covered ordinary user screens remains. Diagnostics and provenance that are truthful and useful must not be removed merely to simplify wording.

---

## FW-P2-41 — R1 Contextual Toolbar Conformance

**Status:** Candidate
**Depends on:** stable destination workflows and the accepted R1 shell direction

Conform remaining destination toolbars to functional, page-specific controls with visible scope and consistent hierarchy. Do not force one dominant Import button onto every destination merely for visual uniformity, and do not add inert controls.

---

## FW-P2-43 — Better Account Icons

**Status:** Candidate
**Depends on:** Account presentation strategy

Improve default account iconography. User customization remains governed by `FW-P2-32`, while institution logos remain governed by `FW-P2-33`.

---

## FW-P2-44 — Dashboard Customization

**Status:** Idea
**Depends on:** Stable dashboard modules

---

## FW-P2-45 — Improved Global Search

**Status:** Candidate
**Depends on:** Stable searchable domains

---

## FW-P2-46 — Interactive Dashboard Charts

**Status:** Blocked  
**Depends on:** Reliable analytical data sources, including the relevant categorization, transfer, recurrence or reporting foundations.

Provide interactive dashboard charts only after their underlying analytical values are derived from authoritative repository-backed financial data.

Until those foundations exist:

- hardcoded spending percentages must not be presented as user financial facts;
- decorative cash-flow values must not appear beside real balances or expenses as though calculated;
- unsupported trends must be removed or shown as unavailable;
- chart labels must not imply categorization, transfer matching, forecasting or historical analysis that is not implemented;
- sample data must remain unmistakably separate from repository data.

Sprint 68 removed the misleading placeholder presentation; that cleanup does not make interactive analytics ready.

Future charts must preserve native-currency safety, provenance, deterministic calculations and the dependency boundaries of `FW-P3-10` and related analytical candidates.

---

## FW-P2-47 — R1 Empty, Loading, Failure and Import Guidance States

**Status:** Candidate
**Depends on:** stable affected workflows

Complete R1 state treatment that distinguishes loading, genuinely empty, unavailable, failed and no-match states. Completed imports must resolve to coherent result/completion presentation. Guidance must not duplicate navigation unnecessarily, fabricate zero financial values or imply unsupported recovery.

---

## FW-P2-48 — R1 Cross-Screen Visual Polish

**Status:** Candidate
**Depends on:** stable primary layouts and the applicable R1 implementation slices

Remaining shared polish includes readable full native-currency summaries, safe account disambiguation, responsive/collapsible inspectors, settings hierarchy/density and Developer Console clarity between the active database and a selected target.

The Transactions portions may be consumed only as needed by Sprint 89; broader cross-screen polish remains for the later shared conformance boundary. Further Salary visual refinement remains lower priority and must not reopen accepted natural input, Save/Command-S, fee validation or persistence behavior.

---

## FW-P2-49 — R1 Native Accessibility Closure

**Status:** Candidate
**Depends on:** stable R1 implementation surfaces

Native/runtime acceptance must cover complete keyboard paths, useful VoiceOver grouping, visible focus distinct from selection, non-colour status meaning, applicable 4.5:1 text and 3:1 meaningful-boundary targets, reduced motion/transparency and readable fallback for user appearance choices.

Static design approval is not accessibility acceptance. The bounded Transactions portion may be exercised with Sprint 89; cross-screen closure remains later.

---

## FW-P2-50 — R1 Keyboard Navigation and Shortcuts

**Status:** Candidate
**Depends on:** stable R1 primary workflows

Complete keyboard reachability for search, filters, sortable headings, table/row selection, inspector interactions, collapse/expand behavior and other R1 primary actions. Focus remains visible and distinct from selection, and shortcuts never bypass confirmation or mutation safety.

The bounded Transactions portion may be included in Sprint 89; cross-screen closure remains later.

---

## FW-P2-51 — Startup, Runtime and Import Performance Optimization

**Status:** Research
**Depends on:** Measured performance evidence plus authentic large sources where source-path performance is under test, or clearly non-source synthetic stress data that makes no parser-support claim

Measure and improve:

- application startup;
- repository hydration;
- large account and transaction presentation;
- import preparation and confirmation;
- large-statement parsing;
- search and filtering.

Sprint 83 completes the serial batch Import Centre. Any future bounded parallel preparation remains unscheduled Research under this existing performance candidate, requiring measured need, transferable `PreparedImport`/source-snapshot ownership and proven dependency thread safety, including the `FW-P2-74` boundary. It must preserve deterministic queue order and per-file review/confirmation and cannot parallelize confirmation or provider commit. This note does not approve implementation.

A splash or launch-progress experience may be considered only when measured startup delay justifies one.

Do not optimize without benchmarks.

---

## FW-P2-52 — User and Workspace Preferences

**Status:** Ready for discovery
**Depends on:** Existing settings presentation and `WorkspaceSettings` domain direction

Define durable, privacy-safe preferences for existing regional/display behavior and the **user-approved `LF-UI-2026-09-R1` appearance direction**:

- Follow System / Light / Dark;
- System Neutral / optional Deep Indigo preset concept;
- accent;
- app-wide text size;
- a small supported font-style set;
- comfortable/compact density;
- bounded foreground/background customization;
- bounded eligible-surface translucency;
- Preview / Apply / Cancel / Restore defaults;
- automatic readable fallback; and
- reduced-transparency compliance.

Also retain candidate scope for date/time formatting, regional number formatting, base/secondary display currencies, default import behavior, dashboard/account/transaction presentation and developer-mode separation.

**Unresolved architecture:** preference persistence/storage ownership remains discovery work. R1 approval does not choose UserDefaults, SQLite or another store. Preference mutation must never rewrite imported financial truth. Reporting-currency preferences remain dependent on `FW-P3-33`.

## FW-P2-53 — Contextual Date-Range and Filter Controls

**Status:** Ready for planning
**Depends on:** Stable date semantics and searchable presentation domains

Implement the approved `LF-UI-2026-09-R1` contextual Transactions/table direction:

- period controls and visible active filter/sort scope;
- sortable supported Date, Description, Account, Category and Amount columns;
- repeated heading action reverses direction;
- currency-safe amount sorting with deterministic/stable tie-breaking;
- resizable columns;
- collapsible inspector with stable selection; and
- contextual controls that remain keyboard accessible and affect only the active presentation domain.

Presentation sorting must never rewrite source order, running-balance semantics or durable transaction ordering. Mixed-currency values must not be silently converted merely to sort or total them.

## FW-P2-54 — Document Library and Source-Document Browsing

**Status:** Ready for discovery  
**Shared prerequisites:** Durable document provenance, transaction-to-source relationships and import-attempt history now exist.  
**Implementation dependency:** Approval of the privacy-safe metadata, navigation and retention boundary.

Provide a user-facing place to inspect imported source-document records and their relationships to:

- accounts;
- import sessions;
- statement periods;
- transactions;
- validation and duplicate outcomes.

Targeted discovery must determine:

- which durable metadata is authoritative and safe to display;
- how document identity differs from filename and source-content identity;
- account, session and transaction navigation;
- treatment of exact duplicates, partial outcomes and unavailable legacy evidence;
- whether source reopening or content retention is excluded;
- privacy-safe search and export boundaries.

The library must not expose raw source content by default and must not treat a document record as the owner of account identity.

---

## FW-P2-55 — Adaptive Appearance Native Implementation

**Status:** Blocked
**Depends on:** accepted `LF-UI-2026-09-R1` design authority and the bounded preference-storage/ownership decision under `FW-P2-52`

**Completed boundary:** The design revision itself is complete. R1 approves Follow System as default, explicit Light/Dark choices and optional Deep Indigo/System Neutral preset direction.

**Remaining boundary:** Native adaptive rendering and runtime/accessibility acceptance remain unimplemented. This candidate owns implementation of the accepted appearance behavior, not another design campaign. Preference persistence ownership stays under `FW-P2-52`; implementation must not mutate financial data.

---

## FW-P2-56 — Development Performance Profiling

**Status:** Research
**Depends on:** Privacy-safe developer tooling and measured performance questions

Provide development-only profiling for:

- startup;
- repository hydration;
- parser and validation stages;
- persistence;
- import completion;
- large-view rendering;
- search and filtering.

Profiling output must remain separate from financial truth and must not retain sensitive source content.

---

# P2 — Engineering Quality

## FW-P2-61 — Authentic-Corpus Regression Matrix Maintenance

**Status:** Maintenance
**Depends on:** ADR-046 and the current supported-source/profile registry

**Completed boundary:** The accepted unnumbered reset established the engineering complete-authentic-corpus regression matrix across the registered 127 carriers, including provider/order campaigns and current native-currency regression across INR and QAR families.

**Remaining boundary:** Maintain the cumulative matrix as recurring authentic sources or shared ingestion semantics change, preserve explicit certified/uncertified family boundaries and keep engineering matrix output aligned with user/engineering support documentation under `FW-P2-79`.

This item must not describe LedgerForge as lacking an engineering corpus matrix, and it must never substitute historical implementation acceptance or fixture presence for current ADR-046 certification.

---

## FW-P2-63 — Additional Cross-Format Authentic-Source Semantic-Parity Tests

**Status:** Candidate
**Depends on:** a newly selected exact source relationship or materially changed recurring carrier family with complete authentic evidence

**Completed boundary:** HDFC PDF/XLS semantic parity is accepted under ADR-042; CBQ current-account multi-source lineage/parity is covered under ADR-043; Axis-card PDF/XLSX parity is accepted under ADR-044; and the accepted 127-carrier reset establishes format-neutral semantic-parity regression for the registered Axis-bank carriers.

**Remaining boundary:** Only future/new carrier pairs, materially changed recurring families, same-format semantic relationships or newly approved partial-overlap semantics remain. Axis-bank engineering semantic parity does **not** by itself establish durable cross-format duplicate/equivalence/suppression semantics; those remain governed separately by `FW-P0-19` and `FW-P1-16`.

---

## FW-P2-64 — Large-Statement and Long-Running Import Tests

**Status:** Candidate
**Depends on:** Authentic large statements for source-path acceptance and/or explicitly non-source generated stress data for resource-limit testing; generated financial-source fixtures cannot certify parser support

---

## FW-P2-65 — Repository Corruption and Recovery Tests

**Status:** Research
**Depends on:** Successful completion and approval of Sprint 47, plus an approved broader corruption-recovery test boundary

Define a broader repository corruption and recovery regression matrix beyond the focused tests required by individual implementation candidates.

Coverage should include:

- SQLite opening or initialization failure;
- migration checksum tampering;
- edited previously applied migrations;
- missing lower migrations;
- duplicated migration versions;
- incomplete migration records;
- unsupported future migration versions;
- corrupted or missing repository relationships;
- interrupted lifecycle operations;
- fail-closed production behaviour;
- recovery without silent substitution of an in-memory provider;
- privacy-safe diagnostics;
- valid upgrades from every supported prior schema version;
- preservation of trusted financial history during recovery.

This item does not authorize automated repair.

Production repair remains governed by `FW-P0-08`. Sprint 47 completed focused fail-closed startup and migration-chain verification tests; this candidate remains limited to the broader corruption and recovery regression matrix.

---

## FW-P2-67 — App Shell and Workflow Decomposition

**Status:** Maintenance
**Depends on:** Stable current navigation, window structure and import behaviour; PR-1 where hydration/runtime-store ownership is touched

**Sprint 80 ownership boundary:** Any decomposition that touches hydration,
runtime stores or import coordination must follow PR-1's explicit staging and
MainActor publication seam. The accepted serial Import Centre boundary does not
authorize a parallel coordinator or a Swift-6 migration as part of this
maintenance item.

Decompose the monolithic SwiftUI application shell while preserving approved financial behaviour and the current product design.

Required direction includes:

- the root scene owning structural composition rather than financial workflows;
- purpose-owned views for major presentation domains;
- import preparation, confirmation and result coordination moved out of presentation-only views;
- persistence lifecycle and provider state coordinated outside ordinary view rendering;
- repository hydration coordination moved behind an explicit workflow or application boundary;
- repository, provider and `RepositoryStoreHydrator` authority preserved;
- existing navigation, keyboard behaviour, accessibility and window behaviour retained unless separately approved;
- no financial-domain redesign merely to complete the structural refactor.

The exact file names, scene hierarchy and coordinator types require implementation planning. This candidate does not authorize an application architecture rewrite.

---

## FW-P2-69 — Remaining macOS CI and UI Smoke Validation

**Status:** Maintenance
**Depends on:** an approved CI/UI-smoke or distribution objective

**Completed boundary:** Repository-owned local build/test entry points, exact-singleton build/run verification, deterministic local cycle-close validation, Debug/Release build foundations and current local runtime/build-identity mechanics are accepted and must not be reopened by this candidate.

**Remaining boundary:** CI-provider setup, commit-status protection, generic UI smoke automation or an approved replacement/enabling of UI-test coverage, plus later distribution/notarization/deployment work where separately selected.

No alternate build configuration may diverge from Xcode project truth.

---

## FW-P2-70 — Remaining macOS Target and Distribution Metadata Hardening

**Status:** Maintenance
**Depends on:** an approved macOS target/distribution metadata decision for each remaining surface

**Completed boundary:** Bundle-derived version/build presentation, local startup/build identity and R1 resource-containment verification are accepted and are not future work here.

**Remaining boundary:** stale non-macOS platform/device metadata, irrelevant generated plist keys, unexpected governance/development resources in built products, minimum-version and entitlement/capability decisions, hardened-runtime/distribution policy and eventual Developer ID/notarization/packaging if external distribution is approved.

No bundle-inclusion defect may be inferred from navigator visibility; target/build-phase or inspected-product evidence is required.

---

## FW-P2-71 — Repository and Xcode Metadata Hygiene

**Status:** Maintenance  
**Depends on:** None

**Completed slice 2026-07-23:** commit `7ee20a909038d1088f830a6ea588311625f415e5` removed the tracked user-specific Find Navigator scope, breakpoint list and scheme-management state from the Git index.

Remaining work is prevention and broader hygiene:

- verify ignore coverage for user-specific Xcode state;
- distinguish shared schemes/configuration from personal IDE metadata;
- add repository checks where proportionate;
- cover derived products, local databases, temporary SQLite files, generated files, sensitive diagnostics and exported private fixtures;
- document privacy-safe cleanup for prohibited metadata already introduced in future.

Do not remove shared Xcode configuration merely because it lives beneath the project bundle. Repository evidence must distinguish personal from shared state.

---

## FW-P2-73 — PR-2 SQLite, Provider and Migration Ownership

**Status:** Candidate
**Depends on:** PR-1 where shared publication or lifecycle surfaces intersect

Correct the bounded SQLite/provider/migration ownership issues identified by
Sprint 80: `SQLiteDatabase` teardown isolation, `DatabaseProvider` ownership,
migration registry/global ownership, migration closure/SQLite ownership and
helper/database shared-source ownership.

This family is required before the coordinated Swift-6 migration. It does not
authorize a migration, a schema change or a generic concurrency framework.

## FW-P2-74 — PR-3 Dependency Concurrency Boundary

**Status:** Candidate
**Depends on:** Sprint 80 accepted readiness discovery

Resolve the dependency boundary before coordinated Swift-6 migration:

- make the ZIPFoundation Swift-6 correction or upgrade decision; and
- define the LegacyXLS/libxls concurrency policy.

The result must remain bounded to the approved dependency surfaces and must not
be treated as generic third-party concurrency support.

## FW-P2-75 — TEST-PR Unit-Test Strict-Concurrency Correction

**Status:** Candidate
**Depends on:** Sprint 80 accepted unit-test strict probe

Make the unit-test target honest under coordinated strict migration through
actor-aware fixture construction, async-safe test synchronization, subprocess
Sendable ownership and actor-aware assertions/macros. The accepted strict probe
found 45 distinct error locations and a large warning surface concentrated in
fixtures/support code; this family must preserve independent test oracles and
must not weaken production assertions to silence diagnostics.

TEST-PR is required before the unit-test target can participate in the
coordinated Swift-6 migration.

## FW-P2-76 — Coordinated Swift-6 Migration

**Status:** Blocked
**Depends on:** PR-2, PR-3 and TEST-PR; completion of the serial Unified Import Centre boundary

After the prerequisite families are accepted, perform one coordinated Swift-6
strict migration and readiness pass. The migration is not a prerequisite to
begin the serial Swift-5 Unified Import Centre, but it is required before
personal-v1 certification. Swift-6 migration is not complete or approved by
Sprint 80; the readiness discovery only establishes that the compiler can be
reached and that the remaining work is materially known.

## FW-P2-77 — Source Tree and Documentation Organization Consolidation

**Status:** Ready for discovery
**Type:** Maintenance
**Depends on:** None
**Origin:** User / documentation synchronization, 2026-09-09
**Evidence / authority:** Repository structure reviewed during the 2026-09-09 planning reconciliation at `main@a560312db5900645779a499016e13f0c87e81435`
**Disposition date:** 2026-09-09
**Owning specification / ADR:** Repository organization discovery; no accepted target layout yet
**Personal-v1 relevance:** Maintenance/readability; not itself an adoption gate

**Purpose:** Establish one understandable repository organization and naming model while preserving behavior, Git history, Xcode membership and project authority.

Verified structural signals include root analyzer/detector/normalizer/parser/reader areas coexisting with feature-local import folders, mixed responsibilities in `Core`, an oversized `ContentView.swift`, mixed Project-doc naming and historical roadmap naming residue.

Discovery must cover feature-oriented versus layer-oriented placement, root ownership, Import/Ingestion boundaries, Core ownership, Views/ViewModels, test-tree correspondence, Project-doc archival naming, Xcode references/resources, script/path assumptions and Git-history impact.

Explicit boundaries:

- no financial behavior change merely for neatness;
- no parser consolidation solely because folders look similar;
- no Swift package/framework split without separate architecture approval;
- no mass move mixed with behavioral refactor;
- no private-original/evidence relocation;
- no migration;
- no speculative target tree accepted before discovery.

Cross-links: `FW-P2-67` owns app-shell/workflow decomposition; `FW-P2-71` owns Xcode/user-metadata hygiene; `FW-P2-77` owns repository organization/naming discovery.

---

## FW-P2-78 — LF-UI-2026-09-R1 Dashboard Implementation

**Status:** Ready for planning
**Depends on:** accepted R1 design authority and existing repository-backed Dashboard/account/card/salary summaries

Implement the bounded R1 Dashboard hierarchy using native-currency groups, bank balances distinct from card liabilities, readable full amounts, authoritative as-of/period context where available, and the accepted Salary/current-funding summary without formula changes.

Required exclusions:

- no hidden FX conversion;
- no invented net worth;
- no new analytics, trends or percentages;
- no repository hydration masquerading as Import Activity;
- no source-financial or persistence-semantic changes.

The layout must adapt responsively without losing currency or liability meaning.

---

## FW-P2-79 — Supported Institution / Source Coverage Documentation

**Status:** Ready for planning
**Depends on:** current accepted source/profile registry and ADR-046 current certification boundary

Maintain a user-readable and engineering-readable support matrix that distinguishes institution, financial family, source format, profile/parser identity/version where appropriate, credential requirement, active authentic-corpus certification status, known exclusions, historical implementation acceptance, current ADR-046 reliability certification and source-uncertified cases.

Support must never be inferred from institution name, fixture presence, filename, format or structural similarity. The matrix is a required input to `FW-P0-26` personal-v1 certification but does not itself certify personal-v1.

---

# P3 — Identity Enhancements

## FW-P3-01 — Identifier Confidence Scoring

**Status:** Research
**Depends on:** Approved non-authoritative evidence policy

Confidence must never silently promote weak evidence into verified identity.

---

## FW-P3-02 — Identifier Aliases and Alternate Institution Identifiers

**Status:** Research
**Depends on:** Identifier ownership and conflict semantics

---

## FW-P3-03 — User-Visible Identity History

**Status:** Idea
**Depends on:** Durable identity provenance

---

## FW-P3-04 — Administrative Identifier Correction

**Status:** Research
**Depends on:** Reversible identity mutations and audit history

---

## FW-P3-05 — Identity Provenance Timeline

**Status:** Idea
**Depends on:** Durable identity history

---

# P3 — Financial Intelligence and Planning

## FW-P3-06 — Financial Intelligence Engine

**Status:** Research
**Depends on:** Reliable financial truth, provenance, rules and explanation foundations

Define the architecture for deterministic, auditable financial conclusions that operate above imported source data.

The engine may coordinate:

- account and transaction relationships;
- recurring activity;
- transfers;
- salary;
- obligations;
- investments;
- multi-currency reporting;
- anomaly and change detection;
- planning and forecasting.

Every conclusion must identify its supporting evidence, deterministic rules and limitations.

The engine must not become a black-box source of financial truth.

---

## FW-P3-07 — Financial Replay, Timeline and Money-Journey Reconstruction

**Status:** Blocked
**Depends on:** Reliable transaction identity, transfer matching, provenance and financial-intelligence foundations

Reconstruct how money moved through the user’s financial entities over time.

Candidate outcomes include:

- a Financial Timeline;
- replay of income, transfers, spending and investment funding;
- explanation of what changed net worth;
- chains showing movement between owned accounts;
- links back to supporting transactions, statements and import sessions;
- deterministic handling of corrected or reversed history.

Internal transfers must never be presented as new income or expense.

---

## FW-P3-08 — Broader Salary and Planning Expansion

**Status:** Blocked
**Depends on:** the specific transaction/reconciliation, recurring-obligation, analytics, investment or FX foundations required by the selected broader planning outcome; a future explicit ADR-045 alignment or successor architecture before external remittance-reference evidence can affect Salary calculations

**Completed boundary:** Sprint 79 and the later accepted startup/monthly-planner package completed exact Qatar Airways salary actuals, Salary History/This Month, coherent natural-input editing, Save/Command-S, contextual provenance, compact layout and configured-fee validation. Those slices are not future work.

**Remaining boundary:** Broader cross-employer planning integration, historical planner analytics/variance explanation and other planning outcomes that genuinely extend the accepted current-month workspace. Generic employer source support stays under `FW-P1-05`; recurring obligations under `FW-P3-09`; transfer/reconciliation under `FW-P2-10`/`FW-P2-11`/`FW-P3-19`; investments and general reporting FX remain in their dedicated candidates.

**User-settled future India-remittance reference direction — 2026-09-09:** Al Dar Exchange is prospective evidence only for **Salary / This Month / India-remittance planning**. It is not general FX, investment FX, ISP FX, net-worth FX or reporting-currency authority. Read-only public-calculator discovery established amount-sensitive forward QAR-send quoting through the provider's public calculator path and also established that the reverse INR-target result is not reciprocal enough to prove sufficient funding. The reverse endpoint may inform later implementation investigation but is not financial authority.

The selected future planner method is:

```text
provisional QAR requirement
→ fetch an amount-specific forward Al Dar QAR→INR quote for that QAR send amount
→ recalculate the planner QAR requirement using the fetched rate
```

This remains a planning approximation/reference, not a guaranteed executable settlement or exact receive amount. Do not silently iterate toward an invented convergence rule, infer Al Dar's proprietary tier schedule, or treat a 1-QAR/table quote as universal. A materially changed funding amount may invalidate the usefulness of an earlier amount-bound quote even when it is recent. The existing ADR-045 upward rounding of the final derived QAR principal to the next QAR minor unit remains the underfunding guard.

Current production remains the explicit dated **user-entered** planning FX contract. A future external quote must retain distinct provider/source/amount/direction/fetch provenance and must never be mislabeled `user_entered`. Manual user-entered FX remains a supported fallback/override. External Al Dar use requires a future explicit ADR-045 alignment or successor architecture before it can affect Salary calculations.

The transfer fee remains a separate editable user/planning input. Public calculator discovery did not establish a universal applicable fee, so LedgerForge must not auto-fetch or auto-change the configured fee without separate evidence. The current accepted configurable-fee behavior remains unchanged.

Historical Budget Analysis percentage haircuts against generic market/reference FX were spreadsheet-specific workarounds for provider spread/commission uncertainty. They are explicitly retired as LedgerForge architecture: do not persist a fixed haircut, create a generic spread multiplier or silently reduce a fetched reference rate.

Further Salary visual polish remains lower priority and must not reopen accepted editor or persistence behavior.

---

## FW-P3-09 — Upcoming Obligations and Cash-Flow Planning

**Status:** Blocked
**Depends on:** Recurring-transaction detection, reliable categories, account balances and planning semantics

Present upcoming financial obligations such as:

- bills;
- subscriptions;
- expected credit-card payments;
- loan payments;
- recurring transfers;
- planned investments;
- other known commitments.

Cash-flow planning must distinguish confirmed obligations, deterministic projections and user-entered assumptions.

No prediction may be presented as a guaranteed future transaction.

---

# P3 — Analytics, Budgets and Reports

These candidates remain blocked until transaction integrity, account identity and source coverage are sufficiently mature.

## FW-P3-10 — Spending Analytics

**Status:** Blocked
**Depends on:** Reliable duplicate handling and categorization

Includes:

- spending timelines;
- monthly and yearly trends;
- category breakdowns.

---

## FW-P3-11 — Budgets

**Status:** Blocked
**Depends on:** Stable categorization and analytics

---

## FW-P3-12 — Financial Goals

**Status:** Blocked
**Depends on:** Stable reporting model

---

## FW-P3-13 — Forecasting

**Status:** Research
**Depends on:** Reliable historical data and approved explainability standards

---

## FW-P3-14 — Smart Alerts

**Status:** Blocked
**Depends on:** Reliable categories, rules or forecasting inputs

---

## FW-P3-15 — Custom Reports

**Status:** Blocked
**Depends on:** Stable analytics

---

## FW-P3-16 — Tax Views

**Status:** Research
**Depends on:** Jurisdiction and supported-data decisions

---

## FW-P3-17 — CSV and Report Export

**Status:** Candidate
**Depends on:** Export schema and privacy policy

Provide user-facing exports of reports and selected financial views. Full machine-readable domain export remains governed by `FW-P3-35`.

---

## FW-P3-18 — Net-Worth History

**Status:** Blocked
**Depends on:** Multi-account, investment and multi-currency foundations

---

## FW-P3-19 — Salary Actuals to Bank-Transaction Reconciliation

**Status:** Blocked
**Depends on:** accepted salary actuals (complete for exact Qatar Airways), reliable account identity and approved transaction/transfer reconciliation semantics under `FW-P2-10` and `FW-P2-11`

Use immutable imported salary actuals to help verify corresponding bank transactions without collapsing payroll evidence into bank-transaction truth.

The remaining blocker is matching/reconciliation semantics, not generic salary-slip support. Candidate outcomes include explainable likely salary-credit relationships, supported gross/net/deduction comparisons, mismatch explanation and explicit review for ambiguity.

A salary source must never silently create, modify or replace a bank transaction.

---

## FW-P3-19A — Liabilities, Loans and Financial Health

**Status:** Research
**Depends on:** Liability domain models, reliable account balances, obligations and multi-currency reporting

Support durable representation and understandable presentation of:

- loans;
- credit obligations;
- repayment schedules;
- outstanding principal;
- interest and fees;
- liquidity;
- debt burden;
- emergency-fund coverage;
- other explainable financial-health indicators.

Financial-health conclusions must show the underlying deterministic calculation and must not be presented as regulated financial advice.

---

# P3 — Investments and Wealth

## FW-P3-20 — Mutual-Fund Holdings

**Status:** Research
**Depends on:** accepted investment/holding identity and valuation provenance; source/user-owned position and cost evidence; authentic investment sources where ingestion support is selected

The user's current Indian mutual-fund domain is owned here, not by manual-valuation fallback merely because the historical workbook was manually maintained.

**User-settled plan identity boundary — 2026-09-09:** the selected Indian mutual-fund holdings are **Direct plans**. Recurring identity must use an explicitly qualified configuration such as exact AMFI scheme code + ISIN + plan/option metadata. Display-name similarity, approximate NAV and fuzzy recurring matching are not identity authority. A Regular plan must never substitute for a configured Direct plan.

Holding ownership, units, contributions/cost basis and correction history remain source/user-owned investment evidence. A fetched NAV never establishes those facts. External AMFI NAV retrieval/freshness belongs under `FW-P3-27`; manual/custom valuation fallback belongs under `FW-P3-28` only when required.

Ordinary valuation remains:

```text
holding units × native-currency NAV = derived native-currency market value
```

Any later reporting conversion is a separate provenance-bearing derived layer and never overwrites the native holding value or imported/source evidence.

---

## FW-P3-21 — ETF and Stock Holdings

**Status:** Research
**Depends on:** Investment domain model and approved non-source holdings test data and/or authentic brokerage sources where ingestion support is in scope

---

## FW-P3-22 — Brokerage Support Including IBKR

**Status:** Research
**Depends on:** Brokerage parsing and account-identity decisions

---

## FW-P3-23 — Folio and Broker Identifier Support

**Status:** Research
**Depends on:** Investment identity architecture

---

## FW-P3-24 — Portfolio Timeline and Performance

**Status:** Blocked
**Depends on:** Reliable holdings and investment-transaction history

---

## FW-P3-25 — Asset Allocation

**Status:** Blocked
**Depends on:** Reliable holdings

---

## FW-P3-26 — Net-Worth Integration

**Status:** Blocked
**Depends on:** Investments and multi-currency reporting

---

## FW-P3-27 — Optional Market-Data Refresh

**Status:** Research
**Depends on:** verified/user-owned holding identity and units; provider-specific access/terms and retrieval-contract qualification; offline-first cache/freshness policy

This candidate owns **external price/NAV retrieval and freshness**, not holding ownership.

### Zurich Qatar Airways ISP price reference

**Reported technical discovery — 2026-09-09:** bounded read-only discovery captured and anonymously replayed the productive public FE request:

```text
GET https://digitalfundservice.feprecisionplus.com/FundDataService.svc/GetRowIdList
```

The prospective Qatar Airways ISP lookup identities are exact Zurich Fund Code + expected **USD** currency:

- `N0USD`
- `USDL3`
- `3UUSD`
- `B0280`

The productive response resolved exactly one row for each configured code. Relevant discovered fields include `Common.FundCode_Customtable`, `Common.Name`, `Price.Bid.Amount`, `Price.Bid.Currency`, `Price.Currency_UnitLevel` and `Price.Change_`. Raw provider price values may carry more precision than rendered page text; preserve exact Decimal source values rather than round-tripping through display formatting.

For the selected funds, provider `PriceDate`, `NAVDate` and `Time` were not established as populated source dates. Durable semantics therefore remain **`PRICE_DATE_NOT_ESTABLISHED`** unless later provider evidence proves otherwise. Fetch/observation time is provenance, not a valuation date, and any global performance date is not silently reused as the price date. The exact period represented by the provider's Change-% field is also `NOT_ESTABLISHED` until source documentation proves it.

Technical retrieval is proven as reported discovery, but the current provider wording does **not** establish permission for automated persistent cached use. Provider terms/access and the exact durable-cache boundary remain implementation gates. Do not claim provider permission beyond evidence.

Zurich price is external valuation evidence only. It never establishes ISP units, contributions, account/policy ownership, policy balance, asset allocation, vesting or transaction history. Those remain under `FW-P3-29`.

### AMFI Indian mutual-fund NAV reference

**Reported technical discovery — 2026-09-09:** AMFI's current publication candidate is:

```text
GET https://portal.amfiindia.com/spages/NAVAll.txt
```

The prospective adapter must target the current eight-field publication contract rather than the retiring legacy `Original_NAVAll.txt` format. Exact configured scheme code + ISIN + Direct-plan/option metadata owns recurring lookup; Regular-plan fallback is prohibited. AMFI supplies NAV and NAV date. Expected INR is a separately qualified/configured contract and must not be falsely described as an AMFI response currency field.

AMFI terms evidence supports personal/noncommercial download, while the exact automated small-cache boundary remains an implementation qualification. Do not claim broader permission than the evidence establishes. Holdings/units/cost basis remain `FW-P3-20` authority, not NAV-feed facts.

### Provider-specific freshness and offline behavior

There is **no fixed once-per-Qatar-day refresh architecture**. Each approved provider adapter must define its own freshness policy based on provider/source semantics and product use.

Shared direction, without creating a generic framework merely for abstraction:

- hydrate/use the last successful cached observation first;
- refresh asynchronously when the relevant view/workflow opens and the observation is stale under that provider's accepted policy;
- an explicit user Refresh may be supported;
- failed refresh retains the previous success as `STALE` and never turns it into zero;
- no prior success plus unavailable source is `UNAVAILABLE`, not Money zero;
- network failure must not become app-startup or repository-hydration failure;
- no background polling requirement;
- provenance retains provider/source identity, exact source value, source timestamp/date where actually supplied, fetch timestamp separately, parser/adapter-contract version and source-response digest;
- provider-specific TTL/refresh numbers remain implementation-policy candidates until accepted, not architecture frozen by this planning document.

If multiple implemented adapters later demonstrably need the same launch/view refresh mechanics, a bounded shared coordinator may own only those proven common mechanics. Do not create a new future-work item merely to invent abstraction.

---

## FW-P3-28 — Manual Holdings and Custom-Fund Valuation

**Status:** Research
**Depends on:** Investment domain model, valuation provenance and reversible editing

Support holdings or valuation evidence that cannot be fully reconstructed from approved source/user evidence or a qualified external provider.

Candidate outcomes include:

- manual holding creation where the product explicitly allows it;
- manual units/contribution/cost evidence with clear provenance;
- dated manual valuations or prices;
- custom fund/security definitions;
- correction history;
- clear separation between imported, fetched and user-entered evidence;
- explicit valuation staleness.

This is a **fallback/manual** boundary. It is not the primary owner of the user's Indian mutual-fund domain, which remains `FW-P3-20`; AMFI NAV retrieval remains `FW-P3-27`. Manual entries must never overwrite imported/source-owned records or masquerade as provider observations.

---

## FW-P3-29 — Retirement and ISP Tracking

**Status:** Research
**Depends on:** accepted investment/holding identity, contribution/employer-benefit and planning-domain models; source/user-owned evidence for units, ownership and contribution classes

Support retirement and employer-sponsored investment plans, including the user's Qatar Airways ISP boundary, without using an external price table as ownership evidence.

Candidate ISP evidence includes:

- source/user-owned policy/account identity;
- mandatory units;
- AVC units;
- future separately evidenced contribution classes;
- total position derived from the accepted unit classes;
- employee/employer/voluntary contribution and cost evidence where available;
- multiple plan portfolios/allocation history where source/user evidence establishes them;
- links to Salary/planning workflows;
- derived current valuation only after independently owned units exist.

**Zurich price separation:** the prospective external price lookup codes are `N0USD`, `USDL3`, `3UUSD` and `B0280`, all with expected USD price currency. Zurich pricing belongs to `FW-P3-27`. A price row does **not** establish units owned, contribution history, policy/account ownership, policy balance, asset allocation, vesting or transactions. Fund name alone is not identity authority.

The historical Budget Analysis `0.75` Conventional Blend factor represented a temporary vesting/availability workaround. By explicit user decision it is **retired from future LedgerForge requirements**: do not implement a permanent 75% multiplier, apply it to `B0280`, or infer any replacement vesting schedule. Future vesting semantics require new explicit/source evidence if they later matter.

Ordinary ISP valuation remains:

```text
verified/user-owned units × native USD fund price = derived native USD market value
```

Any later reporting conversion is separately derived with its own FX provenance.

---

# P3 — Multi-Currency and Ecosystem

## FW-P3-30 — Locale-Aware and Derived Multi-Currency Presentation

**Status:** Blocked
**Depends on:** the accepted native `Money` boundary plus an approved general rate/reporting-currency scope for any converted or secondary-display value

**Completed boundary:** Production QAR and INR support already exists. Native amounts retain their currency/scale and current summaries remain grouped by native currency without hidden conversion.

**Remaining boundary:** locale-aware formatting refinements, regional/Indian grouping where applicable, and any derived base/secondary/reporting-currency presentation. Native values remain primary and derived conversions must visibly retain provider/source/freshness/algorithm context. Missing or stale conversion evidence remains explicit rather than becoming zero. Salary-remittance Al Dar evidence is outside this general reporting path and remains owned by `FW-P3-08`.

---

## FW-P3-31 — General Reference-Rate Storage and Provenance

**Status:** Research
**Depends on:** an accepted general derived-FX architecture, provider/attribution decision, provider-specific freshness/fallback policy and provenance-bearing derived-value contract

This candidate owns **general valuation/reporting reference-rate persistence and provenance**, not Salary-remittance quoting.

**User-selected conversion route — 2026-09-09:** future general reporting/valuation prefers:

```text
INR → QAR → USD
```

using one general QAR→INR reference leg and one fetched general QAR→USD reference leg. For one accepted source snapshot:

```text
QAR = INR / (QAR→INR)
USD = QAR × (QAR→USD)
```

Preserve both raw source legs, their units/orientation, provider/source timestamp, fetch timestamp separately, provider/source identity, source-response digest and derivation algorithm/version. Native `Money` remains authoritative and is never overwritten by conversion.

**Technically qualified provider candidate, not selected architecture:** `ExchangeRate-API` via `https://open.er-api.com/v6/latest/QAR` can provide QAR-based INR and USD legs in one dated snapshot and documents end-use caching with attribution. The user selected the **conversion route**, not a permanent provider. Future implementation discovery/ADR must still approve provider choice, attribution, freshness, fallback and durable-storage policy. ExchangeRate-API is neither the unique allowed provider nor already implemented architecture.

General refresh follows provider-specific freshness policy: use cached success first, optionally refresh asynchronously when a relevant reporting/valuation view opens and the observation is stale, allow explicit Refresh where approved, retain stale success after failure, never turn missing data into zero and do not require background polling. Provisional discovery TTL values are not frozen architecture.

**Al Dar exclusion:** amount-sensitive Al Dar remittance evidence belongs only to Salary/This Month/India-remittance planning under `FW-P3-08` and future ADR-045 alignment. It must not become the provider or rate authority for investment valuation, net worth or reporting currency merely because it publishes exchange information.

---

## FW-P3-32 — Historical FX Conversion

**Status:** Blocked
**Depends on:** `FW-P3-31` plus an accepted historical/effective-time general rate authority and derivation policy

Provide provenance-bearing derived historical conversion without overwriting native values. A current/observed general-rate snapshot does not establish rates for dates it did not cover. Salary-remittance Al Dar quotes are not historical/reporting FX authority.

---

## FW-P3-33 — User-Selectable Reporting Currency

**Status:** Blocked
**Depends on:** `FW-P3-31` and `FW-P3-32`, plus an accepted reporting-currency semantics contract

Provide selectable reporting currency from provenance-bearing derived values while preserving native imported/holding Money. The selected INR→QAR→USD route is a planning direction for derived reporting, not permission to overwrite native values or use Salary-remittance Al Dar evidence as global FX.

---

## FW-P3-34 — Currency-Aware Analytics and Net Worth

**Status:** Blocked
**Depends on:** reliable investment/holding values, analytics foundations, and accepted general reporting-currency conversion under `FW-P3-31` through `FW-P3-33`

Provide consolidated analytics/net-worth presentation only from auditable derived values. Preserve each native position/transaction amount, each external price/NAV observation and both raw FX legs independently. Missing/stale valuation or FX evidence yields incomplete/stale derived reporting, never fabricated zero or silently substituted rates.

---

## FW-P3-35 — Structured Data Export

**Status:** Candidate
**Depends on:** Export schema and privacy policy

Provide a machine-readable export of supported LedgerForge domain data. User-facing report and selected-view exports remain governed by `FW-P3-17`.

---

## FW-P3-36 — Verified Backup, Restore and Disaster Recovery

**Status:** Ready for discovery
**Shared prerequisites:** Canonical database lifecycle, checked close, coordinated SQLite/WAL/SHM handling, DEBUG lifecycle backup, migration-chain integrity and fail-closed recovery foundations exist.
**Implementation dependency:** Approval of the user-facing backup contents, integrity, restore-target, compatibility and confirmation contract.

This is a serious required recoverability input to `FW-P0-26` personal-v1 certification, but importance does not itself promote implementation priority.

Provide explicit user-owned local backup creation, integrity verification, documented contents/exclusions, restore preview/confirmation, safe-target restoration, version/schema compatibility checks, failure-safe recovery and disaster-recovery guidance.

Discovery must distinguish the existing DEBUG lifecycle backup from a production user-owned backup product and ensure restore cannot overwrite unique/newer data without explicit review. A copied file alone is not a trustworthy backup or restore drill.

---

## FW-P3-37 — Optional Encrypted Sync

**Status:** Research
**Depends on:** Backup, encryption, conflict resolution and explicit opt-in architecture

LedgerForge must remain fully functional without synchronization.

---

## FW-P3-38 — Open API and External Integrations

**Status:** Research
**Depends on:** Stable public data contracts and security policy

---

## FW-P3-39 — External Import Plugin Architecture

**Status:** Research
**Depends on:** Stable parser/reader, ADR-046 authentic-corpus acceptance, non-source test-data, security and public extension contracts

Investigate an optional plugin architecture for adding financial institutions, document families or import adapters without modifying LedgerForge’s core application.

The design must preserve:

- offline-first operation;
- privacy by default;
- deterministic parsing;
- validation before persistence;
- explicit plugin trust and installation controls;
- compatibility and versioning rules;
- isolation from repository and credential internals.

Internal parser-framework expansion remains governed separately by `FW-P1-06`.

No external plugin system is approved until its security, signing, compatibility and data-access boundaries are defined.

---

## FW-P3-40 — Multiple Workspaces and Independent Ledgers

**Status:** Research
**Depends on:** Workspace-scoped identity, fingerprint, settings and repository-isolation decisions

Investigate support for more than one independent local financial workspace.

The design must define:

- strict data isolation;
- workspace-scoped account identity;
- workspace-scoped preferences;
- workspace selection and creation;
- import routing;
- fingerprint uniqueness;
- backup and restore boundaries;
- deletion and archival;
- migration from the current single-workspace product model.

No cross-workspace matching or aggregation may occur implicitly.

---

## FW-P3-41 — Portable Workspace Folder

**Status:** Research
**Depends on:** `FW-P3-36`, workspace isolation and safe coordination of external file changes

Investigate storing or exporting a complete LedgerForge workspace in a user-selected local folder that may itself be synchronized by services such as iCloud Drive, OneDrive, Dropbox or Synology tools.

LedgerForge must remain offline-first and must not depend on any cloud provider.

The design must address:

- atomic local writes;
- conflict detection;
- concurrent external modifications;
- locking;
- backup and recovery;
- file permissions;
- sandbox access;
- explicit user control.

---

## FW-P3-42 — Cross-Platform Desktop Strategy

**Status:** Research
**Depends on:** Stable public domain, persistence and presentation boundaries

Evaluate whether LedgerForge should eventually support Windows or Linux while preserving macOS as the primary product.

The research must distinguish:

- reusable domain and repository layers;
- Swift and SwiftUI platform constraints;
- storage and Keychain equivalents;
- native desktop interaction expectations;
- testing and release cost;
- whether a separate client or shared core is justified.

No portability claim may be made without an approved architecture and working evidence.

---

## FW-P3-43 — Local-Data Encryption at Rest

**Status:** Research
**Depends on:** Database lifecycle, backup, credential and recovery architecture

Investigate encryption of LedgerForge financial data at rest.

The design must address:

- key ownership and storage;
- unlock and recovery;
- backup encryption;
- migration of existing databases;
- performance;
- development and testing workflows;
- loss-of-key consequences;
- interaction with portable workspaces and optional sync;
- explicit user understanding.

Encryption must not create a false promise of security while leaving exported backups or diagnostics unprotected.

---

# Research Queue

Items in this section are not implementation candidates until promoted into a priority section. Research already promoted into a numbered candidate is not repeated here.

## Import and Parsing Research

- semi-automated parser-assistance research from authentic source semantics, with generated artifacts explicitly ineligible as parser/source acceptance evidence;
- AI-assisted recovery for unsupported or ambiguous layouts beyond column detection;
- shared parser evidence across CSV, PDF, XLS, XLSX and TXT.

## Persistence Research

- long-term mutation-history compaction and archival after `FW-P0-16` and a concrete durable mutation history exist; compaction cannot precede family-specific retention, privacy and reversibility policy.

## Financial Intelligence Research

- explainable recommendations;
- anomaly detection;
- tax and regulatory assistance.

Research findings must not be reported as planned product work until they are promoted into the prioritized queue.

---

## Maintenance Rules

When editing this document:

- preserve existing candidate IDs;
- add candidates in priority and dependency order;
- update status when dependencies change;
- use only the defined status labels and record unmet conditions under `Depends on` rather than inventing compound status labels;
- record verified bugs explicitly;
- remove completed work;
- remove work selected for execution;
- do not record implementation progress;
- do not duplicate completed sprint history;
- do not place architectural decisions here;
- do not include raw financial identifiers, passwords or source fragments;
- keep candidates implementation-agnostic until repository discovery;
- distinguish candidate work from research and ideas;
- record every approved but unimplemented idea, verified bug, accepted architectural follow-up and deferred sprint exclusion;
- do not remove a candidate merely because its priority is low or its dependency is distant;
- preserve LedgerForge principles:
  - offline first;
  - privacy by default;
  - deterministic before intelligent;
  - single source of truth;
  - resilient parsing;
  - explicit user control;
  - explainable financial decisions;
  - explicit and reversible destructive actions.
