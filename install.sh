#!/usr/bin/env bash
# Re-runnable user install. Never blocks on a sudo password prompt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="${HOME}/.local/bin/omarchy-task-manager"
DESKTOP_DST="${HOME}/.local/share/applications/omarchy-task-manager.desktop"
HYPR_DIR="${HOME}/.config/hypr"
AUTOSTART_LUA="${HYPR_DIR}/autostart.lua"
HYPRLAND_LUA="${HYPR_DIR}/hyprland.lua"
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
        "-- Float bottom-right; no size rule so expand can grow freely.",
        f'o.launch_on_start("{bin_dst}")',
        f'o.window("{klass}", {{',
        "  float = true,",
        '  move = { "monitor_w * 0.5", "monitor_h * 0.75" },',
        "})",
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

install_deps

install -Dm755 "${ROOT}/omarchy-task-manager" "${BIN_DST}"

tmp="$(mktemp)"
sed -E "s|^Exec=.*|Exec=${BIN_DST}|" "${ROOT}/omarchy-task-manager.desktop" > "${tmp}"
install -Dm644 "${tmp}" "${DESKTOP_DST}"
rm -f "${tmp}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
fi

upsert_lua_block "${AUTOSTART_LUA}"
ensure_hyprland_requires_autostart

echo "Installed Task Manager."
echo "Launch: ${BIN_DST}"
echo "Or open \"Task Manager\" from Walker / the application menu."
echo "Hyprland: autostart + float bottom-right (no size clamp) in ${AUTOSTART_LUA}"
echo "Reload with: hyprctl reload"
