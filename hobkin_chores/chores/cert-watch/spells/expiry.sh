#!/usr/bin/env bash
# expiry.sh — the watch: print only certs within $CHORE_DAYS of expiry (or expired/unreachable).
# $CHORE_TARGETS is space-separated: "host:port" (live) and/or paths to PEM files.
set -uo pipefail
days="${CHORE_DAYS:-21}"
now=$(date +%s)

not_after() {   # echo the notAfter date for one target, or nothing on failure
  case "$1" in
    */*|*.pem|*.crt|*.cer)
      [ -f "$1" ] && openssl x509 -enddate -noout -in "$1" 2>/dev/null | cut -d= -f2 ;;
    *:*)
      host="${1%:*}"; port="${1##*:}"
      echo | timeout 10 openssl s_client -connect "$1" -servername "$host" 2>/dev/null \
        | openssl x509 -enddate -noout 2>/dev/null | cut -d= -f2 ;;
    *)
      echo | timeout 10 openssl s_client -connect "$1:443" -servername "$1" 2>/dev/null \
        | openssl x509 -enddate -noout 2>/dev/null | cut -d= -f2 ;;
  esac
}

for t in $CHORE_TARGETS; do
  end=$(not_after "$t")
  if [ -z "$end" ]; then
    echo "  - $t: couldn't read a certificate (unreachable, or no cert there)"
    continue
  fi
  endts=$(date -d "$end" +%s 2>/dev/null) || continue
  left=$(( (endts - now) / 86400 ))
  if [ "$left" -lt 0 ]; then
    echo "  - $t: EXPIRED $(( -left )) days ago ($end)"
  elif [ "$left" -le "$days" ]; then
    echo "  - $t: expires in $left days ($end)"
  fi
done
exit 0
