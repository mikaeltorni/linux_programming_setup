#!/usr/bin/env bash
# Verify the public builder and component with only an isolated target/project.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$(bash "$SCRIPT_DIR/scripts/build_lps_tools.sh" --bin cursor-skills --print)"
[[ "$bin" == "$SCRIPT_DIR/dist/cursor-skills" && -x "$bin" ]]
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
TARGET_HOME="$fixture/home"
PROJECTS_DIR="$fixture/projects"
PROGRAMMING_PROMPTS_DIR="$fixture/programming_prompts"
CURSOR_SKILLS_REPOS="demo missing"
mkdir -p "$TARGET_HOME" "$PROJECTS_DIR/demo" "$PROGRAMMING_PROMPTS_DIR/skills/general-programming-guidelines" "$fixture/traps"
printf '# Test guidelines\n' > "$PROGRAMMING_PROMPTS_DIR/skills/general-programming-guidelines/SKILL.md"
printf '#!/bin/bash\nexit 95\n' > "$fixture/traps/python3"
chmod +x "$fixture/traps/python3"
export PATH="$fixture/traps:$PATH"
# Silence existing install diagnostics; preserve the target runner call boundary.
# Parameters: all diagnostic arguments. Returns: zero without emitting output.
msg() { :; }
# Silence structured installer diagnostics.
# Parameters: level and message. Returns: zero without emitting output.
log() { :; }
# Execute the real command in this test's isolated target paths.
# Parameters: command and its arguments. Returns: command status/output.
run_as_target() { "$@"; }
source "$SCRIPT_DIR/lib/cursor_skills.sh"
for round in 1 2; do
  install_cursor_skills
  detect_cursor_skills
  [[ "$($TARGET_HOME/.local/bin/cursor-skills detect --projects-dir "$PROJECTS_DIR" --repos demo)" == installed ]]
  [[ -L "$PROJECTS_DIR/demo/.cursor/skills/programming-prompts/general-programming-guidelines" ]]
done
file "$TARGET_HOME/.local/bin/cursor-skills" | grep -q ELF
uninstall_cursor_skills
if detect_cursor_skills; then
  printf 'Managed deployment still detected after removal\n' >&2
  exit 1
fi
printf 'Native builder/component installation and repeated detection passed\n'
