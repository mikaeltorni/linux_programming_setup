#!/usr/bin/env bash
# cursor_install.sh — Cursor IDE installation and VS Code extension management
#
# Components:
#   - install_cursor(): Download and install Cursor IDE from .deb package.
#   - install_cursor_extensions(): Install extensions listed in CURSOR_EXTENSIONS_FILE.
#
# Sourced after lib/helpers.sh and lib/apt_helpers.sh.
# Depends on: msg, need_cmd, apt_install, log, run_as_target.
# Requires variables: CURSOR_DEB_URL, CONFIG_DIR, TARGET_HOME, TARGET_USER.

# ── Cursor IDE ───────────────────────────────────────────────────────────────

# install_cursor — Download and install Cursor IDE from a .deb package.
# Arguments: none.
# Requires variable: CURSOR_DEB_URL — optional full URL to the Cursor .deb file.
#   When unset, the package step is skipped so the remaining programming
#   components can still configure cleanly on machines that install Cursor
#   separately.
# Returns: 0 when Cursor is already present, deferred for sudo, or installed
#   successfully; non-zero only when an explicit download/install fails.
install_cursor() {
  if need_cmd cursor; then
    log "info" "Cursor IDE already present, skipping installation"
    return
  fi

  if ! is_root; then
    note_sudo_required "install Cursor IDE .deb (apt install)"
    return 0
  fi

  # CURSOR_DEB_URL is optional because Cursor's current distribution URL changes
  # over time. An unset URL should not abort the rest of the component run.
  if [ -z "${CURSOR_DEB_URL:-}" ]; then
    log "warn" "CURSOR_DEB_URL is not set; skipping Cursor IDE package install. Set it and rerun this component to install Cursor."
    return 0
  fi

  msg "Installing Cursor IDE"
  log "info" "Installing Cursor IDE from $CURSOR_DEB_URL"
  apt_install curl wget

  local tmpdir="/tmp/cursor-install"
  rm -rf "$tmpdir"
  mkdir -p "$tmpdir"

  # Download the .deb package
  curl -fL "$CURSOR_DEB_URL" -o "$tmpdir/cursor.deb"

  # Install the .deb package
  if ! apt install -y "$tmpdir/cursor.deb"; then
    log "error" "Failed to install Cursor IDE from $CURSOR_DEB_URL. Check network connectivity and try again."
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
  msg "Cursor IDE installed successfully"
  log "info" "Cursor IDE installed successfully"
}

# ── Cursor Extensions ────────────────────────────────────────────────────────

# resolve_cursor_extensions_file — Resolve the selected extension-list name
# inside CONFIG_DIR. CURSOR_EXTENSIONS_CONFIG provides a noninteractive
# override; an interactive run offers the repository default as editable text.
# Absolute paths and parent traversal are rejected so installer selection stays
# limited to committed configuration assets. Prints the resolved path.
resolve_cursor_extensions_file() {
  local name="${CURSOR_EXTENSIONS_CONFIG:-vsc_cursor_extensions}"
  if [[ -z "${CURSOR_EXTENSIONS_CONFIG+x}" ]] && { : </dev/tty; } 2>/dev/null; then
    read -r -e -i "$name" -p "Cursor extension config in configs/: " name </dev/tty
  fi
  if [[ -z "$name" || "$name" = /* || "$name" = .. || "$name" = ../* || "$name" = */../* || "$name" = */.. ]]; then
    log "error" "Invalid Cursor extension config name: $name"
    printf 'Cursor extension config must be a relative file inside configs/.\n' >&2
    return 2
  fi
  printf '%s/%s\n' "$CONFIG_DIR" "$name"
}

# install_cursor_extensions — Install every extension listed in
#   the selected config file (one extension ID per line, e.g. "ms-python.python";
#   blank lines and lines starting with '#' are ignored). Each extension is
#   installed as the target user via run_as_target.
# Arguments: none.
# Requires variable: CONFIG_DIR — directory containing extension-list files.
# Returns: 0 when the list is installed or safely skipped (file missing); a
#   per-extension failure degrades to a warning and does not abort the loop.
install_cursor_extensions() {
  local extensions_file
  extensions_file="$(resolve_cursor_extensions_file)" || return
  if [ ! -f "$extensions_file" ]; then
    log "error" "Cursor extensions file not found at $extensions_file"
    printf 'Cursor extension config not found: %s\n' "$extensions_file" >&2
    return 2
  fi

  msg "Installing Cursor extensions from $extensions_file"
  log "info" "Installing Cursor extensions from $extensions_file"
  while IFS= read -r ext_id; do
    # Skip empty lines and comments
    [[ -z "$ext_id" || "$ext_id" =~ ^# ]] && continue
    log "info" "Installing Cursor extension: $ext_id"
    run_as_target cursor --install-extension "$ext_id" 2>/dev/null || \
      log "warn" "Failed to install Cursor extension: $ext_id"
  done < "$extensions_file"
  msg "Cursor extensions installation complete"
  log "info" "Cursor extensions installation complete"
}
