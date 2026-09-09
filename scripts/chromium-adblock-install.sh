#!/usr/bin/env bash
# Force-install uBlock Origin Lite in Omarchy Chromium.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

UBOL_ID="ddkjiahejlhfcafbddmgiahcphecmpfh"
ROOT="$(repo_root)"
POLICY_SRC="$ROOT/config/chromium-adblock/ublock-origin-lite.json"
HOOK_SRC="$ROOT/config/chromium-adblock/extension.json"
POLICY_DEST="/etc/chromium/policies/managed/ublock-origin-lite.json"
HOOK_DEST="/usr/share/chromium/extensions/${UBOL_ID}.json"

need_cmd chromium python3
python3 -c "import json,sys; json.load(open(sys.argv[1])); json.load(open(sys.argv[2]))" \
  "$POLICY_SRC" "$HOOK_SRC"

need_sudo
sudo mkdir -p /etc/chromium/policies/managed /usr/share/chromium/extensions
install_file "$POLICY_SRC" "$POLICY_DEST" 0644
install_file "$HOOK_SRC" "$HOOK_DEST" 0644

echo "Installed uBlock Origin Lite policy:"
echo "  $POLICY_DEST"
echo "  $HOOK_DEST"
echo

if pgrep -x chromium >/dev/null 2>&1; then
  echo "Chromium is running. Quit it fully, then open it again so the extension downloads."
  echo "Reload any YouTube tab that was already open (Ctrl+R)."
else
  echo "Open Chromium. The extension installs on first launch after this policy."
fi
echo
echo "Then: ./scripts/chromium-adblock-status.sh"
