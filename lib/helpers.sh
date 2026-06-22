#!/usr/bin/env bash
# helpers.sh — Programming-setup-specific logger.
#
# The shared install-time helpers (msg, need_cmd, is_root, run_as_target,
# ensure_session_bus, and the sudo-skip reporting) now live in the framework's
# installer_helpers.sh and are loaded by install.sh via isc_load_helpers (single
# source of truth: linux_installation_scripts_functions). This file keeps only
# this repository's logger, which is sourced before the shared helpers so they
# emit through it.
#
# Must be sourced after SCRIPT_DIR, CONFIG_DIR, TARGET_USER, TARGET_HOME,
# RUNTIME_DIR, DISPLAY_VAL, USER_BUS are set.

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
