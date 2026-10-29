#!/usr/bin/env bash
# prank.sh — the watch: maybe play one prank on whatever this account can reach, undo it, log it.
# Prints nothing unless an undo failed (the only thing worth waking the agent for).
#   prank.sh            a normal roll (window, chance, off switch, not-root all apply)
#   prank.sh --dry-run  list the playground and say what it would try; change nothing
set -uo pipefail
work="${HOBKIN_WORK:-.}"; ledger="$work/ledger.tsv"; cant="$work/mischief.cant"; dry=""
[ "${1:-}" = "--dry-run" ] && dry=1
[ -e "$work/mischief.off" ] && exit 0
if [ "$(id -u)" = 0 ] && [ "${CHORE_ALLOW_ROOT:-no}" != yes ]; then
  echo "mischief: running as root, so 'whatever it can reach' is the whole machine. Not playing. Give it a scoped account (or set allow_root=yes)."; exit 0
fi
win="${CHORE_WINDOW:-10-16}"; hour=$((10#$(date +%H)))
[ -z "$dry" ] && { [ "$hour" -lt "${win%-*}" ] || [ "$hour" -ge "${win#*-}" ]; } && exit 0
[ -z "$dry" ] && [ $((RANDOM % 100)) -ge "${CHORE_CHANCE:-25}" ] && exit 0
hold="${CHORE_HOLD:-60}"; touch "$cant" 2>/dev/null
never='(^|[@.-])(ssh|sshd|NetworkManager|systemd-networkd|systemd-resolved|networking|wpa_supplicant|systemd-journald|systemd-logind|journald|rsyslog|syslog-ng|syslog|auditd|dbus|polkit|hobkin|node_exporter|prometheus|alertmanager|grafana|telegraf|datadog|zabbix|collectd|netdata|otel|fluentd|fluent-bit|td-agent|filebeat|metricbeat|vector|promtail|loki|nagios|icinga|wazuh|osquery|falco|crowdstrike|falcon)'
spared() { [[ "$1" =~ $never ]] && return 0; for s in ${CHORE_SPARE:-}; do [ "${1%.service}" = "${s%.service}" ] && return 0; done
           grep -qxF "$1" "$cant" 2>/dev/null; }
log() { printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$1" "$2" "$3" >> "$ledger"; }

# --- the playground: services and processes this account might reach ---
acts=()
if [ -n "${CHORE_SERVICES:-}" ]; then svcs=$CHORE_SERVICES
else svcs=$(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk '{print $1}'); fi
for s in $svcs; do spared "$s" || acts+=("service $s"); done
for s in $(systemctl --user list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk '{print $1}'); do
  spared "$s" || acts+=("userunit $s")
done
mine=" $$ "; p=$$; while [ "$p" -gt 1 ]; do p=$(ps -o ppid= -p "$p" | tr -d ' '); [ -n "$p" ] || break; mine+="$p "; done
mysid=$(ps -o sid= -p $$ | tr -d ' ')          # our own session (pipelines, the agent's shell) is never a target
if [ -n "${CHORE_PROCESSES:-}" ]; then procs=$(for n in $CHORE_PROCESSES; do pgrep -x "$n"; done)
else procs=$(pgrep -U "$(id -u)"); fi
for pid in $procs; do
  [[ "$mine" == *" $pid "* ]] && continue
  [ "$(ps -o sid= -p "$pid" 2>/dev/null | tr -d ' ')" = "$mysid" ] && continue
  name=$(ps -o comm= -p "$pid" 2>/dev/null) || continue; args=$(ps -o args= -p "$pid" 2>/dev/null)
  case "$name" in bash|sh|zsh|fish|dash|tmux*|screen|sudo|su|login|sshd|ssh|ssh-agent|gpg-agent|systemd|'(sd-pam)'|ps|sleep|python3*) [[ "$args" == *hobkin* || "$name" != python3* ]] && continue ;; esac
  [[ "$args" == *hobkin* ]] && continue
  spared "$name" || acts+=("process $name")
done
acts+=("port")
mapfile -t acts < <(printf '%s\n' "${acts[@]}" | sort -u)

if [ -n "$dry" ]; then
  echo "playground (${#acts[@]}):"; printf '  %s\n' "${acts[@]}"
  echo "a real roll picks one at random; out-of-reach targets are remembered in $cant"; exit 0
fi

sys() { systemctl --no-ask-password "$@" 2>/dev/null || sudo -n systemctl "$@" 2>/dev/null; }
for try in 1 2 3 4 5; do                     # up to five picks, skipping what's out of reach
  pick="${acts[RANDOM % ${#acts[@]}]}"; kind=${pick%% *}; target=${pick#* }
  case "$kind" in
    service|userunit)
      u=""; [ "$kind" = userunit ] && u=--user
      if [ -n "$u" ]; then systemctl --user stop "$target" 2>/dev/null; else sys stop "$target"; fi \
        || { echo "$target" >> "$cant"; log stop "$target" "out of reach"; continue; }
      sleep "$hold"
      if [ -n "$u" ]; then systemctl --user start "$target" 2>/dev/null; else sys start "$target"; fi
      if systemctl $u is-active -q "$target"; then log stop "$target" undone; else
        log stop "$target" "NOT RESTORED"; echo "mischief: $target did NOT come back after the prank. Start it now: systemctl $u start $target"; fi
      exit 0 ;;
    process)
      pid=$(pgrep -o -x "$target") || continue
      kill -TERM "$pid" 2>/dev/null || { echo "$target" >> "$cant"; log kill "$target" "out of reach"; continue; }
      sleep "$hold"
      if pgrep -x "$target" >/dev/null; then log kill "$target" "came back"; else
        log kill "$target" "NOT BACK"; echo "mischief: killed $target (pid $pid) and it did NOT come back (no supervisor?). Restart it by hand."; fi
      exit 0 ;;
    port)
      ports="${CHORE_PORTS:-40000-40100}"; lo=${ports%-*}; hi=${ports#*-}; port=$((lo + RANDOM % (hi - lo + 1)))
      python3 -c "import socket,time; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('0.0.0.0',$port)); s.listen(); time.sleep($hold)" 2>/dev/null \
        && log port "$port" "opened and closed" || log port "$port" "couldn't open"
      exit 0 ;;
  esac
done
exit 0
