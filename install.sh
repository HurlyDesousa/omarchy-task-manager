#!/usr/bin/env bash
# Re-runnable user install. Never blocks on a sudo password prompt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="${HOME}/.local/bin/omarchy-task-manager"
DESKTOP_DST="${HOME}/.local/share/applications/omarchy-task-manager.desktop"
PKGS=(python python-gobject gtk4)

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

install_deps

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
