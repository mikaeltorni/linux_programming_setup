#!/usr/bin/env bash
# test_cursor_autostart.sh - Cursor autostart desktop-entry lifecycle tests.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_HOME="$(mktemp -d)"
trap 'rm -rf "$TARGET_HOME"' EXIT

LOG_MESSAGES=()
log() { LOG_MESSAGES+=("$*"); }
msg() { :; }
need_cmd() { [ "$1" = "cursor" ]; }
run_as_target() { "$@"; }

source "$ROOT_DIR/lib/autostart_cursor.sh"
source "$ROOT_DIR/lib/lifecycle.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

configure_cursor_autostart
desktop_file="$TARGET_HOME/.config/autostart/cursor.desktop"
[ -f "$desktop_file" ] || fail "cursor autostart desktop file was not created"
grep -q '^Exec=cursor --no-sandbox$' "$desktop_file" ||
  fail "cursor autostart desktop file has the wrong command"
detect_cursor_autostart || fail "detect_cursor_autostart should see the desktop file"

uninstall_cursor_autostart
[ ! -e "$desktop_file" ] || fail "cursor autostart desktop file was not removed"

printf 'test_cursor_autostart.sh: all assertions passed\n'
