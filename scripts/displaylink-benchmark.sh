#!/usr/bin/env bash
# Measure what the evdi path costs: CPU of Hyprland and DisplayLinkManager, Hyprland log lines per
# second and log growth, over a fixed window. Run it before and after a change and compare.
# Output has no hostnames, monitor names or serials, so it is safe to paste into a public issue.
#
# Usage: displaylink-benchmark.sh [--seconds N] [--label TEXT]
#   Idle:    leave the desktop alone while it runs.
#   Moving:  drag a window across the DisplayLink screens while it runs.
set -euo pipefail

SECONDS_WINDOW=30
LABEL=""
while (($#)); do
  case "$1" in
    --seconds) SECONDS_WINDOW="${2:?--seconds needs a number}"; shift 2 ;;
    --label) LABEL="${2:?--label needs text}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# The login shell's signature can be stale after a relogin; use the newest instance that answers.
instance=""
for dir in $(ls -1dt "${XDG_RUNTIME_DIR:-/run/user/$UID}"/hypr/*/ 2>/dev/null); do
  sig="$(basename "$dir")"
  if HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl version >/dev/null 2>&1; then
    instance="$sig"
    break
  fi
done
[[ -n "$instance" ]] || { echo "No running Hyprland instance found." >&2; exit 1; }
export HYPRLAND_INSTANCE_SIGNATURE="$instance"
log="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/$instance/hyprland.log"

hypr_pid="$(pgrep -x Hyprland | head -1)"
dlm_pid="$(pgrep -f /usr/lib/displaylink/DisplayLinkManager | head -1 || true)"

# utime + stime in clock ticks, from /proc/<pid>/stat (fields 14 and 15; the comm field may hold spaces).
cpu_ticks() {
  local stat
  stat="$(<"/proc/$1/stat")"
  stat="${stat##*) }"
  set -- $stat
  echo $((${12} + ${13}))
}
ticks_per_sec="$(getconf CLK_TCK)"

log_lines() { wc -l <"$log"; }
log_bytes() { stat -c %s "$log"; }

monitors="$(hyprctl monitors | grep -c '^Monitor')"
speeds=""
for d in /sys/bus/usb/devices/*; do
  [[ "$(cat "$d/idVendor" 2>/dev/null)" == 17e9 ]] && speeds+="$(cat "$d/speed")M "
done

h0="$(cpu_ticks "$hypr_pid")"
d0=0
[[ -n "$dlm_pid" ]] && d0="$(cpu_ticks "$dlm_pid")"
l0="$(log_lines)"
b0="$(log_bytes)"
t0="$(date +%s.%N)"

sleep "$SECONDS_WINDOW"

h1="$(cpu_ticks "$hypr_pid")"
d1=0
[[ -n "$dlm_pid" ]] && d1="$(cpu_ticks "$dlm_pid")"
l1="$(log_lines)"
b1="$(log_bytes)"
t1="$(date +%s.%N)"

awk -v t0="$t0" -v t1="$t1" -v h="$((h1 - h0))" -v d="$((d1 - d0))" -v tps="$ticks_per_sec" \
  -v l="$((l1 - l0))" -v b="$((b1 - b0))" -v mons="$monitors" -v speeds="${speeds:-none}" \
  -v label="$LABEL" -v dlm="${dlm_pid:+yes}" -v cores="$(nproc)" 'BEGIN {
    w = t1 - t0
    if (label != "") printf "Label:                   %s\n", label
    printf "Window:                  %.1f s\n", w
    printf "Monitors:                %d\n", mons
    printf "DisplayLink USB link:    %s\n", speeds
    printf "Hyprland CPU:            %.1f %% of one core (machine has %d cores)\n", 100 * h / tps / w, cores
    if (dlm == "yes") printf "DisplayLinkManager CPU:  %.1f %% of one core\n", 100 * d / tps / w
    else print "DisplayLinkManager CPU:  not running"
    printf "Hyprland log:            %.1f lines/s, %.1f KiB/s\n", l / w, b / 1024 / w
  }'
