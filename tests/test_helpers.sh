#!/usr/bin/env bash
# test_helpers.sh — Regression tests for lib/helpers.sh and lib/gsettings_helpers.sh.
#
# Covers:
#   - log() emits a timestamped, level-tagged line.
#   - append_gsettings_list() appends once and is idempotent on repeat runs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/helpers.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/gsettings_helpers.sh"

# ── log() format ─────────────────────────────────────────────────────────────
log_line="$(log "info" "hello" 2>&1)"
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:+-]+ \[INFO\] hello$' <<<"$log_line"

# ── append_gsettings_list() idempotency ──────────────────────────────────────
STORE="[]"
# Mock run_as_target to emulate a gsettings-backed key store.
run_as_target() {
  shift # drop the leading "gsettings"
  if [ "$1" = "get" ]; then
    printf "%s" "$STORE"
  else
    STORE="$4"
  fi
}

append_gsettings_list org.gnome.desktop.autostart enabled-apps cursor.desktop
append_gsettings_list org.gnome.desktop.autostart enabled-apps cursor.desktop
[ "$STORE" = "['cursor.desktop']" ]

echo "test_helpers.sh: all assertions passed"
