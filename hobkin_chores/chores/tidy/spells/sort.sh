#!/usr/bin/env bash
# sort.sh — the broom: sort loose files in $CHORE_FOLDER into subfolders by kind.
#   sort.sh        dry run: print what it would move, change nothing
#   sort.sh --go   actually move them
# Counter-spells, so the workshop never floods:
#   - dry run is the default; you must ask for --go
#   - skips files changed in the last hour (someone may be using them)
#   - skips hidden files and anything already in a subfolder
#   - moves at most $LIMIT files per run (default 300); never overwrites
set -euo pipefail
folder="${CHORE_FOLDER:?set CHORE_FOLDER}"
limit="${LIMIT:-300}"
go=""; [ "${1:-}" = "--go" ] && go=1

# extension -> subfolder; extend this as the folder needs
dest_for() {
  case "${1##*.}" in
    jpg|jpeg|png|gif|webp|heic|svg) echo images ;;
    mp4|mov|mkv|avi|webm)           echo video ;;
    mp3|wav|flac|m4a|ogg)           echo audio ;;
    pdf)                            echo pdfs ;;
    doc|docx|odt|rtf|txt|md)        echo documents ;;
    xls|xlsx|csv|ods)               echo spreadsheets ;;
    zip|tar|gz|tgz|bz2|xz|7z|rar)   echo archives ;;
    deb|rpm|dmg|pkg|appimage|exe|msi) echo installers ;;
    *)                              echo other ;;
  esac
}

moved=0
# -maxdepth 1: top level only; -mmin +60: older than an hour; not hidden
find "$folder" -maxdepth 1 -type f ! -name '.*' -mmin +60 -print0 |
while IFS= read -r -d '' f; do
  [ "$moved" -ge "$limit" ] && { echo "...stopping at the limit of $limit"; break; }
  base=$(basename "$f")
  sub=$(dest_for "$base")
  target="$folder/$sub/$base"
  [ -e "$target" ] && target="$folder/$sub/${base%.*}-$(date +%s).${base##*.}"
  if [ -n "$go" ]; then
    mkdir -p "$folder/$sub"
    mv -n "$f" "$target"
    echo "moved   $base -> $sub/"
  else
    echo "would move  $base -> $sub/"
  fi
  moved=$((moved + 1))
done
[ -z "$go" ] && echo "(dry run — nothing changed; run with --go to do it)"
exit 0
