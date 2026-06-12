#!/usr/bin/env bash
# gsettings_helpers.sh — GSettings / dconf helper functions (minimal)
#
# Components:
#   - user_gsettings(args...): Run gsettings as the target user.
#   - append_gsettings_list(schema, key, value): Append a value to a list (idempotent).
#   - apt_install(pkg): Install an APT package if its command is missing.
#
# Sourced after lib/helpers.sh. Depends on: need_cmd, run_as_target.

# ── GSettings wrapper ────────────────────────────────────────────────────────

# user_gsettings — Run the gsettings command as the target user so reads and
# writes hit the user's dconf database rather than root's.
# Arguments: $@ — arguments forwarded verbatim to gsettings.
# Returns: the exit status of gsettings.
user_gsettings() {
  run_as_target gsettings "$@"
}

# ── List manipulation (uses Python for safe parsing) ────────────────────────

# append_gsettings_list — Append a value to a GSettings array key, de-duplicating
# existing entries so repeated runs are idempotent.
# Arguments:
#   $1 schema — GSettings schema id (e.g. org.gnome.desktop.autostart).
#   $2 key    — the array-valued key to update.
#   $3 value  — the string value to append if not already present.
# Returns: the exit status of the final gsettings set (0 on success).
append_gsettings_list() {
  local schema="$1" key="$2" value="$3"
  local current newlist
  current="$(user_gsettings get "$schema" "$key" 2>/dev/null || echo "[]")"
  newlist="$(VAL="$value" CURRENT="$current" python3 - <<'PY'
import ast, os
cur_raw = os.environ.get("CURRENT", "").strip()
if cur_raw.startswith("@as "):
    cur_raw = cur_raw[4:].strip()
try:
    cur = ast.literal_eval(cur_raw) if cur_raw else []
except Exception:
    cur = []
if not isinstance(cur, list):
    cur = []
cur = list(dict.fromkeys(str(item) for item in cur))
val = os.environ.get("VAL", "")
if val and val not in cur:
    cur.append(val)
print("[" + ", ".join(repr(str(item)) for item in cur) + "]")
PY
)"
  user_gsettings set "$schema" "$key" "$newlist"
}

# ── APT helpers ──────────────────────────────────────────────────────────────

# apt_install — Install an APT package, skipping the work when its command-line
# entry point already exists on PATH (idempotent).
# Arguments: $1 pkg — package name, which is also assumed to be the command name.
# Returns: 0 if already present or installed successfully; non-zero on apt error.
apt_install() {
  local pkg="$1"
  if need_cmd "$pkg"; then
    log "info" "Package '$pkg' already present, skipping apt install"
    return 0
  fi
  if ! is_root; then
    note_sudo_required "apt install $pkg"
    return 0
  fi
  log "info" "Installing APT package: $pkg"
  apt update -y && apt install -y "$pkg"
}
