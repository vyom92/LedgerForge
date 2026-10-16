# Build and project conventions

Repository/Xcode conventions and local commands. Execution authority, one-writer/Git publication, test selection and report mechanics belong to the [Harness](LedgerForge_Standing_Execution_Harness_Guide.md); current accepted Swift/migration/product state belongs to [PROJECT_STATE](PROJECT_STATE.md). These commands do not authorize execution or database resets. Procedures inherit [Guide rule J](Project_Guide.md#documentation-order).

## Repository-First Implementation

Before adding a repository API:

1. inspect existing protocols;
2. inspect SQLite behavior;
3. inspect In-Memory behavior;
4. inspect DTO ownership;
5. inspect provider-level operations;
6. inspect hydration;
7. inspect tests;
8. identify why existing contracts cannot express the required operation.

A new repository API must have:

- one bounded responsibility;
- typed result;
- deterministic ordering;
- SQLite behavior;
- In-Memory behavior where parity applies;
- provider-generation behavior where relevant;
- failure semantics;
- tests;
- hydration impact.

Do not add a generic transaction closure merely to combine unrelated writes.

Do not coordinate cross-domain atomicity from a View, ViewModel or ordinary service.

---

## Xcode Project Baseline

Current project baseline:

```text
Project: LedgerForge.xcodeproj
Shared scheme: LedgerForge
Canonical test plan: TestPlan.xctestplan
Platform: macOS
Primary application target: LedgerForge
Primary test target: LedgerForgeTests
```

The owner-authorized test cleanup removed the disabled `LedgerForgeUITests`
target and its three uncustomized launch/screenshot templates. There is no
automated UI-test target. Native interaction acceptance remains separately
recorded; ordinary test results do not establish native UI behavior.

Never infer current scheme, target or test-plan behavior from memory.

Verify it from the exact repository.

---

## Xcode Project File Safety

When adding or moving files:

1. prefer filesystem-synchronized group behavior where the project already uses it;
2. prefer Xcode-safe project operations;
3. use supported project tooling where available;
4. edit `project.pbxproj` manually only when necessary and authorized;
5. keep the diff minimal;
6. verify target membership;
7. validate project integrity immediately.

Do not:

- reformat the whole project file;
- reorder unrelated objects;
- regenerate identifiers without need;
- change build settings outside scope;
- change target membership by assumption;
- add duplicate file references;
- add duplicate build phases;
- commit user-specific scheme state;
- commit breakpoint state;
- commit Finder or IDE residue.

Do not commit:

- `xcuserdata`;
- user breakpoints;
- Find Navigator state;
- personal scheme-management state;
- per-user workspace settings.

---

## Adding Source Files and Target Membership

Before adding a file:

- confirm it is required;
- choose the correct repository directory;
- verify naming;
- verify its header comment where used;
- verify target membership;
- verify build-phase membership;
- verify test-target membership for tests;
- verify no duplicate reference exists.

After adding:

```bash
xcodebuild -list -project LedgerForge.xcodeproj
```

Then run an appropriate build.

Typical intent:

| File family | Expected target |
|---|---|
| App source | LedgerForge |
| Runtime stores | LedgerForge |
| Services and coordinators | LedgerForge |
| Readers, parsers and detectors | LedgerForge |
| Unit and integration tests | LedgerForgeTests |
| Fixtures | Test resources or repository evidence according to current structure |

Always inspect actual membership.

A file existing on disk does not prove it is compiled.

---

## Project-Integrity Validation

A change to any of the following requires project-integrity validation:

- `project.pbxproj`;
- shared scheme;
- test plan;
- target membership;
- build setting;
- entitlement;
- asset catalog;
- resource phase;
- package dependency;
- signing configuration.

Minimum checks:

```bash
git diff --check
xcodebuild -list -project LedgerForge.xcodeproj
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

A project-file change is not documentation-only work.

---

## Local static Legacy XLS dependency

`Vendor/LegacyXLS` is the only approved legacy XLS reader dependency. It vendors
the required libxls 1.6.3 source files from `libxls/libxls` tag `v1.6.3` at
commit `c199d132494833da696b58aa4acf3fc5a36d930b` under the BSD 2-clause
license. The verbatim upstream `LICENSE` and the repository
`THIRD_PARTY_NOTICE.md` must remain present.

The checked-in local Swift package builds a static C target from only
`xlstool.c`, `endian.c`, `locale.c`, `ole.c`, `xls.c`, the required headers and
the narrow LedgerForge bridge. Its deterministic macOS configuration requires
no application-build-time Autotools step. The only external link boundary is
the macOS system `iconv` library. `xls.c` additionally rejects worksheet
dimensions above 10,000 rows, 256 columns or 1,000,000 cells before allocating
the cell table.

For a Release acceptance, inspect the application with `otool -L`, inspect the
bundle contents and confirm the bridge/libxls symbols are present in the app
executable. No libxls dynamic library, Homebrew libxls, Java, Python or
LibreOffice runtime may be copied into or required by the app. Changing the
libxls version, source set, safety patch, linkage or supported workbook boundary
requires an explicitly approved task and fresh Debug, Release and dependency
inspection evidence.

---

## Repository-owned command interface

The [script guide](../script/README.md) and executable [validate.sh](../script/validate.sh) / [build_and_run.sh](../script/build_and_run.sh) own exact flags and behavior. Xcode project `LedgerForge.xcodeproj`, shared scheme `LedgerForge`, destination `platform=macOS` and `TestPlan.xctestplan` remain truth. The current ordinary/integration split is recorded below and in the script guide. The macOS app Debug and Release configurations specify 1.2 (4); test, helper and iPhone target versions remain separate.

| Need | Existing command | Boundary |
| --- | --- | --- |
| Debug build | `./script/validate.sh build-debug` | Fresh signed Debug, task-owned artifacts |
| Release build | `./script/validate.sh build-release` | Fresh signed optimized Release |
| Focused tests | `./script/validate.sh test-focused LedgerForgeTests/PersistenceAvailabilityTests` | Real selectors; zero executed tests fails evidence |
| Complete canonical plan | `./script/validate.sh test-full` | Only for a recorded Harness/prompt trigger |
| Cycle close | `./script/validate.sh cycle-close` | Separate fresh Debug, Release and one complete TestPlan |
| Ordinary durable startup | `./script/validate.sh durable-startup` | Existing Current Database; verified SQLite/hydration, clean quit and same-database relaunch; no reset |
| Isolated schema experiment | `LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE=task-schema-experiment ./script/validate.sh schema-experiment LedgerForgeTests/MigrationIdentityLockTests` | Namespace preflight; task-owned targets only, no accepted migration edits |
| Safe isolated Run | `./script/build_and_run.sh --verify` | Verified single exact app process; DEBUG non-durable memory, not durable startup proof |
| Stop isolated Run | `./script/build_and_run.sh --stop` | Existing verified process/path safeguards; never stop another task without authorization |
| Command help | `./script/validate.sh --help`, `./script/build_and_run.sh --help` | Read exact current usage before nonstandard calls |

The Run helper defaults to `--verify`; it validates exact executable/bundle identity before graceful quit/TERM/KILL, requires zero instances before build/launch, and proves one exact newly built instance. It never uses partial-name process killing or global launch environment. Test-memory and debug-memory markers are compile-time inactive in Release. Ambiguous ownership or a live unrelated app is a stop condition; do not invoke a stop sequence merely to obtain a writer window.

The owner-selected Developer Mode controls compile into the app's Debug and Release configurations through `LEDGERFORGE_DEVELOPER_TOOLS`. The helper and subprocess targets do not receive this flag. It enables the existing profile/lifecycle/warning/acknowledgement controls without enabling Debug-only environment selectors or fault injection. Release Current Database keeps the adopted personal path and cannot be reset through profile controls; Debug Current and the separate development profiles keep their established identities. See the [4 October owner decision](SCOPE_DECISIONS.md#background-recovery-release-developer-tools-20261004) and [ADR-035](ADR.md#adr-035).

The [15 October testing decision](SCOPE_DECISIONS.md#testing-restrictions-retired-20261015) permits deterministic synthetic fixtures and ordinary local evidence files in isolated tests. Routine tests must not require the owner's statements, credentials, adopted ledger or live provider sessions. `TestPlan.xctestplan` owns the ordinary exclusions; retained original-backed, populated-ledger and live-provider checks run explicitly when their boundary is affected. Moving a test to integration is not a passing result and must be justified by its prerequisites, never by a failed assertion.

The accepted 16 October enumeration contains **978 definitions: 833 ordinary and 145 explicit integrations**, with 99 typed, disjoint exclusion selectors. Xcode navigator counts are not execution evidence. The current typed TestPlan and CLI identifier sets were independently matched; the ordinary run had 939 parameter-expanded passing executions.

The driver always builds for testing with the existing `.TestRun` bundle suffix, then executes the generated `.xctestrun`. It forwards canonical exclusions for `test-full`; for `test-focused`, it removes only generated skip lists and applies explicit selectors. Every requested selector must resolve to a passing executed definition. Zero/skip-only results fail. Timeouts, serial scheduling and existing metadata remain intact. Build time, test time, definitions and parameterized executions are distinct measures.

App-hosted tests do not reliably inherit arbitrary shell variables. An explicitly selected integration may use `LEDGERFORGE_TEST_ENVIRONMENT_FILE`, an external string dictionary merged into generated test environments. Keep credentials, private originals, real financial evidence, local databases, DerivedData and result bundles out of Git. The [script guide](../script/README.md) owns exact setup and current integration routes. Historical Sprint-94 counts and transport restrictions are superseded for current testing; their past results retain their original evidence boundaries.

A test-only selection/fixture change needs affected focused checks and one ordinary run because it changes global test infrastructure. It does not require a product deployment, live-ledger mutation, a new whole-corpus campaign or unrelated native UI repetition. Preserve required local results before cleaning only task-owned artifacts.

## Local installed upgrade and rollback

An owner-authorized local release uses a fresh native verified ledger backup and retains the complete previous installed app separately. Build the optimized signed Release with the app’s existing identity and entitlements, verify the full bundle inventory/signature, then replace only the application after a normal quit. Verify the installed version, Current database identity/integrity, account and transaction counts, applicable preferences, connection state and ordinary launch/relaunch. Classify normal background cache activity separately from protected financial records; never infer data preservation from an unchanged main SQLite file while WAL is active.

App rollback restores the retained application only after quitting its replacement. It must not automatically restore the older ledger backup. Financial-data restoration requires a separate explicit decision. Keep compact release receipts, backup and rollback outside temporary build output and outside Git. The [v1.2 outcome](Archive/Accepted%20outcomes/Unnumbered_2026-10.md#v12-ui-release) records the release-specific evidence and limits.

## Documentation and resource containment

Do not infer target membership from folder placement. Inspect PBX groups, synchronized roots, membership exceptions and resource phases. Keep published documentation/design/reference files and PNGs outside executable resources; add exact exceptions for actual descendants where needed, not an assumed recursive directory token. Inspect relevant untracked local files before a build as well as the intended committed set.

A bounded documentation membership change may alter only exact document references/exclusions/resource entries; preserve unrelated project WIP and avoid project reserialization. Verify plist/project parse, the smallest affected configuration build(s), emitted resource commands and final bundle contents. Do not claim committed-tree containment from a build that silently packaged unrelated local files. Do not alter signing, schemes, targets, build settings, deployment or product behavior to make a docs check pass.

## Repository source conventions

Search existing ownership before adding a parallel abstraction. Views render/interact; view models project accepted state; generic readers extract source evidence; family parsers interpret financial meaning; services coordinate without bypassing provider-owned persistence; repositories map durable values; canonical hydration publishes runtime stores. Use [Architecture](Architecture_v1.0_Frozen.md) and [Engineering Standards](Engineering%20Standards.md), not folder similarity, to decide ownership. Keep source/test target membership and script/path consumers explicit. Preserve local static Legacy XLS license/source provenance and Release containment requirements above.
