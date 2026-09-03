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
SHELL_JSON="${HOME}/.config/omarchy/shell.json"
PKGS=(python python-gobject gtk4)
CLASS="art.sw.omarchy.TaskManager"

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
  local file="$1"
  mkdir -p "$(dirname "${file}")"
  python3 - "$file" "$BIN_DST" "$CLASS" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
bin_dst = sys.argv[2]
klass = sys.argv[3]
begin = "-- omarchy-task-manager begin"
end = "-- omarchy-task-manager end"
snippet = "\n".join(
    [
        begin,
        f'o.launch_on_start("{bin_dst}")',
        f'o.window("{klass}", {{ float = true }})',
        end,
        "",
    ]
)

if path.exists():
    text = path.read_text(encoding="utf-8")
else:
    text = "-- Extra autostart processes.\n"

# Drop a previous marked block, if any.
out = []
skip = False
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

# Drop unlabeled copies of this app's launch/window (laptop already live).
kept = []
i = 0
class_open = re.compile(
    r'o\.window\(\s*["\']' + re.escape(klass) + r'["\']'
)
while i < len(out):
    raw = out[i]
    stripped = raw.strip()
    if "o.launch_on_start" in stripped and "omarchy-task-manager" in stripped:
        i += 1
        continue
    if class_open.search(stripped):
        depth = raw.count("{") - raw.count("}")
        i += 1
        while i < len(out) and depth > 0:
            raw = out[i]
            depth += raw.count("{") - raw.count("}")
            i += 1
        continue
    kept.append(out[i])
    i += 1

body = "".join(kept).rstrip() + "\n\n" + snippet
path.write_text(body, encoding="utf-8")

PY
}

ensure_hyprland_requires_autostart() {
  [[ -f "${HYPRLAND_LUA}" ]] || return 0
  if grep -qE 'require\(["'"'"']hypr\.autostart["'"'"']\)' "${HYPRLAND_LUA}"; then
    return 0
  fi
  printf '\nrequire("hypr.autostart")\n' >> "${HYPRLAND_LUA}"
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
upsert_waybar_config
upsert_waybar_style

echo "Installed Task Manager."
echo "Launch: ${BIN_DST}"
echo "Or open \"Task Manager\" from Walker / the application menu."
echo "Hyprland: autostart (launch-on-login) registered in ${AUTOSTART_LUA}"
echo "Quickshell plugin: ${PLUGIN_DIR}"
echo "  Bar icon placed in center next to omarchy.weather."
echo "  Restart shell: omarchy-restart-shell"
echo "  (or: omarchy-shell shell rescanPlugins && omarchy plugin enable ${PLUGIN_ID})"
