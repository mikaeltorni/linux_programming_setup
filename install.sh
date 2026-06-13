#!/usr/bin/env bash
set -euo pipefail
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

# ── Configuration variables (can be overridden via environment) ───────────────
CURSOR_DEB_URL="${CURSOR_DEB_URL:-}"
CURSOR_EXTENSIONS_FILE="${CURSOR_EXTENSIONS_FILE:-$CONFIG_DIR/vsc_cursor_extensions}"

# ── Runtime variables ────────────────────────────────────────────────────────
RUNTIME_DIR="/run/user/${TARGET_UID}"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"

# ── Library includes ────────────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/lib/apt_helpers.sh"
source "$SCRIPT_DIR/lib/gsettings_helpers.sh"
source "$SCRIPT_DIR/lib/cursor_install.sh"
source "$SCRIPT_DIR/lib/autostart_cursor.sh"
source "$SCRIPT_DIR/lib/continue_setup.sh"
source "$SCRIPT_DIR/lib/claude_status_bar_setup.sh"
source "$SCRIPT_DIR/lib/uv_supply_chain.sh"
source "$SCRIPT_DIR/lib/installer_runtime.sh"

# ── Main installer logic ────────────────────────────────────────────────────

# main_inner — Run the installation steps. In normal mode it requires root and
# runs every step in order; in config-only mode (ISC_APPLY_HOTKEYS_ONLY=1) it
# applies only the editor/autostart/uv configuration, tolerating per-step
# failures. Arguments: $@ — forwarded but currently unused. Returns: 0 on
# success; aborts via set -e if a normal-mode step fails.
main_inner() {
  ensure_session_bus
  
  local install_steps=(
    install_cursor
    install_cursor_extensions
    configure_continue
    configure_claude_status_bar
    configure_cursor_autostart
    configure_uv_supply_chain
  )

  if [[ "${ISC_APPLY_HOTKEYS_ONLY:-0}" == "1" ]]; then
    msg "=== LPS CONFIG-ONLY MODE ==="
    # In config-only mode, apply editor and autostart configuration.
    configure_continue || true
    configure_claude_status_bar || true
    configure_cursor_autostart || true
    configure_uv_supply_chain || true
  else
    for step in "${install_steps[@]}"; do
      "$step"
    done
  fi
  report_sudo_required
}

# Only run the main installer if the script is executed, not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_and_log_with_reboot "$@"
fi
