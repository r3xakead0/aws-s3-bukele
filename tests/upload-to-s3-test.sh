#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT
readonly SCRIPT_UNDER_TEST="${PROJECT_ROOT}/bin/upload-to-s3.sh"
TEST_TMP_DIR="$(mktemp -d)"
readonly TEST_TMP_DIR
readonly MOCK_BIN_DIR="${TEST_TMP_DIR}/bin"
readonly MOCK_LOG="${TEST_TMP_DIR}/aws.log"
readonly MOCK_STATE_DIR="${TEST_TMP_DIR}/state"

command_output=""
command_status=0
tests_run=0

cleanup() {
    rm -rf "$TEST_TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$MOCK_BIN_DIR" "$MOCK_STATE_DIR"

cat >"${MOCK_BIN_DIR}/aws" <<'MOCK_AWS'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >>"${MOCK_LOG:?}"

if [[ "${1:-}" == "sts" && "${2:-}" == "get-caller-identity" ]]; then
    if [[ "${MOCK_IDENTITY_FAIL_ONCE:-0}" == "1" && ! -f "${MOCK_STATE_DIR:?}/identity-failed" ]]; then
        touch "${MOCK_STATE_DIR}/identity-failed"
        exit 1
    fi

    exit 0
fi

if [[ "${1:-}" == "sso" && "${2:-}" == "login" ]]; then
    exit 0
fi

if [[ "${1:-}" == "s3" && "${2:-}" == "cp" ]]; then
    exit 0
fi

exit 1
MOCK_AWS

chmod +x "${MOCK_BIN_DIR}/aws"
touch "${TEST_TMP_DIR}/archive.zip" "${TEST_TMP_DIR}/notes.txt"

run_command() {
    set +e
    command_output=$("$@" 2>&1)
    command_status=$?
    set -e
    tests_run=$((tests_run + 1))
}

assert_status() {
    local expected="$1"

    if [[ "$command_status" -ne "$expected" ]]; then
        printf 'FAIL: expected status %s, got %s\nOutput:\n%s\n' \
            "$expected" "$command_status" "$command_output" >&2
        exit 1
    fi
}

assert_output_contains() {
    local expected="$1"

    if [[ "$command_output" != *"$expected"* ]]; then
        printf 'FAIL: output does not contain: %s\nOutput:\n%s\n' \
            "$expected" "$command_output" >&2
        exit 1
    fi
}

assert_log_contains() {
    local expected="$1"

    if ! grep -Fqx "$expected" "$MOCK_LOG"; then
        printf 'FAIL: AWS log does not contain: %s\nLog:\n' "$expected" >&2
        cat "$MOCK_LOG" >&2
        exit 1
    fi
}

run_command "$SCRIPT_UNDER_TEST" --help
assert_status 0
assert_output_contains "Usage: upload-to-s3.sh"

run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    S3_BUCKET="test-bucket" \
    "$SCRIPT_UNDER_TEST" "${TEST_TMP_DIR}/missing.zip"
assert_status 1
assert_output_contains "File not found"

run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    S3_BUCKET="test-bucket" \
    "$SCRIPT_UNDER_TEST" "${TEST_TMP_DIR}/notes.txt"
assert_status 1
assert_output_contains "Unsupported compressed file format"

run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    S3_BUCKET="" \
    "$SCRIPT_UNDER_TEST" "${TEST_TMP_DIR}/archive.zip"
assert_status 1
assert_output_contains "S3 bucket is required"

run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    S3_BUCKET="test-bucket" \
    S3_STORAGE_CLASS="INVALID_CLASS" \
    "$SCRIPT_UNDER_TEST" "${TEST_TMP_DIR}/archive.zip"
assert_status 1
assert_output_contains "Unsupported S3 storage class: INVALID_CLASS"

: >"$MOCK_LOG"
run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_STATE_DIR="$MOCK_STATE_DIR" \
    "$SCRIPT_UNDER_TEST" \
    --bucket "test-bucket" \
    --profile "test-profile" \
    "${TEST_TMP_DIR}/archive.zip"
assert_status 0
assert_output_contains "Storage class: STANDARD"
assert_log_contains "s3 cp ${TEST_TMP_DIR}/archive.zip s3://test-bucket/backups/archive.zip --storage-class STANDARD --profile test-profile"

: >"$MOCK_LOG"
run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_STATE_DIR="$MOCK_STATE_DIR" \
    "$SCRIPT_UNDER_TEST" \
    --bucket "test-bucket" \
    --profile "test-profile" \
    --prefix "/releases/" \
    --storage-class "STANDARD_IA" \
    "${TEST_TMP_DIR}/archive.zip"
assert_status 0
assert_output_contains "s3://test-bucket/releases/archive.zip"
assert_output_contains "Storage class: STANDARD_IA"
assert_log_contains "sts get-caller-identity --profile test-profile"
assert_log_contains "s3 cp ${TEST_TMP_DIR}/archive.zip s3://test-bucket/releases/archive.zip --storage-class STANDARD_IA --profile test-profile"

: >"$MOCK_LOG"
rm -f "${MOCK_STATE_DIR}/identity-failed"
run_command env \
    PATH="${MOCK_BIN_DIR}:/usr/bin:/bin" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_STATE_DIR="$MOCK_STATE_DIR" \
    MOCK_IDENTITY_FAIL_ONCE=1 \
    S3_BUCKET="test-bucket" \
    AWS_PROFILE="test-profile" \
    S3_PREFIX="backups" \
    S3_STORAGE_CLASS="GLACIER_IR" \
    "$SCRIPT_UNDER_TEST" "${TEST_TMP_DIR}/archive.zip"
assert_status 0
assert_output_contains "Starting SSO login"
assert_output_contains "Storage class: GLACIER_IR"
assert_log_contains "sso login --profile test-profile"
assert_log_contains "s3 cp ${TEST_TMP_DIR}/archive.zip s3://test-bucket/backups/archive.zip --storage-class GLACIER_IR --profile test-profile"

printf 'PASS: %s integration tests completed successfully.\n' "$tests_run"
