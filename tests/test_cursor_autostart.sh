#!/usr/bin/env bash
# test_cursor_autostart.sh - Cursor master-menu startup metadata contract.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

startup_output="$(bash "$ROOT_DIR/install.sh" --list-startup-components)"
[ "$startup_output" = $'cursor\tcursor.desktop\ton\t2' ] || {
  printf 'FAIL: Cursor startup metadata mismatch: %q\n' "$startup_output" >&2
  exit 1
}

favorite_output="$(bash "$ROOT_DIR/install.sh" --list-favorite-components)"
[ "$favorite_output" = $'cursor\tcursor.desktop' ] || {
  printf 'FAIL: Cursor favorite metadata mismatch: %q\n' "$favorite_output" >&2
  exit 1
}

component_ids="$(bash "$ROOT_DIR/install.sh" --list-components | cut -f1)"
grep -qx cursor <<<"$component_ids" || {
  printf 'FAIL: Cursor application component is missing\n' >&2
  exit 1
}
if grep -qx cursor_autostart <<<"$component_ids"; then
  printf 'FAIL: legacy cursor_autostart component bypasses [S]\n' >&2
  exit 1
fi

cursor_row="$(bash "$ROOT_DIR/install.sh" --list-components | awk -F'\t' '$1 == "cursor"')"
[ "$cursor_row" = $'cursor\tCursor IDE\ton\tDesktop applications' ] || {
  printf 'FAIL: Cursor should be grouped as a desktop application: %q\n' "$cursor_row" >&2
  exit 1
}

component_rows="$(bash "$ROOT_DIR/install.sh" --list-components)"
grep -Fqx $'cursor_extensions\tCursor extensions (default: vsc_cursor_extensions)\ton\tProgramming tools\tcursor' <<<"$component_rows" || {
  printf 'FAIL: Cursor extensions should show the default config and require Cursor\n' >&2
  exit 1
}
grep -Fqx $'continue\tContinue AI assistant config (default: continue/config.yaml)\toff\tProgramming tools\tcursor' <<<"$component_rows" || {
  printf 'FAIL: Continue should remain available but default off in favor of Cursor Autotab\n' >&2
  exit 1
}
if grep -Eq $'^(uv_supply_chain|tmux)\t' <<<"$component_rows"; then
  printf 'FAIL: UV and tmux configuration should be owned by configuration setup\n' >&2
  exit 1
fi

if grep -R -n -E '\.config/autostart|X-GNOME-Autostart-enabled' \
    "$ROOT_DIR/lib" --include='*.sh'; then
  printf 'FAIL: programming installer writes app autostart outside [S]\n' >&2
  exit 1
fi

printf 'test_cursor_autostart.sh: [S] metadata assertions passed\n'
