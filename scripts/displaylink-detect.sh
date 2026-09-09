#!/usr/bin/env bash
# Report DisplayLink / evdi / Hyprland state. --sanitize redacts host-specific values.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SANITIZE=0
[[ "${1:-}" == "--sanitize" ]] && SANITIZE=1

emit() {
  if (( SANITIZE )); then
    sanitize_text
  else
    cat
  fi
}

{
  echo "=== kernel ==="
  uname -r
  pacman -Q linux linux-headers 2>/dev/null || true
  pacman -Qq | grep -E 'headers$' || true

  echo
  echo "=== DisplayLink USB (vendor 17e9) ==="
  if command -v lsusb >/dev/null; then
    lsusb | grep -iE '17e9|DisplayLink|Synaptics' || echo "(none)"
    echo
    echo "=== USB tree (speed) ==="
    lsusb -t 2>/dev/null || true
  else
    echo "lsusb not installed (omarchy pkg add usbutils)"
    for d in /sys/bus/usb/devices/*; do
      [[ -f "$d/idVendor" ]] || continue
      printf '%s %s:%s speed=%s %s %s\n' \
        "$(basename "$d")" "$(cat "$d/idVendor")" "$(cat "$d/idProduct")" \
        "$(cat "$d/speed")" "$(cat "$d/manufacturer" 2>/dev/null || true)" \
        "$(cat "$d/product" 2>/dev/null || true)"
    done
  fi

  echo
  echo "=== packages ==="
  pacman -Q evdi-dkms evdi-dkms-git displaylink dkms 2>/dev/null || true

  echo
  echo "=== evdi module ==="
  lsmod | grep -E '^evdi' || echo "(not loaded)"
  [[ -f /sys/module/evdi/version ]] && echo "evdi version $(cat /sys/module/evdi/version)"

  echo
  echo "=== displaylink.service ==="
  systemctl is-enabled displaylink.service 2>/dev/null || echo "not enabled"
  systemctl is-active displaylink.service 2>/dev/null || echo "not active"

  echo
  echo "=== DRM ==="
  ls -l /dev/dri/ /dev/dri/by-path/ 2>/dev/null || true
  echo
  for c in /sys/class/drm/card*-*; do
    [[ -f "$c/status" ]] || continue
    echo "$(basename "$c"): status=$(cat "$c/status") enabled=$(cat "$c/enabled" 2>/dev/null || echo n/a)"
  done

  echo
  echo "=== GPU ==="
  lspci -d ::03xx -nnk 2>/dev/null || true

  echo
  echo "=== hyprctl monitors ==="
  if command -v hyprctl >/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -d "${XDG_RUNTIME_DIR:-}/hypr" ]]; then
    hyprctl monitors 2>/dev/null || echo "(hyprctl failed)"
  else
    echo "(not in a Hyprland session)"
  fi
} | emit
