#!/usr/bin/env bash
set -euo pipefail

source_text="$(cat "$(dirname "$0")/../install.sh")"
grep -q 'log_dir="$SCRIPT_DIR/.log"' <<<"$source_text"
grep -q 'mkdir -p "$log_dir"' <<<"$source_text"
