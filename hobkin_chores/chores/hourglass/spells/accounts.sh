#!/usr/bin/env bash
# accounts.sh — a fuller report of Linux password/account expiry, soonest first.
# Reads /etc/shadow if it can (all users), else reports your own account via chage.
set -uo pipefail
today=$(( $(date +%s) / 86400 ))
rows=""
add() { rows+="$1"$'\t'"$2"$'\t'"$3"$'\n'; }   # days-left, user, what
if [ -r /etc/shadow ]; then
  while IFS=: read -r user pw last min max warn inact expire; do
    case "$pw" in ""|"*"|"!"*) continue ;; esac
    [ -n "$max" ] && [ -n "$last" ] 2>/dev/null && [ "$max" -lt 99999 ] 2>/dev/null && [ "$last" -gt 0 ] 2>/dev/null && add $(( last + max - today )) "$user" "password expires"
    [ -n "$expire" ] && [ "$expire" -gt 0 ] 2>/dev/null && add $(( expire - today )) "$user" "account expires"
  done < /etc/shadow
else
  me=$(id -un)
  echo "(can't read /etc/shadow — showing only '$me'; run as root for all users)"
  chage -l "$me"
  exit 0
fi
if [ -z "$rows" ]; then echo "no accounts have an expiry set."; else
  echo "account/password expiry, soonest first (negative = already expired):"
  printf '%s' "$rows" | sort -n | awk -F'\t' '{printf "  %5sd  %-16s %s\n", $1, $2, $3}'
fi
