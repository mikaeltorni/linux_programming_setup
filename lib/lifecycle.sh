#!/usr/bin/env bash
# lifecycle.sh - Detection and uninstall functions for the programming-setup
# components. detect_* report live state for --detect; uninstall_* reverse each
# install. The shared runtime clears each component's receipt after a successful
# uninstall.

# detect_cursor - true when the Cursor IDE package/binary is present.
detect_cursor() {
  run_as_target bash -lc 'command -v cursor >/dev/null 2>&1' || dpkg -s cursor >/dev/null 2>&1
}

# detect_cursor_extensions - true when the Cursor extensions dir holds entries.
detect_cursor_extensions() {
  local d="$TARGET_HOME/.cursor/extensions"
  [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]
}

# detect_continue - true when the Continue assistant config is deployed.
detect_continue() { [ -f "$TARGET_HOME/.continue/config.yaml" ]; }

# detect_uv_supply_chain - true when the machine-wide uv.toml cutoff is deployed.
detect_uv_supply_chain() { [ -f "$TARGET_HOME/.config/uv/uv.toml" ]; }

# detect_tmux - true when the repo tmux config is deployed.
detect_tmux() { [ -f "$TARGET_HOME/.tmux.conf" ]; }

# uninstall_cursor - remove the Cursor IDE package (root).
uninstall_cursor() {
  if [ "$(id -u)" -ne 0 ]; then
    msg "SKIP (requires sudo): apt remove cursor — run: sudo apt remove cursor"
    return 0
  fi
  msg "Removing Cursor IDE package"
  DEBIAN_FRONTEND=noninteractive apt remove -y cursor 2>/dev/null || true
}

# uninstall_cursor_extensions - uninstall every extension listed in the file.
uninstall_cursor_extensions() {
  local extensions_file
  extensions_file="$(resolve_cursor_extensions_file)" || return
  [ -f "$extensions_file" ] || { msg "No Cursor extensions list; nothing to remove"; return 0; }
  msg "Uninstalling Cursor extensions listed in $extensions_file"
  local ext
  while IFS= read -r ext; do
    ext="${ext%%#*}"; ext="$(printf '%s' "$ext" | tr -d '[:space:]')"
    [ -z "$ext" ] && continue
    run_as_target cursor --uninstall-extension "$ext" 2>/dev/null || true
  done < "$extensions_file"
}

# uninstall_continue - remove the deployed Continue config.
uninstall_continue() {
  msg "Removing Continue config"
  run_as_target rm -f "$TARGET_HOME/.continue/config.yaml"
}

# uninstall_uv_supply_chain - remove the machine-wide uv.toml cutoff config.
uninstall_uv_supply_chain() {
  msg "Removing UV supply-chain config"
  run_as_target rm -f "$TARGET_HOME/.config/uv/uv.toml"
}

# uninstall_tmux - remove the deployed tmux config.
uninstall_tmux() {
  msg "Removing tmux config"
  run_as_target rm -f "$TARGET_HOME/.tmux.conf"
}
