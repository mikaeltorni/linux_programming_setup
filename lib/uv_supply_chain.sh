#!/usr/bin/env bash
# uv_supply_chain.sh — Global UV supply-chain protection.
#
# Components:
#   - configure_uv_supply_chain(): Install the machine-wide uv.toml that enforces
#     a rolling 24-hour package-publication delay for every project.
#
# Sourced after lib/helpers.sh. Depends on: msg, run_as_target.
# Requires variables: TARGET_HOME, CONFIG_DIR.

# configure_uv_supply_chain — Copy the repository's uv.toml into the target
# user's ~/.config/uv so every uv invocation inherits the 24-hour cutoff.
# Arguments: none. Returns: exit status of the install command.
configure_uv_supply_chain() {
  local uv_config_dir="$TARGET_HOME/.config/uv"

  msg "Installing global UV supply-chain config (rolling 24-hour cutoff)"
  log "info" "Deploying UV config: $CONFIG_DIR/uv/uv.toml -> $uv_config_dir/uv.toml"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/uv/uv.toml" \
    "$uv_config_dir/uv.toml"
}
