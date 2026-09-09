#!/usr/bin/env bash
# Remove the uBlock Origin Lite Chromium policy this playbook installed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

UBOL_ID="ddkjiahejlhfcafbddmgiahcphecmpfh"
POLICY_DEST="/etc/chromium/policies/managed/ublock-origin-lite.json"
HOOK_DEST="/usr/share/chromium/extensions/${UBOL_ID}.json"

need_sudo
sudo rm -f "$POLICY_DEST" "$HOOK_DEST"

echo "Removed:"
echo "  $POLICY_DEST"
echo "  $HOOK_DEST"
echo
echo "Quit and reopen Chromium so it drops the force-installed extension."
echo "Omarchy theme policy (color.json) and bundled extensions are unchanged."
