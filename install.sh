#!/usr/bin/env bash
# Re-runnable user install. Never blocks on a sudo password prompt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="${HOME}/.local/bin/omarchy-task-manager"
TOGGLE_DST="${HOME}/.local/bin/omarchy-task-manager-toggle"
WAYBAR_EXEC_DST="${HOME}/.local/bin/omarchy-task-manager-waybar"
DESKTOP_DST="${HOME}/.local/share/applications/omarchy-task-manager.desktop"
HYPR_DIR="${HOME}/.config/hypr"
AUTOSTART_LUA="${HYPR_DIR}/autostart.lua"
HYPRLAND_LUA="${HYPR_DIR}/hyprland.lua"
WAYBAR_CONFIG="${HOME}/.config/waybar/config.jsonc"
WAYBAR_STYLE="${HOME}/.config/waybar/style.css"
PLUGIN_ID="sw.art.task-manager"
PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
PLUGIN_SRC="${ROOT}/shell/${PLUGIN_ID}"
KBD_PLUGIN_ID="sw.art.kbd-backlight"
KBD_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${KBD_PLUGIN_ID}"
KBD_PLUGIN_SRC="${ROOT}/shell/${KBD_PLUGIN_ID}"
CURSOR_PLUGIN_ID="sw.art.cursor"
CURSOR_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${CURSOR_PLUGIN_ID}"
CURSOR_PLUGIN_SRC="${ROOT}/shell/${CURSOR_PLUGIN_ID}"
PILOCAL_PLUGIN_ID="sw.art.pi-local"
PILOCAL_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${PILOCAL_PLUGIN_ID}"
PILOCAL_PLUGIN_SRC="${ROOT}/shell/${PILOCAL_PLUGIN_ID}"
GROK_PLUGIN_ID="sw.art.grok"
GROK_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${GROK_PLUGIN_ID}"
GROK_PLUGIN_SRC="${ROOT}/shell/${GROK_PLUGIN_ID}"
AI_USAGE_PLUGIN_ID="sw.art.ai-usage"
AI_USAGE_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${AI_USAGE_PLUGIN_ID}"
AI_USAGE_PLUGIN_SRC="${ROOT}/shell/${AI_USAGE_PLUGIN_ID}"
USAGE_STATE_DIR="${HOME}/.local/state/omarchy/agents/usage"
SHELL_JSON="${HOME}/.config/omarchy/shell.json"
PKGS=(python)

