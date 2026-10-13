#!/usr/bin/env bash
# Show whether Resizable BAR is on in firmware and in the NVIDIA driver.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ok() { printf '  %-22s %s\n' "$1" "$2"; }

need_cmd lspci

echo "NVIDIA Resizable BAR status"
echo

found=0
while read -r pci; do
  found=1
  # The largest prefetchable region is BAR 1 (VRAM aperture).
  bar="$(lspci -v -s "$pci" | grep -E 'prefetchable\) \[size=' | grep -oE 'size=[0-9]+[MG]' | sort -t= -k2 -h | tail -1 | cut -d= -f2)"
  case "$bar" in
    256M | "") ok "BAR 1:" "${bar:-unknown} — firmware: enable Above 4G Decoding + Re-Size BAR" ;;
    *) ok "BAR 1:" "$bar — resized" ;;
  esac
done < <(lspci -D -d 10de: | awk '/VGA|3D controller/ {print $1}')
[[ $found -eq 1 ]] || ok "BAR 1:" "no NVIDIA GPU found"

if [[ -r /proc/driver/nvidia/params ]]; then
  ok "driver option:" "$(grep -E '^EnableResizableBar' /proc/driver/nvidia/params || echo 'not reported')"
else
  ok "driver option:" "nvidia module not loaded"
fi

if grep -rqs 'NVreg_EnableResizableBar=1' /etc/modprobe.d/; then
  ok "modprobe option:" "present"
else
  ok "modprobe option:" "missing — ./scripts/nvidia-resizable-bar-install.sh"
fi
