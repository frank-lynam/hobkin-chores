#!/usr/bin/env bash
# clutter.sh — the watch: print only when $CHORE_FOLDER has more than $CHORE_THRESHOLD
# loose files at the top level (older than an hour). Silence = tidy = no model call.
set -euo pipefail
folder="${CHORE_FOLDER:?}"; threshold="${CHORE_THRESHOLD:-20}"
n=$(find "$folder" -maxdepth 1 -type f ! -name '.*' -mmin +60 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" -gt "$threshold" ]; then
  echo "$n loose files in $folder (threshold $threshold). Time to tidy: dry-run spells/sort.sh, then --go."
fi
exit 0
