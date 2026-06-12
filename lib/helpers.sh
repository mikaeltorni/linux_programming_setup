#!/usr/bin/env bash
# helpers.sh — Core utility functions sourced by install.sh
#
# Components:
#   - msg(msg): User-facing message with arrow prefix.
#   - need_cmd(cmd): Check if a command exists in PATH.
#   - run_as_target(cmd...): Execute a command as the target user.
#   - ensure_root(): Exit with error if not running as root.
#   - ensure_session_bus(): Exit with error if session bus is missing.
#   - log(level, msg): Centralized, timestamped, level-aware logger.
#
# Must be sourced after SCRIPT_DIR, CONFIG_DIR, TARGET_USER, TARGET_HOME,
# RUNTIME_DIR, DISPLAY_VAL, USER_BUS are set.

# ── User-facing messages ─────────────────────────────────────────────────────

msg() { printf "\n==> %s\n" "$*"; }

# ── Command availability check ───────────────────────────────────────────────

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ── Run as target user ───────────────────────────────────────────────────────

run_as_target() {
  if [ "$(id -un)" = "$TARGET_USER" ]; then
    env \
      HOME="$TARGET_HOME" \
      USER="$TARGET_USER" \
      LOGNAME="$TARGET_USER" \
      XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$USER_BUS" \
      DISPLAY="$DISPLAY_VAL" \
      "$@"
  else
    sudo -H -u "$TARGET_USER" env \
      HOME="$TARGET_HOME" \
      USER="$TARGET_USER" \
      LOGNAME="$TARGET_USER" \
      XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$USER_BUS" \
      DISPLAY="$DISPLAY_VAL" \
      "$@"
  fi
}

# ── Root privilege helpers ───────────────────────────────────────────────────

# is_root — Test whether the script runs with root privileges.
is_root() { [ "$(id -u)" -eq 0 ]; }

# Root-only steps skipped during a non-root run; reported at the end.
SUDO_REQUIRED_STEPS=()

# note_sudo_required — Record a skipped root-only step for the final report.
note_sudo_required() {
  SUDO_REQUIRED_STEPS+=("$1")
  msg "SKIP (requires sudo): $1"
}

# report_sudo_required — Print all root-only steps skipped this run, if any.
report_sudo_required() {
  [ "${#SUDO_REQUIRED_STEPS[@]}" -eq 0 ] && return 0
  msg "The following steps still require root and were skipped:"
  printf '    - %s\n' "${SUDO_REQUIRED_STEPS[@]}"
  msg "Apply them with: sudo bash install.sh"
}

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

# ── Logging ──────────────────────────────────────────────────────────────────

# log — Centralized, timestamped logger used across the installer libraries.
# Arguments:
#   $1   level — one of: verbose, debug, info, warn, error. Unknown values are
#                printed verbatim as the level label.
#   $@   message — the remaining arguments form the log message.
# Behaviour:
#   - Prefixes every line with an ISO-8601 timestamp and an uppercase level.
#   - Routes warn/error to stderr; everything else to stdout.
# Returns: always 0.
log() {
  local level="$1"; shift
  local ts
  ts="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  case "$level" in
    error) printf "%s [ERROR] %s\n"   "$ts" "$*" >&2 ;;
    warn)  printf "%s [WARN] %s\n"    "$ts" "$*" >&2 ;;
    info)  printf "%s [INFO] %s\n"    "$ts" "$*" ;;
    debug) printf "%s [DEBUG] %s\n"   "$ts" "$*" ;;
    verbose) printf "%s [VERBOSE] %s\n" "$ts" "$*" ;;
    *)     printf "%s [%s] %s\n" "$ts" "$level" "$*" ;;
  esac
}
