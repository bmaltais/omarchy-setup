#!/usr/bin/env bash
# Enable NVreg_EnableResizableBar and rebuild the boot image.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(repo_root)"
SRC="$ROOT/config/nvidia-resizable-bar/nvidia-resizable-bar.conf"
DEST="/etc/modprobe.d/nvidia-resizable-bar.conf"

need_cmd limine-update

if grep -rqs 'NVreg_EnableResizableBar=1' /etc/modprobe.d/; then
  echo "NVreg_EnableResizableBar=1 is already set under /etc/modprobe.d/. Nothing to do."
  exit 0
fi

need_sudo
install_file "$SRC" "$DEST" 0644
# NVIDIA loads from the initramfs, so the option must be baked into the UKI.
sudo limine-update

echo
echo "Installed $DEST and rebuilt the boot image. Reboot, then:"
echo "  ./scripts/nvidia-resizable-bar-status.sh"
