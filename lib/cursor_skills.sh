#!/usr/bin/env bash
# cursor_skills.sh — Deploy programming_prompts skills into each setup-chain
# project's `.cursor/skills/programming-prompts/` tree, plus an alwaysApply
# Cursor rule so general-programming-guidelines runs on every Agent prompt.
#
# Layout (per project):
#   .cursor/skills/programming-prompts/<skill>/   # symlink → programming_prompts
#   .cursor/rules/programming-prompts-always-on.mdc
#   .gitignore managed block covering ONLY those two paths (never other skills)
#
# Cursor discovers nested skill categories recursively; the category folder is
# organizational so project-specific skills can live at `.cursor/skills/<name>/`
# without being gitignored. Official Cursor skills docs: skills auto-apply when
# relevant unless `disable-model-invocation: true`. Always-on behaviour requires
# a `.cursor/rules/*.mdc` with `alwaysApply: true`.
#
# Sourced after lib/helpers.sh. Depends on: msg, log, run_as_target,
# ensure_linked_repository (from shared installer_helpers).
# Requires variables: TARGET_HOME, SCRIPT_DIR.

PROGRAMMING_PROMPTS_DIR="${PROGRAMMING_PROMPTS_DIR:-${TARGET_HOME:-${HOME:-/tmp}}/projects/programming_prompts}"
PROGRAMMING_PROMPTS_REPO_URL="${PROGRAMMING_PROMPTS_REPO_URL:-https://github.com/mikaeltorni/programming_prompts.git}"
PROJECTS_DIR="${PROJECTS_DIR:-${TARGET_HOME:-${HOME:-/tmp}}/projects}"
INSTALLATION_SCRIPTS_DIR="${INSTALLATION_SCRIPTS_DIR:-${TARGET_HOME:-${HOME:-/tmp}}/projects/installation_scripts}"

# ensure_cursor_skills_prompts — Resolve the programming_prompts content source.
# Existing checkouts are left untouched; a missing one is cloned because the
# cursor_skills component explicitly selected content from that repository.
ensure_cursor_skills_prompts() {
  [ -d "$PROGRAMMING_PROMPTS_DIR/skills" ] && return 0
  INSTALLER_AUTH=1 ensure_linked_repository \
    "programming prompts" "$PROGRAMMING_PROMPTS_DIR" \
    "$PROGRAMMING_PROMPTS_REPO_URL"
}

# cursor_skills_repo_list — Print the repository directory names that receive
# managed Cursor skills. Prefer CURSOR_SKILLS_REPOS (tests/overrides). Otherwise
# source CLONE_REPOS from the sibling installation_scripts manifest and append
# installation_scripts itself (the orchestrator is not in CLONE_REPOS).
# Prints a single space-separated line on stdout.
cursor_skills_repo_list() {
  if [ -n "${CURSOR_SKILLS_REPOS:-}" ]; then
    printf '%s\n' "$CURSOR_SKILLS_REPOS"
    return 0
  fi

  local manifest="$INSTALLATION_SCRIPTS_DIR/scripts/repository_manifest.sh"
  if [ ! -f "$manifest" ]; then
    log "error" "installation_scripts manifest missing at $manifest"
    printf '%s\n' "Clone installation_scripts beside this repository before deploying Cursor skills." >&2
    return 2
  fi

  # shellcheck disable=SC1090
  source "$manifest"
  local repos=("${CLONE_REPOS[@]}")
  local name seen=0
  for name in "${repos[@]}"; do
    [ "$name" = "installation_scripts" ] && seen=1
  done
  if [ "$seen" -eq 0 ]; then
    repos+=("installation_scripts")
  fi
  printf '%s\n' "${repos[*]}"
}

# _cursor_skills_py — Run the Python deployer as the target user.
# Arguments: action (install|uninstall|detect) plus optional extra args.
# Returns: the Python process exit status.
_cursor_skills_py() {
  local action="$1"
  shift
  local repos
  repos="$(cursor_skills_repo_list)" || return
  run_as_target python3 "$SCRIPT_DIR/lib/cursor_skills.py" "$action" \
    --projects-dir "$PROJECTS_DIR" \
    --prompts-dir "$PROGRAMMING_PROMPTS_DIR" \
    --repos "$repos" \
    "$@"
}

# install_cursor_skills — Link every programming_prompts skill into each
# setup-chain project and write the always-on Cursor rule + selective gitignore.
# Arguments: none.
# Returns: 0 on success; non-zero when prompts are missing or no projects deploy.
install_cursor_skills() {
  msg "Deploying programming_prompts Cursor skills into setup-chain projects"
  log "info" "Deploying Cursor skills from $PROGRAMMING_PROMPTS_DIR into $PROJECTS_DIR"
  ensure_cursor_skills_prompts || return 1
  if [ ! -d "$PROGRAMMING_PROMPTS_DIR/skills" ]; then
    log "error" "programming_prompts skills directory missing at $PROGRAMMING_PROMPTS_DIR"
    printf '%s\n' "programming_prompts checkout is required for cursor_skills." >&2
    return 2
  fi
  _cursor_skills_py install
}

# detect_cursor_skills — True when every existing target checkout has the
# managed guidelines skill and always-on rule.
detect_cursor_skills() {
  local out
  out="$(_cursor_skills_py detect 2>/dev/null)" || return 1
  [ "$out" = "installed" ]
}

# uninstall_cursor_skills — Remove managed Cursor skill links, always-on rule,
# and the managed gitignore block from each target project. Project-specific
# skills outside programming-prompts/ are left untouched.
uninstall_cursor_skills() {
  msg "Removing managed programming_prompts Cursor skills from setup-chain projects"
  log "info" "Uninstalling managed Cursor skills from $PROJECTS_DIR"
  _cursor_skills_py uninstall || true
}
