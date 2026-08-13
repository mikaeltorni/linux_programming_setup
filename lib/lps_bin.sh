#!/usr/bin/env bash
# lps_bin.sh — Resolve and invoke the lps-tools Rust helper.
#
# Sourced by lib/gsettings_helpers.sh after PROGRAMMING_GSETTINGS_LIB_DIR is set.
# Builds the binary on demand via scripts/build_lps_tools.sh.
#
# Public functions:
#   ensure_lps_bin  — build/locate dist/lps-tools; sets LPS_BIN
#   lps_bin         — ensure_lps_bin then run it with "$@"

# ensure_lps_bin — Locate or build dist/lps-tools; export LPS_BIN.
ensure_lps_bin() {
  local build_script bin root
  root="${SCRIPT_DIR:-$(cd "${PROGRAMMING_GSETTINGS_LIB_DIR:-.}/.." && pwd)}"
  build_script="$root/scripts/build_lps_tools.sh"
  if [ -n "${LPS_BIN:-}" ] && [ -x "$LPS_BIN" ]; then
    return 0
  fi
  if [ ! -x "$build_script" ]; then
    if declare -F msg >/dev/null 2>&1; then
      msg "Missing build helper: $build_script"
    else
      printf 'Missing build helper: %s\n' "$build_script" >&2
    fi
    return 1
  fi
  bin="$(bash "$build_script" --print)" || return 1
  LPS_BIN="$bin"
  export LPS_BIN
}

# lps_bin — Run the helper CLI.
lps_bin() {
  ensure_lps_bin || return 1
  "$LPS_BIN" "$@"
}
