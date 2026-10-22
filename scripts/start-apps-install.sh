#!/usr/bin/env bash
# Install StartBar, StartAppImage, StartFS (daemon), StartFSGUI and Oma Cast.
# Usage: start-apps-install.sh [--bind-oma-cast]
#   --bind-oma-cast  also add Oma Cast's Hyprland keybinding (edits ~/.config/hypr)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

OMA_CAST_URL="https://github.com/typecraft-dev/oma-cast.git"
OMA_CAST_DIR="${OMA_CAST_DIR:-$HOME/.local/share/oma-cast}"

bind=0
[[ "${1:-}" == "--bind-oma-cast" ]] && bind=1

need_cmd omarchy git curl

plugin_installed() { omarchy plugin list 2>/dev/null | awk -v id="$1" '$1 == id { f=1 } END { exit !f }'; }

add_plugin() {
  local id="$1" url="$2"
  if plugin_installed "$id"; then
    echo "$id already installed"
  else
    omarchy plugin add "$url" --enable
  fi
}

# System packages first: unsquashfs for StartAppImage, FUSE + Tailscale for StartFS.
need_sudo
omarchy pkg add squashfs-tools fuse3 tailscale

add_plugin io.github.bmaltais.startbar https://github.com/bmaltais/StartBar
add_plugin io.github.bmaltais.startappimage https://github.com/bmaltais/StartAppImage.git

# StartFS: the installer drops ~/.local/bin/startfs and a systemd user service.
if command -v startfs >/dev/null 2>&1; then
  echo "startfs already installed ($(startfs --version | head -1))"
else
  curl -fsSL https://raw.githubusercontent.com/bmaltais/StartFS/main/scripts/install.sh | sh
fi
add_plugin io.github.bmaltais.startfsgui https://github.com/bmaltais/StartFSGUI

# Oma Cast links the plugin from the clone, so the clone has to stay in place.
if [[ -d "$OMA_CAST_DIR/.git" ]]; then
  git -C "$OMA_CAST_DIR" pull --ff-only
else
  git clone "$OMA_CAST_URL" "$OMA_CAST_DIR"
fi
"$OMA_CAST_DIR/bin/oma-cast" install
if (( bind )); then
  echo "Back up ~/.config/hypr first; oma-cast edits it."
  oma-cast setup hyprland
fi

echo
echo "Still manual: join the tailnet with 'sudo systemctl enable --now tailscaled && sudo tailscale up'."
echo "Then: ./scripts/start-apps-status.sh"
