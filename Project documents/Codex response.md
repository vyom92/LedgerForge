# Codex Response

## Summary

Repository housekeeping from the post Sprint 11B architecture audit is complete.

Completed in series:

1. Read `Project documents/Codex response.md` for next steps.
2. Read `Project documents/Project_Guide.md` as the canonical routing document.
3. Verified generated build artifacts and editor backup directories are absent.
4. Verified generated artifacts are not tracked by Git.
5. Consolidated duplicate historical implementation reports under `Project documents/Implementation Reports/`.
6. Removed obsolete duplicate report copies from `Project documents/` root.
7. Normalized the malformed `Architecture_v1.0_Frozen.md` filename.
8. Updated `Project_Guide.md` current status fields after Sprint 11B.
9. Executed the three Project Guide Verification Tests before Sprint 11C implementation.
10. Built and tested the project.

No application behaviour was changed.

## Files Created

None.

## Files Modified

- `Project documents/Project_Guide.md`
- `Project documents/Codex response.md`
- `LedgerForge.xcodeproj/project.pbxproj` through Xcode-managed documentation filename update

## Files Removed

Removed duplicate root-level historical reports after verifying byte-for-byte identical copies already existed under `Project documents/Implementation Reports/`:

- `Project documents/Database_Architecture_Update_Report.md`
- `Project documents/Sprint10_Phase2B_CodeAudit.md`
- `Project documents/Sprint10_Phase2B_Report.md`
- `Project documents/Sprint10_Phase2C_Plan.md`
- `Project documents/Sprint10_Phase2C_Report.md`

Removed generated local metadata:

- `Project documents/.DS_Store`

## Files Renamed

- `Project documents/Architecture_v1.0_Frozen.md⁠` -> `Project documents/Architecture_v1.0_Frozen.md`

## Build Result

Xcode build completed successfully.

Result: `The project built successfully.`

## Test Result

All active scheme tests passed.

Result: `12 tests: 12 passed, 0 failed, 0 skipped, 0 expected failures, 0 not run`

## Project Guide Verification Tests

### Test 1 - Task Routing

For Sprint 11C, `Project_Guide.md` routes the task through these categories:

- Import Framework
- Reader Implementation
- Parser Implementation
- Repository Changes
- Testing

Documents to read before Sprint 11C implementation:

- `Project documents/Project_Guide.md` - required first by Standard AI Workflow.
- `Project documents/Architecture_v1.0_Frozen.md` - required for Import Framework, Reader Implementation and Parser Implementation.
- `Project documents/ADR.md` - required for Import Framework, Reader Implementation and Parser Implementation.
- `Project documents/Engineering Standards.md` - required for Import Framework and Testing.
- `Project documents/Database_v1_Architecture.md` - required for Repository Changes.
- `Project documents/Codex response.md` - required for Repository Changes, Testing and Standard AI Workflow review.

Documents intentionally not read for Sprint 11C implementation unless the task expands:

- `Project documents/Product Vision.md` - routed for New Feature planning, not specifically for Import Framework, Reader Implementation, Parser Implementation, Repository Changes or Testing.
- `Project documents/AI_WORKFLOW.md` - Project_Guide.md is the canonical routing document and already contains the Standard AI Workflow.
- `.github/context.md` - routed for AI onboarding and context refresh, not Sprint 11C implementation.
- `.github/ai-instructions.md` - routed for AI onboarding, not Sprint 11C implementation.
- `.github/prompts.md` - routed for AI onboarding, not Sprint 11C implementation.
- Historical implementation reports - not listed by the Task Routing Guide for Sprint 11C.

### Test 2 - Sprint Boundary

Sprint 11C is allowed to work on the documented next milestone:

`Existing CSV Import -> ImportCoordinator -> Reader -> FinancialDocument -> Existing Parser -> Validation -> Repositories -> Stores`

Allowed scope from the documented next step:

