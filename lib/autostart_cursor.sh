#!/usr/bin/env bash
# autostart_cursor.sh — Cursor IDE autostart configuration
#
# Components:
#   - configure_cursor_autostart(): Create an autostart entry for Cursor IDE.
#     Adds cursor to the user's autostart applications list via GSettings.
#
# Sourced after lib/helpers.sh and lib/gsettings_helpers.sh.
# Depends on: msg, log, need_cmd, append_gsettings_list

# ── Cursor Autostart ─────────────────────────────────────────────────────────

# configure_cursor_autostart — Create an autostart entry for Cursor IDE by
# appending cursor.desktop to the target user's GSettings autostart list. The
# write goes through append_gsettings_list (run as the target user), so it
# reaches the user's dconf even when the installer runs as root and is
# idempotent across repeated installs.
# Arguments: none (reads cursor availability from PATH).
# Returns: 0 when configured or safely skipped (cursor not installed).
configure_cursor_autostart() {
  if ! need_cmd cursor; then
    log "warn" "Cursor not installed, skipping autostart configuration"
    return 0
  fi

  msg "Configuring Cursor IDE autostart"
  log "info" "Appending cursor.desktop to org.gnome.desktop.autostart enabled-apps"

  # Append cursor.desktop to the user's autostart list (de-duplicated/idempotent).
  if append_gsettings_list org.gnome.desktop.autostart enabled-apps cursor.desktop; then
    msg "Cursor IDE autostart configured"
    log "info" "Cursor IDE autostart configured"
  else
    log "warn" "Could not update autostart list; Cursor autostart not configured"
  fi
}
