#!/usr/bin/env bash
# cursor_install.sh — Cursor IDE installation and VS Code extension management
#
# Components:
#   - install_cursor(): Download and install Cursor IDE from .deb package.
#   - install_cursor_extensions(): Install extensions listed in CURSOR_EXTENSIONS_FILE.
#
# Sourced after lib/helpers.sh and lib/apt_helpers.sh.
# Depends on: msg, need_cmd, apt_install, log, run_as_target.
# Requires variables: CURSOR_DEB_URL, CURSOR_EXTENSIONS_FILE, TARGET_HOME, TARGET_USER

# ── Cursor IDE ───────────────────────────────────────────────────────────────

# install_cursor — Download and install Cursor IDE from .deb package.
# Requires: CURSOR_DEB_URL (full URL to the .deb file)

install_cursor() {
  if need_cmd cursor; then
    return
  fi

  if ! is_root; then
    note_sudo_required "install Cursor IDE .deb (apt install)"
    return 0
  fi

  msg "Installing Cursor IDE"
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
}

# ── Cursor Extensions ────────────────────────────────────────────────────────

# install_cursor_extensions — Install extensions listed in CURSOR_EXTENSIONS_FILE.
# Each line in the file should contain an extension ID (e.g., "ms-python.python").
# Runs as the target user via run_as_target.

install_cursor_extensions() {
  if [ ! -f "$CURSOR_EXTENSIONS_FILE" ]; then
    log "warn" "Cursor extensions file not found at $CURSOR_EXTENSIONS_FILE, skipping"
    return 0
  fi

  msg "Installing Cursor extensions from $CURSOR_EXTENSIONS_FILE"
  while IFS= read -r ext_id; do
    # Skip empty lines and comments
    [[ -z "$ext_id" || "$ext_id" =~ ^# ]] && continue
    run_as_target cursor --install-extension "$ext_id" 2>/dev/null || \
      log "warn" "Failed to install Cursor extension: $ext_id"
  done < "$CURSOR_EXTENSIONS_FILE"
  msg "Cursor extensions installation complete"
}
