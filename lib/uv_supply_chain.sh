#!/usr/bin/env bash
# Global UV supply-chain protection — installs the machine-wide uv.toml that
# enforces a rolling 24-hour package-publication delay for every project.

configure_uv_supply_chain() {
  local uv_config_dir="$TARGET_HOME/.config/uv"

  msg "Installing global UV supply-chain config (rolling 24-hour cutoff)"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/uv/uv.toml" \
    "$uv_config_dir/uv.toml"
}