install_deps() {
  command -v pacman >/dev/null 2>&1 || return 0

  local missing=() pkg
  for pkg in "${PKGS[@]}"; do
    if ! pacman -Q "${pkg}" >/dev/null 2>&1; then
      missing+=("${pkg}")
    fi
  done
  if ((${#missing[@]} == 0)); then
    return 0
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    pacman -S --needed --noconfirm "${missing[@]}"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    if sudo -n pacman -S --needed --noconfirm "${missing[@]}"; then
      return 0
    fi
    echo "sudo pacman failed; continuing with the app install."
    return 0
  fi

  echo "Packages not installed (sudo needs a TTY/password): ${missing[*]}"
  echo "Install them with: sudo pacman -S --needed ${missing[*]}"
  echo "Continuing with the app install."
}

upsert_lua_block() {
  # Legacy: remove the old GTK autostart block if present (panel needs no autostart).
  local file="$1"
  [[ -f "${file}" ]] || return 0
  python3 - "${file}" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
begin = "-- omarchy-task-manager begin"
end = "-- omarchy-task-manager end"
if not path.exists():
    sys.exit(0)
text = path.read_text(encoding="utf-8")
if begin not in text:
    sys.exit(0)
out, skip = [], False
for line in text.splitlines(True):
    stripped = line.rstrip("\n")
    if stripped == begin:
        skip = True
        continue
    if skip and stripped == end:
        skip = False
        continue
    if skip:
        continue
    out.append(line)
path.write_text("".join(out).rstrip() + "\n", encoding="utf-8")
print(f"Removed legacy autostart block from {path}")
PY
}

ensure_hyprland_requires_autostart() {
  return 0
}

# ── Quickshell / Omarchy shell plugin ─────────────────────────────────────────
# Installs the bar-widget plugin under ~/.config/omarchy/plugins/sw.art.task-manager/
# and patches ~/.config/omarchy/shell.json to place the widget in bar.layout.center
# next to omarchy.weather (idempotent).

install_quickshell_plugin() {
  [[ -d "${PLUGIN_SRC}" ]] || { echo "Warning: plugin source not found at ${PLUGIN_SRC}"; return 0; }
  mkdir -p "${PLUGIN_DIR}"
  install -Dm644 "${PLUGIN_SRC}/manifest.json" "${PLUGIN_DIR}/manifest.json"
  install -Dm644 "${PLUGIN_SRC}/BarWidget.qml"  "${PLUGIN_DIR}/BarWidget.qml"
  install -Dm644 "${PLUGIN_SRC}/Panel.qml"      "${PLUGIN_DIR}/Panel.qml"
  echo "Quickshell plugin: installed to ${PLUGIN_DIR}"
}

patch_shell_json() {
  [[ -f "${SHELL_JSON}" ]] || { echo "Note: ${SHELL_JSON} not found; skipping bar layout patch. Create it or run: omarchy plugin enable ${PLUGIN_ID}"; return 0; }

  python3 - "${SHELL_JSON}" "${PLUGIN_ID}" <<'PY'
import json, sys, pathlib

path      = pathlib.Path(sys.argv[1])
plugin_id = sys.argv[2]
anchor    = "omarchy.weather"

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"Warning: could not parse {path}: {exc}", file=sys.stderr)
    sys.exit(0)

center = (
    data.setdefault("bar", {})
        .setdefault("layout", {})
        .setdefault("center", [])
)

# Idempotent: exit early if already present.
if any(e.get("id") == plugin_id for e in center):
    sys.exit(0)

entry = {"id": plugin_id}
anchor_idx = next(
    (i for i, e in enumerate(center) if e.get("id") == anchor), None
)
if anchor_idx is not None:
    center.insert(anchor_idx + 1, entry)
else:
    center.append(entry)

path.write_text(
    json.dumps(data, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
print(f"shell.json: added {plugin_id} to bar.layout.center")
PY
}

# ── Quickshell kbd-backlight plugin ───────────────────────────────────────────
# Installs sw.art.kbd-backlight under ~/.config/omarchy/plugins/ and patches
# shell.json to place it immediately to the left of the clock/time widget
# (idempotent; does not affect sw.art.task-manager or omarchy.weather entries).

install_kbd_backlight_plugin() {
  [[ -d "${KBD_PLUGIN_SRC}" ]] || { echo "Warning: kbd-backlight plugin source not found at ${KBD_PLUGIN_SRC}"; return 0; }
  mkdir -p "${KBD_PLUGIN_DIR}"
  install -Dm644 "${KBD_PLUGIN_SRC}/manifest.json"   "${KBD_PLUGIN_DIR}/manifest.json"
  install -Dm644 "${KBD_PLUGIN_SRC}/KbdBacklight.qml" "${KBD_PLUGIN_DIR}/KbdBacklight.qml"
  echo "kbd-backlight plugin: installed to ${KBD_PLUGIN_DIR}"
}

patch_shell_json_kbd() {
  [[ -f "${SHELL_JSON}" ]] || {
    echo "Note: ${SHELL_JSON} not found; skipping bar layout patch."
    echo "      Run: omarchy plugin enable ${KBD_PLUGIN_ID}"
    return 0
  }

  python3 - "${SHELL_JSON}" "${KBD_PLUGIN_ID}" <<'PY'
import json, sys, pathlib

path      = pathlib.Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"Warning: could not parse {path}: {exc}", file=sys.stderr)
    sys.exit(0)

center = (
    data.setdefault("bar", {})
        .setdefault("layout", {})
        .setdefault("center", [])
)

# Idempotent: exit early if already present.
if any(e.get("id") == plugin_id for e in center):
    sys.exit(0)

entry = {"id": plugin_id}

# Find the clock/time widget: match any id containing "clock" or "time".
clock_idx = next(
    (i for i, e in enumerate(center)
     if any(kw in e.get("id", "").lower() for kw in ("clock", "time"))),
    None,
)

if clock_idx is not None:
    center.insert(clock_idx, entry)
    print(f"shell.json: inserted {plugin_id} left of '{center[clock_idx + 1]['id']}'")
else:
    center.append(entry)
    print(f"shell.json: appended {plugin_id} (no clock widget found to anchor against)")

path.write_text(
    json.dumps(data, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
}

# ── AI tray plugins (cursor / pi-local / grok / ai-usage) ─────────────────────
# pi-local, grok, and ai-usage are patched into bar.layout.right immediately
# left of the system-icon cluster (before omarchy.tray when present).
# sw.art.cursor files are installed but never added to bar.layout.*; existing
# cursor bar entries are removed on upgrade (idempotent).

install_ai_tray_plugins() {
  local entries=(
    "${CURSOR_PLUGIN_SRC}:${CURSOR_PLUGIN_DIR}:BarWidget.qml"
    "${PILOCAL_PLUGIN_SRC}:${PILOCAL_PLUGIN_DIR}:BarWidget.qml"
    "${GROK_PLUGIN_SRC}:${GROK_PLUGIN_DIR}:BarWidget.qml"
    "${AI_USAGE_PLUGIN_SRC}:${AI_USAGE_PLUGIN_DIR}:BarWidget.qml,Panel.qml"
  )
  local entry
  for entry in "${entries[@]}"; do
    local src dir files
    src="${entry%%:*}"; entry="${entry#*:}"
    dir="${entry%%:*}"; files="${entry#*:}"
    if [[ ! -d "${src}" ]]; then
      echo "Warning: plugin source not found at ${src}"; continue
    fi
    mkdir -p "${dir}"
    install -Dm644 "${src}/manifest.json" "${dir}/manifest.json"
    local qml
    IFS=',' read -ra qml_files <<< "${files}"
    for qml in "${qml_files[@]}"; do
      install -Dm644 "${src}/${qml}" "${dir}/${qml}"
    done
    echo "AI tray plugin: installed $(basename "${dir}") to ${dir}"
  done
}

patch_shell_json_ai_tray() {
  [[ -f "${SHELL_JSON}" ]] || {
    echo "Note: ${SHELL_JSON} not found; skipping AI tray bar layout patch."
    echo "      Run: omarchy plugin enable ${PILOCAL_PLUGIN_ID}"
    echo "           omarchy plugin enable ${GROK_PLUGIN_ID}"
    echo "           omarchy plugin enable ${AI_USAGE_PLUGIN_ID}"
    return 0
  }

  python3 - "${SHELL_JSON}" "${CURSOR_PLUGIN_ID}" \
      "${PILOCAL_PLUGIN_ID}" "${GROK_PLUGIN_ID}" "${AI_USAGE_PLUGIN_ID}" <<'PY'
import json, sys, pathlib

path       = pathlib.Path(sys.argv[1])
cursor_id  = sys.argv[2]
bar_ids    = sys.argv[3:]

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"Warning: could not parse {path}: {exc}", file=sys.stderr)
    sys.exit(0)

layout = data.setdefault("bar", {}).setdefault("layout", {})
center = layout.setdefault("center", [])
right  = layout.setdefault("right", [])
changed = False

def remove_ids(entries, ids):
    removed = [e.get("id") for e in entries if e.get("id") in ids]
    if removed:
        entries[:] = [e for e in entries if e.get("id") not in ids]
    return removed

removed_cursor_center = remove_ids(center, {cursor_id})
removed_cursor_right = remove_ids(right, {cursor_id})
if removed_cursor_center or removed_cursor_right:
    changed = True
    print(
        "shell.json: removed cursor bar launcher from layout:"
        f" center={removed_cursor_center or []} right={removed_cursor_right or []}"
    )

migrated_center = remove_ids(center, set(bar_ids))
if migrated_center:
    changed = True
    print(f"shell.json: removed AI tray from center: {migrated_center}")

migrated_right = remove_ids(right, set(bar_ids))
if migrated_right:
    changed = True
    print(f"shell.json: relocated AI tray within right (was: {migrated_right})")

def insert_before_system_cluster(entries):
    ids = [e.get("id", "") for e in entries]
    if "omarchy.tray" in ids:
        return ids.index("omarchy.tray")
    system_ids = {
        "omarchy.agents", "agents",
        "omarchy.bluetooth", "bluetooth",
        "omarchy.network", "network",
        "omarchy.audio", "audio",
        "omarchy.monitor", "monitor",
        "omarchy.power",
    }
    for i, eid in enumerate(ids):
        if eid in system_ids:
            return i
    return 0

insert_at = insert_before_system_cluster(right)
entries = [{"id": pid} for pid in bar_ids]
right[insert_at:insert_at] = entries
changed = True

anchor = right[insert_at].get("id") if insert_at < len(right) else "end"
print(f"shell.json: placed AI tray on bar.layout.right before {anchor}: {bar_ids}")

if changed:
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
PY
}

ensure_usage_state_dir() {
  # Preserve across reinstalls — never delete existing usage JSON on upgrade.
  mkdir -p "${USAGE_STATE_DIR}"
}

patch_shell_json_tray_hidden() {
  [[ -f "${SHELL_JSON}" ]] || return 0

  python3 - "${SHELL_JSON}" <<'PY'
import json, sys, pathlib

path = pathlib.Path(sys.argv[1])
hidden_icon = "Cursor_status_icon_1"

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"Warning: could not parse {path}: {exc}", file=sys.stderr)
    sys.exit(0)

tray = data.setdefault("omarchy", {}).setdefault("tray", {})
hidden = tray.setdefault("hidden", [])
if not isinstance(hidden, list):
    hidden = []
    tray["hidden"] = hidden

if hidden_icon not in hidden:
    hidden.append(hidden_icon)
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"shell.json: added {hidden_icon} to omarchy.tray.hidden")
PY
}

# ── Waybar integration (optional – skipped when waybar is not configured) ─────
# Idempotently adds custom/omarchy-task-manager to ~/.config/waybar/config.jsonc
# (near custom/weather in modules-center) and a margin rule to style.css.

upsert_waybar_config() {
  [[ -f "${WAYBAR_CONFIG}" ]] || return 0
  python3 - "${WAYBAR_CONFIG}" "${TOGGLE_DST}" "${WAYBAR_EXEC_DST}" <<'PY'
import pathlib, re, sys

config_path = pathlib.Path(sys.argv[1])
MODULE_ID = '"custom/omarchy-task-manager"'

text = config_path.read_text(encoding="utf-8")
if MODULE_ID in text:
    sys.exit(0)  # already present

MODULE_DEF = '''\
  "custom/omarchy-task-manager": {
    "exec": "omarchy-task-manager-waybar",
    "return-type": "json",
    "interval": 5,
    "on-click": "omarchy-task-manager-toggle",
    "tooltip": true
  }'''

# Insert into modules-center: prefer after "custom/weather", fall back to
# before the first "]" that terminates a modules-* array.
weather_pat = re.compile(r'("custom/weather")')
center_end = re.compile(r'("modules-center"\s*:\s*\[(?:[^\[\]]|\[[^\[\]]*\])*?)(\])', re.DOTALL)

if weather_pat.search(text):
    text = weather_pat.sub(
        r'\1,\n        "custom/omarchy-task-manager"',
        text,
        count=1,
    )
else:
    def add_to_center(m):
        inner = m.group(1)
        inner_stripped = inner.rstrip()
        sep = "," if not inner_stripped.endswith("[") else ""
        return inner_stripped + sep + '\n        "custom/omarchy-task-manager"\n    ' + m.group(2)
    text, n = center_end.subn(add_to_center, text, count=1)

# Append module definition before the final closing brace.
last_brace = text.rfind("}")
before = text[:last_brace].rstrip()
sep = "," if not before.endswith("{") and not before.endswith(",") else ""
text = before + sep + "\n" + MODULE_DEF + "\n}"

config_path.write_text(text, encoding="utf-8")
print("Waybar: added custom/omarchy-task-manager to config.jsonc")
PY
}

upsert_waybar_style() {
  [[ -f "${WAYBAR_STYLE}" ]] || return 0
  if grep -qF '#custom-omarchy-task-manager' "${WAYBAR_STYLE}"; then
    return 0
  fi
  printf '\n#custom-omarchy-task-manager {\n  margin-right: 8px;\n}\n' >> "${WAYBAR_STYLE}"
  echo "Waybar: added #custom-omarchy-task-manager style to style.css"
}

# ─────────────────────────────────────────────────────────────────────────────

install_deps

install -Dm755 "${ROOT}/omarchy-task-manager"        "${BIN_DST}"
install -Dm755 "${ROOT}/omarchy-task-manager-toggle"  "${TOGGLE_DST}"
install -Dm755 "${ROOT}/omarchy-task-manager-waybar"  "${WAYBAR_EXEC_DST}"

tmp="$(mktemp)"
sed -E "s|^Exec=.*|Exec=${BIN_DST}|" "${ROOT}/omarchy-task-manager.desktop" > "${tmp}"
install -Dm644 "${tmp}" "${DESKTOP_DST}"
rm -f "${tmp}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
fi

upsert_lua_block "${AUTOSTART_LUA}"
ensure_hyprland_requires_autostart
install_quickshell_plugin
patch_shell_json
install_kbd_backlight_plugin
patch_shell_json_kbd
install_ai_tray_plugins
patch_shell_json_ai_tray
patch_shell_json_tray_hidden
ensure_usage_state_dir
upsert_waybar_config
upsert_waybar_style

echo "Installed Task Manager (KeyboardPanel popout)."
echo "Toggle: ${TOGGLE_DST}  or  omarchy-shell shell toggle ${PLUGIN_ID} '{}'"
echo "Stats:  ${BIN_DST} snapshot"
echo "Quickshell plugin: ${PLUGIN_DIR}"
echo "  Bar icon placed in center next to omarchy.weather."
echo "  Restart shell: omarchy-restart-shell"
echo "  (or: omarchy-shell shell rescanPlugins && omarchy plugin enable ${PLUGIN_ID})"
echo "Keyboard backlight plugin: ${KBD_PLUGIN_DIR}"
echo "  Bar icon placed immediately left of the clock."
echo "  State file: ~/.local/state/omarchy/kbd-backlight"
echo "  (or: omarchy plugin enable ${KBD_PLUGIN_ID})"
echo "AI tray plugins:"
echo "  ${CURSOR_PLUGIN_DIR}  (Cursor IDE — plugin files only, not added to bar)"
echo "  ${PILOCAL_PLUGIN_DIR}  (pi --provider llama-local)"
echo "  ${GROK_PLUGIN_DIR}  (grok CLI)"
echo "  ${AI_USAGE_PLUGIN_DIR}  (Cursor/Grok Bot/Grok build quota usage)"
echo "  Bar icons on bar.layout.right before system cluster: pi-local → grok → ai-usage"
echo "  Terminal launcher: xdg-terminal-exec (fallback: ghostty, kitty)"
echo "  Usage refresh: omarchy-task-manager ai-usage-update"
