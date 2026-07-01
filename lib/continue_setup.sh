#!/usr/bin/env bash
# continue_setup.sh — Continue editor configuration and its LM Studio
# autocomplete profile. The vibethinker model download is a separate component so
# the master installer can keep model installation selectable.
#
# Components:
#   - install_continue_config(): Deploy ~/.continue/config.yaml.
#   - ensure_lmstudio_vibethinker(): Separate component that installs only the
#     vibethinker model via linux_lmstudio_local_agents (the owner of LM Studio
#     serving).
#   - install_lmstudio_autocomplete_profile(): Deploy the LM Studio model profile.
#   - configure_continue(): Orchestrate the deployments.
#
# Sourced after lib/helpers.sh. Depends on: msg, log, run_as_target.
# Requires variables: TARGET_HOME, CONFIG_DIR, TARGET_USER.

LMSTUDIO_LOCAL_AGENTS_DIR="${LMSTUDIO_LOCAL_AGENTS_DIR:-${TARGET_HOME:-${HOME:-/tmp}}/projects/linux_lmstudio_local_agents}"
LMSTUDIO_LOCAL_AGENTS_REPO_URL="${LMSTUDIO_LOCAL_AGENTS_REPO_URL:-https://github.com/mikaeltorni/linux_lmstudio_local_agents.git}"

# ensure_continue_lmstudio_owner — resolve the public model-owner dependency for
# a standalone checkout. Existing checkouts are left untouched; a missing one
# is cloned non-interactively because selecting/configuring a model explicitly
# authorizes fetching that public dependency.
ensure_continue_lmstudio_owner() {
  [ -f "$LMSTUDIO_LOCAL_AGENTS_DIR/install.sh" ] && return 0
  INSTALLER_AUTH=1 ensure_linked_repository \
    "LM Studio local agents" "$LMSTUDIO_LOCAL_AGENTS_DIR" \
    "$LMSTUDIO_LOCAL_AGENTS_REPO_URL"
}

# resolve_continue_config_file — Resolve the selected Continue YAML file inside
# CONFIG_DIR. CONTINUE_CONFIG_NAME is the noninteractive override; interactive
# runs expose the default as editable text. Prints the validated source path.
resolve_continue_config_file() {
  local name="${CONTINUE_CONFIG_NAME:-continue/config.yaml}"
  if [[ -z "${CONTINUE_CONFIG_NAME+x}" ]] && { : </dev/tty; } 2>/dev/null; then
    read -r -e -i "$name" -p "Continue config in configs/: " name </dev/tty
  fi
  if [[ -z "$name" || "$name" = /* || "$name" = .. || "$name" = ../* || "$name" = */../* || "$name" = */.. ]]; then
    log "error" "Invalid Continue config name: $name"
    printf 'Continue config must be a relative file inside configs/.\n' >&2
    return 2
  fi
  printf '%s/%s\n' "$CONFIG_DIR" "$name"
}

# continue_model_override_file — path containing the persisted Continue model key.
continue_model_override_file() {
  printf '%s\n' "$TARGET_HOME/.config/linux-programming-setup/continue-autocomplete-model"
}

# continue_model_source_file — persisted one-line source collected by the
# nested component configurator before the install phase.
continue_model_source_file() {
  printf '%s\n' "$TARGET_HOME/.config/linux-programming-setup/continue-autocomplete-source"
}

