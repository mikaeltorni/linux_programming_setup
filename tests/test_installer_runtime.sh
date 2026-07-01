#!/usr/bin/env bash
# test_installer_runtime.sh — Characterization tests for installer execution.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  grep -Fq "$needle" <<<"$haystack" ||
    fail "expected output to contain: $needle"
}

test_no_reboot_mode() (
  source "$ROOT_DIR/install.sh"

  local temp_dir output log_file
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  SCRIPT_DIR="$temp_dir"
  ISC_NO_REBOOT=1

  date() { printf '20260102-030405\n'; }
  main_inner() { printf 'installed:%s\n' "$1"; }
  reboot() { fail "reboot called in no-reboot mode"; }

  output="$(run_and_log_with_reboot "editor")"
  log_file="$temp_dir/.log/linux_programming_setup-20260102-030405.log"

  [ -f "$log_file" ] || fail "installer log was not created"
  [ "$(cat "$log_file")" = "installed:editor" ] ||
    fail "installer output was not written to the log"
  assert_contains "$output" "All done. Log file written to: $log_file"
  assert_contains "$output" "Skipping reboot due to ISC_NO_REBOOT/INSTALLER_NO_REBOOT"
)

test_master_no_reboot_var_skips_reboot() (
  # The master orchestrator runs children with INSTALLER_NO_REBOOT=1 (not
  # ISC_NO_REBOOT); honoring it keeps this installer from rebooting mid-run and
  # killing the repositories sequenced after it.
  source "$ROOT_DIR/install.sh"

  local temp_dir output
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  SCRIPT_DIR="$temp_dir"
  unset ISC_NO_REBOOT
  INSTALLER_NO_REBOOT=1

  date() { printf '20260102-030405\n'; }
  id() { printf '0\n'; }
  main_inner() { printf 'installed\n'; }
  reboot() { fail "reboot called despite INSTALLER_NO_REBOOT=1"; }

  output="$(run_and_log_with_reboot)"
  assert_contains "$output" "Skipping reboot due to ISC_NO_REBOOT/INSTALLER_NO_REBOOT"
)

test_user_mode_skips_reboot() (
  source "$ROOT_DIR/install.sh"

  local temp_dir output
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  SCRIPT_DIR="$temp_dir"
  unset ISC_NO_REBOOT

  date() { printf '20260102-030405\n'; }
  id() { printf '1000\n'; }
  main_inner() { printf 'installed\n'; }
  reboot() { fail "reboot called in user mode"; }

  output="$(run_and_log_with_reboot)"
  assert_contains "$output" \
    "Done. Log out and back in for changes to take effect (reboot skipped in user mode)."
)

test_root_mode_reboots_after_delay() (
  source "$ROOT_DIR/install.sh"

  local temp_dir output reboot_marker sleep_marker
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  SCRIPT_DIR="$temp_dir"
  reboot_marker="$temp_dir/rebooted"
  sleep_marker="$temp_dir/slept"
  unset ISC_NO_REBOOT

  date() { printf '20260102-030405\n'; }
  id() { printf '0\n'; }
  main_inner() { printf 'installed\n'; }
  sleep() { printf '%s\n' "$1" >"$sleep_marker"; }
  reboot() { touch "$reboot_marker"; }

  output="$(run_and_log_with_reboot)"
  assert_contains "$output" "Rebooting now in 10 seconds. Press Ctrl+C to cancel."
  [ "$(cat "$sleep_marker")" = "10" ] || fail "unexpected reboot delay"
  [ -f "$reboot_marker" ] || fail "root mode did not request a reboot"
)

test_installer_failure_propagates() {
  local temp_dir output status log_file
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  log_file="$temp_dir/.log/linux_programming_setup-20260102-030405.log"

  set +e
  output="$(
    bash -c '
      source "$1/install.sh"
      SCRIPT_DIR="$2"
      ISC_NO_REBOOT=1
      date() { printf "20260102-030405\n"; }
      main_inner() {
        printf "failed install\n"
        return 23
      }
      run_and_log_with_reboot
    ' _ "$ROOT_DIR" "$temp_dir" 2>&1
  )"
  status=$?
  set -e

  [ "$status" -eq 23 ] || fail "installer failure status was not propagated"
  [ "$(cat "$log_file")" = "failed install" ] ||
    fail "failed installer output was not logged"
  if grep -Fq "All done." <<<"$output"; then
    fail "success message was emitted after installer failure"
  fi
}

test_interactive_mode_preserves_tty() {
  command -v script >/dev/null 2>&1 || fail "script(1) is required for PTY regression test"
  local output temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  output="$(script -qec "bash -c '
    source \"$ROOT_DIR/install.sh\"
    SCRIPT_DIR=\"$temp_dir\"
    INSTALLER_NO_REBOOT=1
    main_inner() { if [[ -t 0 && -t 1 ]]; then printf tty-preserved; else printf tty-lost; return 9; fi; }
    run_and_log_with_reboot
  '" /dev/null)"
  assert_contains "$output" "tty-preserved"
  if grep -Fq "tty-lost" <<<"$output"; then
    fail "interactive installer lost its terminal through the logging pipeline"
  fi
}

test_no_reboot_mode
test_master_no_reboot_var_skips_reboot
test_user_mode_skips_reboot
test_root_mode_reboots_after_delay
test_installer_failure_propagates
test_interactive_mode_preserves_tty

echo "test_installer_runtime.sh: all assertions passed"
