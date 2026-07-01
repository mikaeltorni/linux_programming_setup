#!/usr/bin/env bash
# components.sh - Component manifest for linux_programming_setup.
#
# Maps each developer-tooling component to the install_*/configure_* function
# (defined in lib/) that performs it. install.sh sources the lib files first,
# then this manifest, then routes execution through component_main from
# component_runtime.sh.
#
# Entry format: "id|label|default(on/off)|function".

ISC_REPO_NAME="linux_programming_setup"
ISC_REPO_LABEL="Programming tools and editors"

ISC_PREFLIGHT="ensure_session_bus"
ISC_POSTFLIGHT="report_sudo_required"

ISC_COMPONENTS=(
  "continue_vibethinker_model|Continue VibeThinker autocomplete model|on|ensure_lmstudio_vibethinker|detect_continue_vibethinker_model|uninstall_continue_vibethinker_model|Models"
  "continue_custom_model|Custom Continue autocomplete model (enter GGUF URL)|off|install_custom_continue_autocomplete_model|detect_custom_continue_autocomplete_model|uninstall_custom_continue_autocomplete_model|Models"
  "cursor|Cursor IDE|on|install_cursor|detect_cursor|uninstall_cursor|Desktop applications"
  "cursor_extensions|Cursor extensions (default: vsc_cursor_extensions)|on|install_cursor_extensions|detect_cursor_extensions|uninstall_cursor_extensions|Programming tools|cursor"
  "continue|Continue AI assistant config (default: continue/config.yaml)|on|configure_continue|detect_continue|uninstall_continue|Programming tools|cursor"
  "tmux|tmux configuration|on|configure_tmux|detect_tmux|uninstall_tmux|Programming tools"
)

# lps_list_favorite_components - Publish Cursor as a dock-favorite candidate.
# Output: component id<TAB>comma-separated desktop ids.
lps_list_favorite_components() {
  printf 'cursor\tcursor.desktop\n'
}

# lps_list_startup_components - Print GUI components whose login startup is
# controlled by the master installer's [S] action.
# Output: component id<TAB>desktop candidates<TAB>default selection.
lps_list_startup_components() {
  printf 'cursor\tcursor.desktop\ton\n'
}