- Preserve existing CSV import user-visible behaviour.
- Route existing CSV import through the unified import framework path.
- Use `ImportCoordinator` as orchestration.
- Keep validation before repository persistence.
- Keep repositories as the persistence boundary.
- Add regression coverage needed to preserve existing behaviour.

Sprint 11C must not change:

- User-visible import behaviour.
- PDF import support.
- XLS import support.
- XLSX import support.
- TXT import support.
- Dashboard behaviour.
- Financial calculations.
- Parser financial interpretation unless required only as an adapter with unchanged behaviour.
- Architecture rules in `Project_Guide.md`.

Relevant `Project_Guide.md` sections:

- `Task Routing Guide`
- `Sprint Scope Contract`
- `Standard AI Workflow`
- `Non-Negotiable Architecture Rules`

### Test 3 - Workflow Compliance

Assuming Sprint 11C is requested, the Standard AI Workflow output before coding is:

Documents to read:

- `Project documents/Project_Guide.md`
- `Project documents/Architecture_v1.0_Frozen.md`
- `Project documents/ADR.md`
- `Project documents/Engineering Standards.md`
- `Project documents/Database_v1_Architecture.md`
- `Project documents/Codex response.md`

Implementation plan:

1. Add CSV baseline regression tests around current observable import behaviour.
2. Add repository rollback contract tests if the Sprint 11C persistence path writes through repositories.
3. Introduce adapter code that lets existing CSV import pass through `ImportCoordinator` without changing UI behaviour.
4. Reuse existing CSV reader/parser/validator behaviour rather than replacing financial interpretation.
5. Persist only after validation succeeds.
6. Keep stores as runtime state owners.
7. Run build and full tests after each significant step.

Risks:

- Accidentally changing CSV import behaviour during migration.
- Duplicating logic between legacy `ImportEngine` and `ImportCoordinator`.
- Bypassing validation before repository writes.
- Introducing persistence writes before regression coverage is in place.
- Expanding into reader/parser support outside Sprint 11C.

Files likely to change:

- `Import/Coordinator/DefaultImportCoordinator.swift`
- `Import/Protocols/ReaderRegistry.swift`
- `Import/Models/*`
- `Services/Services/ImportEngine.swift`
- `Readers/CSVReader.swift` or a CSV adapter file if approved
- `LedgerForgeTests/ImportFrameworkTests.swift`
- `LedgerForgeTests/RepositoryContractTests.swift`
- New CSV regression test file if approved
- `Project documents/Codex response.md`

Stop condition:

Stop after Sprint 11C migration foundation is complete, existing CSV behaviour is preserved, build passes, tests pass, and no PDF/XLS/XLSX/TXT support has been added.

## Architecture Decisions

No application architecture changed during this housekeeping pass.

The documentation cleanup preserves the established architecture: `Project_Guide.md` remains the canonical routing document, historical sprint reports live under `Project documents/Implementation Reports/`, and `Architecture_v1.0_Frozen.md` now has a normalized filename.

## Documentation Updated

- Updated `Project documents/Project_Guide.md` current project snapshot, architecture status table and sprint roadmap.
- Updated `Project documents/Codex response.md` with this housekeeping report and Sprint 11C readiness verification.

## Remaining Technical Debt

- Sprint 11C has not been implemented.
- Existing CSV import still needs controlled migration into `ImportCoordinator`.
- CSV baseline regression tests still need implementation before or during Sprint 11C.
- Repository rollback contract tests remain recommended before Sprint 11C persistence integration.
- End-to-end import integration tests remain deferred until after CSV migration.

## Deferred Items

Deferred intentionally:

- Sprint 11C implementation.
- PDF reader.
- XLS reader.
- XLSX reader.
- TXT reader.
- Password provider implementation.
- Institution detection framework implementation.
- Parser migration beyond existing CSV behaviour preservation.
- UI changes.
- Dashboard changes.

## Next Recommended Sprint

Next recommended sprint: Sprint 11C.

Recommended first step: add CSV baseline regression tests before migrating existing CSV import through `ImportCoordinator`.
