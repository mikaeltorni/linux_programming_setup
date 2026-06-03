#!/usr/bin/env bash
# gsettings_helpers.sh — GSettings / dconf helper functions (minimal)
#
# Components:
#   - user_gsettings(args...): Run gsettings as the target user.
#   - join_as_gsettings_array(values...): Format values as a GSettings array string.
#   - append_gsettings_list(schema, key, value): Append a value to a list (idempotent).
#
# Sourced after lib/helpers.sh. Depends on: msg, run_as_target, join_as_gsettings_array.

# ── GSettings wrapper ────────────────────────────────────────────────────────

user_gsettings() {
  run_as_target gsettings "$@"
}

# ── Array formatting ────────────────────────────────────────────────────────

join_as_gsettings_array() {
  local out="[" first=1 val
  for val in "$@"; do
    [ -n "$val" ] || continue
    if [ "$first" -eq 0 ]; then
      out+=", "
    fi
    out+="'$val'"
    first=0
  done
  out+="]"
  printf "%s" "$out"
}

# ── List manipulation (uses Python for safe parsing) ────────────────────────

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

# ── APT helpers (minimal) ───────────────────────────────────────────────────

apt_install() {
  local pkg="$1"
  if need_cmd "$pkg"; then
    return 0
  fi
  apt update -y && apt install -y "$pkg"
}