# configure_custom_continue_model_source — collect and validate the single
# Hugging Face URL / owner-model-quant field shown from RIGHT in either menu.
# This only saves configuration; the component install performs the download.
configure_custom_continue_model_source() {
  local source="${CONTINUE_AUTOCOMPLETE_MODEL_SOURCE:-}"
  ensure_continue_lmstudio_owner || return 1
  local owner="$LMSTUDIO_LOCAL_AGENTS_DIR"
  if [ -z "$source" ] && [ -t 0 ] && [ -t 1 ]; then
    read -r -p "Hugging Face URL or owner/model@quant: " source </dev/tty
  fi
  [ -n "$source" ] || return 1
  if [ ! -f "$owner/scripts/lmstudio_models.py" ]; then
    log "error" "LM Studio model owner is unavailable at $owner"
    printf '%s\n' "Clone linux_lmstudio_local_agents beside this repository before configuring a custom model." >&2
    return 2
  fi
  python3 "$owner/scripts/lmstudio_models.py" profile-from-source \
    --catalog "$owner/configs/lmstudio/model-profiles.json" --source "$source" >/dev/null
  local source_file
  source_file="$(continue_model_source_file)"
  run_as_target mkdir -p "$(dirname "$source_file")"
  printf '%s\n' "$source" | run_as_target tee "$source_file" >/dev/null
  run_as_target chmod 0644 "$source_file"
  log "info" "Saved custom Continue model source for the install phase"
}

# is_valid_continue_model_key — accept model identifiers that are safe in YAML.
is_valid_continue_model_key() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/:+-]*$ ]]
}

# resolved_continue_model_key — explicit override, persisted choice, or default.
resolved_continue_model_key() {
  local model_key
  if [ -n "${CONTINUE_AUTOCOMPLETE_MODEL_KEY:-}" ]; then
    model_key="$CONTINUE_AUTOCOMPLETE_MODEL_KEY"
  elif [ -s "$(continue_model_override_file)" ]; then
    model_key="$(head -n 1 "$(continue_model_override_file)")"
  else
    model_key="vibethinker-1.5b"
  fi
  if ! is_valid_continue_model_key "$model_key"; then
    log "error" "Continue autocomplete model key contains unsupported characters"
    printf '%s\n' "Continue autocomplete model requires a valid model key (letters, digits, . _ / : + -)." >&2
    return 2
  fi
  printf '%s\n' "$model_key"
}

# install_continue_config — Copy the repository's Continue config.yaml into the
# target user's ~/.continue directory (creating it with 0644 perms).
install_continue_config() {
  local continue_dir="$TARGET_HOME/.continue" model_key config_file
  model_key="$(resolved_continue_model_key)"
  config_file="$(resolve_continue_config_file)" || return
  if [ ! -f "$config_file" ]; then
    log "error" "Continue config not found at $config_file"
    printf 'Continue config not found: %s\n' "$config_file" >&2
    return 2
  fi

  msg "Installing Continue configuration"
  log "info" "Deploying Continue config: $config_file -> $continue_dir/config.yaml"
  run_as_target install -D -m 0644 \
    "$config_file" \
    "$continue_dir/config.yaml"
  run_as_target python3 - "$continue_dir/config.yaml" "$model_key" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
model_key = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace("name: VibeThinker 1.5B LM Studio", f"name: {model_key} LM Studio")
text = text.replace("model: vibethinker-1.5b", f"model: {model_key}")
path.write_text(text, encoding="utf-8")
PY
}

# ensure_lmstudio_vibethinker — Install only the vibethinker model that Continue
# autocomplete depends on, via the linux_lmstudio_local_agents repository (the
# owner of LM Studio serving). Cloned alongside this repo under
# $TARGET_HOME/projects by the master installer; no-op (with a warning) when it
# is absent so a standalone programming-setup run never fails.
# Arguments: none. Requires variable: TARGET_USER, TARGET_HOME.
ensure_lmstudio_vibethinker() {
  local repo_dir="$LMSTUDIO_LOCAL_AGENTS_DIR"
  local installer="$repo_dir/install.sh"

  if ! ensure_continue_lmstudio_owner || [[ ! -f "$installer" ]]; then
    log "warn" "linux_lmstudio_local_agents not found at $repo_dir; skipping vibethinker model install."
    return 0
  fi

  msg "Installing the vibethinker autocomplete model via linux_lmstudio_local_agents"
  log "info" "Delegating to LM Studio local-agents installer (vibethinker model only)"
  TARGET_USER="$TARGET_USER" LMSTUDIO_ADD_MODELS="vibethinker" \
    bash "$installer" --select lm_studio_app,serve,models

  # Write receipt so the component framework detects this as installed
  _isc_mark_installed "continue_vibethinker_model" || log "warn" "receipt write failed for continue_vibethinker_model"
}

