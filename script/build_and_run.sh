#!/usr/bin/env bash
set -uo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly VALIDATE_SCRIPT="$ROOT_DIR/script/validate.sh"
readonly APP_NAME="LedgerForge"
readonly BUNDLE_IDENTIFIER="com.vyom.LedgerForge"
readonly DESTINATION="platform=macOS"

ARTIFACT_ROOT=""
DERIVED_DATA=""
FRESH_EXECUTABLE=""
FRESH_LAUNCH_STARTED=0
VERIFIED_PIDS=()
VERIFIED_EXECUTABLES=()

usage() {
    cat <<'USAGE'
Usage:
  ./script/build_and_run.sh
  ./script/build_and_run.sh --verify
  ./script/build_and_run.sh --stop
  ./script/build_and_run.sh --help

The default command and --verify stop only verified LedgerForge app instances,
build a fresh Debug app, and launch exactly one isolated run-host instance.
USAGE
}

fail() {
    local message="$1"
    local status="${2:-2}"
    printf 'build_and_run.sh: %s\n' "$message" >&2
    exit "$status"
}

canonical_path() {
    /bin/realpath "$1"
}

temporary_base() {
    canonical_path "${TMPDIR:-/tmp}"
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
        ARTIFACT_ROOT="$(/usr/bin/mktemp -d "$temp_base/LedgerForge-run.XXXXXX")" || fail "unable to create task-owned artifact root" 70
        ARTIFACT_ROOT="$(canonical_path "$ARTIFACT_ROOT")" || fail "unable to resolve task-owned artifact root" 70
    fi

    case "$ARTIFACT_ROOT" in
        "$temp_base"/LedgerForge-*) ;;
        *) fail "artifact root escaped the task-owned temporary directory" 64 ;;
    esac

    DERIVED_DATA="$ARTIFACT_ROOT/DerivedData"
}

list_exact_name_pids() {
    local status

    /usr/bin/pgrep -x "$APP_NAME" 2>/dev/null
    status=$?
    case "$status" in
        0|1) return 0 ;;
        *) return "$status" ;;
    esac
}

process_executable_path() {
    local pid="$1"
    local reported_path
    local resolved_path

    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac

    reported_path="$(/usr/sbin/lsof -n -p "$pid" -a -d txt -Fn 2>/dev/null | /usr/bin/awk '/^n/ { sub(/^n/, ""); print; exit }')"
    [[ -n "$reported_path" ]] || return 1
    resolved_path="$(canonical_path "$reported_path")" || return 1
    printf '%s\n' "$resolved_path"
}

bundle_for_executable() {
    local executable="$1"
    local bundle

    case "$executable" in
        */LedgerForge.app/Contents/MacOS/LedgerForge)
            bundle="${executable%/Contents/MacOS/LedgerForge}"
            ;;
        *) return 1 ;;
    esac

    canonical_path "$bundle"
}

plist_value() {
    local bundle="$1"
    local key="$2"
    local plist="$bundle/Contents/Info.plist"

    [[ -f "$plist" ]] || return 1
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null
}

classify_exact_name_pid() {
    local pid="$1"
    local executable
    local bundle
    local bundle_identifier
    local bundle_executable

    executable="$(process_executable_path "$pid")" || return 1
    bundle="$(bundle_for_executable "$executable")" || return 1
    bundle_identifier="$(plist_value "$bundle" "CFBundleIdentifier")" || return 1
    bundle_executable="$(plist_value "$bundle" "CFBundleExecutable")" || return 1
    [[ "$bundle_identifier" == "$BUNDLE_IDENTIFIER" ]] || return 1
    [[ "$bundle_executable" == "$APP_NAME" ]] || return 1
    [[ "$executable" == "$bundle/Contents/MacOS/$bundle_executable" ]] || return 1

    printf '%s\t%s\n' "$pid" "$executable"
}

verify_all_exact_name_processes() {
    local pids
    local pid
    local record
    local verified_pid
    local verified_executable

    pids="$(list_exact_name_pids)" || return 2
    VERIFIED_PIDS=()
    VERIFIED_EXECUTABLES=()
    [[ -n "$pids" ]] || return 0

    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        record="$(classify_exact_name_pid "$pid")" || {
            printf 'build_and_run.sh: exact-name PID %s is ambiguous; no signals sent\n' "$pid" >&2
            return 1
        }
        IFS=$'\t' read -r verified_pid verified_executable <<< "$record"
        VERIFIED_PIDS+=("$verified_pid")
        VERIFIED_EXECUTABLES+=("$verified_executable")
    done <<< "$pids"
}

request_graceful_quit() {
    local pid="$1"

    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac

    /usr/bin/osascript -l JavaScript \
        -e "ObjC.import('AppKit'); const application = \
$.NSRunningApplication.runningApplicationWithProcessIdentifier($pid); \
if (application.isNil() || !ObjC.unwrap(application.terminate)) { \
throw new Error('Unable to request graceful quit for verified PID'); }"
}

