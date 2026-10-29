#!/usr/bin/env bash
# shred-plaintext.sh — DELETE plaintext whose ciphertext exists. Irreversible. Human-gated.
#   shred-plaintext.sh        dry run: list what would be removed
#   shred-plaintext.sh --go   remove plaintext, but ONLY where <file>.locked exists and is non-empty
# Run this only after lockdown.sh --go, and only after you've proven you can decrypt with your offline key.
set -uo pipefail
read -r -a paths <<< "${CHORE_PATHS:?set CHORE_PATHS}"
read -r -a globs <<< "${CHORE_PATTERNS:-*.sql *.dump *.csv *.json *.pem *.key *.env}"
go=""; [ "${1:-}" = "--go" ] && go=1
work="${HOBKIN_WORK:-.}"; manifest="$work/shred-$(date +%Y%m%d-%H%M%S).manifest.txt"

find_args=(); for g in "${globs[@]}"; do find_args+=(-name "$g" -o); done; unset 'find_args[${#find_args[@]}-1]'
mapfile -d '' files < <(find "${paths[@]}" -type f \( "${find_args[@]}" \) ! -name '*.locked' -print0 2>/dev/null)

[ -n "$go" ] && echo "# shred manifest $(date)" > "$manifest"
removed=0; skipped=0
for f in "${files[@]}"; do
  if [ ! -s "$f.locked" ]; then
    echo "  SKIP (no ciphertext) $f"; skipped=$((skipped+1)); continue
  fi
  if [ -z "$go" ]; then
    echo "  would shred  $f  (ciphertext: $f.locked)"
  else
    sum=$(sha256sum "$f" | cut -d' ' -f1)
    if command -v shred >/dev/null; then shred -u "$f"; else rm -f "$f"; fi
    echo "SHREDDED $sum $f" >> "$manifest"; echo "  shredded $f"; removed=$((removed+1))
  fi
done
if [ -z "$go" ]; then
  echo "(dry run — nothing removed. $skipped file(s) have no ciphertext and would be left.)"
else
  echo "done: $removed shredded, $skipped left (no ciphertext) (manifest: $manifest)"
fi
exit 0
