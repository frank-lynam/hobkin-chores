#!/usr/bin/env bash
# expiring.sh — the watch: print ONLY what's within $CHORE_DAYS of expiring (or expired).
# Checks TLS certs in $CHORE_TARGETS and the local Linux accounts it can read. Silence = nothing's
# due = no model call. Teach it more (databases, whois, keytabs) as this box needs — see CHORE.md.
set -uo pipefail
days="${CHORE_DAYS:-21}"
today=$(( $(date +%s) / 86400 ))
out=""

# --- TLS certificates ---
cert_end() {
  case "$1" in
    */*|*.pem|*.crt|*.cer) [ -f "$1" ] && openssl x509 -enddate -noout -in "$1" 2>/dev/null | cut -d= -f2 ;;
    *:*)  h="${1%:*}"; echo | timeout 10 openssl s_client -connect "$1" -servername "$h" 2>/dev/null | openssl x509 -enddate -noout 2>/dev/null | cut -d= -f2 ;;
    *)    echo | timeout 10 openssl s_client -connect "$1:443" -servername "$1" 2>/dev/null | openssl x509 -enddate -noout 2>/dev/null | cut -d= -f2 ;;
  esac
}
for t in ${CHORE_TARGETS:-}; do
  end=$(cert_end "$t")
  if [ -z "$end" ]; then out+="  - cert $t: couldn't read a certificate (unreachable, or none there)"$'\n'; continue; fi
  endd=$(( $(date -d "$end" +%s 2>/dev/null || echo 0) / 86400 )); left=$(( endd - today ))
  if [ "$left" -lt 0 ]; then out+="  - cert $t: EXPIRED $(( -left ))d ago ($end)"$'\n'
  elif [ "$left" -le "$days" ]; then out+="  - cert $t: expires in ${left}d ($end)"$'\n'; fi
done

# --- Linux passwords and accounts ---
emit_account() {   # $1 user, $2 label, $3 days-left
  [ -z "${3:-}" ] && return
  if [ "$3" -lt 0 ]; then out+="  - $2 for '$1': EXPIRED $(( -$3 ))d ago"$'\n'
  elif [ "$3" -le "$days" ]; then out+="  - $2 for '$1': in ${3}d"$'\n'; fi
}
if [ -r /etc/shadow ]; then                   # all users, when we can read it (usually root)
  while IFS=: read -r user pw last min max warn inact expire; do
    case "$pw" in ""|"*"|"!"*) continue ;; esac   # no password / locked: skip
    if [ -n "$max" ] && [ -n "$last" ] 2>/dev/null && [ "$max" -lt 99999 ] 2>/dev/null && [ "$last" -gt 0 ] 2>/dev/null; then
      emit_account "$user" "password" $(( last + max - today ))
    fi
    [ -n "$expire" ] && [ "$expire" -gt 0 ] 2>/dev/null && emit_account "$user" "account" $(( expire - today ))
  done < /etc/shadow
else                                          # at least our own account, via chage
  me=$(id -un)
  pe=$(chage -l "$me" 2>/dev/null | sed -n 's/^Password expires *: *//p')
  ae=$(chage -l "$me" 2>/dev/null | sed -n 's/^Account expires *: *//p')
  [ -n "$pe" ] && [ "$pe" != never ] && emit_account "$me" "password" $(( $(date -d "$pe" +%s 2>/dev/null || echo 0)/86400 - today ))
  [ -n "$ae" ] && [ "$ae" != never ] && emit_account "$me" "account" $(( $(date -d "$ae" +%s 2>/dev/null || echo 0)/86400 - today ))
fi

[ -n "$out" ] && { echo "something's running out of time (within ${days}d):"; printf '%s' "$out"; }
exit 0
