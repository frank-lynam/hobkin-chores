#!/usr/bin/env bash
# _repos.sh — list the git repos in $CHORE_REPOS (paths, or folders whose subfolders are repos), one per line.
for p in ${CHORE_REPOS:-}; do
  p="${p/#\~/$HOME}"
  if [ -d "$p/.git" ]; then echo "$p"
  elif [ -d "$p" ]; then for s in "$p"/*/; do [ -d "$s.git" ] && echo "${s%/}"; done; fi
done
