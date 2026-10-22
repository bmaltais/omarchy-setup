#!/usr/bin/env bash
# Run displaylink-configure.sh against throwaway copies of your Hyprland/UWSM files and show the diff.
# Nothing is installed or reloaded: sudo and hyprctl reload are stubbed, HOME points at a temp dir.
# Usage: displaylink-dryrun.sh [--fake-evdi] [configure options...]
#   DRYRUN_CONFIGERRORS=text  make the stubbed `hyprctl configerrors` report an error, to exercise the rollback
#   --fake-evdi  pretend two evdi outputs (DVI-I-1, DVI-I-2) exist, to exercise the monitors.lua merge
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

need_cmd hyprctl python3 diff

FAKE=0
args=()
for a in "$@"; do
  if [[ "$a" == "--fake-evdi" ]]; then FAKE=1; else args+=("$a"); fi
done

REAL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home/.config/hypr" "$SANDBOX/home/.config/uwsm" "$SANDBOX/bin"
[[ -f "$REAL_CONFIG/hypr/monitors.lua" ]] && cp "$REAL_CONFIG/hypr/monitors.lua" "$SANDBOX/home/.config/hypr/"
[[ -f "$REAL_CONFIG/uwsm/env-hyprland" ]] && cp "$REAL_CONFIG/uwsm/env-hyprland" "$SANDBOX/home/.config/uwsm/"
cp -r "$SANDBOX/home/.config" "$SANDBOX/before"

REAL_HYPRCTL="$(command -v hyprctl)"
cat >"$SANDBOX/bin/sudo" <<'STUB'
#!/bin/sh
echo "[dry-run] sudo $*" >&2
STUB
cat >"$SANDBOX/bin/hyprctl" <<STUB
#!/usr/bin/env bash
if [[ "\$*" == "-j monitors all" ]]; then
  if [[ "$FAKE" == 1 ]]; then
    "$REAL_HYPRCTL" -j monitors all | python3 -c '
import json, sys
mons = json.load(sys.stdin)
for n in ("DVI-I-1", "DVI-I-2"):
    mons.append({"name": n, "x": 0, "y": 0, "width": 0, "height": 0, "scale": 1, "disabled": True, "availableModes": ["1920x1080@60.00Hz"]})
print(json.dumps(mons))'
  else
    exec "$REAL_HYPRCTL" "\$@"
  fi
  exit
fi
if [[ "\$1" == configerrors ]]; then echo "\${DRYRUN_CONFIGERRORS:-}"; exit 0; fi
echo "[dry-run] hyprctl \$*" >&2
STUB
chmod +x "$SANDBOX/bin/"*

HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/home/.config" PATH="$SANDBOX/bin:$PATH" \
  "$SCRIPT_DIR/displaylink-configure.sh" "${args[@]}" 2>&1 | sed "s#$SANDBOX#<sandbox>#g"

echo
echo "=== what would change under ~/.config (- before, + after) ==="
diff -ru "$SANDBOX/before" "$SANDBOX/home/.config" | sed "s#$SANDBOX/##g" || true
