#!/usr/bin/env bash
# test_cursor_install.sh — Regression tests for install_cursor() guards.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$ROOT_DIR/lib/helpers.sh"
source "$ROOT_DIR/lib/apt_helpers.sh"
source "$ROOT_DIR/lib/cursor_install.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

LOG_MESSAGES=()
SUDO_NOTES=()
APT_CALLS=()

log() { LOG_MESSAGES+=("$*"); }
msg() { :; }
note_sudo_required() { SUDO_NOTES+=("$*"); }
apt_install() { APT_CALLS+=("$*"); }

# Already-installed cursor must short-circuit without touching apt or sudo notes.
need_cmd() { return 0; }
is_root() { return 0; }
install_cursor || fail "install_cursor failed when cursor already present"
[ "${#APT_CALLS[@]}" -eq 0 ] || fail "apt ran though cursor already present"

# Non-root run must defer to sudo and not attempt a download.
need_cmd() { return 1; }
is_root() { return 1; }
SUDO_NOTES=()
install_cursor || fail "install_cursor failed in user mode"
[ "${SUDO_NOTES[0]}" = "install Cursor IDE .deb (apt install)" ] ||
  fail "missing sudo-required note in user mode"

# Root run with an empty CURSOR_DEB_URL must skip cleanly before installing
# curl/wget, returning success so optional Cursor absence does not abort the
# rest of the programming setup.
need_cmd() { return 1; }
is_root() { return 0; }
APT_CALLS=()
LOG_MESSAGES=()
CURSOR_DEB_URL=""
install_cursor || fail "install_cursor failed with an empty CURSOR_DEB_URL"
[ "${#APT_CALLS[@]}" -eq 0 ] || fail "apt ran despite an unset CURSOR_DEB_URL"
printf '%s\n' "${LOG_MESSAGES[@]}" | grep -q 'CURSOR_DEB_URL is not set; skipping Cursor IDE package install' ||
  fail "missing explanatory skip for unset CURSOR_DEB_URL"

echo "test_cursor_install.sh: all assertions passed"
