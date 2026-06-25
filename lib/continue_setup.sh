#!/usr/bin/env bash
# continue_setup.sh — Continue editor configuration and its LM Studio
# autocomplete profile. The qwen-coder model download is a separate component so
# the master installer can keep model installation selectable.
#
# Components:
#   - install_continue_config(): Deploy ~/.continue/config.yaml.
#   - ensure_lmstudio_qwen_coder(): Separate component that installs only the
#     qwen-coder model via linux_lmstudio_local_agents (the owner of LM Studio
#     serving).
#   - install_lmstudio_autocomplete_profile(): Deploy the LM Studio model profile.
#   - configure_continue(): Orchestrate the deployments.
#
# Sourced after lib/helpers.sh. Depends on: msg, log, run_as_target.
# Requires variables: TARGET_HOME, CONFIG_DIR, TARGET_USER.

# install_continue_config — Copy the repository's Continue config.yaml into the
# target user's ~/.continue directory (creating it with 0644 perms).
# Arguments: none. Returns: exit status of the install command.
install_continue_config() {
  local continue_dir="$TARGET_HOME/.continue"

  msg "Installing Continue configuration"
  log "info" "Deploying Continue config: $CONFIG_DIR/continue/config.yaml -> $continue_dir/config.yaml"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/continue/config.yaml" \
    "$continue_dir/config.yaml"
}

# ensure_lmstudio_qwen_coder — Install only the qwen-coder model that Continue
# autocomplete depends on, via the linux_lmstudio_local_agents repository (the
# owner of LM Studio serving). Cloned alongside this repo under
# $TARGET_HOME/projects by the master installer; no-op (with a warning) when it
# is absent so a standalone programming-setup run never fails.
# Arguments: none. Requires variable: TARGET_USER, TARGET_HOME.
ensure_lmstudio_qwen_coder() {
  local repo_dir="$TARGET_HOME/projects/linux_lmstudio_local_agents"
  local installer="$repo_dir/install.sh"

  if [[ ! -f "$installer" ]]; then
    log "warn" "linux_lmstudio_local_agents not found at $repo_dir; skipping qwen-coder model install."
    return 0
  fi

  msg "Installing the qwen-coder autocomplete model via linux_lmstudio_local_agents"
  log "info" "Delegating to LM Studio local-agents installer (qwen-coder model only)"
  TARGET_USER="$TARGET_USER" LMSTUDIO_ADD_MODELS="qwen-coder" \
    bash "$installer" --select lm_studio_app,serve,models
}

# install_lmstudio_autocomplete_profile — Deploy the LM Studio autocomplete
# profile and, if the shared LM Studio user service is already installed,
# restart it so the new profile takes effect immediately.
# Arguments: none. Returns: 0 (restart failures degrade to a warning).
install_lmstudio_autocomplete_profile() {
  local profile_dir="$TARGET_HOME/.config/linux-programming-setup/lmstudio"
  local service_name="${LMSTUDIO_USER_SERVICE_NAME:-lmstudio-serve.service}"

  msg "Installing LM Studio autocomplete profile"
  log "info" "Deploying LM Studio profile: $CONFIG_DIR/lmstudio/autocomplete.env -> $profile_dir/autocomplete.env"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/lmstudio/autocomplete.env" \
    "$profile_dir/autocomplete.env"

  # linux_lmstudio_local_agents owns the shared LM Studio service. Restart it
  # when it is already installed so a standalone programming-setup run takes
  # effect.
  if [ -f "$TARGET_HOME/.config/systemd/user/$service_name" ]; then
    log "info" "Restarting $service_name to apply the new autocomplete profile"
    run_as_target systemctl --user restart "$service_name" || \
      log "warn" "Could not restart $service_name; profile applies on next login."
  fi
}

# configure_continue — Entry point: install the Continue editor config and the
# LM Studio autocomplete profile in order. Model downloads are intentionally not
# performed here; keep the continue_qwen_model component selected or use the standalone
# linux_lmstudio_local_agents models component when local autocomplete models
# should be installed.
# Arguments: none. Returns: 0 on success.
configure_continue() {
  log "info" "Configuring Continue (editor config + LM Studio autocomplete profile; model install is optional)"
  install_continue_config
  install_lmstudio_autocomplete_profile
}
