#!/usr/bin/env bash
# autostart_cursor.sh — Cursor IDE autostart configuration
#
# Components:
#   - configure_cursor_autostart(): Create an autostart entry for Cursor IDE.
#     Installs ~/.config/autostart/cursor.desktop for the target user.
#
# Sourced after lib/helpers.sh.
# Depends on: msg, log, need_cmd, run_as_target, TARGET_HOME

# ── Cursor Autostart ─────────────────────────────────────────────────────────

# configure_cursor_autostart — Create an autostart entry for Cursor IDE by
# installing a freedesktop autostart desktop file. This avoids relying on a
# GNOME-specific autostart GSettings schema that is not present on all releases.
# Arguments: none (reads cursor availability from PATH).
# Returns: 0 when configured or safely skipped (cursor not installed).
configure_cursor_autostart() {
  if ! need_cmd cursor; then
    log "warn" "Cursor not installed, skipping autostart configuration"
    return 0
  fi

  msg "Configuring Cursor IDE autostart"
  log "info" "Installing Cursor autostart desktop entry"

  run_as_target install -d -m 0755 "$TARGET_HOME/.config/autostart"
  run_as_target tee "$TARGET_HOME/.config/autostart/cursor.desktop" >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Cursor
Exec=cursor --no-sandbox
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
  run_as_target chmod 0644 "$TARGET_HOME/.config/autostart/cursor.desktop"
  msg "Cursor IDE autostart configured"
  log "info" "Cursor IDE autostart configured"
}
