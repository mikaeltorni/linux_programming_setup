#!/usr/bin/env bash
# autostart_cursor.sh — Cursor IDE autostart configuration
#
# Components:
#   - configure_cursor_autostart(): Create an autostart entry for Cursor IDE.
#     Adds cursor to the user's autostart applications list via GSettings.
#
# Sourced after lib/helpers.sh, lib/gsettings_helpers.sh, and lib/autostart.sh.
# Depends on: msg, run_as_target, TARGET_HOME, TARGET_USER

# ── Cursor Autostart ─────────────────────────────────────────────────────────

# configure_cursor_autostart — Create an autostart entry for Cursor IDE.
# Adds cursor to the user's autostart applications list via GSettings.

configure_cursor_autostart() {
  if ! need_cmd cursor; then
    msg "Cursor not installed, skipping autostart configuration"
    return 0
  fi

  msg "Configuring Cursor IDE autostart"
  
  # Add cursor to the autostart GSettings list (idempotent)
  local current_autostart
  current_autostart="$(gsettings get org.gnome.desktop.autostart enabled-apps 2>/dev/null || echo "[]")"
  
  # Check if cursor.desktop is already in the list
  if echo "$current_autostart" | grep -q 'cursor\.desktop'; then
    msg "Cursor IDE already in autostart, skipping"
    return 0
  fi
  
  # Add cursor.desktop to the autostart list
  gsettings set org.gnome.desktop.autostart enabled-apps "$(echo "$current_autostart" | sed 's/\]/, '\''cursor.desktop'\'']/')" || true
  
  msg "Cursor IDE autostart configured"
}