# install_custom_continue_autocomplete_model — prompt for or consume custom
# CONTINUE_AUTOCOMPLETE_MODEL_* fields, add a switch-free keep-on model through
# the LM Studio owner, and persist the model key used by Continue.
install_custom_continue_autocomplete_model() {
  local name="${CONTINUE_AUTOCOMPLETE_MODEL_NAME:-}"
  local model_key="${CONTINUE_AUTOCOMPLETE_MODEL_KEY:-}"
  local url="${CONTINUE_AUTOCOMPLETE_MODEL_URL:-}"
  local source="${CONTINUE_AUTOCOMPLETE_MODEL_SOURCE:-}"
  local sha256="${CONTINUE_AUTOCOMPLETE_MODEL_SHA256:-}"
  local installer="$LMSTUDIO_LOCAL_AGENTS_DIR/install.sh"
  if [ -z "$source" ] && [ -s "$(continue_model_source_file)" ]; then
    source="$(head -n 1 "$(continue_model_source_file)")"
  fi
  if [ -z "$source" ] && { [ -z "$model_key" ] || [ -z "$url" ]; } \
    && { : </dev/tty; } 2>/dev/null; then
    read -r -p "Hugging Face URL or owner/model@quant: " source </dev/tty
  fi
  if [ -n "$source" ]; then
    ensure_continue_lmstudio_owner || return 1
    local profile_json
    profile_json="$(python3 "$LMSTUDIO_LOCAL_AGENTS_DIR/scripts/lmstudio_models.py" \
      profile-from-source --catalog "$LMSTUDIO_LOCAL_AGENTS_DIR/configs/lmstudio/model-profiles.json" \
      --source "$source")" || return 2
    IFS=$'\t' read -r name model_key < <(printf '%s' "$profile_json" | python3 -c \
      'import json,sys; p=json.load(sys.stdin); print(p["description"]+"\t"+p["model_key"])')
  fi
  if [ -z "$source" ] && { [ -z "$model_key" ] || [ -z "$url" ]; }; then
    log "error" "Custom Continue model requires a Hugging Face source"
    printf '%s\n' "Enter a Hugging Face URL, or owner/model@quant when using catalog search." >&2
    return 2
  fi
  if ! is_valid_continue_model_key "$model_key"; then
    log "error" "Custom Continue model key contains unsupported characters"
    printf '%s\n' "Custom Continue model requires a valid model key (letters, digits, . _ / : + -)." >&2
    return 2
  fi
  [ -n "$name" ] || name="$model_key"
  if [ ! -f "$installer" ]; then
    log "error" "linux_lmstudio_local_agents not found at $installer"
    return 1
  fi
  msg "Installing custom Continue autocomplete model via linux_lmstudio_local_agents"
  TARGET_USER="$TARGET_USER" TARGET_HOME="$TARGET_HOME" \
    LMSTUDIO_ADD_CUSTOM_MODEL=1 \
    LMSTUDIO_CUSTOM_MODEL_NAME="$name" \
    LMSTUDIO_CUSTOM_MODEL_KEY="$model_key" \
    LMSTUDIO_CUSTOM_MODEL_URL="$url" \
    LMSTUDIO_CUSTOM_MODEL_SOURCE="$source" \
    LMSTUDIO_CUSTOM_MODEL_SHA256="$sha256" \
    LMSTUDIO_CUSTOM_MODEL_SWITCH_ENV_VAR="" \
    LMSTUDIO_CUSTOM_MODEL_ROLE="keep-on" \
    bash "$installer" --select lm_studio_app,serve,models
  local override_file
  override_file="$(continue_model_override_file)"
  run_as_target mkdir -p "$(dirname "$override_file")"
  printf '%s\n' "$model_key" | run_as_target tee "$override_file" >/dev/null
  run_as_target chmod 0644 "$override_file"
  CONTINUE_AUTOCOMPLETE_MODEL_KEY="$model_key" configure_continue
}

