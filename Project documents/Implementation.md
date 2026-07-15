**ChatGPT mode:** Codex  
**Model:** GPT-5.6 Terra  
**Purpose:** Implement, validate, document, commit and push LedgerForge Sprint 42. Do not begin Sprint 43.

# Repository

`vyom92/LedgerForge`

# Sprint

**Sprint 42 — Durable Import Attempt History**

# Objective

Persist and present a privacy-safe, read-only history of supported import outcomes without treating rejected content as imported financial history or authorizing corrective mutation.

# Mandatory preflight

Before implementation, read in order:

1. `Project documents/.github/Context_Manifest.yaml`
2. `AGENTS.md`
3. `Project documents/Project_Guide.md`
4. `Project documents/PROJECT_STATE.md`
5. this ACTIVE contract
6. `Project documents/FUTURE_WORK.MD`
7. `Project documents/ADR.md`, especially ADR-019, ADR-030, ADR-031 and ADR-032
8. relevant repository, migration, service, ViewModel, view and test evidence

Verify `main`, a clean worktree, `HEAD == origin/main`, Sprint 41 complete and verified, and no unapproved Sprint 42 implementation. Do not use private original bank statements.

# Governing architecture

Preserve offline-first operation, explicit confirmation, parser-owned evidence, immutable repository identity, ADR-030 exact-content authority, ADR-031 bounded Axis UPI authority, provider-owned atomic persistence, SQLite/In-Memory parity, and `RepositoryStoreHydrator` as the sole persistence-to-runtime boundary.

ADR-032 governs this sprint. An import attempt records an attempted source; a successful import session records accepted financial history. Rejected or failed attempts are never represented as successful imported history.

# Approved scope

Core candidates:

- `FW-P0-07` — Durable Import Audit Trail
- `FW-P1-26` — Global Import-Session History

Narrowed candidates:

- `FW-P1-25` — read-only review of currently supported duplicate outcomes only;
- `FW-P2-12` — explanation of supported Axis UPI transaction-event blocking only;
- `FW-P1-29` — bounded enumerated guidance for supported outcomes;
- `FW-P0-10` — account-decision provenance required by import history only;
- `FW-P2-01` — provenance within import-attempt history and detail only.

Broader forms of these candidates are not completed by Sprint 42.

# Domain and persistence contract

## Attempt and outcome model

Use a separate durable `import_attempts` ledger. Outcome, coverage, account-decision and guidance values are bounded, versionable and privacy-safe enumerations. Initial supported outcomes are:

- successful import;
- validation failure;
- persistence failure;
- exact-statement duplicate;
- existing eligible Axis UPI transaction event;
- repeated eligible incoming evidence;
- transaction-event ownership conflict;
- repository-integrity conflict only where an authoritative production path detects it.

Coverage must distinguish supported evaluation from unsupported or unevaluated coverage. Missing Axis UPI evidence never proves novelty. ADR-031 does not generalize to IMPS, NEFT, cards/e-commerce, unstructured references, refunds, reversals or other institutions.

Account decisions and guidance use bounded codes. Presentation may explain trusted account/session/document relationships without exposing private evidence.

## Privacy

Never persist or present from attempt history raw statement content, unrestricted source fragments, passwords, raw financial identifiers, UPI references, exact fingerprints, transaction-event digests, canonical identity payloads, unrestricted narrations, source paths, unrestricted localized errors or free-form financial validation text. Do not add private original statements to fixtures or Git.

## Atomicity and side effects

A successful attempt record participates in the same provider-owned atomic operation as successful import history. A successful financial commit cannot exist without its corresponding successful attempt record once Sprint 42 is active. Rejected-attempt recording must not weaken or override the rejection; a failure to record a rejected attempt must never convert rejection into success. Document the limitation that an audit write may itself fail when persistence is unavailable.

Existing workspace/account/identifier side effects may occur before the atomic import-history operation. Report verified side-effect truth and do not claim complete rollback or broader cross-repository atomicity.

## Migration and providers

Implement additive Migration V4 for `import_attempts`. Existing completed successful import sessions may be backfilled only where repository evidence is authoritative. Never invent historical rejected attempts, duplicates, validation failures or persistence failures. The migration must not alter transactions, fingerprints, identifiers, event ownership, accounts, documents or import-session relationships. SQLite and In-Memory providers enforce equivalent domain behaviour.

## Runtime and presentation boundaries

Use existing repository abstractions and `RepositoryStoreHydrator`; do not bypass the persistence-to-runtime boundary. Add only bounded read-only presentation: immediate Import Wizard outcome status, a global Imports history list, selected attempt detail, and trusted navigation to prior successful account/session/document relationships where available. Do not redesign Accounts or transaction detail pages.

# Explicit exclusions

No duplicate override or acceptance, partial import, silent transaction omission, historical rejected-attempt reconstruction, historical duplicate repair, account linking/unlinking, account merge/split, transaction deletion/reversal, identifier reassignment/correction, reversible financial-mutation infrastructure, speculative duplicate detection, additional event families, cross-process or external-writer safety, persistent developer diagnostic history, full validation timeline, dedicated developer import-session inspector, development database reset relaunch fix, broad Accounts-page redesign or broad transaction-detail redesign.

# Expected implementation surfaces

Follow current repository organization. Likely surfaces include existing DTO, repository, migration, SQLite/In-Memory provider, import persistence, import engine, hydrator, import-attempt domain/runtime, history ViewModel and Imports presentation files. Do not prescribe unverified symbol names or redesign unrelated architecture.

# Required validation

Add focused tests for attempt domain values; outcome, coverage, account-decision and guidance codes; SQLite/In-Memory parity; additive V4 migration; V3-to-V4 recreation; authoritative successful-session backfill without invented rejection; atomic successful import plus attempt; rollback when successful attempt persistence fails; validation-failure, exact-duplicate, supported Axis UPI block, repeated incoming evidence, ownership-conflict and persistence-failure truthfulness; no financial mutation on rejected attempts; exact-statement and Sprint 41 regressions; sanitized baseline and overlap imports in both orders; transaction-event canonicalization; DTO and reopened SQLite privacy; financial baseline; hydration count/no hydration where applicable; global history ViewModel and presentation.

Run diagnostics, clean build and the complete configured unit/integration plan. Record exact totals, failures and skips. No private original bank statements are required.

# Manual runtime acceptance

Using disposable databases and approved sanitized fixtures:

1. Upgrade V3 and display existing successful history without inventing rejected history.
2. Import the Axis baseline; verify one successful attempt and unchanged financial truth.
3. Re-import the exact statement; verify a durable rejected attempt linked to prior successful history.
4. Import the approved overlap fixture; verify supported event blocking and no financial mutation.
5. Repeat the overlap scenario in reverse order.
6. Produce a privacy-safe validation failure and verify an accountless durable attempt.
7. Inject persistence failure and verify truthful side-effect and history reporting.
8. Reopen the same SQLite path and verify attempt history survives provider recreation.
9. Confirm trusted navigation uses immutable repository relationships.
10. Confirm prohibited evidence is absent from persistence, presentation and diagnostics.

# Documentation and Git handoff

After implementation and required validation, update only the authorized handoff documentation. Preserve Sprint 41 history and do not claim Sprint 42 implementation before it is verified. Review the complete diff, run `git diff --check` and conflict scans, verify only approved implementation/test and documentation files changed, commit on `main` with an accurate Sprint 42 message, push `origin/main`, verify the remote SHA and leave a clean worktree. Do not create Sprint 43 planning.
