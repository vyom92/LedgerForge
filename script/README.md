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

`build-debug` and `build-release` run a fresh signed build in the named Xcode
configuration. `test-focused` requires one or more real Xcode test selectors
and translates each to `-only-testing:`. A focused result with zero executed
tests is failed evidence. `test-full` invokes the ordinary app regression plan selection in
the canonical `TestPlan`.
`cycle-close` uses separate fresh Debug, Release and test artifact roots, then
runs that same ordinary app regression plan selection after both builds pass.

The Sprint-94 owner decision separates 17 existing definitions from ordinary
regression: 13 corpus campaigns, their evidence-destination preflight, two tests
that copy statement files, and the separately authorized live-provider check.
Their definitions are retained. `TestPlan.xctestplan` owns the exclusion list;
`test-full` also forwards it as explicit `-skip-testing:` arguments because the
current Xcode runner does not consistently apply Swift Testing exclusions from
the plan alone. This applies to both direct testing and external-environment
testing. Use this driver for the ordinary run; an unfiltered Xcode run is not
the owner-approved selection. The earlier Sprint-94 ordinary app regression plan passed 554 definitions /
614 executions. Final owner corrections added 13 definitions; the renewed
ordinary app regression plan passed 567 definitions / 627 executions with zero
failures/skips. It is not complete authentic/source acceptance. The same 12
selectors cover 17 retained, separately gated definitions; no exclusions were
added by the corrections. No definition may be excluded because it fails.
Parameterized cases may produce more executions than definitions. The final
two-decimal-only Sprint-94 correction adds one focused definition and passed
1/1 plus Debug, optimized Release and native inspection. The owner explicitly
retains the preceding 567/627 ordinary result without a rerun; do not describe
it as an execution on the last display-only fingerprint.

App-hosted tests do not reliably inherit arbitrary variables exported only in
the invoking shell. When authentic tests require private paths, temporary
passwords or other external configuration, create a JSON dictionary outside
the repository whose keys and values are strings, then point the validation
command to it:

```bash
LEDGERFORGE_TEST_ENVIRONMENT_FILE=/absolute/external/test-environment.json \
  ./script/validate.sh test-focused 'LedgerForgeTests/SomeSuite/someTest()'
```

For `test-focused`, `test-full` and the test phase of `cycle-close`, this option
first builds the canonical project, scheme and test plan for testing. It then
merges the supplied dictionary into every generated test target's existing
`EnvironmentVariables` and runs that exact generated `.xctestrun` with
`test-without-building`. Existing Xcode variables and test-run metadata are
preserved. Without the option, validation retains its existing one-step
`xcodebuild test` behavior.

Treat the JSON file as restricted private credential material and store it only
in an approved task-owned location. Its values are copied into the task-owned
`.xctestrun`, so that artifact root is also private until it is recoverably
removed. Do not publish passwords, authentic-source paths, source oracles or the
environment file. Merely exporting the underlying variables in the shell is
not evidence that an app-hosted test received them.

The separately gated global authentic-corpus campaign is excluded from the
current ordinary selection. Its historical workflow below creates derived
financial evidence and is incompatible with the current in-memory-only source
processing rule; it must not run without a new explicit owner decision.
That historical gate requires `LEDGERFORGE_GLOBAL_AUTHENTIC_RESULT_FILE`
to name a writable test-host destination. Forwarding a path does not grant sandbox
write access: use a task-owned directory inside the app's container, then copy the
completed result to the external evidence archive after the run. A source-independent
atomic-write/readback/remove preflight runs before the corpus and can also be selected
alone as `LedgerForgeTests/GlobalAuthenticCorpusAcceptanceTests/configuredEvidenceDestinationSupportsAtomicWrites()`.
The final report write remains mandatory and any write failure fails the gate.

A missing required original, password or oracle in the approved selection is a
failed test environment, not a passing result or a reason to disable that test. The script
continues to require a readable nonzero test-result summary after execution.

### Post-94 affected-family checks

