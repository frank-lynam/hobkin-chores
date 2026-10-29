#!/usr/bin/env bash
# artifacts.sh — find leftover sysadmin artifacts (backups, editor droppings, package leftovers).
#   artifacts.sh               report: every artifact, its age, its original, stale or not
#   artifacts.sh --quarantine  move the STALE ones (that it may move) into $CHORE_FOLDER/_quarantine/<date>/
# Stale = older than $CHORE_STALE_DAYS, the original exists, and the original is newer and different.
set -uo pipefail
stale_days="${CHORE_STALE_DAYS:-90}"; q=""; [ "${1:-}" = "--quarantine" ] && q=1
read -r -a roots <<< "${CHORE_ARTIFACT_PATHS:-/etc} ${CHORE_FOLDER:-}"
qdir="${CHORE_FOLDER:-$HOBKIN_WORK}/_quarantine/$(date +%F)"; manifest="$qdir/MANIFEST.tsv"
now=$(date +%s)

original_of() {   # strip the artifact suffix to name the original
  local f="$1"
  case "$f" in
    *.dpkg-old|*.dpkg-dist|*.dpkg-bak|*.rpmsave|*.rpmorig|*.rpmnew|*.ucf-old|*.ucf-dist) echo "${f%.*}" ;;
    *.bak|*.backup|*.orig|*.old|*.save|*.prev) echo "${f%.*}" ;;
    *~) echo "${f%\~}" ;;
    */.*.swp) d=$(dirname "$f"); b=$(basename "$f" .swp); echo "$d/${b#.}" ;;
    *) echo "$f" | sed -E 's/[._-](19|20)[0-9]{2}-?[01][0-9]-?[0-3][0-9]([._-]?[0-9]{4,6})?$//' ;;
  esac
}

printf '%-6s %-7s %s\n' "days" "status" "artifact -> original"
find "${roots[@]}" -xdev -type f \( -name '*.bak' -o -name '*.backup' -o -name '*.orig' -o -name '*.old' \
    -o -name '*.save' -o -name '*.prev' -o -name '*~' -o -name '.*.swp' -o -name '*.dpkg-*' -o -name '*.rpmsave' \
    -o -name '*.rpmorig' -o -name '*.rpmnew' -o -name '*.ucf-*' -o -regex '.*[._-]\(19\|20\)[0-9][0-9]-?[01][0-9]-?[0-3][0-9]\([._-]?[0-9]+\)?$' \) \
    -not -path '*/_quarantine/*' 2>/dev/null | sort | while IFS= read -r f; do
  orig=$(original_of "$f"); age=$(( (now - $(stat -c %Y "$f")) / 86400 ))
  if [ "$orig" = "$f" ] || [ ! -e "$orig" ]; then status="orphan"
  elif [ "$age" -ge "$stale_days" ] && [ "$orig" -nt "$f" ] && ! cmp -s "$f" "$orig"; then status="STALE"
  else status="keep"; fi
  printf '%-6s %-7s %s -> %s\n' "$age" "$status" "$f" "$orig"
  if [ -n "$q" ] && [ "$status" = STALE ]; then
    if [ -w "$(dirname "$f")" ] && mkdir -p "$qdir$(dirname "$f")" 2>/dev/null && mv -n "$f" "$qdir$f" 2>/dev/null; then
      printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$f" "$qdir$f" >> "$manifest"; echo "       quarantined -> $qdir$f"
    else echo "       (can't move it from here: put it in a for-review script)"; fi
  fi
done
exit 0
