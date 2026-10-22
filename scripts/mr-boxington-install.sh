#!/usr/bin/env bash
# Install Rust and mr-boxington (shared Cargo build cache) globally through mise.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# The mr_boxington Rust option needs mise 2026.9.2 or newer.
MIN_MISE="2026.9.2"

need_cmd mise

have="$(mise --version | awk '{print $1}')"
if [[ "$(printf '%s\n%s\n' "$MIN_MISE" "$have" | sort -V | head -1)" != "$MIN_MISE" ]]; then
  echo "mise $have is older than $MIN_MISE; update mise first." >&2
  exit 1
fi

mise use --global --tool-option mr_boxington=true rust mr-boxington

echo
echo "Open a new shell (or run: eval \"\$(mise activate bash)\"), then verify:"
echo "  command -v cargo   # should resolve through mise, not ~/.cargo/bin"
echo "  mbx --version"
