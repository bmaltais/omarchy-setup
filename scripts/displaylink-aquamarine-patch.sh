#!/usr/bin/env bash
# Build and install Arch's aquamarine with the evdi-on-NVIDIA CPU-copy patch (hyprwm/aquamarine#279).
# Needed only when Hyprland renders on NVIDIA and DisplayLink outputs stay at 0x0.
#
# Usage: displaylink-aquamarine-patch.sh [mode]
#   (none)          build the patched package and install it
#   --build-only    build it into ~/.cache/omarchy-setup, do not install
#   --status        print "patched" or "stock" for the installed library (exit 0 / 1)
#   --ensure        do nothing unless DisplayLink + NVIDIA are in use and the installed library
#                   lacks the fix; then rebuild, install and notify. Meant for the update hook.
#   --install-hook  run --ensure after every `omarchy update` (writes one file under ~/.config/omarchy/hooks)
#   --remove-hook   remove that file
#
# Testing overrides: AQUAMARINE_LIB (library to inspect), AQUAMARINE_PATCH (patch to build).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(repo_root)"
PATCH="${AQUAMARINE_PATCH:-$ROOT/config/displaylink/aquamarine-evdi-nvidia.patch}"
LIB="${AQUAMARINE_LIB:-/usr/lib/libaquamarine.so}"
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
HOOK="$HOOK_DIR/displaylink-aquamarine.hook"
# Logged by the patched library when the CPU-copy path is taken; a stock build lacks it. If upstream
# merges the fix with a different message, this check reports "stock" and the rebuild fails to apply,
# which the notification explains.
MARKER='dumb-buffer CPU copy'
MODE="${1:-install}"

notify() {
  echo "$1: $2" >&2
  if command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -u critical "$1" "$2" || true
  fi
}

has_fix() { grep -aqs -- "$MARKER" "$LIB"; }

uses_displaylink_on_nvidia() {
  pacman -Q displaylink >/dev/null 2>&1 && [[ -d /sys/module/nvidia_drm ]]
}

pr_state() {
  curl -fsS --max-time 5 https://api.github.com/repos/hyprwm/aquamarine/pulls/279 2>/dev/null |
    python3 -c 'import json,sys; d=json.load(sys.stdin); print("merged" if d.get("merged") else d.get("state","unknown"))' 2>/dev/null ||
    echo unknown
}

work=""
cleanup() { [[ -n "$work" ]] && rm -rf "$work"; return 0; }
trap cleanup EXIT

# Builds into $work and leaves the package path in $PKG. Returns non-zero with a message on failure.
build_package() {
  need_cmd pacman makepkg git patch curl python3 bsdtar || return 1
  omarchy pkg add cmake hyprwayland-scanner base-devel || return 1

  # Installed version looks like 0.15.1-1 (stock) or 0.15.1-1.1 (already patched).
  local installed pkgver pkgrel
  installed="$(pacman -Q aquamarine | awk '{print $2}')"
  pkgver="${installed%%-*}"
  pkgrel="${installed#*-}"
  pkgrel="${pkgrel%%.*}"
  echo "Stock base: aquamarine $pkgver-$pkgrel (installed: $installed)"

  # Build outside the repo: it may live on a FUSE mount, and makepkg needs a plain filesystem.
  work="$(mktemp -d)"
  git clone -q --depth 1 --branch "$pkgver-$pkgrel" \
    https://gitlab.archlinux.org/archlinux/packaging/packages/aquamarine.git "$work/aquamarine" 2>/dev/null || {
    echo "No Arch packaging tag $pkgver-$pkgrel." >&2
    return 1
  }

  [[ -s "$PATCH" ]] || { echo "Patch file is missing or empty: $PATCH" >&2; return 3; }

  # The patch is written against one upstream release; verify it applies before building.
  mkdir -p "$work/src"
  curl -fsSL "https://github.com/hyprwm/aquamarine/archive/v$pkgver/aquamarine-$pkgver.tar.gz" | tar xz -C "$work/src" || return 1
  if ! patch -Np1 --dry-run -d "$work/src/aquamarine-$pkgver" -i "$PATCH" >/dev/null; then
    echo "The patch does not apply to aquamarine $pkgver (upstream PR #279 is: $(pr_state))." >&2
    return 2
  fi

  cd "$work/aquamarine"
  cp "$PATCH" aquamarine-evdi-nvidia.patch
  local sum
  sum="$(sha256sum aquamarine-evdi-nvidia.patch | cut -d' ' -f1)"
  python3 - "$sum" <<'PY'
