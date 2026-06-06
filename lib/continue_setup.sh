#!/usr/bin/env bash
# Continue editor configuration and its LM Studio autocomplete profile.

install_continue_config() {
  local continue_dir="$TARGET_HOME/.continue"

  msg "Installing Continue configuration"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/continue/config.yaml" \
    "$continue_dir/config.yaml"
}

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
      msg "WARN: Could not restart $service_name; profile applies on next login."
  fi
}

configure_continue() {
  install_continue_config
  install_lmstudio_autocomplete_profile
}
