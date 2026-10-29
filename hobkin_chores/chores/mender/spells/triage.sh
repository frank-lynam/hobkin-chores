#!/usr/bin/env bash
# triage.sh — a fast, READ-ONLY sweep of everything that usually breaks (on your host, if you have one).
set -uo pipefail
sec() { echo; echo "=== $1 ==="; bash -c "$2" 2>&1 | head -n "${3:-25}"; }
echo "triage of $(hostname) at $(date '+%F %T')"
sec "who and how long up"     'hostname; uptime; last -x reboot shutdown 2>/dev/null | head -5'
sec "disk (space, then inodes)" 'df -hP -x tmpfs -x devtmpfs; echo; df -iP -x tmpfs -x devtmpfs | awk "NR==1 || \$5+0>=80"'
sec "memory, and OOM kills"   'free -h; journalctl -k -b --no-pager 2>/dev/null | grep -i -E "out of memory|oom-kill" | tail -5'
sec "failed services"         'systemctl --failed --no-legend --plain 2>/dev/null || echo "(no systemd)"'
sec "errors in the last 2h"   'journalctl -p err --since "-2h" --no-pager -q 2>/dev/null | tail -20' 25
sec "kernel trouble"          'dmesg -T --level=err,crit,alert,emerg 2>/dev/null | tail -10 || journalctl -k -p err -b --no-pager -q | tail -10'
sec "network: addresses and routes" 'ip -brief addr 2>/dev/null; ip route 2>/dev/null | head -5'
sec "network: can it get out?" 'gw=$(ip route 2>/dev/null | awk "/default/{print \$3; exit}"); [ -n "$gw" ] && (ping -c1 -W2 "$gw" >/dev/null && echo "gateway $gw: ok" || echo "gateway $gw: NO REPLY") || echo "no default route"; getent hosts example.com >/dev/null && echo "DNS: ok" || echo "DNS: FAILING ($(grep -m2 nameserver /etc/resolv.conf | tr "\n" " "))"; (timeout 5 bash -c "</dev/tcp/1.1.1.1/443" 2>/dev/null && echo "outbound 443: ok") || echo "outbound 443: BLOCKED/DOWN"'
sec "time"                    'timedatectl 2>/dev/null | grep -E "Local time|synchronized|NTP" || date'
sec "listening"               'ss -ltnup 2>/dev/null | head -20'
sec "what changed (packages)" 'tail -n 30 /var/log/apt/history.log 2>/dev/null | grep -E "^(Start-Date|Commandline|Upgrade|Install|Remove)" | tail -12; (rpm -qa --last 2>/dev/null | head -8)'
sec "what changed (/etc, last 2 days)" 'find /etc -xdev -type f -mtime -2 -printf "%TY-%Tm-%Td %TH:%TM  %p\n" 2>/dev/null | sort -r | head -15'
sec "load and top processes"  'cat /proc/loadavg; ps -eo pid,user,pcpu,pmem,etime,comm --sort=-pcpu | head -8'
echo; echo "(read-only: nothing was changed)"
