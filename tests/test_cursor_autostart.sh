#!/usr/bin/env bash
# test_cursor_autostart.sh - Cursor master-menu startup metadata contract.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

startup_output="$(bash "$ROOT_DIR/install.sh" --list-startup-components)"
[ "$startup_output" = $'cursor\tcursor.desktop\ton' ] || {
  printf 'FAIL: Cursor startup metadata mismatch: %q\n' "$startup_output" >&2
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

if grep -R -n -E '\.config/autostart|X-GNOME-Autostart-enabled' \
    "$ROOT_DIR/lib" --include='*.sh'; then
  printf 'FAIL: programming installer writes app autostart outside [S]\n' >&2
  exit 1
fi

printf 'test_cursor_autostart.sh: [S] metadata assertions passed\n'
