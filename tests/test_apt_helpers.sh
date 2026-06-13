#!/usr/bin/env bash
# test_apt_helpers.sh — Regression tests for apt_install().
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$ROOT_DIR/lib/helpers.sh"
source "$ROOT_DIR/lib/apt_helpers.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

installer_source="$(cat "$ROOT_DIR/install.sh")"
grep -q 'source "$SCRIPT_DIR/lib/apt_helpers.sh"' <<<"$installer_source" ||
  fail "install.sh does not source apt_helpers.sh"

APT_CALLS=()
LOG_MESSAGES=()
SUDO_NOTES=()

apt() {
  APT_CALLS+=("$*")
  return "${APT_STATUS:-0}"
}

log() {
  LOG_MESSAGES+=("$*")
}

note_sudo_required() {
  SUDO_NOTES+=("$*")
}

# Existing commands must not trigger package-manager work.
need_cmd() { return 0; }
is_root() { return 1; }
apt_install curl
[ "${#APT_CALLS[@]}" -eq 0 ] || fail "apt called for an existing command"
[ "${#SUDO_NOTES[@]}" -eq 0 ] || fail "sudo noted for an existing command"

# User-mode installs must be deferred and reported.
need_cmd() { return 1; }
is_root() { return 1; }
apt_install curl
[ "${SUDO_NOTES[0]}" = "apt install curl" ] || fail "missing sudo-required note"
[ "${#APT_CALLS[@]}" -eq 0 ] || fail "apt called in user mode"

# Root installs must update package metadata and install the requested package.
SUDO_NOTES=()
is_root() { return 0; }
apt_install curl
[ "${APT_CALLS[0]}" = "update -y" ] || fail "apt update was not called first"
[ "${APT_CALLS[1]}" = "install -y curl" ] || fail "apt install used unexpected arguments"

# A failed apt update must fail the helper and skip installation.
APT_CALLS=()
APT_STATUS=1
if apt_install wget; then
  fail "apt_install succeeded after apt update failed"
fi
[ "${#APT_CALLS[@]}" -eq 1 ] || fail "apt install ran after a failed update"
[ "${APT_CALLS[0]}" = "update -y" ] || fail "unexpected failed-update command"

echo "test_apt_helpers.sh: all assertions passed"
