#!/usr/bin/env bash
set -euo pipefail
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

# ── Configuration variables (can be overridden via environment) ───────────────
# Default is the newest Linux x64 .deb link published on https://cursor.com/download
# (currently v3.9). It redirects to the versioned build; curl -fL follows it.
# Override CURSOR_DEB_URL to pin a different version/build.
CURSOR_DEB_URL="${CURSOR_DEB_URL:-https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/3.9}"

# ── Runtime variables ────────────────────────────────────────────────────────
RUNTIME_DIR="/run/user/${TARGET_UID}"
DISPLAY_VAL="${DISPLAY:-:0}"
USER_BUS="unix:path=${RUNTIME_DIR}/bus"

# ── Library includes ────────────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/helpers.sh"   # repo logger (log); sourced before shared helpers

# Load the shared installer framework + shared install-time helpers (single
# source of truth in linux_installation_scripts_functions) before any library
# uses run_as_target/msg/need_cmd. No vendored copy: resolve a sibling checkout
# or download on demand.
for __isc_d in "${ISC_FUNCTIONS_DIR:-}" \
               "$SCRIPT_DIR/../linux_installation_scripts_functions" \
               "$HOME/projects/linux_installation_scripts_functions"; do
  [ -n "$__isc_d" ] && [ -f "$__isc_d/component_loader.sh" ] && { source "$__isc_d/component_loader.sh"; break; }
done
declare -F isc_load_helpers >/dev/null 2>&1 || \
  source <(curl -fsSL "https://raw.githubusercontent.com/mikaeltorni/linux_installation_scripts_functions/${ISC_FUNCTIONS_REF:-master}/component_loader.sh")
isc_load_helpers

source "$SCRIPT_DIR/lib/apt_helpers.sh"   # repo-specific apt_install (overrides shared)
source "$SCRIPT_DIR/lib/gsettings_helpers.sh"
source "$SCRIPT_DIR/lib/cursor_install.sh"
source "$SCRIPT_DIR/lib/continue_setup.sh"
source "$SCRIPT_DIR/lib/uv_supply_chain.sh"
source "$SCRIPT_DIR/lib/tmux_config.sh"
source "$SCRIPT_DIR/lib/lifecycle.sh"
source "$SCRIPT_DIR/lib/installer_runtime.sh"

# Component selection runtime and this repository's component manifest. The
# framework was already resolved above (for isc_load_helpers); activate the
# component runtime from the same checkout.
isc_activate_components
source "$SCRIPT_DIR/installer/components.sh"

# ── Main installer logic ────────────────────────────────────────────────────

# main_inner — Run the installation steps. In normal mode it requires root and
# runs every step in order; in config-only mode (ISC_APPLY_HOTKEYS_ONLY=1) it
# applies only editor/uv configuration, tolerating per-step
# failures. Arguments: $@ — forwarded but currently unused. Returns: 0 on
# success; aborts via set -e if a normal-mode step fails.
main_inner() {
  msg "=== Linux Programming Setup ==="
  
  # Feature-specific installation support (--features=feature1,feature2,...)  
  SELECTED_FEATURES="${FEATURES:-}"
  
  if [ -n "$SELECTED_FEATURES" ]; then
    IFS="," read -ra FEATURE_ARRAY <<< "$SELECTED_FEATURES"
    msg "Feature filter active: ${FEATURE_ARRAY[*]}"
    
    component_main "--select=${FEATURE_ARRAY[0]:-}"  
  else
    msg "Installing all configured components"  
    component_main "$@"
  fi
}

# Only run the main installer if the script is executed, not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Listing/help must print only their own output (the master installer parses
    # --list-components) and must not log or reboot.
    case "${1:-}" in
      --list-favorite-components) lps_list_favorite_components; exit $? ;;
      --list-startup-components) lps_list_startup_components; exit $? ;;
      --list-components|--detect|--help|-h|--uninstall|--uninstall=*) component_main "$@"; exit $? ;;
    esac
    run_and_log_with_reboot "$@"
fi
