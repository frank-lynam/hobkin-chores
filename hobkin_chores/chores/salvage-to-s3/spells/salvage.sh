#!/usr/bin/env bash
# salvage.sh — copy $CHORE_SOURCES (plus anything you add) to $CHORE_DEST, with a manifest.
#   salvage.sh           dry run: list what would be copied, and the total size
#   salvage.sh --go      actually copy
#   salvage.sh --go PATH...   copy these paths instead of $CHORE_SOURCES (e.g. your staging/ dumps)
# Dest: s3://bucket/prefix (aws s3 sync) | remote:path (rclone copy) | a folder (cp -a). Safe to re-run.
set -uo pipefail
dest="${CHORE_DEST:?set CHORE_DEST}"
go=""; [ "${1:-}" = "--go" ] && { go=1; shift; }
sources=("$@"); [ ${#sources[@]} -eq 0 ] && read -r -a sources <<< "${CHORE_SOURCES:-/etc /var/log}"
stamp=$(date +%Y%m%d-%H%M%S); host=$(hostname)
work="${HOBKIN_WORK:-.}"; manifest="$work/salvage-$stamp.manifest.txt"

echo "salvage: ${#sources[@]} source(s) -> $dest"
total=0
for s in "${sources[@]}"; do
  if [ -e "$s" ]; then
    sz=$(du -sh "$s" 2>/dev/null | cut -f1); echo "  $s ($sz)"
  else
    echo "  $s (MISSING — skipped)"
  fi
done
if [ -z "$go" ]; then
  echo "(dry run — nothing copied; run with --go to do it)"
  exit 0
fi

upload() {   # upload one path to $dest/<host>/<basename>
  local src="$1" base; base=$(basename "$src")
  case "$dest" in
    s3://*)   aws s3 sync "$src" "${dest%/}/$host/$base" ;;
    *:*)      rclone copy "$src" "${dest%/}/$host/$base" ;;
    *)        mkdir -p "$dest/$host/$base" && cp -a "$src/." "$dest/$host/$base/" 2>/dev/null \
                || { mkdir -p "$dest/$host" && cp -a "$src" "$dest/$host/"; } ;;
  esac
}

echo "# salvage manifest $stamp from $host -> $dest" > "$manifest"
rc=0
for s in "${sources[@]}"; do
  [ -e "$s" ] || continue
  echo ">> $s"
  if upload "$s"; then
    find "$s" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
      sum=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1); sz=$(stat -c%s "$f" 2>/dev/null)
      echo "$sum  $sz  $f" >> "$manifest"
    done
  else
    echo "!! FAILED: $s" >> "$manifest"; rc=1; echo "  failed to copy $s"
  fi
done
files=$(grep -c '^[0-9a-f]' "$manifest" 2>/dev/null || echo 0)
echo "done: $files files in the manifest ($manifest)"
[ "$rc" -ne 0 ] && echo "SOME COPIES FAILED — see the manifest; run again to resume."
exit $rc
