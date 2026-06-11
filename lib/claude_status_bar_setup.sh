#!/usr/bin/env bash
# Claude Code status bar configuration.
#
# The status bar lives in its own repository (claude_code_status_bar), cloned
# alongside this one under $TARGET_HOME/projects by the master installer. Here
# we simply delegate to that repository's idempotent install.sh, which copies
# the status-line script into ~/.claude and wires it into settings.json.

# configure_claude_status_bar — Run the claude_code_status_bar installer for the
#   target user. No-op (with a warning) when the repository is not present, so a
#   standalone programming-setup run never fails on a missing optional repo.
# Arguments: none. Requires variable: TARGET_USER, TARGET_HOME.
# Returns: 0 when configured or safely skipped; the installer's status otherwise.
configure_claude_status_bar() {
  local repo_dir="$TARGET_HOME/projects/claude_code_status_bar"
  local installer="$repo_dir/install.sh"

  if [[ ! -f "$installer" ]]; then
    log "warn" "claude_code_status_bar not found at $repo_dir; skipping status bar."
    return 0
  fi

  msg "Configuring Claude Code status bar"
  TARGET_USER="$TARGET_USER" bash "$installer"
}
