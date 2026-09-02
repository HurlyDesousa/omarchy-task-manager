#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="${HOME}/.local/bin/omarchy-task-manager"
DESKTOP_DST="${HOME}/.local/share/applications/omarchy-task-manager.desktop"

if command -v pacman >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]]; then
    pacman -S --needed --noconfirm python python-gobject gtk4
  else
    sudo pacman -S --needed --noconfirm python python-gobject gtk4
  fi
fi

install -Dm755 "${ROOT}/omarchy-task-manager" "${BIN_DST}"

tmp="$(mktemp)"
sed -E "s|^Exec=.*|Exec=${BIN_DST}|" "${ROOT}/omarchy-task-manager.desktop" > "${tmp}"
install -Dm644 "${tmp}" "${DESKTOP_DST}"
rm -f "${tmp}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
fi

echo "Installed Task Manager."
echo "Launch: ${BIN_DST}"
echo "Or open \"Task Manager\" from Walker / the application menu."
