#!/usr/bin/env bash
# tmux_config.sh — tmux user configuration.
#
# Components:
#   - configure_tmux(): Install the repository's .tmux.conf into the target
#     user's home directory (mouse support, large scrollback, vi mode-keys).
#
# Sourced after lib/helpers.sh. Depends on: msg, log, run_as_target.
# Requires variables: TARGET_HOME, CONFIG_DIR.

# configure_tmux — Copy the repository's .tmux.conf into the target user's home
# directory so new tmux sessions inherit the shared defaults. The write goes
# through run_as_target so it lands in the user's home and ownership even when
# the installer runs as root; install -D makes it idempotent across repeated
# runs. tmux itself need not be installed for the config to be deployed safely.
# Arguments: none. Returns: exit status of the install command.
configure_tmux() {
  msg "Installing tmux configuration"
  log "info" "Deploying tmux config: $CONFIG_DIR/.tmux.conf -> $TARGET_HOME/.tmux.conf"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/.tmux.conf" \
    "$TARGET_HOME/.tmux.conf"
}
