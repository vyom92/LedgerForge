# LedgerForge – Engineering Standards

## Purpose

This document defines the engineering principles used throughout LedgerForge. It exists to keep the codebase consistent, maintainable and scalable as the application grows.

---

# Core Rules

## Decision Framework

Before implementing any feature, ask:

1. Does it reduce manual work?
2. Does it increase confidence?
3. Does it surface meaningful financial insight?
4. Does it align with the Product Vision?
5. Can it be explained to the user?

If the answer to all five is "No", do not build it.

1. The project must build successfully after every completed sprint.
2. Prefer small, verifiable commits over large refactors.
2a. Only commit after the project builds successfully and required sprint tests pass.
2b. Before committing, verify there are no unresolved merge conflict markers and all staged files are legitimate, compatible work authorized by the prompt.
2c. Successful sprint work should be pushed to `origin/main` immediately after the commit.
3. New features should integrate with the existing architecture rather than bypass it.
4. Avoid duplicate business logic.
5. Offline-first is the default.
6. Every automatic decision must be explainable.
7. Every imported value must be traceable back to its source.
8. Every monetary value must retain its native currency.
9. Currency conversion is a presentation concern, never a storage concern.
10. Financial calculations must be deterministic and reproducible.
11. Monetary values must be formatted using the correct regional numbering system.

---

# Folder Responsibilities

Views/
- User interface only.
- No parsing or business logic.

Models/
- Domain models.
- No UI code.

Services/
- Application workflow orchestration.
- Import coordination, validation and repository persistence.
- Legacy import orchestration only where migration is still in progress.

Readers/
- Read file formats only.
- Receive optional passwords from the ImportCoordinator.
- Produce RawDocument.
- Extract document contents.
- Never access Keychain.
- Never perform business logic.
- Never interpret financial meaning.

Detectors/
- Detect financial institutions.
- Classify document types.
- Identify parser candidates.

Parsers/
- Produce FinancialDocument.
- Own institution- and layout-specific financial interpretation, including verification of parser-supported financial identifiers.
- Never perform validation.
- Never persist data.

Database/
- Repository implementations and persistence only.

Core/
- Shared application state and infrastructure.

ViewModels/
- Presentation logic only.
- No persistence.
- No parsing.
- Observe application state and prepare data for Views.

---

# Coding Principles

- Prefer composition over duplication.
- Keep functions focused on a single responsibility.
- Avoid hardcoded institution-specific logic when a generic solution exists.
- Use descriptive names rather than abbreviations.
- Minimize force unwrapping.
- Keep UI and business logic separated.
- Prefer domain value types (for example, Money) over primitive values when representing financial concepts.
- Every object should have a single owner.
- Avoid mixing presentation formatting with business logic.

# Error Handling Standards

- Fail early with meaningful errors.
- Never silently discard financial data.
- Prefer validation over assumptions.
- Log unexpected conditions for later diagnosis.
- Every parsing failure should explain what failed and why.

---

# Development Workflow

## Planning

Before implementation:

1. Read `AGENTS.md`, `Project documents/Project_Guide.md` and `Project documents/PROJECT_STATE.md`.
2. Use the Guide to identify additional subject authorities.
3. For planning, review `Project documents/FUTURE_WORK.MD` after verified state.
4. The complete Chat-approved prompt supplied directly in the current conversation is the execution contract.
5. Work discovery is read-only and reported directly in chat.
6. Do not modify source code during discovery.

## Implementation

1. Read and execute only the complete approved prompt from the current conversation.
2. Work only within its scope.
3. Select exactly one file at a time.
4. Verify the filename before editing.
5. Implement one logical change.
6. Build.
7. Run the required sprint tests.
8. Reconcile and validate the complete legitimate repository state.
9. Verify there are no unresolved merge conflict markers.
10. Generate a concise commit message describing the completed work.
11. Commit.
12. Push to the tracked branch (normally `origin/main`).
13. Push the sprint tag if one was created.
14. Update `Project documents/PROJECT_STATE.md` only after successful validation.
15. Report execution directly in chat.
16. Continue only after successful validation.
# Definition of Done

A task is complete only when:

- The project builds successfully.
- Required sprint tests pass.
- No unresolved merge conflict markers exist.
- The completed sprint has been committed.
- The completed sprint has been pushed to the tracked branch.
- Sprint tag has been created and pushed (if applicable).
- Existing functionality still works.
- The feature has been manually verified.
- Approved reference fixtures continue producing identical financial truth.
- Documentation is updated if architecture changed.
- `Project documents/PROJECT_STATE.md` reflects the current repository state.
- Verified durable facts are recorded only in their subject authorities; Git preserves detailed history.
- The implementation follows Product Vision and Architecture.

