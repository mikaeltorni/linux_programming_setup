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

# Component selection runtime and this repository's component manifest.
# Load the shared installer component framework. Its single source of truth is
# the linux_installation_scripts_functions repository (cloned as a sibling by
# installation_scripts, or downloaded on demand) -- no per-repo vendored copy.
for __isc_d in "${ISC_FUNCTIONS_DIR:-}" \
               "$SCRIPT_DIR/../linux_installation_scripts_functions" \
               "$HOME/projects/linux_installation_scripts_functions"; do
  [ -n "$__isc_d" ] && [ -f "$__isc_d/component_loader.sh" ] && { source "$__isc_d/component_loader.sh"; break; }
done
declare -F isc_activate_components >/dev/null 2>&1 || \
  source <(curl -fsSL "https://raw.githubusercontent.com/mikaeltorni/linux_installation_scripts_functions/${ISC_FUNCTIONS_REF:-master}/component_loader.sh")
isc_activate_components
source "$SCRIPT_DIR/installer/components.sh"

# ── Main installer logic ────────────────────────────────────────────────────

# main_inner — Run the installation steps. In normal mode it requires root and
# runs every step in order; in config-only mode (ISC_APPLY_HOTKEYS_ONLY=1) it
# applies only the editor/autostart/uv configuration, tolerating per-step
# failures. Arguments: $@ — forwarded but currently unused. Returns: 0 on
# success; aborts via set -e if a normal-mode step fails.
main_inner() {
  if [[ "${ISC_APPLY_HOTKEYS_ONLY:-0}" == "1" ]]; then
    ensure_session_bus
    msg "=== LPS CONFIG-ONLY MODE ==="
    # In config-only mode, apply editor and autostart configuration.
    configure_continue || true
    configure_claude_status_bar || true
    configure_cursor_autostart || true
    configure_uv_supply_chain || true
    report_sudo_required
    return 0
  fi

  # Normal mode: install the selected components (preflight ensures the session
  # bus; postflight reports any skipped root-only steps).
  component_main "$@"
}

# Only run the main installer if the script is executed, not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Listing/help must print only their own output (the master installer parses
    # --list-components) and must not log or reboot.
    case "${1:-}" in
      --list-components|--help|-h) component_main "$@"; exit $? ;;
    esac
    run_and_log_with_reboot "$@"
fi
