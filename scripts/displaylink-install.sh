#!/usr/bin/env bash
# Install evdi + DisplayLink userspace on Omarchy.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

need_cmd omarchy pacman

kver="$(uname -r)"
echo "Running kernel: $kver"

header_pkg=""
if [[ -d "/usr/lib/modules/$kver/build" ]]; then
  echo "Kernel headers already present for $kver"
else
  kpkg="$(pacman -Qo "/usr/lib/modules/$kver" 2>/dev/null | awk '{print $5}' || true)"
  if [[ -n "$kpkg" ]]; then
    header_pkg="${kpkg}-headers"
  else
    header_pkg="linux-headers"
  fi
  echo "Installing $header_pkg"
fi

omarchy pkg add dkms usbutils ${header_pkg:-}

if ! pacman -Q evdi-dkms >/dev/null 2>&1 && ! pacman -Q evdi-dkms-git >/dev/null 2>&1; then
  echo "Building evdi-dkms and displaylink from the AUR (this can take a minute)…"
  omarchy pkg aur add evdi-dkms displaylink
else
  omarchy pkg aur add displaylink
fi

need_sudo
sudo systemctl enable --now displaylink.service
echo
systemctl --no-pager --full status displaylink.service || true
echo
echo "Next: ./scripts/displaylink-configure.sh"
echo "Then reboot with the hub plugged into a USB 3 port."
