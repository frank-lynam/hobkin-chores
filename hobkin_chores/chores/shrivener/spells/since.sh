#!/usr/bin/env bash
# since.sh REPO — what changed since you last heard it: log, diffstat, then the diff (first 3000 lines).
r="${1:?usage: since.sh REPO}"; key=$(echo "$r" | tr '/' '_')
last=$(cat "${HOBKIN_WORK:-.}/shrivener/heard/$key" 2>/dev/null)
range=${last:+$last..HEAD}; range=${range:-HEAD~20..HEAD}
git -C "$r" rev-parse -q --verify "${range%%..*}" >/dev/null 2>&1 || range=$(git -C "$r" rev-list --max-parents=0 HEAD | tail -1)..HEAD
echo "== $r: $range"; git -C "$r" log --format='%h %an %ad %s' --date=short "$range"
echo; git -C "$r" diff --stat "$range" | tail -40; echo
git -C "$r" diff "$range" | head -3000
