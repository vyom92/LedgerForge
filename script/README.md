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
tests is failed evidence. `test-full` invokes the complete canonical `TestPlan`.
`cycle-close` uses separate fresh Debug, Release and test artifact roots, then
runs one complete `TestPlan` after both builds pass.

Each command resolves the repository root from its own location and uses only
`LedgerForge.xcodeproj`, scheme `LedgerForge`, destination `platform=macOS` and
test plan `TestPlan`. A nonzero `xcodebuild` status is returned unchanged.

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
