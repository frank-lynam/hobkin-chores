#!/usr/bin/env bash
# try.sh CMD... — run one install step and journal it (time, exit code, folder, command).
# The journal ($HOBKIN_WORK/shipwright/journal.tsv) is the honest record the final script is built from.
set -uo pipefail
[ $# -eq 0 ] && { echo "usage: try.sh COMMAND [ARGS...]"; exit 2; }
j="${HOBKIN_WORK:-.}/shipwright/journal.tsv"; mkdir -p "$(dirname "$j")"
[ -f "$j" ] || printf 'when\texit\tfolder\tcommand\n' > "$j"
"$@"; rc=$?
printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$rc" "$PWD" "$(printf '%q ' "$@")" >> "$j"
[ "$rc" -eq 0 ] && echo "[try: ok, journaled]" || echo "[try: exit $rc, journaled as a dead end]"
exit $rc
