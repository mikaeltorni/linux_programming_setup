#!/usr/bin/env bash
# gsettings_helpers.sh — GSettings / dconf helper functions (minimal)
#
# Components:
#   - user_gsettings(args...): Run gsettings as the target user.
#   - append_gsettings_list(schema, key, value): Append a value to a list (idempotent).
#
# Sourced after lib/helpers.sh. Depends on: need_cmd, run_as_target.

PROGRAMMING_GSETTINGS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lps_bin.sh
source "$PROGRAMMING_GSETTINGS_LIB_DIR/lps_bin.sh"

# ── GSettings wrapper ────────────────────────────────────────────────────────

# user_gsettings — Run the gsettings command as the target user so reads and
# writes hit the user's dconf database rather than root's.
# Arguments: $@ — arguments forwarded verbatim to gsettings.
# Returns: the exit status of gsettings.
user_gsettings() {
  run_as_target gsettings "$@"
}

# ── List manipulation ────────────────────────────────────────────────────────

# append_gsettings_list — Append a value to a GSettings array key, de-duplicating
# existing entries so repeated runs are idempotent. If the current key cannot be
# read, abort before writing so an unavailable schema/session cannot overwrite
# existing user state with a synthetic empty list.
# Arguments:
#   $1 schema — GSettings schema id (e.g. org.gnome.desktop.autostart).
#   $2 key    — the array-valued key to update.
#   $3 value  — the string value to append if not already present.
# Returns: the exit status of the final gsettings set (0 on success).
append_gsettings_list() {
  local schema="$1" key="$2" value="$3"
  local current newlist
  if ! current="$(user_gsettings get "$schema" "$key" 2>/dev/null)"; then
    log "warn" "Could not read GSettings key $schema $key; leaving it unchanged"
    return 1
  fi
  newlist="$(CURRENT="$current" lps_bin "$value")"
  user_gsettings set "$schema" "$key" "$newlist"
}
