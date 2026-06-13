#!/usr/bin/env bash
# apt_helpers.sh — Root-optional APT package installation helpers.
#
# Components:
#   - apt_install(pkg): Install an APT package when its command is unavailable.
#
# Sourced after lib/helpers.sh.
# Depends on: need_cmd, is_root, note_sudo_required, log.

# apt_install — Install an APT package, skipping the work when its command-line
# entry point already exists on PATH (idempotent).
# Arguments: $1 pkg — package name, which is also assumed to be the command name.
# Returns: 0 if already present, deferred for sudo, or installed successfully;
# non-zero on apt error.
apt_install() {
  local pkg="$1"
  if need_cmd "$pkg"; then
    log "info" "Package '$pkg' already present, skipping apt install"
    return 0
  fi
  if ! is_root; then
    note_sudo_required "apt install $pkg"
    return 0
  fi
  log "info" "Installing APT package: $pkg"
  apt update -y && apt install -y "$pkg"
}
