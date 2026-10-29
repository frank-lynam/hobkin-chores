#!/usr/bin/env bash
# drift.sh REPO — code that changed since you last heard it while no docs changed alongside (a hint, not a verdict).
r="${1:?usage: drift.sh REPO}"; key=$(echo "$r" | tr '/' '_')
last=$(cat "${HOBKIN_WORK:-.}/shrivener/heard/$key" 2>/dev/null); range=${last:+$last..HEAD}; range=${range:-HEAD~20..HEAD}
files=$(git -C "$r" diff --name-only "$range" 2>/dev/null)
docs=$(echo "$files" | grep -Ei '(^|/)(readme|changelog|docs?/|.*\.md$|.*\.rst$|man/)' )
code=$(echo "$files" | grep -Evi '(^|/)(readme|changelog|docs?/|.*\.md$|.*\.rst$|man/|tests?/)' | grep -v '^$')
echo "changed code (${range}):"; echo "${code:-  (none)}" | sed 's/^/  /'
echo "changed docs:"; echo "${docs:-  (none)}" | sed 's/^/  /'
[ -n "$code" ] && [ -z "$docs" ] && echo "=> code moved and no docs did: check README, docs, help text and examples against it."
exit 0
