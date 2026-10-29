#!/usr/bin/env bash
# keep.sh FILE... — before editing a file on the target, save a copy and record how to put it back.
# Copies go in $HOBKIN_WORK/mender/backups/<time>/<path>; each is logged in mender/changes.tsv with its undo.
set -uo pipefail
on="$(cd "$(dirname "$0")" && pwd)/on.sh"; stamp=$(date +%Y%m%d-%H%M%S)
dir="${HOBKIN_WORK:-.}/mender/backups/$stamp"; log="${HOBKIN_WORK:-.}/mender/changes.tsv"; mkdir -p "$dir"
[ -f "$log" ] || printf 'when\tfile\tbackup\tundo\n' > "$log"
for f in "$@"; do
  mkdir -p "$dir$(dirname "$f")"
  if "$on" "cat '$f'" > "$dir$f" 2>/dev/null; then
    undo="spells/on.sh \"cat > '$f'\" < '$dir$f'"
    printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$f" "$dir$f" "$undo" >> "$log"; echo "kept $f -> $dir$f   (undo: $undo)"
  else echo "couldn't read $f on ${CHORE_TARGET:-local}: not saved, so don't edit it blind"; rm -f "$dir$f"; exit 1; fi
done