wait_for_exact_name_zero() {
    local timeout_seconds="$1"
    local elapsed=0
    local pids

    while [[ "$elapsed" -lt "$timeout_seconds" ]]; do
        pids="$(list_exact_name_pids)" || return 2
        [[ -z "$pids" ]] && return 0
        /bin/sleep 1
        elapsed=$((elapsed + 1))
    done

    pids="$(list_exact_name_pids)" || return 2
    [[ -z "$pids" ]]
}

signal_remaining_verified_processes() {
    local signal="$1"
    local index
    local pid
    local expected_executable
    local current_executable

    verify_all_exact_name_processes || return $?

    for index in "${!VERIFIED_PIDS[@]}"; do
        pid="${VERIFIED_PIDS[$index]}"
        expected_executable="${VERIFIED_EXECUTABLES[$index]}"
        /bin/kill -0 "$pid" 2>/dev/null || continue
        current_executable="$(process_executable_path "$pid")" || return 1
        [[ "$current_executable" == "$expected_executable" ]] || return 1
        /bin/kill "-$signal" "$pid" 2>/dev/null || {
            /bin/kill -0 "$pid" 2>/dev/null && return 1
        }
    done
}

terminate_verified_exact_name_processes() {
    local index
    local graceful_failures=0
    local wait_status

    verify_all_exact_name_processes || fail "an exact-name LedgerForge process could not be safely identified" 64
    [[ "${#VERIFIED_PIDS[@]}" -gt 0 ]] || return 0

    for index in "${!VERIFIED_PIDS[@]}"; do
        if ! request_graceful_quit "${VERIFIED_PIDS[$index]}"; then
            graceful_failures=$((graceful_failures + 1))
        fi
    done
    [[ "$graceful_failures" -eq 0 ]] || printf 'build_and_run.sh: graceful quit request was unavailable for %s verified PID(s); waiting before TERM\n' "$graceful_failures" >&2

    wait_for_exact_name_zero 4
    wait_status=$?
    [[ "$wait_status" -eq 0 ]] && return 0
    [[ "$wait_status" -eq 1 ]] || fail "unable to inspect exact-name processes while waiting for graceful quit" 70

    signal_remaining_verified_processes TERM || fail "a remaining exact-name process became ambiguous before TERM" 64
    wait_for_exact_name_zero 3
    wait_status=$?
    [[ "$wait_status" -eq 0 ]] && return 0
    [[ "$wait_status" -eq 1 ]] || fail "unable to inspect exact-name processes while waiting after TERM" 70

    signal_remaining_verified_processes KILL || fail "a remaining exact-name process became ambiguous before KILL" 64
    wait_for_exact_name_zero 2 || fail "verified exact-name LedgerForge processes remained after KILL" 65
}

prove_zero_exact_name_instances() {
    local pids

    pids="$(list_exact_name_pids)" || fail "unable to inspect exact-name processes" 70
    [[ -z "$pids" ]] || fail "exact-name LedgerForge instances remain; launch is unsafe" 64
    printf 'Verified exact-name LedgerForge instances: 0\n'
}

resolve_built_bundle() {
    local settings_file="$ARTIFACT_ROOT/build-settings.txt"
    local target_build_dir
    local wrapper_name
    local bundle
    local bundle_identifier
    local bundle_executable

    /usr/bin/xcodebuild \
        -project "$ROOT_DIR/LedgerForge.xcodeproj" \
        -scheme "$APP_NAME" \
        -configuration Debug \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -showBuildSettings >"$settings_file" 2>&1 || fail "unable to resolve the built bundle through Xcode build settings" 65

    target_build_dir="$(/usr/bin/awk -F ' = ' '$1 ~ /^[[:space:]]*TARGET_BUILD_DIR$/ { print $2; exit }' "$settings_file")"
    wrapper_name="$(/usr/bin/awk -F ' = ' '$1 ~ /^[[:space:]]*WRAPPER_NAME$/ { print $2; exit }' "$settings_file")"
    [[ -n "$target_build_dir" && -n "$wrapper_name" ]] || fail "Xcode build settings did not identify the built app bundle" 65

    bundle="$(canonical_path "$target_build_dir/$wrapper_name")" || fail "the Xcode-resolved built app bundle is missing" 65
    bundle_identifier="$(plist_value "$bundle" "CFBundleIdentifier")" || fail "the built bundle has no readable identifier" 65
    bundle_executable="$(plist_value "$bundle" "CFBundleExecutable")" || fail "the built bundle has no readable executable" 65
    [[ "$bundle_identifier" == "$BUNDLE_IDENTIFIER" ]] || fail "the built bundle identifier is not $BUNDLE_IDENTIFIER" 65
    [[ "$bundle_executable" == "$APP_NAME" ]] || fail "the built bundle executable is not $APP_NAME" 65

    FRESH_EXECUTABLE="$(canonical_path "$bundle/Contents/MacOS/$bundle_executable")" || fail "the built executable is missing" 65
    case "$FRESH_EXECUTABLE" in
        */LedgerForge.app/Contents/MacOS/LedgerForge) ;;
        *) fail "the built executable does not have the required LedgerForge app shape" 65 ;;
    esac

    /usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle" || fail "the built bundle did not pass code-signing verification" 65
    /usr/bin/codesign -d --verbose=2 "$bundle" >"$ARTIFACT_ROOT/codesign.txt" 2>&1 || fail "the built bundle has no inspectable code-signing provenance" 65

    printf 'Fresh bundle: %s\n' "$bundle"
    printf 'Fresh executable: %s\n' "$FRESH_EXECUTABLE"
    printf 'Code signing: verified\n'
}

