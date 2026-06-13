#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
installer_source="$(cat "$root_dir/install.sh")"
runtime_source="$(cat "$root_dir/lib/installer_runtime.sh")"

grep -q 'source "$SCRIPT_DIR/lib/installer_runtime.sh"' <<<"$installer_source"
grep -q 'log_dir="$SCRIPT_DIR/.log"' <<<"$runtime_source"
grep -q 'mkdir -p "$log_dir"' <<<"$runtime_source"
