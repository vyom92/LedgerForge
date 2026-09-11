# UI/UX v1.0 — shared architecture and current routing

The frozen hierarchy remains the shared interface architecture. [R1 README](UI%20Assets/LF-UI-2026-09-R1/README.md) is the canonical package map for approved written design and its supporting/draft distinctions. [PROJECT_STATE](PROJECT_STATE.md) owns accepted behavior and WIP; [SCOPE_DECISIONS](SCOPE_DECISIONS.md) owns product decisions/rejections. Design approval is not native implementation or financial acceptance.

## Screen and shared-authority routing

Order inherits [Guide rule H](Project_Guide.md#documentation-order): revision, then natural SC number/suffix. Detailed screen requirements have one written owner; untouched inherited behavior remains explicit.

| Need | Canonical owner |
| --- | --- |
| Shared visual/component requirements and ignored captions | [DESIGN_HANDOFF](UI%20Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md) |
| SC-01 shell, navigation and responsive hierarchy | [SC-01_App_Shell](UI%20Assets/LF-UI-2026-09-R1/SC-01_App_Shell.md) |
| SC-02 Transactions | [SC-02_Transactions](UI%20Assets/LF-UI-2026-09-R1/SC-02_Transactions.md) |
| SC-03 Dashboard | [SC-03_Dashboard](UI%20Assets/LF-UI-2026-09-R1/SC-03_Dashboard.md) |
| Accounts, Import/Preview, Salary, Settings, Developer Console and simple appearance | [Inherited_Screens](UI%20Assets/LF-UI-2026-09-R1/Inherited_Screens.md) |
| Existing numeric design roles | [DESIGN_TOKENS](UI%20Assets/LF-UI-2026-09-R1/DESIGN_TOKENS.json) |
| Required visual/interaction checks | [ACCEPTANCE](UI%20Assets/LF-UI-2026-09-R1/ACCEPTANCE.md) |
| Original visual provenance and exact machine inventory | [SOURCES](UI%20Assets/LF-UI-2026-09-R1/SOURCES.md), [ASSET_MANIFEST](UI%20Assets/LF-UI-2026-09-R1/ASSET_MANIFEST.json) |

# Core Principles

LedgerForge is a desktop financial application.

It is not:

- a spreadsheet;
- a developer tool;
- a database browser;
- an institution-specific transaction viewer;
- an importer pretending to be a financial product.

The interface prioritizes:

1. Clarity
2. Financial truth
3. Information density
4. Speed
5. Predictability
6. Consistency
7. Privacy

Every screen should answer a user question.

Examples:

- What is my financial position?
- What changed recently?
- Where did my money go?
- What imported successfully?
- Which account owns this activity?
- Why is this information unavailable?

---

# Shared Truthfulness Rules

Every screen must derive visible financial and workflow state from its authoritative owner.

## Required behavior

- Financial values use authoritative `Money`.
- Native currency remains visible.
- Mixed currencies are not silently combined.
- Unknown or malformed persisted values use neutral bounded presentation.
- Unsupported features appear absent or explicitly unavailable.
- Repository-unavailable state is distinct from empty state.
- Current workflow state takes precedence over stale historical activity.
- Imported source values remain distinguishable from future corrections or derived values.
- Missing provenance is omitted or marked unavailable rather than inferred.
- Privacy-safe summaries replace raw identifiers.

## Prohibited behavior

- hardcoded financial totals presented as user data;
- transformed raw persistence codes shown directly;
- filename-based identity claims;
- global validation state applied to unrelated transactions;
- fake counts derived from transient file selection;
- enabled controls with no complete outcome;
- navigation to unrelated placeholders;
- path, SQL or unrestricted source-fragment disclosure.

---

# Change Policy

Major UI changes require:

1. Proposal
2. Design review
3. Master Design Board update when shell or visual language changes
4. Affected screen-asset updates
5. Approval
6. Frozen-document revision
7. Visual and interaction acceptance criteria
8. Implementation authorization

Minor refinements may update individual screen assets without a new master Design Board only when:

- the shell is unchanged;
- the visual language is unchanged;
- financial and workflow semantics are unchanged;
- the refinement is explicitly approved.

Implementation must not become the source of truth for design.

When implementation and approved assets differ, the approved hierarchy controls unless a newer frozen revision has been approved.

Architecture, Product Vision, this frozen specification and approved assets together define the UI implementation boundary. Repository state and the current execution prompt determine which bounded portion may actually be implemented.
