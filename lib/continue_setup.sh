#!/usr/bin/env bash
# continue_setup.sh — Continue editor configuration and its LM Studio
# autocomplete profile.
#
# Components:
#   - install_continue_config(): Deploy ~/.continue/config.yaml.
#   - install_lmstudio_autocomplete_profile(): Deploy the LM Studio model profile.
#   - configure_continue(): Orchestrate both deployments.
#
# Sourced after lib/helpers.sh. Depends on: msg, log, run_as_target.
# Requires variables: TARGET_HOME, CONFIG_DIR.

# install_continue_config — Copy the repository's Continue config.yaml into the
# target user's ~/.continue directory (creating it with 0644 perms).
# Arguments: none. Returns: exit status of the install command.
install_continue_config() {
  local continue_dir="$TARGET_HOME/.continue"

  msg "Installing Continue configuration"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/continue/config.yaml" \
    "$continue_dir/config.yaml"
}

# install_lmstudio_autocomplete_profile — Deploy the LM Studio autocomplete
# profile and, if the shared LM Studio user service is already installed,
# restart it so the new profile takes effect immediately.
# Arguments: none. Returns: 0 (restart failures degrade to a warning).
install_lmstudio_autocomplete_profile() {
  local profile_dir="$TARGET_HOME/.config/linux-programming-setup/lmstudio"
  local service_name="${LMSTUDIO_USER_SERVICE_NAME:-lmstudio-serve.service}"

  msg "Installing LM Studio autocomplete profile"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/lmstudio/autocomplete.env" \
    "$profile_dir/autocomplete.env"

  # Agent Command Center owns the shared LM Studio service. Restart it when it
  # is already installed so a standalone programming-setup run takes effect.
  if [ -f "$TARGET_HOME/.config/systemd/user/$service_name" ]; then
    run_as_target systemctl --user restart "$service_name" || \
      log "warn" "Could not restart $service_name; profile applies on next login."
  fi
}

# configure_continue — Entry point: install the Continue editor config and the
# LM Studio autocomplete profile in order.
# Arguments: none. Returns: 0 on success.
configure_continue() {
  install_continue_config
  install_lmstudio_autocomplete_profile
}
