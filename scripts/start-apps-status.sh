#!/usr/bin/env bash
# Show which Start* plugins, the StartFS daemon, and Oma Cast are installed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ok() { printf '  %-16s %s\n' "$1" "$2"; }

plugin_state() {
  omarchy plugin list 2>/dev/null | awk -v id="$1" '$1 == id { print $2; found=1 } END { if (!found) print "missing" }'
}

echo "Start apps status"
echo

for pair in \
  "StartBar:io.github.bmaltais.startbar" \
  "StartAppImage:io.github.bmaltais.startappimage" \
  "StartFSGUI:io.github.bmaltais.startfsgui" \
  "Oma Cast:typecraft.oma-cast"; do
  ok "${pair%%:*}:" "$(plugin_state "${pair#*:}")"
done

if command -v startfs >/dev/null 2>&1; then
  ok "startfs:" "$(startfs --version 2>/dev/null | head -1)"
else
  ok "startfs:" "missing"
fi
ok "startfs service:" "$(systemctl --user is-active startfs 2>/dev/null || echo inactive)"
ok "tailscaled:" "$(systemctl is-active tailscaled 2>/dev/null || echo inactive)"
command -v unsquashfs >/dev/null 2>&1 && ok "unsquashfs:" "present" || ok "unsquashfs:" "MISSING (StartAppImage needs squashfs-tools)"
command -v oma-cast >/dev/null 2>&1 && ok "oma-cast cli:" "present" || ok "oma-cast cli:" "missing"
if command -v startappimage >/dev/null 2>&1; then
  startappimage list 2>/dev/null | awk '$1 == "artcraft-launcher" { print "  artcraft:        " $2; f=1 } END { if (!f) print "  artcraft:        missing" }'
else
  ok "artcraft:" "unknown (startappimage not on PATH)"
fi
