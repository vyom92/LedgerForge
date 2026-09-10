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
TEST_ENVIRONMENT_FILE=""
XCTESTRUN_PATH=""

usage() {
    cat <<'USAGE'
Usage:
  ./script/validate.sh build-debug
  ./script/validate.sh build-release
  ./script/validate.sh test-focused <selector> [selector...]
  ./script/validate.sh test-full
  ./script/validate.sh cycle-close
  ./script/validate.sh durable-startup
  ./script/validate.sh schema-experiment <selector> [selector...]
  ./script/validate.sh --help

Build/test commands use isolated task-owned DerivedData, except durable-startup,
which refreshes and qualifies the ordinary Xcode Run product.
Set LEDGERFORGE_TEST_ENVIRONMENT_FILE to an external JSON dictionary when
app-hosted tests require explicitly forwarded environment variables.
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

prepare_test_environment_file() {
    local configured_file="${LEDGERFORGE_TEST_ENVIRONMENT_FILE:-}"
    local resolved_file

    TEST_ENVIRONMENT_FILE=""
    [[ -n "$configured_file" ]] || return 0
    [[ -f "$configured_file" && -r "$configured_file" ]] || fail "LEDGERFORGE_TEST_ENVIRONMENT_FILE must name a readable regular file" 64

    resolved_file="$(canonical_path "$configured_file")" || fail "unable to resolve LEDGERFORGE_TEST_ENVIRONMENT_FILE" 70
    case "$resolved_file" in
        "$ROOT_DIR"|"$ROOT_DIR"/*) fail "LEDGERFORGE_TEST_ENVIRONMENT_FILE must use an approved task-owned path" 64 ;;
    esac

    /usr/bin/jq -s -e '
        length == 1
        and (.[0] | type == "object")
        and (.[0] | all(to_entries[]; (.key | length) > 0 and (.value | type) == "string"))
    ' "$resolved_file" >/dev/null || fail "LEDGERFORGE_TEST_ENVIRONMENT_FILE must contain one JSON dictionary with nonempty keys and string values" 64

    TEST_ENVIRONMENT_FILE="$resolved_file"
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

derive_generated_xctestrun() {
    local products_directory="$DERIVED_DATA/Build/Products"
    local generated_file
    local -a generated_files=()

    [[ -d "$products_directory" ]] || fail "build-for-testing did not create a Build/Products directory" 65
    while IFS= read -r generated_file; do
        generated_files+=("$generated_file")
    done < <(/usr/bin/find "$products_directory" -maxdepth 1 -type f -name '*.xctestrun' -print | /usr/bin/sort)

    [[ "${#generated_files[@]}" -eq 1 ]] || fail "build-for-testing must produce exactly one generated xctestrun file" 65
    XCTESTRUN_PATH="${generated_files[0]}"
}

merge_test_environment_into_xctestrun() {
    local configured_xctestrun

    [[ -n "$TEST_ENVIRONMENT_FILE" ]] || fail "internal test-environment forwarding state is missing" 70
    [[ -f "$XCTESTRUN_PATH" ]] || fail "generated xctestrun file is missing" 65
    configured_xctestrun="$(/usr/bin/mktemp "$ARTIFACT_ROOT/.configured-xctestrun.XXXXXX")" || fail "unable to create a private configured xctestrun" 70

    if ! /usr/bin/plutil -convert json -o - "$XCTESTRUN_PATH" \
        | /usr/bin/jq --slurpfile supplied_environment "$TEST_ENVIRONMENT_FILE" '
            if (.TestConfigurations | type) != "array" then
                error("generated xctestrun has no TestConfigurations array")
            elif ([.TestConfigurations[].TestTargets | type] | all(. == "array") | not) then
                error("generated xctestrun has an invalid TestTargets value")
            elif ([.TestConfigurations[].TestTargets[]] | length) == 0 then
                error("generated xctestrun has no test targets")
            else
                .TestConfigurations |= map(
                    .TestTargets |= map(
                        if ((.EnvironmentVariables // {}) | type) != "object" then
                            error("generated test target has invalid EnvironmentVariables")
                        else
                            .EnvironmentVariables = ((.EnvironmentVariables // {}) + $supplied_environment[0])
                        end
                    )
                )
            end
        ' \
        | /usr/bin/plutil -convert xml1 -o "$configured_xctestrun" -; then
        [[ ! -e "$configured_xctestrun" ]] || /bin/rm "$configured_xctestrun"
        fail "unable to merge the external test environment into the generated xctestrun" 65
    fi

    /usr/bin/plutil -lint "$configured_xctestrun" >/dev/null || {
        /bin/rm "$configured_xctestrun"
        fail "configured xctestrun is not a valid property list" 65
    }
    /usr/bin/plutil -convert json -o - "$configured_xctestrun" \
        | /usr/bin/jq --slurpfile supplied_environment "$TEST_ENVIRONMENT_FILE" -e '
            [
                .TestConfigurations[].TestTargets[].EnvironmentVariables as $actual
                | ($supplied_environment[0] | to_entries | all(.[]; $actual[.key] == .value))
            ] as $matches
            | ($matches | length) > 0 and ($matches | all(.[]; . == true))
        ' >/dev/null || {
            /bin/rm "$configured_xctestrun"
            fail "configured xctestrun did not retain the supplied test environment" 65
        }

    /bin/mv "$configured_xctestrun" "$XCTESTRUN_PATH" || fail "unable to install the configured xctestrun" 70
}

run_test_with_external_environment() {
    local operation="$1"
    shift
    local status

    run_xcodebuild "$operation build-for-testing" \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -testPlan "$TEST_PLAN" \
        build-for-testing
    status=$?
    [[ "$status" -eq 0 ]] || return "$status"

    derive_generated_xctestrun
    merge_test_environment_into_xctestrun

    run_xcodebuild "$operation" \
        -xctestrun "$XCTESTRUN_PATH" \
        -destination "$DESTINATION" \
        -resultBundlePath "$RESULT_BUNDLE" \
        "$@" \
        test-without-building
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

    if [[ -n "$TEST_ENVIRONMENT_FILE" ]]; then
        run_test_with_external_environment "test-focused" "${only_testing_arguments[@]}"
    else
        run_xcodebuild "test-focused" \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME" \
            -destination "$DESTINATION" \
            -derivedDataPath "$DERIVED_DATA" \
            -resultBundlePath "$RESULT_BUNDLE" \
            -testPlan "$TEST_PLAN" \
            "${only_testing_arguments[@]}" \
            test
    fi
    status=$?
    [[ "$status" -eq 0 ]] || return "$status"
    verify_result_contains_tests "test-focused"
}

run_full_test() {
    local status

    if [[ -n "$TEST_ENVIRONMENT_FILE" ]]; then
        run_test_with_external_environment "test-full"
    else
        run_xcodebuild "test-full" \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME" \
            -destination "$DESTINATION" \
            -derivedDataPath "$DERIVED_DATA" \
            -resultBundlePath "$RESULT_BUNDLE" \
            -testPlan "$TEST_PLAN" \
            test
    fi
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


validate_schema_namespace() {
    local namespace="${LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE:-}"
    [[ -n "$namespace" && "${#namespace}" -le 48 && "$namespace" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "schema-experiment requires a valid isolated LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE; ordinary Current Database is forbidden" 64
}

run_durable_startup() {
    [[ -z "${LEDGERFORGE_TEST_HOST+x}" && -z "${LEDGERFORGE_RUN_HOST+x}" && -z "${LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE+x}" ]] || fail "durable-startup rejects memory/test/namespace markers" 64
    # Deliberately build the workspace's ordinary Xcode Run product.
    run_xcodebuild "ordinary Xcode Debug product" -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration Debug -destination "$DESTINATION" build || return $?
    local settings="$ARTIFACT_ROOT/build-settings.json"
    /usr/bin/xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration Debug -showBuildSettings -json > "$settings" || return $?
    local app
    app="$(/usr/bin/jq -r '.[] | select(.target == "LedgerForge") | .buildSettings | .TARGET_BUILD_DIR + "/" + .FULL_PRODUCT_NAME' "$settings")"
    [[ -d "$app" ]] || fail "unable to identify exact Xcode Debug product" 65
    python3 "$ROOT_DIR/script/durable_startup.py" "$app" "$ARTIFACT_ROOT"
}

command_name="${1:-}"
case "$command_name" in
    durable-startup)
        [[ "$#" -eq 1 ]] || fail "durable-startup does not accept additional arguments"
        prepare_artifact_root
        run_durable_startup
        exit $?
        ;;
    schema-experiment)
        [[ "$#" -ge 2 ]] || fail "schema-experiment requires focused test selectors"
        validate_schema_namespace
        prepare_artifact_root
        prepare_test_environment_file
        shift
        run_focused_test "$@"
        exit $?
        ;;
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
        prepare_test_environment_file
        shift
        run_focused_test "$@"
        exit $?
        ;;
    test-full)
        [[ "$#" -eq 1 ]] || fail "test-full does not accept additional arguments"
        prepare_artifact_root
        prepare_test_environment_file
        run_full_test
        exit $?
        ;;
    cycle-close)
        [[ "$#" -eq 1 ]] || fail "cycle-close does not accept additional arguments"
        prepare_artifact_root
        prepare_test_environment_file
        run_cycle_close
        exit $?
        ;;
    *)
        usage >&2
        fail "expected one supported command" 2
        ;;
esac
