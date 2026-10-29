#!/usr/bin/env bash
# readycheck.sh — the watch: print ONLY when lockdown isn't ready to run (silence = ready).
# Checks there's a tool and a recipient, and that a test string encrypts. (It can't test that YOU
# can decrypt — only your offline private key can — so it reminds you to prove that yourself.)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/_enc.sh"
problems=()
[ -z "${CHORE_RECIPIENT:-}" ] && problems+=("no recipient set (CHORE_RECIPIENT)")
[ "$(enc_tool)" = none ] && problems+=("no encryption tool: install age or gpg")
if [ -n "${CHORE_RECIPIENT:-}" ] && [ "$(enc_tool)" != none ]; then
  tmp=$(mktemp -d); echo "canary $(date)" > "$tmp/t"
  if ! encrypt_file "$tmp/t" "$tmp/t.locked" 2>"$tmp/err" || [ ! -s "$tmp/t.locked" ]; then
    problems+=("the recipient won't encrypt a test file: $(tr -d '\n' < "$tmp/err" | cut -c1-200)")
  fi
  rm -rf "$tmp"
fi
if [ ${#problems[@]} -gt 0 ]; then
  printf '%s\n' "lockdown isn't ready (fix this BEFORE you need it):" "${problems[@]/#/  - }"
  echo "  Until it's ready, you can't protect the data in an emergency."
else
  # ready — but readiness only proves it can LOCK. Remind to prove UNLOCK works, off the box.
  canary="${HOBKIN_WORK:-.}/.lockdown-canary-checked"
  if [ ! -f "$canary" ] || [ -n "$(find "$canary" -mtime +30 2>/dev/null)" ]; then
    echo "lockdown can encrypt, but have you proven you can DECRYPT?"
    echo "  Decrypt a .locked file on another machine with your offline key, then: touch '$canary'"
    echo "  (A key that locks but can't unlock protects no one.)"
  fi
fi
exit 0
