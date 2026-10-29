#!/usr/bin/env bash
# prank.sh — the watch: maybe play one prank from the allow-list, undo it, log it.
# Prints nothing unless an undo failed (that's the only thing worth waking the agent for).
#   prank.sh            a normal roll (respects the window, the chance and the off switch)
#   prank.sh --dry-run  say what it would do, change nothing
set -uo pipefail
work="${HOBKIN_WORK:-.}"; ledger="$work/ledger.tsv"; dry=""; [ "${1:-}" = "--dry-run" ] && dry=1
[ -e "$work/mischief.off" ] && exit 0
hour=$((10#$(date +%H))); start=${CHORE_WINDOW%-*}; end=${CHORE_WINDOW#*-}
[ -z "$dry" ] && { [ "$hour" -lt "$start" ] || [ "$hour" -ge "$end" ]; } && exit 0
[ -z "$dry" ] && [ $((RANDOM % 100)) -ge "${CHORE_CHANCE:-25}" ] && exit 0
hold="${CHORE_HOLD:-60}"
never='^(ssh|sshd|systemd-journald|rsyslog|syslog|auditd|hobkin.*)(\.service)?$'
sys() { if [ "$(id -u)" = 0 ]; then systemctl "$@"; else sudo -n systemctl "$@"; fi; }
log() { printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$1" "$2" "$3" >> "$ledger"; }

acts=()
for s in ${CHORE_SERVICES:-}; do [[ "$s" =~ $never ]] || acts+=("service $s"); done
for p in ${CHORE_PROCESSES:-}; do [[ "$p" =~ $never ]] || acts+=("process $p"); done
acts+=("port")
pick="${acts[RANDOM % ${#acts[@]}]}"; kind=${pick%% *}; target=${pick#* }

case "$kind" in
  service)
    [ -n "$dry" ] && { echo "would stop $target for ${hold}s, then start it"; exit 0; }
    systemctl is-active -q "$target" || { log stop "$target" "skipped (wasn't running)"; exit 0; }
    sys stop "$target" 2>/dev/null || { log stop "$target" "no permission"; exit 0; }
    sleep "$hold"; sys start "$target" 2>/dev/null
    if systemctl is-active -q "$target"; then log stop "$target" undone; else
      log stop "$target" "NOT RESTORED"; echo "mischief: $target did NOT come back after the prank. Start it now: systemctl start $target"; fi ;;
  process)
    pid=$(pgrep -o -x "$target") || { [ -n "$dry" ] && echo "no $target running"; log kill "$target" "skipped (not running)"; exit 0; }
    [ -n "$dry" ] && { echo "would kill $target (pid $pid) and check it comes back within ${hold}s"; exit 0; }
    kill -TERM "$pid" 2>/dev/null || { log kill "$target" "no permission"; exit 0; }
    sleep "$hold"
    if pgrep -x "$target" >/dev/null; then log kill "$target" "came back"; else
      log kill "$target" "NOT BACK"; echo "mischief: killed $target and it did NOT come back (no supervisor?). Restart it by hand."; fi ;;
  port)
    ports="${CHORE_PORTS:-40000-40100}"; lo=${ports%-*}; hi=${ports#*-}; port=$((lo + RANDOM % (hi - lo + 1)))
    [ -n "$dry" ] && { echo "would listen on port $port for ${hold}s, then close it"; exit 0; }
    python3 -c "import socket,time,sys; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('0.0.0.0',$port)); s.listen(); time.sleep($hold)" 2>/dev/null \
      && log port "$port" "opened and closed" || log port "$port" "couldn't open" ;;
esac
exit 0
