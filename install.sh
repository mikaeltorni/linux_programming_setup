#!/usr/bin/env bash
set -euo pipefail
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

# ── Configuration variables (can be overridden via environment) ───────────────
CURSOR_DEB_URL="${CURSOR_DEB_URL:-}"
CURSOR_VERSION="${CURSOR_VERSION:-2.6.22}"
CURSOR_EXTENSIONS_FILE="${CURSOR_EXTENSIONS_FILE:-$CONFIG_DIR/vsc_cursor_extensions}"

# ── Runtime variables ────────────────────────────────────────────────────────
RUNTIME_DIR="/run/user/${TARGET_UID}"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"

# ── Library includes ────────────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/lib/gsettings_helpers.sh"
source "$SCRIPT_DIR/lib/cursor_install.sh"
source "$SCRIPT_DIR/lib/autostart_cursor.sh"

# ── Main installer logic ────────────────────────────────────────────────────

main_inner() {
  ensure_session_bus
  
  local install_steps=(
    install_cursor
    install_cursor_extensions
    configure_cursor_autostart
  )

  if [[ "${ISC_APPLY_HOTKEYS_ONLY:-0}" == "1" ]]; then
    msg "=== LPS CONFIG-ONLY MODE ==="
    ensure_root
    # In config-only mode, only run autostart configuration
    configure_cursor_autostart || true
  else
    ensure_root
    for step in "${install_steps[@]}"; do
      "$step"
    done
  fi
}

run_and_log_with_reboot() {
  local ts log_dir log_file
  ts=$(date +"%Y%m%d-%H%M%S")
  log_dir="$SCRIPT_DIR/.log"
  mkdir -p "$log_dir"
  log_file="$log_dir/linux_programming_setup-$ts.log"

  main_inner "$@" 2>&1 | tee "$log_file"
  msg "All done. Log file written to: $log_file"

  if [[ "${ISC_NO_REBOOT:-0}" == "1" ]]; then
    msg "Skipping reboot due to ISC_NO_REBOOT=1"
  else
    msg "Rebooting now in 10 seconds. Press Ctrl+C to cancel."
    sleep 10
    reboot
  fi
}

# Only run the main installer if the script is executed, not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_and_log_with_reboot "$@"
fi
