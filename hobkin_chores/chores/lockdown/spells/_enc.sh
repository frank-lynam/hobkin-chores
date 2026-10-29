#!/usr/bin/env bash
# _enc.sh — shared helpers: pick the encryption tool from $CHORE_RECIPIENT, encrypt one file.
# age if the recipient looks like age (age1... or an age recipients file) and `age` is installed;
# otherwise gpg. The recipient is a PUBLIC key; the private half is never on this machine.
enc_tool() {
  case "$CHORE_RECIPIENT" in
    age1*|*.age|*.age-recipients) command -v age >/dev/null && { echo age; return; } ;;
  esac
  command -v gpg >/dev/null && { echo gpg; return; }
  command -v age >/dev/null && { echo age; return; }
  echo none
}
# encrypt $1 -> $2 (overwrites $2). Returns non-zero on failure.
encrypt_file() {
  case "$(enc_tool)" in
    age)
      case "$CHORE_RECIPIENT" in
        *.age|*.age-recipients) age -R "$CHORE_RECIPIENT" -o "$2" "$1" ;;
        *)                      age -r "$CHORE_RECIPIENT" -o "$2" "$1" ;;
      esac ;;
    gpg)  gpg --batch --yes --trust-model always -r "$CHORE_RECIPIENT" -o "$2" --encrypt "$1" ;;
    *)    echo "no encryption tool (install age or gpg)" >&2; return 2 ;;
  esac
}