import re, sys
s = open("PKGBUILD").read()
s = s.replace("pkgrel=1\n", "pkgrel=1.1\n", 1)
s = re.sub(r'(source=\("[^"]*")\)', r'\1\n        aquamarine-evdi-nvidia.patch)', s, count=1)
s = re.sub(r"(sha256sums=\('[0-9a-f]+')\)", r"\1\n            '%s')" % sys.argv[1], s, count=1)
s = s.replace("build() {", 'prepare() {\n\tcd "$_archive"\n\t# hyprwm/aquamarine#279: CPU-copy fallback for evdi outputs on NVIDIA\n\tpatch -Np1 -i ../aquamarine-evdi-nvidia.patch\n}\n\nbuild() {', 1)
open("PKGBUILD", "w").write(s)
PY
  grep -q 'aquamarine-evdi-nvidia.patch' PKGBUILD && grep -q '^prepare()' PKGBUILD || {
    echo "The Arch PKGBUILD changed shape; the patch step could not be added." >&2
    return 1
  }

  makepkg -f --noconfirm || return 1
  PKG="$work/aquamarine/$(ls aquamarine-"$pkgver"-1.1-*.pkg.tar.zst | head -1)"

  # Never install a package that does not carry the fix (empty or wrong patch, changed build).
  # grep -c reads the whole stream; grep -q would exit early and break bsdtar's pipe under pipefail.
  local hits
  hits="$(bsdtar -xOf "$PKG" --include 'usr/lib/libaquamarine.so.*' | grep -ac -- "$MARKER" || true)"
  if (( hits == 0 )); then
    echo "The built package does not contain the evdi fix; refusing to use it." >&2
    return 3
  fi
}

install_package() {
  need_sudo
  sudo pacman -U --noconfirm "$PKG"
}

case "$MODE" in
  install)
    build_package
    install_package
    echo
    echo "Installed $(basename "$PKG"). Log out and back in so Hyprland loads it."
    echo "Undo: sudo pacman -S aquamarine   (reinstalls the stock package)"
    ;;
  --build-only)
    build_package
    keep="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-setup"
    mkdir -p "$keep"
    cp "$PKG" "$keep/"
    echo "Built $keep/$(basename "$PKG") (not installed)."
    ;;
  --status)
    if has_fix; then echo "patched"; else echo "stock"; exit 1; fi
    ;;
  --ensure)
    uses_displaylink_on_nvidia || exit 0
    if has_fix; then
      echo "aquamarine already has the evdi fix."
      exit 0
    fi
    echo "aquamarine lost the evdi fix (package update?). Rebuilding the patched package..."
    rc=0
    build_package || rc=$?
    if (( rc == 2 )); then
      notify "DisplayLink screens need attention" \
        "The Aquamarine evdi patch no longer applies (upstream PR #279: $(pr_state)). Dock screens will show no signal until the patch is updated."
      exit 1
    elif (( rc != 0 )); then
      notify "DisplayLink patch rebuild failed" \
        "Could not build the patched Aquamarine. Dock screens will show no signal. Run displaylink-aquamarine-patch.sh by hand."
      exit 1
    fi
    if ! install_package; then
      notify "DisplayLink patch install failed" "The patched Aquamarine was built but could not be installed."
      exit 1
    fi
    notify "DisplayLink patch reinstalled" "Aquamarine was updated; the evdi patch was rebuilt. Log out and back in."
    ;;
  --install-hook)
    mkdir -p "$HOOK_DIR"
    cat >"$HOOK" <<EOF
#!/usr/bin/env bash
# Installed by omarchy-setup (displaylink-aquamarine-patch.sh --install-hook). Remove with --remove-hook.
script='$SCRIPT_DIR/displaylink-aquamarine-patch.sh'
if [[ -x \$script ]]; then
  exec "\$script" --ensure
fi
omarchy-notification-send -u critical "DisplayLink patch hook" "\$script is missing; run --remove-hook or restore the repo." 2>/dev/null || true
EOF
    chmod +x "$HOOK"
    echo "Installed $HOOK"
    ;;
  --remove-hook)
    rm -f "$HOOK"
    echo "Removed $HOOK"
    ;;
  *)
    echo "Unknown option: $MODE" >&2
    exit 2
    ;;
esac
