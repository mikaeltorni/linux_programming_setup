#!/usr/bin/env bash
# Check Continue's public shell entrypoints with native helpers and Python trapped.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$(bash "$SCRIPT_DIR/scripts/build_lps_tools.sh" --bin continue-tools --print)"
[[ "$bin" == "$SCRIPT_DIR/dist/continue-tools" && -x "$bin" ]]
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
TARGET_HOME="$fixture/home"
CONFIG_DIR="$SCRIPT_DIR/configs"
CONTINUE_CONFIG_NAME=continue/config.yaml
CONTINUE_AUTOCOMPLETE_MODEL_KEY=custom-model
mkdir -p "$TARGET_HOME" "$fixture/traps"
printf '#!/bin/bash\nexit 95\n' > "$fixture/traps/python3"
chmod +x "$fixture/traps/python3"
export PATH="$fixture/traps:$PATH"
# Suppress unrelated installer diagnostics in this isolated configuration check.
# Parameters: diagnostic arguments. Returns: zero without output.
msg() { :; }
# Suppress existing structured diagnostics.
# Parameters: level and message. Returns: zero without output.
log() { :; }
# Invoke commands in this test's isolated target paths.
# Parameters: command and arguments. Returns: the command status/output.
run_as_target() { "$@"; }
source "$SCRIPT_DIR/lib/continue_setup.sh"
for round in 1 2; do
  configure_continue
  grep -qF 'model: custom-model' "$TARGET_HOME/.continue/config.yaml"
  grep -qF 'LMSTUDIO_AUTOCOMPLETE_LOAD_MODEL="custom-model"' "$TARGET_HOME/.config/linux-programming-setup/lmstudio/autocomplete.env"
done
[[ "$(sha256sum "$TARGET_HOME/.continue/config.yaml" | cut -d ' ' -f 1)" == 24a8779d2fb2257dd72f26f138b1d87d23a0392b2c2f9f3764d7d98f628be9c7 ]]
[[ "$(sha256sum "$TARGET_HOME/.config/linux-programming-setup/lmstudio/autocomplete.env" | cut -d ' ' -f 1)" == 2dd43eaad00010b9d40abde217d09f0df2331c694489e10c8d188b1decb19101 ]]
catalog="$TARGET_HOME/.config/lmstudio-local-agents/configs/lmstudio/model-profiles.json"
mkdir -p "$(dirname "$catalog")" "$TARGET_HOME/.lmstudio/models/owner"
printf '{"profiles":[{"id":"vibethinker","default_install":true,"model_path":"owner/model.gguf"}]}' > "$catalog"
printf 'synthetic weight' > "$TARGET_HOME/.lmstudio/models/owner/model.gguf"
detect_continue_vibethinker_model
rm "$TARGET_HOME/.lmstudio/models/owner/model.gguf"
if detect_continue_vibethinker_model; then exit 1; fi
# Use the model owner's real native source parser; replace only its installer
# so this fixture cannot download a weight or start a service.
common_git="$(git -C "$SCRIPT_DIR" rev-parse --path-format=absolute --git-common-dir)"
owner="${CONTINUE_TEST_LM_OWNER:-$(dirname "$(dirname "$common_git")")/linux_lmstudio_local_agents}"
owner="$(cd "$owner" && pwd)"
LMSTUDIO_LOCAL_AGENTS_DIR="$fixture/model-owner"
mkdir -p "$LMSTUDIO_LOCAL_AGENTS_DIR/lib"
mkdir -p "$LMSTUDIO_LOCAL_AGENTS_DIR/configs/lmstudio"
cp "$owner/configs/lmstudio/model-profiles.json" "$LMSTUDIO_LOCAL_AGENTS_DIR/configs/lmstudio/model-profiles.json"
ln -s "$owner/lib/lm_studio.sh" "$LMSTUDIO_LOCAL_AGENTS_DIR/lib/lm_studio.sh"
export LMLA_MODELS_CLI="$owner/target/release/lmstudio-models"
export CONTINUE_TEST_CAPTURE="$fixture/model-install"
cat > "$LMSTUDIO_LOCAL_AGENTS_DIR/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '--select lm_studio_app,serve,models' ]]
[[ "$LMSTUDIO_CUSTOM_MODEL_ROLE" == keep-on && -z "$LMSTUDIO_CUSTOM_MODEL_SWITCH_ENV_VAR" ]]
printf '%s\n' "$LMSTUDIO_CUSTOM_MODEL_NAME" "$LMSTUDIO_CUSTOM_MODEL_KEY" "$LMSTUDIO_CUSTOM_MODEL_SOURCE" > "$CONTINUE_TEST_CAPTURE"
EOF
TARGET_USER="$(id -un)"
CONTINUE_AUTOCOMPLETE_MODEL_SOURCE=https://huggingface.co/acme/model/resolve/main/Model-Q4.gguf
configure_custom_continue_model_source
[[ "$(cat "$(continue_model_source_file)")" == "$CONTINUE_AUTOCOMPLETE_MODEL_SOURCE" ]]
install_custom_continue_autocomplete_model
[[ "$(cat "$CONTINUE_TEST_CAPTURE")" == "$(printf 'Model-Q4\nmodel-q4\n%s' "$CONTINUE_AUTOCOMPLETE_MODEL_SOURCE")" ]]
[[ "$(cat "$(continue_model_override_file)")" == model-q4 ]]
grep -qF 'model: model-q4' "$TARGET_HOME/.continue/config.yaml"
# Standalone probes require no installer runner.
unset -f run_as_target
printf 'synthetic weight' > "$TARGET_HOME/.lmstudio/models/owner/model.gguf"
detect_continue_vibethinker_model
printf 'Continue config/environment and selected weight queries use native helpers\n'
