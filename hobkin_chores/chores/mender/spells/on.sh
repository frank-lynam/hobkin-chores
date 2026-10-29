#!/usr/bin/env bash
# on.sh CMD... — run a command on the machine being mended: here ($CHORE_TARGET=local) or over ssh.
set -uo pipefail
t="${CHORE_TARGET:-local}"
if [ "$t" = local ]; then bash -c "$*"
else ssh -o BatchMode=yes -o ConnectTimeout=10 "$t" "$*"; fi
