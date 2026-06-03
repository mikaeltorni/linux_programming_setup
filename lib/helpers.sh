#!/usr/bin/env bash
# helpers.sh — Core utility functions sourced by install.sh
#
# Components:
#   - msg(msg): User-facing message with arrow prefix.
#   - need_cmd(cmd): Check if a command exists in PATH.
#   - run_as_target(cmd...): Execute a command as the target user.
#   - ensure_root(): Exit with error if not running as root.
#   - ensure_session_bus(): Exit with error if session bus is missing.
#
# Must be sourced after SCRIPT_DIR, CONFIG_DIR, TARGET_USER, TARGET_HOME,
# RUNTIME_DIR, DISPLAY_VAL, USER_BUS are set.

# ── User-facing messages ─────────────────────────────────────────────────────

msg() { printf "\n==> %s\n" "$*"; }

# ── Command availability check ───────────────────────────────────────────────

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ── Run as target user ───────────────────────────────────────────────────────

run_as_target() {
  sudo -H -u "$TARGET_USER" env \
    HOME="$TARGET_HOME" \
    USER="$TARGET_USER" \
    LOGNAME="$TARGET_USER" \
    XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$USER_BUS" \
    DISPLAY="$DISPLAY_VAL" \
    "$@"
}

# ── Root privilege check ─────────────────────────────────────────────────────

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "error" "Please run with sudo: sudo bash $0"
    echo "Please run with sudo: sudo bash $0"
    exit 1
  fi
}

# ── Session bus check ────────────────────────────────────────────────────────

ensure_session_bus() {
  if [ ! -S "${RUNTIME_DIR}/bus" ]; then
    log "error" "No user session bus at ${RUNTIME_DIR}/bus"
    cat <<EOF
No user session bus at ${RUNTIME_DIR}/bus.
Open a terminal in ${TARGET_USER}'s *logged-in desktop* session and run:
  sudo bash $0
EOF
    exit 1
  fi
}

# ── Logging (minimal) ────────────────────────────────────────────────────────

log() {
  local level="$1"; shift
  case "$level" in
    error) echo "ERROR: $*" >&2 ;;
    warn)  echo "WARN: $*" >&2 ;;
    *)     echo "$level: $*" ;;
  esac
}
