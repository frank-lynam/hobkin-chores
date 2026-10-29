#!/usr/bin/env bash
# survey.sh — what's in the pile: kind, size, sha256, checksum/signature files, notes. Read-only.
set -uo pipefail
from="${CHORE_FROM:?set CHORE_FROM}"
kind() {
  case "${1,,}" in
    *.deb) echo deb ;; *.rpm) echo rpm ;; *.appimage) echo appimage ;; *.whl) echo wheel ;; *.jar) echo jar ;;
    *.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tar.zst|*.tar) echo tarball ;; *.zip) echo zip ;;
    *.run|*.bin|*.sh) echo installer ;; *.pkg|*.dmg|*.msi|*.exe) echo "not-for-linux" ;;
    *sha256sums*|*.sha256|*.sha512|*.md5) echo checksums ;; *.asc|*.sig|*.gpg) echo signature ;;
    *readme*|*install*|*.md|*.txt) echo notes ;; *) file -b "$1" | cut -c1-40 ;;
  esac
}
printf '%-14s %10s  %-16s %s\n' kind bytes sha256 file
find "$from" -type f | sort | while IFS= read -r f; do
  printf '%-14s %10s  %-16s %s\n' "$(kind "$f")" "$(stat -c %s "$f")" "$(sha256sum "$f" | cut -c1-16)" "${f#$from/}"
done
echo
for c in $(find "$from" -type f \( -iname '*sha256sums*' -o -name '*.sha256' \)); do
  echo "checking $c:"; (cd "$(dirname "$c")" && sha256sum -c --ignore-missing "$(basename "$c")" 2>&1 | sed 's/^/  /')
done
exit 0
