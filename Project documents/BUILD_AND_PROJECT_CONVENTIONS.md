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
Generic UI-test target: LedgerForgeUITests
```

`LedgerForgeUITests` remains intentionally disabled unless an approved prompt changes that state.

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
| Generic UI tests | LedgerForgeUITests, only when explicitly enabled |
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

The [script guide](../script/README.md) and executable [validate.sh](../script/validate.sh) / [build_and_run.sh](../script/build_and_run.sh) own exact flags and behavior. Xcode project `LedgerForge.xcodeproj`, shared scheme `LedgerForge`, destination `platform=macOS` and `TestPlan.xctestplan` remain truth. Checked against those scripts during this documentation restructure; their behavior is unchanged.

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

App-hosted tests do not reliably inherit arbitrary shell variables. The existing `LEDGERFORGE_TEST_ENVIRONMENT_FILE` route builds for testing, merges string dictionary entries into each generated `.xctestrun` target while preserving metadata, then runs `test-without-building`. That route writes artifacts and is **not certified against the owner's newer prohibition on derived financial evidence files**. The [source-processing decision](SCOPE_DECISIONS.md#source-processing-decision) takes precedence: inspect/configure a compliant in-memory boundary before future financial runs, or stop. No script behavior changes are authorized by this document.

Test selectors must discover nonzero tests, preserve TestPlan timeouts and serial test-target scheduling, and use existing result inspection; never skip absent authentic evidence to get green. Required results must not expose private financial content or violate the current disk-artifact rule. Keep ordinary build/test artifacts outside the repository; preserve required permitted evidence before cleanup and remove only task-owned paths. Never commit DerivedData, result bundles, local databases/sidecars, credentials or Xcode user state.

## Documentation and resource containment

Do not infer target membership from folder placement. Inspect PBX groups, synchronized roots, membership exceptions and resource phases. Keep published documentation/design/reference files and PNGs outside executable resources; add exact exceptions for actual descendants where needed, not an assumed recursive directory token. Inspect relevant untracked local files before a build as well as the intended committed set.

A bounded documentation membership change may alter only exact document references/exclusions/resource entries; preserve unrelated project WIP and avoid project reserialization. Verify plist/project parse, the smallest affected configuration build(s), emitted resource commands and final bundle contents. Do not claim committed-tree containment from a build that silently packaged unrelated local files. Do not alter signing, schemes, targets, build settings, deployment or product behavior to make a docs check pass.

## Repository source conventions

Search existing ownership before adding a parallel abstraction. Views render/interact; view models project accepted state; generic readers extract source evidence; family parsers interpret financial meaning; services coordinate without bypassing provider-owned persistence; repositories map durable values; canonical hydration publishes runtime stores. Use [Architecture](Architecture_v1.0_Frozen.md) and [Engineering Standards](Engineering%20Standards.md), not folder similarity, to decide ownership. Keep source/test target membership and script/path consumers explicit. Preserve local static Legacy XLS license/source provenance and Release containment requirements above.
