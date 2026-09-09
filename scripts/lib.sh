# shellcheck shell=bash
# Shared helpers for omarchy-setup playbook scripts.

set -euo pipefail

repo_root() {
  local src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  local here
  here="$(cd "$(dirname "$src")" && pwd)"
  git -C "$here" rev-parse --show-toplevel 2>/dev/null || realpath "$here/.."
}

need_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || {
      echo "Missing command: $c" >&2
      return 1
    }
  done
}

need_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo "This step needs sudo in a visible terminal." >&2
  fi
}

install_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  sudo install -D -m "$mode" "$src" "$dest"
}

# Vendor of the PCI GPU that currently owns a connected connector, else first VGA.
primary_gpu_pci() {
  local conn pci
  for conn in /sys/class/drm/card*-*; do
    [[ -f "$conn/status" ]] || continue
    [[ "$(cat "$conn/status")" == connected ]] || continue
    pci="$(readlink -f "$conn" | grep -oE '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]' | tail -1 || true)"
    if [[ -n "${pci:-}" ]]; then
      echo "$pci"
      return 0
    fi
  done
  lspci -Dnnd ::03xx 2>/dev/null | awk '{print $1; exit}'
}

gpu_vendor_from_pci() {
  local pci="$1" vendor
  vendor="$(cat /sys/bus/pci/devices/$pci/vendor 2>/dev/null || true)"
  case "$vendor" in
    0x10de) echo nvidia ;;
    0x1002) echo amd ;;
    0x8086) echo intel ;;
    *) echo gpu ;;
  esac
}

sanitize_text() {
  local host user
  host="$(hostname 2>/dev/null || true)"
  user="${USER:-}"
  sed -E \
    -e "s/${host:-__nohost__}/<hostname>/g" \
    -e "s/${user:-__nouser__}/<user>/g" \
    -e 's#/home/[^/]+#/home/<user>#g' \
    -e 's/\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b/<mac>/g' \
    -e 's/\bserial: .*/serial: <redacted>/' \
    -e 's/\bSerialNumber: .*/SerialNumber: <redacted>/'
}
