#!/usr/bin/env bash
# Build and install Arch's aquamarine with the evdi-on-NVIDIA CPU-copy patch (hyprwm/aquamarine#279).
# Needed only when Hyprland renders on NVIDIA and DisplayLink outputs stay at 0x0.
# Usage: displaylink-aquamarine-patch.sh [--build-only]
# Rerun after every Arch/Omarchy update that changes the aquamarine package.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ROOT="$(repo_root)"
PATCH="$ROOT/config/displaylink/aquamarine-evdi-nvidia.patch"
BUILD_ONLY=0
[[ "${1:-}" == "--build-only" ]] && BUILD_ONLY=1

need_cmd pacman makepkg git patch
omarchy pkg add cmake hyprwayland-scanner base-devel

# Installed version looks like 0.15.1-1 (stock) or 0.15.1-1.1 (already patched).
installed="$(pacman -Q aquamarine | awk '{print $2}')"
pkgver="${installed%%-*}"
pkgrel="${installed#*-}"
pkgrel="${pkgrel%%.*}"
echo "Stock base: aquamarine $pkgver-$pkgrel (installed: $installed)"

# Build outside the repo: it may live on a FUSE mount, and makepkg needs a plain filesystem.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone -q --depth 1 --branch "$pkgver-$pkgrel" \
  https://gitlab.archlinux.org/archlinux/packaging/packages/aquamarine.git "$work/aquamarine" 2>/dev/null \
  || { echo "No Arch packaging tag $pkgver-$pkgrel; check the aquamarine package page." >&2; exit 1; }
cd "$work/aquamarine"

# The patch is written against the upstream source of one release; verify it before building.
src="$work/src"
mkdir -p "$src"
curl -fsSL "https://github.com/hyprwm/aquamarine/archive/v$pkgver/aquamarine-$pkgver.tar.gz" | tar xz -C "$src"
if ! patch -Np1 --dry-run -d "$src/aquamarine-$pkgver" -i "$PATCH" >/dev/null; then
  echo "The patch does not apply to aquamarine $pkgver." >&2
  echo "Check whether hyprwm/aquamarine#279 was merged, or rebase config/displaylink/aquamarine-evdi-nvidia.patch." >&2
  exit 1
fi

cp "$PATCH" aquamarine-evdi-nvidia.patch
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
grep -q 'aquamarine-evdi-nvidia.patch' PKGBUILD && grep -q '^prepare()' PKGBUILD

makepkg -f --noconfirm
pkg="$(ls aquamarine-"$pkgver"-1.1-*.pkg.tar.zst | head -1)"

if (( BUILD_ONLY )); then
  keep="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-setup"
  mkdir -p "$keep"
  cp "$pkg" "$keep/"
  echo "Built $keep/$pkg (not installed)."
  exit 0
fi

need_sudo
sudo pacman -U --noconfirm "$pkg"
echo
echo "Installed $pkg. Log out and back in so Hyprland loads it."
echo "Undo: sudo pacman -S aquamarine   (reinstalls the stock package)"
