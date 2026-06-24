#!/usr/bin/env bash
# test_tmux_config.sh — Regression tests for configure_tmux().
#
# Covers:
#   - configure_tmux() deploys configs/.tmux.conf into $TARGET_HOME/.tmux.conf.
#   - The deployment is idempotent (repeated runs reproduce the same file).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$ROOT_DIR/lib/helpers.sh"
source "$ROOT_DIR/lib/tmux_config.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

msg() { :; }
log() { :; }
# Run install commands directly as the test user (no privilege drop).
run_as_target() { "$@"; }

TARGET_HOME="$(mktemp -d)"
CONFIG_DIR="$ROOT_DIR/configs"
trap 'rm -rf "$TARGET_HOME"' EXIT

configure_tmux || fail "configure_tmux failed"
[ -f "$TARGET_HOME/.tmux.conf" ] || fail "tmux config not deployed"
diff -q "$CONFIG_DIR/.tmux.conf" "$TARGET_HOME/.tmux.conf" >/dev/null ||
  fail "deployed tmux config differs from source"

# Idempotent: a second run reproduces the same file without error.
configure_tmux || fail "configure_tmux not idempotent"
diff -q "$CONFIG_DIR/.tmux.conf" "$TARGET_HOME/.tmux.conf" >/dev/null ||
  fail "deployed tmux config differs from source after repeat run"

echo "test_tmux_config.sh: all assertions passed"
