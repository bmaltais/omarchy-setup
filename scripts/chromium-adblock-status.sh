#!/usr/bin/env bash
# Show whether uBlock Origin Lite is installed for Chromium.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

UBOL_ID="ddkjiahejlhfcafbddmgiahcphecmpfh"
POLICY_DEST="/etc/chromium/policies/managed/ublock-origin-lite.json"
HOOK_DEST="/usr/share/chromium/extensions/${UBOL_ID}.json"
EXT_DIR="${HOME}/.config/chromium/Default/Extensions/${UBOL_ID}"

ok() { printf '  %-22s %s\n' "$1" "$2"; }

echo "Chromium ad blocker status"
echo

if command -v chromium >/dev/null 2>&1; then
  ver="$(pacman -Q chromium 2>/dev/null || chromium --product-version 2>/dev/null || echo present)"
  ok "chromium:" "$ver"
else
  ok "chromium:" "MISSING — omarchy install browser chromium"
fi

if [[ -f "$POLICY_DEST" ]]; then
  ok "policy:" "present ($POLICY_DEST)"
else
  ok "policy:" "missing"
fi

if [[ -f "$HOOK_DEST" ]]; then
  ok "store hook:" "present ($HOOK_DEST)"
else
  ok "store hook:" "missing"
fi

if [[ -d "$EXT_DIR" ]]; then
  ver="$(ls -1 "$EXT_DIR" 2>/dev/null | head -1)"
  ok "extension on disk:" "yes${ver:+ ($ver)}"
else
  if pgrep -x chromium >/dev/null 2>&1 && [[ ! -f "$POLICY_DEST" ]]; then
    ok "extension on disk:" "no (policy not installed)"
  elif pgrep -x chromium >/dev/null 2>&1; then
    ok "extension on disk:" "no (restart Chromium so it can download)"
  else
    ok "extension on disk:" "no (open Chromium after install)"
  fi
fi

if pgrep -x chromium >/dev/null 2>&1; then
  ok "chromium process:" "running"
else
  ok "chromium process:" "not running"
fi
