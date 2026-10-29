#!/usr/bin/env bash
# gather.sh [DAYS] — the raw material for a chronicle: the last DAYS days (default 7). Read-only.
days="${1:-7}"; since="$(date -d "-$days days" +%F)"; work="${HOBKIN_WORK:-.}/chronicler"; mkdir -p "$work"
echo "### $(hostname), $since to $(date +%F)"
echo; echo "## Commits"
for p in ${CHORE_REPOS:-}; do p="${p/#\~/$HOME}"
  for r in "$p" "$p"/*/; do [ -d "$r/.git" ] || continue
    n=$(git -C "$r" rev-list --count --since="$since" HEAD 2>/dev/null); [ "${n:-0}" -gt 0 ] || continue
    echo "- $(basename "$r"): $n commits"; git -C "$r" log --since="$since" --format='    %ad %an: %s' --date=short | head -12
  done
done
echo; echo "## Packages"
zgrep -hE "^(Start-Date|Commandline)" /var/log/apt/history.log* 2>/dev/null | awk -v s="$since" '/Start-Date/{d=$2} /Commandline/ && d>=s{print "- " d ": " substr($0, 14)}' | tail -20
echo; echo "## Reboots"; last -x -s "$since" reboot 2>/dev/null | head -10
echo; echo "## Failed services now"; systemctl --failed --no-legend --plain 2>/dev/null | head -10
echo; echo "## Errors per day"
for i in $(seq "$days" -1 0); do d=$(date -d "-$i days" +%F)
  echo "- $d: $(journalctl -p err --since "$d 00:00" --until "$d 23:59:59" -q --no-pager 2>/dev/null | wc -l)"; done
echo; echo "## Disk (now; last chronicle's in brackets)"
df -hP -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR>1{print $6, $5}' | while read -r m u; do
  was=$(awk -v m="$m" '$1==m{print $2}' "$work/disk-last" 2>/dev/null); echo "- $m $u${was:+ (was $was)}"; done
df -hP -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR>1{print $6, $5}' > "$work/disk-last.new"
echo; echo "## hobkin incidents"; find "$HOME/.hobkins" -path '*/work/incident-*.md' -newermt "$since" 2>/dev/null | head -5 | while read -r f; do echo "- $f: $(head -1 "$f")"; done
echo; echo "(when the chronicle's written: mv $work/disk-last.new $work/disk-last)"