---

# Architecture Rules

Readers extract data.
Institution Detection identifies the source.
Statement Classification determines the document family.
Parser Selection chooses the correct parser.
Statement Parsers produce FinancialDocument.
FinancialDocument is the canonical parser output.
Validation verifies financial correctness.
Repositories persist validated financial data.
Runtime Stores own observable application state.
ViewModels observe stores.
Views never coordinate business workflows.

## Direct execution and reporting

- The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.
- Work reports read-only discovery directly in chat.
- Codex reports implementation and documentation execution directly in chat.
- Verified durable facts go only to their subject authorities; Git preserves implementation history.

## Manual runtime verification

1. Automated tests prove covered data-path and financial correctness.
2. A DEBUG-only approved-fixture launcher may verify deterministic runtime presentation and navigation.
3. The launcher enters ordinary production preparation and preserves explicit confirmation.
4. Native macOS file selection receives one bounded smoke test.
5. Repeated fixture scenarios do not depend on accessibility navigation in `NSOpenPanel`.
6. Manual intervention is limited to the exact unavoidable action.
7. Reports distinguish passed, pending, unavailable and explicitly accepted deferral.
8. No private fixture or alternate import path is permitted.

## Documentation-only cycles

A documentation-only cycle may skip full test execution only when Swift, tests, schemas, migrations, fixtures, executable build settings and assets are unchanged. A cycle that modifies `project.pbxproj` requires Xcode project-integrity validation and a clean Debug build.

---

# Quality Standards

Every feature should:
- Reduce manual work, or
- Increase confidence, or
- Surface meaningful financial insight.
- Preserve financial truth.
- Support future financial institutions without architectural changes.
- Remain explainable to the end user.

If it satisfies none of these goals, reconsider whether it belongs in LedgerForge.

---

# Long-Term Philosophy

Optimize for maintainability over cleverness.

Build systems that learn instead of accumulating special cases.

The code should make adding the next financial institution easier than adding the previous one.

---

# Currency Standards

- Preserve native currency.
- Store exchange rates separately from monetary values.
- Never overwrite imported financial values after conversion.
- Support multiple simultaneous display currencies.
- Respect regional formatting conventions for each currency.

---

# Financial Statement Fixture Evidence Standards

- Private-statement-derived fixtures may enter Git only through an approved repository-safe sanitized or clean-room evidence package.
- For packages classified as clean-room reconstructions, source pages, content streams, images, XObjects, font objects, metadata, annotations, forms, attachments and rasterized source backgrounds must not be reused.
- New evidence packages that use expected metadata and manifests must use the repository-approved metadata schema and a neutral document-family classification. Older integrated fixtures must not be rewritten solely to enforce later metadata uniformity.
- Fixture evidence must preserve exact source-supported financial values, native currencies, source order and declared structural relationships.
- When original-currency, FX, fee, markup or tax information exists as distinct source evidence, it must remain separate from the posted statement amount. Missing values must not be calculated merely to populate common metadata.
- Geometry claims must use explicit measured tolerances where preservation is tolerance-qualified. Visual review cannot override a numeric failure.
- Native-text and OCR boundaries must be stated explicitly. OCR must not be used when reliable native extraction is available.
- Fictional identity continuity must be deterministic and must not expose original identifiers, suffixes, merchants, references, paths or private mappings.
- Repository tests must verify positive metadata assertions and forbidden private surfaces.
- Fixture integration proves only the evidence declared by its tests and metadata. It does not establish production parsing, persistence support or finalized domain semantics.

---

# AI Development Standards

- Never assume statement layouts.
- Always request reference documents when required.
- Chat owns planning and approval; Work owns read-only discovery; Codex owns authorised repository edits, validation, documentation execution and Git operations.
- The direct Chat-approved prompt is the only execution contract.
- Never invent financial rules.
- Verify the filename in the header comment before editing.
- Build after every significant change.
- Never commit if the build or required tests fail.
- Validate all legitimate compatible changes in the combined repository state before committing.
- Generate commit messages from completed work rather than generic templates.
- Report the commit hash, tag (if created) and push result after every successful automated commit.
- Resolve compile errors before continuing.
- Run regression tests whenever parser or import code changes.
- Verify production-supported fixtures for production claims. Foundation-only fixtures, including the current Axis PDF fixture, validate only the layers explicitly covered by their tests and do not establish end-to-end format support.
- Summarize architectural decisions after every sprint.

---

# Technical Debt Policy

Technical debt should be documented, not ignored.

When shortcuts are necessary:

- Record the reason.
- Record the intended solution.
- Record the expected impact.
- Create a follow-up milestone.

Temporary code should never become permanent architecture.