The six existing affected family suites support the current in-memory-only
source rule. They read the approved originals directly and retain source/oracle
comparisons only in memory. Their external environment dictionary needs paths,
not passwords: `LEDGERFORGE_PRIVATE_AMEX_ROOT`, `LEDGERFORGE_AXIS_BANK_ROOT`,
`LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT`, `LEDGERFORGE_CBQ_BANK_ROOT`,
`LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY` (the retained key now points to original
CBQ card PDFs), and `LEDGERFORGE_AXIS_CARD_PRIVATE_DIRECTORY`. Ordinary
original-backed tests use `LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY` as well.
Passwords come from the existing statement-password Keychain scopes. A missing
credential is an explicit test-environment failure; never put a password in a
checked-in command or source file. The older file-output global workflow above
remains separately gated and incompatible with the current source rule.

Use the existing focused selection, after authorizing the relevant authentic
campaign:

```bash
LEDGERFORGE_TEST_ENVIRONMENT_FILE=/absolute/external/paths-only.json \
  ./script/validate.sh test-focused \
  LedgerForgeTests/AmericanExpressPrivateAcceptanceTests \
  LedgerForgeTests/AxisBankAuthenticAcceptanceTests \
  LedgerForgeTests/HDFCBankAccountAuthenticAcceptanceTests \
  LedgerForgeTests/CBQBankAuthenticAcceptanceTests \
  LedgerForgeTests/CBQCreditCardPrivateAcceptanceTests \
  LedgerForgeTests/AxisCreditCardAuthenticAcceptanceTests
```

### Sprint-96 current-holdings qualification

`InvestmentSourceImportTests` and `InvestmentRAMOriginalTests` are separately
selected original-dependent suites (eight definitions), alongside the retained
pre-existing corpus exclusions. Select them explicitly with `test-focused`.
The local suite reads `LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY`. The RAM suite
requires `LEDGERFORGE_INVESTMENT_RAM_PIPE`, an owner-owned FIFO containing the
unchanged nominated originals and independent comparison fields. Passwords and
financial comparisons stay in memory; neither a statement substitute nor an
oracle file is a permitted setup step.

The complete Salary suite also accepts
`LEDGERFORGE_PRIVATE_SALARY_ORACLE_PIPE` with the real Salary originals root.
Its independent native-text/geometry comparison traverses the FIFO in memory;
the older file-backed oracle path remains historical and is not used under the
current source-processing rule.

For an explicitly selected real-process continuation, the populated investment
recovery test accepts `LEDGERFORGE_S96_RECOVERY_NAMESPACE` beginning with
`s93-recovery-s96-`. It requires a fresh isolated namespace and exports only an
ordinary app database plus its genuine format-1 backup for the existing DEBUG
restore/reopen probe. It never selects or replaces the owner's actual Current
database. The ordinary Dashboard/Transactions checks read Current's exact
registered schema prefix through read-only connections, without applying a
candidate migration.

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
database path, modify signing settings, enable the disabled UI-test target,
perform UI smoke automation, configure CI or change distribution, notarization
or deployment behavior.

### Sprint 97 live investment qualification

`InvestmentPriceQualificationTests` is a separately selected live-provider/original-ledger gate, outside the ordinary app plan. Its one definition uses the accepted closed isolated `input.ledgerforgebackup/ledger.sqlite` through `LEDGERFORGE_S97_QUALIFIED_LEDGER`; it never populates Current. Forward `LEDGERFORGE_S97_PYTHON` with the actual Python executable returned by `xcrun --find python3`, not the `/usr/bin/python3` developer shim (the shim invokes xcrun, which is unavailable inside the app sandbox). Full response and independent Decimal/Fraction expectations stay in RAM; only normal isolated databases/backups and minimal public quote cache are written. Existing source/corpus exclusions are unchanged; this adds one explicitly live qualification selector.

`ZurichISPQualificationTests` is a separate authenticated native gate. Set `LEDGERFORGE_S97_ZIO_QUALIFY=1` alongside those path variables; it reads the existing saved LedgerForge ISP credential from Keychain, performs one complete native account read, and replays original responses in RAM. It checks the independent source fields and reported-summary totals, direct/CSV provider parity, atomic persistence, stale/cancel/failure retention and V22 backup/reopen. It never creates or replaces credentials. This adds two gated definitions; ordinary TestPlan does not perform authenticated Zurich requests.
