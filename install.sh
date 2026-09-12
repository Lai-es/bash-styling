#!/usr/bin/env bash
#
# install.sh — installer/uninstaller for Lai-es/bash-styling
#
# Install:   curl -fsSL https://raw.githubusercontent.com/Lai-es/bash-styling/main/install.sh | bash
# Uninstall: curl -fsSL https://raw.githubusercontent.com/Lai-es/bash-styling/install.sh | bash -s -- uninstall

set -euo pipefail

REPO="Lai-es/bash-styling"
INSTALL_DIR="$HOME/.local/share/bash-styling"
FUNCS_FILE="$INSTALL_DIR/functions.sh"
BOX_FILE="$INSTALL_DIR/success-box"
BASHRC="$HOME/.bashrc"

BACKUP_MSG="Making backup of $BASHRC"

MARKER_START="# >>> bash-styling >>>"
MARKER_END="# <<< bash-styling <<<"

err() {
  echo "Error: $*" >&2
  exit 1
}

get_latest_version() {
    local url final_url version
    url="https://github.com/${REPO}/releases/latest"
    if command -v curl >/dev/null 2>&1; then
        final_url="$(curl -sSfIL -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null || true)"
    elif command -v wget >/dev/null 2>&1; then
        final_url="$(wget --max-redirect=0 --server-response -O /dev/null "$url" 2>&1 | grep -i 'location:' | head -1 || true)"
    else
        err "Neither curl nor wget is available. Please install one and retry."
    fi
    version="$(printf '%s' "$final_url" | sed 's|.*/||' | cut -d' ' -f1 | tr -d '\r\n')"
    [ -n "$version" ] || err "Could not determine latest version from GitHub Release redirect."
    echo "$version"
}

remove_block() {
  if grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
    # NOTE: macOS/BSD sed wants `-i ''`, GNU sed wants `-i`.
    sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$BASHRC"
  fi
}

do_install() {
  local version repo_raw funcs_url box_url
  version="$(get_latest_version)"
  repo_raw="https://raw.githubusercontent.com/${REPO}/${version}"
  funcs_url="${repo_raw}/lib/functions.sh"
  box_url="${repo_raw}/lib/success-box"

  mkdir -p "$INSTALL_DIR"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$funcs_url" -o "$FUNCS_FILE"
    curl -fsSL "$box_url" -o "$BOX_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$FUNCS_FILE" "$funcs_url"
    wget -qO "$BOX_FILE" "$box_url"
  else
    err "Neither curl nor wget is available. Please install one and retry."
  fi

  echo "$BACKUP_MSG"
  if [[ -f "$BASHRC" ]]; then
    cp "$BASHRC" "$BASHRC.bak.$(date +%s)"
  else
    touch "$BASHRC" #make bashrc if not yet existing
  fi
  remove_block

  {
    echo ""
    echo "$MARKER_START"
    echo "# GitHub-repo: $REPO version: $version"
    echo "source \"$FUNCS_FILE\""
    echo "$MARKER_END"
  } >> "$BASHRC"

  echo "Installed $version. Source $BASHRC for changes to take effect"
}

do_uninstall() {
  echo "$BACKUP_MSG"
  cp "$BASHRC" "$BASHRC.bak.$(date +%s)"
  remove_block
  rm -rf "$INSTALL_DIR"
  echo "Uninstalled. Restart your shell to fully clear it."
}

case "${1:-install}" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  *) err "Usage: install.sh [install|uninstall]" ;;
esac