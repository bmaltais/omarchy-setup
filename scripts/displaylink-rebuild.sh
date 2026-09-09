#!/usr/bin/env bash
# Rebuild evdi after a kernel / Omarchy update and restart DisplayLink.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

need_cmd dkms
need_sudo
sudo dkms autoinstall
sudo systemctl restart displaylink.service
echo
dkms status | grep -i evdi || true
systemctl --no-pager --full status displaylink.service || true
lsmod | grep -E '^evdi' || echo "evdi is not loaded — check dkms build logs under /var/lib/dkms/evdi/"
