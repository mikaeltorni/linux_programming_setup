#!/usr/bin/env bash
# test_helpers.sh — Regression tests for lib/helpers.sh and lib/gsettings_helpers.sh.
#
# Covers:
#   - log() emits a timestamped, level-tagged line.
#   - append_gsettings_list() appends once and is idempotent on repeat runs.
#   - append_gsettings_list() fails closed when the current key cannot be read.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/helpers.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/gsettings_helpers.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# ── log() format ─────────────────────────────────────────────────────────────
log_line="$(log "info" "hello" 2>&1)"
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:+-]+ \[INFO\] hello$' <<<"$log_line"

# ── append_gsettings_list() idempotency ──────────────────────────────────────
STORE="[]"
LOG_MESSAGES=()
SET_CALLS=0

log() {
  LOG_MESSAGES+=("$*")
}

# Mock run_as_target to emulate a gsettings-backed key store.
run_as_target() {
  shift # drop the leading "gsettings"
  if [ "$1" = "get" ]; then
    printf "%s" "$STORE"
  else
    SET_CALLS=$((SET_CALLS + 1))
    STORE="$4"
  fi
}

append_gsettings_list org.gnome.desktop.autostart enabled-apps cursor.desktop
append_gsettings_list org.gnome.desktop.autostart enabled-apps cursor.desktop
[ "$STORE" = "['cursor.desktop']" ]
[ "$SET_CALLS" -eq 2 ] || fail "expected two successful gsettings set calls"

# Failed reads must not synthesize [] and overwrite user settings.
run_as_target() {
  shift
  if [ "$1" = "get" ]; then
    return 7
  fi
  SET_CALLS=$((SET_CALLS + 1))
  STORE="$4"
}

LOG_MESSAGES=()
SET_CALLS=0
if append_gsettings_list org.gnome.desktop.autostart enabled-apps cursor.desktop; then
  fail "append_gsettings_list succeeded after gsettings get failed"
fi
[ "$SET_CALLS" -eq 0 ] || fail "gsettings set ran after failed read"
printf '%s\n' "${LOG_MESSAGES[@]}" | grep -q 'Could not read GSettings key' ||
  fail "missing warning for failed gsettings read"

echo "test_helpers.sh: all assertions passed"
