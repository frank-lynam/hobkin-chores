#!/usr/bin/env bash
# heard.sh REPO — record REPO's current HEAD as reviewed, so the watch goes quiet until there's more.
r="${1:?usage: heard.sh REPO}"; d="${HOBKIN_WORK:-.}/shrivener/heard"; mkdir -p "$d"
git -C "$r" rev-parse HEAD > "$d/$(echo "$r" | tr '/' '_')" && echo "heard $r up to $(git -C "$r" rev-parse --short HEAD)"
