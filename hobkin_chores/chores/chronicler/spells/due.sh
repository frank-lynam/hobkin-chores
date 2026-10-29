#!/usr/bin/env bash
# due.sh — the watch: once a week, on $CHORE_DAY, say it's chronicle time. `due.sh --done` marks this week written.
stamp="${HOBKIN_WORK:-.}/chronicler/last-week"; mkdir -p "$(dirname "$stamp")"; week=$(date +%G-W%V)
[ "${1:-}" = "--done" ] && { echo "$week" > "$stamp"; echo "chronicle for $week marked written"; exit 0; }
[ "$(cat "$stamp" 2>/dev/null)" = "$week" ] && exit 0
[ "$(date +%a)" = "${CHORE_DAY:-Mon}" ] || [ "${1:-}" = "--now" ] || exit 0
echo "It's $(date +%A): time to write the chronicle for the week before $(date +%F) (spells/gather.sh, then due.sh --done)."
