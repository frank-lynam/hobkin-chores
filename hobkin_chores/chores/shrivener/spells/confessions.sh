#!/usr/bin/env bash
# confessions.sh — the watch: print the repos with commits not yet heard (silence = nothing new).
here="$(cd "$(dirname "$0")" && pwd)"; heard="${HOBKIN_WORK:-.}/shrivener/heard"
out=""
while IFS= read -r r; do
  head=$(git -C "$r" rev-parse HEAD 2>/dev/null) || continue
  key=$(echo "$r" | tr '/' '_'); last=$(cat "$heard/$key" 2>/dev/null)
  if [ "$head" != "$last" ]; then
    n=$( [ -n "$last" ] && git -C "$r" rev-list --count "$last..$head" 2>/dev/null || echo "all")
    out+="  - $r: $n new commit(s) to hear"$'\n'
  fi
done < <("$here/_repos.sh")
[ -n "$out" ] && { echo "confessions waiting:"; printf '%s' "$out"; }
exit 0
