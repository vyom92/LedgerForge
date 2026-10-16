# LedgerForge local validation and isolated Run commands

The Xcode project, shared `LedgerForge` scheme and `TestPlan.xctestplan` remain
the build and test truth. These scripts provide the preferred reproducible
local interface; their `xcodebuild` arguments intentionally name that truth
directly.

## Validation commands

```bash
./script/validate.sh build-debug
./script/validate.sh build-release
./script/validate.sh test-focused LedgerForgeTests/PersistenceAvailabilityTests
./script/validate.sh test-full
./script/validate.sh cycle-close
./script/validate.sh --help
```

`build-debug` and `build-release` run signed builds in the named Xcode
configuration. `test-focused` requires one or more real Xcode selectors;
`test-full` runs the complete ordinary selection in `TestPlan.xctestplan`.
`cycle-close` uses separate fresh Debug, Release and test artifact roots, then
runs that same ordinary selection after both builds pass. Use a fresh artifact
root for fresh-build evidence; explicitly reusing a task-owned root permits
incremental builds and must be reported as such.

### Ordinary tests and explicit integrations

The owner retired the historical authentic-only fixture, FIFO-only transport
and cumulative whole-corpus testing restrictions on 15 October 2026. See the
[current decision](../Project%20documents/SCOPE_DECISIONS.md#testing-restrictions-retired-20261015).
Ordinary tests use deterministic fixtures, temporary databases and isolated
Keychain test items. They require no owner statements, statement passwords,
existing personal ledger or live provider session. Tests use the existing
`.TestRun` bundle suffix and disable automatic background/public-reference
network work. They never install or replace the production app.

The accepted 16 October compiled inventory is **978 definitions: 833 ordinary and 145 retained integrations**. The ordinary run passed 939 parameter-expanded executions with zero failures/skips; the historical Xcode navigator count is not a substitute for compiled enumeration. The 60-definition cleanup preserved unique assertions, and UI-template removal predates that cleanup baseline.

`TestPlan.xctestplan` is the single ordinary-selection authority. Its exclusions
identify retained original/corpus, populated-ledger and live-provider integration
checks. Exclusions are classified by prerequisites, not by failed assertions.
`test-full` forwards that same list as explicit `-skip-testing:` arguments because
this Xcode version does not consistently apply Swift Testing plan exclusions.
The unused UI-test target and its three launch/screenshot templates were removed
under the owner's instruction. Ordinary results do not certify unexecuted
integration conditions or native UI behavior; existing native interaction
acceptance remains separate.

`test-focused` explicitly selects the requested suite or method, including an
integration excluded from ordinary selection. Both commands build the canonical
project/scheme/plan for testing, preserve generated metadata, then execute that
`.xctestrun`. For focused runs only, the generated skip lists are removed before
applying `-only-testing:`; the canonical plan itself is not rewritten. Timeouts
and serial target scheduling remain in force. Every requested selector must
resolve to at least one passing executed definition in the result tree. A zero,
skip-only or unresolved-selector result fails the command, even if Xcode exits
successfully. A suite selector does not promise a fixture for its integration
methods: use exact method selectors when you need only its ordinary checks.

The small CSV mechanics fixture traverses the actual reader, classifier, parser,
validator and mapper. Each preparation owns its engine and snapshot. Its fixed
invented values exercise repository/snapshot/lifecycle mechanics; they do not
claim institution-source coverage. The nonfinancial BIFF8 fixture exercises real
libxls open/copy/lifetime/cancellation. The genuine three-carrier CSV/PDF/XLS
mapper comparison and independent source oracles remain explicit integrations.

### Running an explicitly selected integration

App-hosted tests do not reliably inherit arbitrary shell variables. Supply the
specific integration's existing prerequisites in an external JSON dictionary
with string keys/values, then run its exact selector:

```bash
LEDGERFORGE_TEST_ENVIRONMENT_FILE=/absolute/external/test-environment.json \
  ./script/validate.sh test-focused \
  'LedgerForgeTests/ImportPersistenceFormatAuthorityMapperTests/authenticCarriersKeepExactFormatAndFingerprintAuthority()'
```

The driver merges that dictionary into each generated test target's environment.
Missing prerequisites fail the integration; they are never counted as a pass.
The environment and generated `.xctestrun` can contain private paths/credentials,
so keep them outside Git. Legitimate local evidence files are permitted.
`AuthenticSourceTestSupport.presentationDatabaseURL()` requires an explicit
`LEDGERFORGE_PRESENTATION_DATABASE` nomination; it no longer silently falls back
to the adopted Current database. Its readers remain read-only.

Retained family integrations use their existing keys, including
`LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY`, `LEDGERFORGE_AXIS_BANK_ROOT`,
`LEDGERFORGE_PRIVATE_AMEX_ROOT`, `LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT`,
`LEDGERFORGE_CBQ_BANK_ROOT`, `LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY` (original
PDFs), and `LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY`. Statement credentials use
the existing Keychain scopes or explicitly forwarded test configuration.
Check the selected test's helper for its exact inputs; do not run every private
campaign for an unrelated change.

Some historical integration implementations still accept named FIFO/oracle
transports (`LEDGERFORGE_INVESTMENT_RAM_PIPE`,
`LEDGERFORGE_PRIVATE_SALARY_ORACLE_PIPE`) and a selected real-process recovery
namespace. Those are implementation-specific routes, not a ban on ordinary test
files. The shared RAM-nomination helper now accepts a regular JSON file or FIFO.
The retained global-corpus test still requires its result destination and runs
its atomic-write/readback/remove preflight internally before the corpus. Its
redundant standalone preflight test was removed. Use a writable destination in
the isolated test host's container; forwarding a path does not grant sandbox
access. Do not use a test namespace to replace or migrate the adopted ledger.

LegacyXLS's source-independent integer/buffer check constructs no workbook or
financial row. It covers fixed-width sector identifiers, sentinel/range paths,
allocation overflow and transcoding errors/growth. Run it with both sanitizers
and the original narrowing-warning category treated as an error:

```bash
xcrun clang -std=c11 -g -fsanitize=address,undefined \
  -Wshorten-64-to-32 -Werror=shorten-64-to-32 \
  -I Vendor/LegacyXLS/Sources/CLegacyXLS \
  -I Vendor/LegacyXLS/Sources/CLegacyXLS/include \
  Vendor/LegacyXLS/Tests/IntegerBufferMechanics.c \
  Vendor/LegacyXLS/Sources/CLegacyXLS/src/xls.c \
  Vendor/LegacyXLS/Sources/CLegacyXLS/src/endian.c \
  Vendor/LegacyXLS/Sources/CLegacyXLS/src/locale.c \
  -liconv -o "$TMPDIR/LedgerForge-integer-buffer-check"
"$TMPDIR/LedgerForge-integer-buffer-check"
```

This mechanics result does not replace complete genuine XLS-family comparison
or fresh Debug/Release compilation. Isolated validation builds also do not
refresh diagnostics shown by an older ordinary Xcode build; build the open
project and verify its unfiltered Issue Navigator separately when that is the
reported problem. Do not hide or suppress diagnostics to make it look clean.

The test plan keeps timeouts enabled and permits a maximum allowance of 1,200
seconds. The complete six-order authentic-corpus test explicitly requests a
20-minute limit because its ordinary import/replay/reopen campaign exceeds the
default 600-second allowance. Other tests retain the default allowance; no
corpus source or assertion is skipped to shorten the campaign.

The LedgerForgeTests target explicitly disables runner-level parallelization in
the test plan. The complete corpus gate and other runtime-state tests share an
in-process isolation gate; scheduling them concurrently would spend their
600-second execution allowance waiting for the long corpus test. Serial runner
scheduling starts each budget with its own test, while concurrency deliberately
created inside a test remains exercised. Generated native test metadata must
retain `InProcessParallelizationEnabled=false` and the unchanged timeout limits.

Each command resolves the repository root from its own location and uses only
`LedgerForge.xcodeproj`, scheme `LedgerForge`, destination `platform=macOS` and
test plan `TestPlan`. A nonzero `xcodebuild` status is returned unchanged.

## Durable startup and schema experiments

`./script/validate.sh durable-startup` builds the ordinary Xcode Debug product using the workspace’s usual DerivedData location, resolves its exact bundle from Xcode build settings, and runs two complete startup/quit cycles. It requires an already-existing Current Database and rejects test-memory, debug-memory and namespace environment markers before launch. The helper requires a structured signal emitted only after verified SQLite and complete canonical publication, verifies actual product and database identities, and compares migration records and the database hash across relaunch. Missing hydration evidence, unknown build provenance, a live pre-existing app, or a memory provider fails the gate. This command never resets or removes a database. Quit LedgerForge before running it.

The probe environment flag observes startup only; it cannot select a provider. Evidence logs and the JSON result stay in the task-owned artifact directory. Build identity is generated into the signed product by an Xcode build phase, including direct Xcode Run builds. It reports build-time commit, clean/dirty status, configuration and UTC timestamp; runtime never queries Git. A dirty commit label does not uniquely identify uncommitted bytes, so executable and debug-dylib hashes are retained by durable acceptance.

For deliberately requested schema experiments, use:

```bash
LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE=task-schema-experiment \
  ./script/validate.sh schema-experiment LedgerForgeTests/MigrationIdentityLockTests
```

The namespace preflight fails before building when the namespace is missing or invalid. Selected tests must still use task-owned database paths; the namespace does not authorize deleting Current or Persistent Debug Database. No experiment edits accepted migration history or refreshes the literal baseline lock. Adopted-data upgrades require authentic upgrade-copy acceptance. The explicitly authorized disposable Current Database recreation on 2026-09-09 is not a reusable repair policy.

## Isolated Run commands

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --stop
./script/build_and_run.sh --help
```

The default command and `--verify` have the same deterministic sequence:

1. find every exact-name `LedgerForge` process with `pgrep -x`;
2. accept a process only when its resolved executable is exactly inside
   `LedgerForge.app/Contents/MacOS/LedgerForge` and its bundle identifier is
   `com.vyom.LedgerForge`;
3. request a graceful quit, then use TERM and KILL only for still-verified PIDs;
4. prove a zero-instance precondition;
5. build Debug through `validate.sh`, resolve the bundle through Xcode build
   settings, verify its bundle metadata and code signature, then launch it;
6. pass `LEDGERFORGE_RUN_HOST=1` only to that launched process and prove one
   exact-name PID resolves to the freshly built executable.

`--stop` performs only the verified termination sequence and the zero-instance
proof. It does not build or launch. If any exact-name process has an ambiguous
path, bundle shape or bundle identifier, the script stops before sending a
signal. It never uses partial-name matching, `killall`, `pkill`,
`launchctl setenv` or a caller-provided SQLite path.

## Debug, Release and persistence boundary

An ordinary unmarked Debug launch keeps the existing persistence bootstrap.
`LEDGERFORGE_TEST_HOST=1` remains reserved for app-hosted tests and selects
intentional test memory. The repository-owned Run script passes only
`LEDGERFORGE_RUN_HOST=1`; in a Debug build that selects intentional non-durable
Debug memory before any default SQLite bootstrap. Both markers are compile-time
inactive in Release.

The app target defines `LEDGERFORGE_DEVELOPER_TOOLS` in Debug and Release for
the owner-selected Developer Mode controls. That flag does not enable Debug
test-host/run-host selectors or fault injection. Release Current Database
continues to use the adopted personal `ledgerforge.sqlite`; the development
profiles use their separate lifecycle-owned identities. Current remains
ineligible for profile reset. The helper does not receive this flag.

The script inspects the local `/usr/bin/open` contract for process-local
`--env` support before launch. It does not mutate the global launch environment.

## Artifacts, cleanup and failures

Build, test, Xcode build-setting, signing and launch-contract artifacts live in
a unique task-owned `TMPDIR/LedgerForge-*` directory. `validate.sh` prints its
artifact root, isolated DerivedData location and test result-bundle path for
every build or test operation. Test `.xcresult` bundles stay there for review
and are never written into the repository.

The scripts do not remove caller-supplied paths. A failed launch may terminate
only a PID whose resolved executable equals the freshly built executable. The
caller is responsible for recoverably removing completed task-owned artifact
roots after preserving any required evidence.

Useful failure classes are: `2` for command usage, `64` for an unsafe process or
artifact boundary, `65` for build, signing, bundle or launch verification,
`69` for a missing process-local launch environment contract, and `70` for a
local inspection or artifact-creation failure. Other `xcodebuild` failures are
returned unchanged.

## Explicit exclusions

These scripts do not create an alternate Xcode configuration, choose a custom
database path, modify signing settings, add test targets,
perform UI smoke automation, configure CI or change distribution, notarization
or deployment behavior.

### Sprint 97 live investment qualification

`InvestmentPriceQualificationTests` is a separately selected live-provider/original-ledger gate, outside the ordinary app plan. Its one definition uses the accepted closed isolated `input.ledgerforgebackup/ledger.sqlite` through `LEDGERFORGE_S97_QUALIFIED_LEDGER`; it never populates Current. Forward `LEDGERFORGE_S97_PYTHON` with the actual Python executable returned by `xcrun --find python3`, not the `/usr/bin/python3` developer shim (the shim invokes xcrun, which is unavailable inside the app sandbox). Full response and independent Decimal/Fraction expectations stay in RAM; only normal isolated databases/backups and minimal public quote cache are written. Existing source/corpus exclusions are unchanged; this adds one explicitly live qualification selector.

`ZurichISPQualificationTests` is a separate authenticated native gate. Set `LEDGERFORGE_S97_ZIO_QUALIFY=1` alongside those path variables; it reads the existing saved LedgerForge ISP credential from Keychain, performs one complete native account read, and replays original responses in RAM. It checks the independent source fields and reported-summary totals, direct/CSV provider parity, atomic persistence, stale/cancel/failure retention and V22 backup/reopen. It never creates or replaces credentials. This adds two gated definitions; ordinary TestPlan does not perform authenticated Zurich requests.

## Owner-authorized local releases

The app target’s Debug and Release metadata currently specifies **1.2 (4)**.
`build-release` creates the optimized signed candidate but does not install it.
The release executor must verify the fresh native backup, retain the prior app,
check signature/entitlements and complete bundle identity, then install only the
qualified artifact after normal quit. Ordinary installed launch/relaunch and
Current-ledger preservation are separate checks. Do not use `build_and_run.sh`
as a production installer; its Debug memory-host behavior is deliberate.

Only delete inventoried task-owned temporary output after retaining required
results, source/build receipts and native evidence. Preserve the native backup
and app-only rollback separately. See the [build/rollback contract](../Project%20documents/BUILD_AND_PROJECT_CONVENTIONS.md#local-installed-upgrade-and-rollback)
and [v1.2 outcome](../Project%20documents/Archive/Accepted%20outcomes/Unnumbered_2026-10.md#v12-ui-release).
