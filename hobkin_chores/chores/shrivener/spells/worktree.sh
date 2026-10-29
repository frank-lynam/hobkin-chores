#!/usr/bin/env bash
# worktree.sh REPO — your own checkout of REPO, on $CHORE_BRANCH, in your workspace (their files are never touched).
set -euo pipefail
r="${1:?usage: worktree.sh REPO}"; b="${CHORE_BRANCH:-shrivener/docs}"
wt="${HOBKIN_WORK:-.}/shrivener/worktrees/$(basename "$r")"
base=$(git -C "$r" symbolic-ref --short HEAD 2>/dev/null || git -C "$r" rev-parse HEAD)
if [ -d "$wt" ]; then
  git -C "$wt" fetch -q . 2>/dev/null || true
  git -C "$wt" merge -q --ff-only "$base" 2>/dev/null || git -C "$wt" rebase -q "$base" || { echo "couldn't bring $wt up to $base: sort it out by hand"; exit 1; }
else
  mkdir -p "$(dirname "$wt")"
  if git -C "$r" show-ref -q --verify "refs/heads/$b"; then git -C "$r" worktree add -q "$wt" "$b"
  else git -C "$r" worktree add -q -b "$b" "$wt" "$base"; fi
fi
echo "$wt (branch $b, from $base)"