verify_open_environment_contract() {
    local help_file="$ARTIFACT_ROOT/open-help.txt"

    /usr/bin/open --help >"$help_file" 2>&1 || true
    /usr/bin/grep -F -- '--env' "$help_file" >/dev/null || fail "/usr/bin/open cannot inject a process-local run-host marker" 69
}

cleanup_fresh_launch_after_failure() {
    local pids
    local pid
    local executable

    [[ -n "$FRESH_EXECUTABLE" ]] || return 0
    pids="$(list_exact_name_pids)" || return 0
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        executable="$(process_executable_path "$pid")" || continue
        [[ "$executable" == "$FRESH_EXECUTABLE" ]] || continue
        /bin/kill -TERM "$pid" 2>/dev/null || true
        /bin/sleep 1
        executable="$(process_executable_path "$pid")" || continue
        [[ "$executable" == "$FRESH_EXECUTABLE" ]] || continue
        /bin/kill -KILL "$pid" 2>/dev/null || true
    done <<< "$pids"
}

finish_with_cleanup_on_failure() {
    local status=$?
    trap - EXIT
    if [[ "$status" -ne 0 && "$FRESH_LAUNCH_STARTED" -eq 1 ]]; then
        cleanup_fresh_launch_after_failure
    fi
    exit "$status"
}

launch_and_verify_fresh_bundle() {
    local elapsed=0
    local timeout_seconds=8
    local pids
    local pid
    local executable
    local count

    prove_zero_exact_name_instances
    verify_open_environment_contract
    /usr/bin/open -n --env LEDGERFORGE_RUN_HOST=1 "${FRESH_EXECUTABLE%/Contents/MacOS/LedgerForge}"
    FRESH_LAUNCH_STARTED=1

    while [[ "$elapsed" -lt "$timeout_seconds" ]]; do
        pids="$(list_exact_name_pids)" || fail "unable to inspect exact-name processes after launch" 70
        if [[ -n "$pids" ]]; then
            count="$(printf '%s\n' "$pids" | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')"
            if [[ "$count" -eq 1 ]]; then
                pid="$(printf '%s\n' "$pids" | /usr/bin/awk 'NF { print; exit }')"
                executable="$(process_executable_path "$pid")" || fail "the launched PID executable could not be resolved" 65
                if [[ "$executable" == "$FRESH_EXECUTABLE" ]]; then
                    printf 'Verified PID: %s\n' "$pid"
                    printf 'Verified executable: %s\n' "$executable"
                    return 0
                fi
                fail "the launched PID resolved to a different executable" 65
            fi
            fail "more than one exact-name LedgerForge process exists after launch" 65
        fi
        /bin/sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "the fresh LedgerForge bundle did not launch within the bounded timeout" 65
}

run() {
    prepare_artifact_root
    terminate_verified_exact_name_processes
    prove_zero_exact_name_instances

    LEDGERFORGE_ARTIFACT_ROOT="$ARTIFACT_ROOT" "$VALIDATE_SCRIPT" build-debug
    local build_status=$?
    [[ "$build_status" -eq 0 ]] || fail "Debug build validation failed" "$build_status"

    resolve_built_bundle
    prove_zero_exact_name_instances
    launch_and_verify_fresh_bundle
    printf 'Artifact root: %s\n' "$ARTIFACT_ROOT"
    printf 'DerivedData: %s\n' "$DERIVED_DATA"
}

mode="${1:-run}"
[[ "$#" -le 1 ]] || fail "expected at most one option" 2

case "$mode" in
    run|--verify)
        trap finish_with_cleanup_on_failure EXIT
        run
        ;;
    --stop)
        terminate_verified_exact_name_processes
        prove_zero_exact_name_instances
        ;;
    --help)
        usage
        ;;
    *)
        usage >&2
        fail "expected --verify, --stop, or --help" 2
        ;;
esac
