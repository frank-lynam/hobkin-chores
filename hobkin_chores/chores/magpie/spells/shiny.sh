#!/usr/bin/env bash
# shiny.sh — the watch: gather updates and advisories, print only findings not reported before.
set -uo pipefail
dir="${HOBKIN_WORK:-.}/magpie"; mkdir -p "$dir"; seen="$dir/seen"; touch "$seen"; now=$(mktemp)
# the system
if command -v apt >/dev/null; then
  apt list --upgradable 2>/dev/null | awk -F/ 'NR>1{split($2,a," "); sec=($2 ~ /-security/) ? "SECURITY " : ""; print "system: " sec $1 " -> " a[2]}' >> "$now"
elif command -v dnf >/dev/null; then
  dnf -q updateinfo list --security 2>/dev/null | awk '{print "system: SECURITY " $3 " (" $1 ")"}' >> "$now"
fi
# projects
for root in ${CHORE_PROJECTS:-}; do
  root="${root/#\~/$HOME}"
  while IFS= read -r f; do
    p=$(dirname "$f")
    case "$f" in
      */requirements*.txt|*/pyproject.toml)
        command -v pip-audit >/dev/null && pip-audit -r "$f" --format columns 2>/dev/null | awk -v p="$p" 'NR>2 && NF{print "python " p ": SECURITY " $1 " " $2 " (" $3 ")"}' >> "$now" ;;
      */package.json)
        [ -f "$p/package-lock.json" ] && command -v npm >/dev/null && (cd "$p" && npm audit --json 2>/dev/null) \
          | python3 -c 'import json,sys
d=json.load(sys.stdin)
for n,v in (d.get("vulnerabilities") or {}).items(): print(f"node {sys.argv[1]}: SECURITY {n} ({v.get(\"severity\")})")' "$p" 2>/dev/null >> "$now" ;;
    esac
  done < <(find "$root" -maxdepth 3 \( -name node_modules -o -name .git -o -name .venv \) -prune -o \
             \( -name 'requirements*.txt' -o -name pyproject.toml -o -name package.json \) -print 2>/dev/null)
  command -v osv-scanner >/dev/null && osv-scanner -r "$root" 2>/dev/null | awk -F'|' 'NF>4 && $2 ~ /[A-Z]/{gsub(/ /,"",$2); print "osv: SECURITY " $2 " " $5 " " $6}' >> "$now"
done
new=$(sort -u "$now" | comm -23 - <(sort -u "$seen"))
sort -u "$now" "$seen" -o "$seen"; rm -f "$now"
if [ -n "$new" ]; then
  n=$(echo "$new" | wc -l); s=$(echo "$new" | grep -c SECURITY)
  echo "magpie found $n new shiny thing(s), $s of them security:"; echo "$new" | sort -r | head -40 | sed 's/^/  - /'
fi
exit 0