# install_lmstudio_autocomplete_profile — Deploy the LM Studio autocomplete
# profile and, if the shared LM Studio user service is already installed,
# restart it so the new profile takes effect immediately.
# Arguments: none. Returns: 0 (restart failures degrade to a warning).
install_lmstudio_autocomplete_profile() {
  local profile_dir="$TARGET_HOME/.config/linux-programming-setup/lmstudio" model_key
  local service_name="${LMSTUDIO_USER_SERVICE_NAME:-lmstudio-serve.service}"
  model_key="$(resolved_continue_model_key)"

  msg "Installing LM Studio autocomplete profile"
  log "info" "Deploying LM Studio profile: $CONFIG_DIR/lmstudio/autocomplete.env -> $profile_dir/autocomplete.env"
  run_as_target install -D -m 0644 \
    "$CONFIG_DIR/lmstudio/autocomplete.env" \
    "$profile_dir/autocomplete.env"
  run_as_target python3 - "$profile_dir/autocomplete.env" "$model_key" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
model_key = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace(
    'LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL="vibethinker-1.5b"',
    f'LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL="{model_key}"',
)
path.write_text(text, encoding="utf-8")
PY

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
# performed here; keep the continue_vibethinker_model component selected or use the standalone
# linux_lmstudio_local_agents models component when local autocomplete models
# should be installed.
# Arguments: none. Returns: 0 on success.
configure_continue() {
  log "info" "Configuring Continue (editor config + LM Studio autocomplete profile; model install is optional)"
  install_continue_config
  install_lmstudio_autocomplete_profile
}

# detect_continue_vibethinker_model — true when VibeThinker is selected and its
# downloaded weight exists at the path recorded by the LM Studio owner catalog.
detect_continue_vibethinker_model() {
  local catalog="$TARGET_HOME/.config/lmstudio-local-agents/configs/lmstudio/model-profiles.json"
  [ -f "$catalog" ] || return 1
  python3 - "$catalog" "$TARGET_HOME/.lmstudio/models" <<'PY'
import json
import sys
from pathlib import Path

catalog, models_dir = sys.argv[1:3]
try:
    profiles = json.load(open(catalog, encoding="utf-8")).get("profiles", [])
except (OSError, ValueError):
    raise SystemExit(1)
for profile in profiles:
    if profile.get("id") == "vibethinker" and profile.get("default_install"):
        raise SystemExit(
            0 if (Path(models_dir) / str(profile.get("model_path") or "")).is_file() else 1
        )
raise SystemExit(1)
PY
}

# detect_custom_continue_autocomplete_model — true when an override is persisted.
detect_custom_continue_autocomplete_model() {
  [ -s "$(continue_model_override_file)" ]
}

# uninstall_continue_vibethinker_model — Remove the LM Studio autocomplete profile and
# clear the install receipt. Does not delete model files (those are owned by
# linux_lmstudio_local_agents). After removal, the component framework will show
# this as uninstalled until re-selected.
uninstall_continue_vibethinker_model() {
  log "info" "Removing continue_vibethinker_model installation markers"
  local profile_dir="$TARGET_HOME/.config/linux-programming-setup/lmstudio/autocomplete.env"
  if [ -f "$profile_dir" ]; then
    rm -f "$profile_dir"
    log "info" "Removed LM Studio autocomplete env file"
  fi
  _isc_clear_receipt "continue_vibethinker_model" || true
}

# uninstall_custom_continue_autocomplete_model — reset Continue to VibeThinker.
# Downloaded weights remain under LM Studio ownership.
uninstall_custom_continue_autocomplete_model() {
  log "info" "Resetting Continue autocomplete to VibeThinker"
  run_as_target rm -f "$(continue_model_override_file)"
  CONTINUE_AUTOCOMPLETE_MODEL_KEY="vibethinker-1.5b" configure_continue
}
