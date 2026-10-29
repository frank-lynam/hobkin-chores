#!/usr/bin/env bash
# lockdown.sh — encrypt sensitive files to <file>.locked, KEEPING the plaintext.
#   lockdown.sh        dry run: list what would be encrypted
#   lockdown.sh --go   encrypt them (safe to re-run; skips files already locked and unchanged)
# Files: under $CHORE_PATHS, matching $CHORE_PATTERNS. Recipient: $CHORE_RECIPIENT (public key).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/_enc.sh"
: "${CHORE_RECIPIENT:?set CHORE_RECIPIENT (the public key to encrypt to)}"
read -r -a paths <<< "${CHORE_PATHS:?set CHORE_PATHS}"
read -r -a globs <<< "${CHORE_PATTERNS:-*.sql *.dump *.csv *.json *.pem *.key *.env}"
go=""; [ "${1:-}" = "--go" ] && go=1
work="${HOBKIN_WORK:-.}"; manifest="$work/lockdown-$(date +%Y%m%d-%H%M%S).manifest.txt"

find_args=(); for g in "${globs[@]}"; do find_args+=(-name "$g" -o); done; unset 'find_args[${#find_args[@]}-1]'
mapfile -d '' files < <(find "${paths[@]}" -type f \( "${find_args[@]}" \) ! -name '*.locked' -print0 2>/dev/null)

echo "lockdown: ${#files[@]} sensitive file(s) under ${paths[*]}"
[ -z "$go" ] && { printf '  would encrypt  %s\n' "${files[@]}"; echo "(dry run — nothing encrypted; --go to do it)"; exit 0; }
[ "$(enc_tool)" = none ] && { echo "no encryption tool (install age or gpg)"; exit 2; }

echo "# lockdown manifest $(date) recipient=$CHORE_RECIPIENT tool=$(enc_tool)" > "$manifest"
locked=0; failed=0
for f in "${files[@]}"; do
  out="$f.locked"
  [ -s "$out" ] && [ "$out" -nt "$f" ] && { echo "  (already locked) $f"; continue; }
  if encrypt_file "$f" "$out.tmp" && [ -s "$out.tmp" ]; then
    mv -f "$out.tmp" "$out"
    echo "LOCKED  $(stat -c%s "$f")  $f -> $out" >> "$manifest"; echo "  locked $f"; locked=$((locked+1))
  else
    rm -f "$out.tmp"; echo "FAILED  $f" >> "$manifest"; echo "  FAILED $f"; failed=$((failed+1))
  fi
done
echo "done: $locked locked, $failed failed (manifest: $manifest)"
echo "Plaintext is UNTOUCHED. Prove you can decrypt a .locked file with your offline key before shredding."
[ "$failed" -eq 0 ]
