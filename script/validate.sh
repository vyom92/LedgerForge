#!/usr/bin/env bash
set -uo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly PROJECT_PATH="$ROOT_DIR/LedgerForge.xcodeproj"
readonly SCHEME="LedgerForge"
readonly DESTINATION="platform=macOS"
readonly TEST_PLAN="TestPlan"

ARTIFACT_ROOT=""
DERIVED_DATA=""
RESULT_BUNDLE=""

usage() {
    cat <<'USAGE'
Usage:
  ./script/validate.sh build-debug
  ./script/validate.sh build-release
  ./script/validate.sh test-focused <selector> [selector...]
  ./script/validate.sh test-full
  ./script/validate.sh cycle-close
  ./script/validate.sh --help

Each build and test command uses an isolated task-owned DerivedData directory.
USAGE
}

fail() {
    local message="$1"
    local status="${2:-2}"
    printf 'validate.sh: %s\n' "$message" >&2
    exit "$status"
}

canonical_path() {
    /bin/realpath "$1"
}

temporary_base() {
    local base="${TMPDIR:-/tmp}"
    canonical_path "$base"
}

prepare_artifact_root() {
    local requested_root="${LEDGERFORGE_ARTIFACT_ROOT:-}"
    local temp_base

    temp_base="$(temporary_base)" || fail "unable to resolve the temporary-directory root" 70

    if [[ -n "$requested_root" ]]; then
        case "$requested_root" in
            "$temp_base"/LedgerForge-*) ;;
            *) fail "LEDGERFORGE_ARTIFACT_ROOT must be a task-owned path below $temp_base/LedgerForge-*" 64 ;;
        esac
        /bin/mkdir -p "$requested_root" || fail "unable to create task-owned artifact root" 70
        ARTIFACT_ROOT="$(canonical_path "$requested_root")" || fail "unable to resolve task-owned artifact root" 70
    else
        ARTIFACT_ROOT="$(/usr/bin/mktemp -d "$temp_base/LedgerForge-validation.XXXXXX")" || fail "unable to create task-owned artifact root" 70
        ARTIFACT_ROOT="$(canonical_path "$ARTIFACT_ROOT")" || fail "unable to resolve task-owned artifact root" 70
    fi

    case "$ARTIFACT_ROOT" in
        "$temp_base"/LedgerForge-*) ;;
        *) fail "artifact root escaped the task-owned temporary directory" 64 ;;
    esac

    DERIVED_DATA="$ARTIFACT_ROOT/DerivedData"
    RESULT_BUNDLE="$ARTIFACT_ROOT/TestResults.xcresult"
}

prepare_child_artifacts() {
    local child="$1"
    local parent="$ARTIFACT_ROOT"

    ARTIFACT_ROOT="$parent/$child"
    /bin/mkdir -p "$ARTIFACT_ROOT" || fail "unable to create cycle-close artifact root" 70
    ARTIFACT_ROOT="$(canonical_path "$ARTIFACT_ROOT")" || fail "unable to resolve cycle-close artifact root" 70
    DERIVED_DATA="$ARTIFACT_ROOT/DerivedData"
    RESULT_BUNDLE="$ARTIFACT_ROOT/TestResults.xcresult"
}

print_context() {
    local operation="$1"
    printf 'Operation: %s\n' "$operation"
    printf 'Artifact root: %s\n' "$ARTIFACT_ROOT"
    printf 'DerivedData: %s\n' "$DERIVED_DATA"
    printf 'Result bundle: %s\n' "$RESULT_BUNDLE"
}

run_xcodebuild() {
    local operation="$1"
    shift

    print_context "$operation"
    /usr/bin/xcodebuild "$@"
    local status=$?
    if [[ "$status" -ne 0 ]]; then
        printf 'validate.sh: %s failed with xcodebuild status %s\n' "$operation" "$status" >&2
    fi
    return "$status"
}

run_build() {
    local configuration="$1"
    local operation="$2"

    run_xcodebuild "$operation" \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$configuration" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        build
}

verify_result_contains_tests() {
    local operation="$1"
    local summary
    local test_count

    summary="$(/usr/bin/xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" --compact)" || {
        printf 'validate.sh: %s completed without a readable test result summary\n' "$operation" >&2
        return 65
    }
    test_count="$(printf '%s' "$summary" | /usr/bin/sed -n 's/.*"totalTestCount"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    if [[ ! "$test_count" =~ ^[0-9]+$ || "$test_count" -eq 0 ]]; then
        printf 'validate.sh: %s produced zero executed tests\n' "$operation" >&2
        return 65
    fi
    printf 'Recorded executed tests: %s\n' "$test_count"
}

run_focused_test() {
    local -a only_testing_arguments=()
    local selector
    local status

    for selector in "$@"; do
        [[ -n "$selector" ]] || fail "test selectors must not be empty" 2
        only_testing_arguments+=("-only-testing:$selector")
    done

    run_xcodebuild "test-focused" \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULT_BUNDLE" \
        -testPlan "$TEST_PLAN" \
        "${only_testing_arguments[@]}" \
        test
    status=$?
    [[ "$status" -eq 0 ]] || return "$status"
    verify_result_contains_tests "test-focused"
}

run_full_test() {
    local status

    run_xcodebuild "test-full" \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULT_BUNDLE" \
        -testPlan "$TEST_PLAN" \
        test
    status=$?
    [[ "$status" -eq 0 ]] || return "$status"
    verify_result_contains_tests "test-full"
}

run_cycle_close() {
    prepare_child_artifacts "build-debug"
    run_build "Debug" "cycle-close build-debug" || return $?

    ARTIFACT_ROOT="$(dirname "$ARTIFACT_ROOT")"
    prepare_child_artifacts "build-release"
    run_build "Release" "cycle-close build-release" || return $?

    ARTIFACT_ROOT="$(dirname "$ARTIFACT_ROOT")"
    prepare_child_artifacts "test-full"
    run_full_test
}

command_name="${1:-}"
case "$command_name" in
    --help)
        [[ "$#" -eq 1 ]] || fail "--help does not accept additional arguments"
        usage
        ;;
    build-debug)
        [[ "$#" -eq 1 ]] || fail "build-debug does not accept additional arguments"
        prepare_artifact_root
        run_build "Debug" "build-debug"
        exit $?
        ;;
    build-release)
        [[ "$#" -eq 1 ]] || fail "build-release does not accept additional arguments"
        prepare_artifact_root
        run_build "Release" "build-release"
        exit $?
        ;;
    test-focused)
        [[ "$#" -ge 2 ]] || fail "test-focused requires at least one selector"
        prepare_artifact_root
        shift
        run_focused_test "$@"
        exit $?
        ;;
    test-full)
        [[ "$#" -eq 1 ]] || fail "test-full does not accept additional arguments"
        prepare_artifact_root
        run_full_test
        exit $?
        ;;
    cycle-close)
        [[ "$#" -eq 1 ]] || fail "cycle-close does not accept additional arguments"
        prepare_artifact_root
        run_cycle_close
        exit $?
        ;;
    *)
        usage >&2
        fail "expected one supported command" 2
        ;;
esac
