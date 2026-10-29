#!/usr/bin/env bash
# vitals.sh — the watch: print only what's wrong (silence = healthy = no model call).
# Thresholds come from the chore's settings, as $CHORE_DISK_PCT / _MEM_PCT / _LOAD_PER_CPU.
set -uo pipefail
disk_max="${CHORE_DISK_PCT:-90}"; mem_max="${CHORE_MEM_PCT:-90}"; load_max="${CHORE_LOAD_PER_CPU:-4}"
msgs=()

# Disk: every real filesystem's use%
while read -r use mount; do
  [ "${use%\%}" -ge "$disk_max" ] 2>/dev/null && msgs+=("disk ${use} on ${mount}")
done < <(df -P -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR>1{print $5, $6}')

# Memory: used% of total
read -r total avail < <(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, a}' /proc/meminfo 2>/dev/null)
if [ -n "${total:-}" ] && [ "$total" -gt 0 ]; then
  used=$(( (total - avail) * 100 / total ))
  [ "$used" -ge "$mem_max" ] && msgs+=("memory ${used}% used")
fi

# Load per CPU
cpus=$(nproc 2>/dev/null || echo 1)
load1=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
perc=$(awk -v l="$load1" -v c="$cpus" 'BEGIN{printf "%.1f", l/c}')
awk -v p="$perc" -v m="$load_max" 'BEGIN{exit !(p+0 >= m+0)}' && msgs+=("load ${load1} over ${cpus} CPUs (${perc}/cpu)")

# Failed systemd units
if command -v systemctl >/dev/null 2>&1; then
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd, -)
  [ -n "$failed" ] && msgs+=("failed units: ${failed}")
fi

[ ${#msgs[@]} -gt 0 ] && printf '%s\n' "something's amiss:" "${msgs[@]/#/  - }"
exit 0
