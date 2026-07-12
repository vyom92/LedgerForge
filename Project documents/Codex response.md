# DTO Concurrency Isolation Report

## Root Cause

The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so repository DTO value types in `Database/DTOs.swift` inherited unintended main actor isolation for synthesized `Equatable` conformances. Repository tests compare these DTOs from nonisolated contexts, including `RepositorySnapshot` equality, producing Swift 6 migration warnings.

## Files Modified

- `Database/DTOs.swift`
- `Project documents/Codex response.md`
- `Project documents/PROJECT_STATE.md`

`Project documents/Implementation.md` was not modified.

## Isolation Correction

Applied explicit `nonisolated Equatable` conformances to:

- `WorkspaceDTO`
- `TransactionRawRowDTO`
- `TransactionDTO`
- `AccountDTO`
- `ImportSessionRecordDTO`

`TransactionRawRowDTO` was included because `TransactionDTO` stores `[TransactionRawRowDTO]`; the first build after correcting the four originally warned DTOs exposed the nested row DTO conformance warning through synthesized `TransactionDTO` equality.

## Equatable Behaviour

Synthesized `Equatable` is preserved for all corrected DTOs. No equality operators were hand-written, no fields were removed or reordered, and all initializers are unchanged.

## Sendable Decision

`Sendable` was not added. It is not required to remove the reported warnings, and adding it would broaden the maintenance change beyond the requested isolation correction.

## Repository and Runtime Integrity

No parser, validation, repository contract, persistence, schema, hydration, runtime-store or financial behaviour was changed. Repository DTO field structure and repository APIs are unchanged.

## Diagnostics

Xcode live diagnostics:

- `LedgerForge/Database/DTOs.swift`: 0 issues
- `LedgerForgeTests/RepositoryContractTests.swift`: 0 issues
- `LedgerForge/LedgerForgeTests/LedgerForgeTests.swift`: 0 issues
- `LedgerForge/LedgerForgeTests/RepositoryStoreHydratorTests.swift`: 0 issues
- `LedgerForge/LedgerForgeTests/ImportRepositoryIntegrationTests.swift`: 0 issues

## Build

Xcode `BuildProject` passed.

Build log:

`/var/folders/cx/mf26lvyn7bb4bt65f3fb334m0000gn/T/ActionArtifacts/BC89253F-B2D9-4379-A749-12AF62790A06/BuildProject/BuildProject-Log-20260712-130324.txt`

## Tests

Xcode-native `RunAllTests` passed using active test plan `TestPlan`.

- Total: 112
- Passed: 112
- Failed: 0
- Skipped: 0
- Expected failures: 0
- Not run: 0

Test summary:

`/var/folders/cx/mf26lvyn7bb4bt65f3fb334m0000gn/T/ActionArtifacts/BC89253F-B2D9-4379-A749-12AF62790A06/RunAllTests/B31877E5-43BD-41D2-BF5F-D03DAC988351.txt`

## Warning Verification

Final build and test logs were searched for:

- `Main actor-isolated conformance`
- `main actor-isolated conformance`
- `cannot be used in nonisolated context`
- `WorkspaceDTO`
- `AccountDTO`
- `ImportSessionRecordDTO`
- `TransactionDTO`
- `TransactionRawRowDTO`

No matches were found in the final build or test logs.

## Commit and Remote Verification

Implementation commit:

`481185a711a3a7366229e74081401c84c7acc6c6`

Commit message:

`Fix repository DTO concurrency isolation`

Remote implementation verification:

`481185a711a3a7366229e74081401c84c7acc6c6	refs/heads/main`

The push to `origin/main` completed successfully. The local tracking ref update was blocked by the sandbox because `.git/refs/remotes/origin/main.lock` could not be created, so `git ls-remote origin refs/heads/main` was used as the authoritative remote verification.

## Remaining Issues

None verified.

`git diff --check` passed.
