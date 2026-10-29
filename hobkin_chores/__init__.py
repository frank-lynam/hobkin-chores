"""hobkin-chores: standing jobs for a hobkin.

A chore is a ready-made job you hand a hobkin and leave it to: keep a folder
tidy, watch a system's health, copy an instance's data off before you kill it.
Drop a hobkin in, give it a chore, walk away.

    hobkin-chores list                 the chores, with what they do and their settings
    hobkin-chores install [NAME...]    copy them where `hobkin --chore` looks (default: all)
    hobkin-chores path                 the folder they live in (for "chore_dirs" in config)

Each chore is then given to an agent by hobkin itself:

    hobkin --chore tidy --set folder=~/Downloads --id tidier --safe

See the README for how a chore is built, and for the sorcerer's-apprentice rule
every chore agent follows: write spells to do the job, keep a counter-spell for
each, and never let the brooms multiply.
"""

from __future__ import annotations

__version__ = "0.1.0"

import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CHORES = os.path.join(HERE, "chores")


def chore_home() -> str:
    """Where hobkin looks for shared chores: $HOBKIN_HOME/_shared/chores, else ~/.hobkins/_shared/chores."""
    home = os.environ.get("HOBKIN_HOME") or os.path.expanduser("~/.hobkins")
    return os.path.join(home, "_shared", "chores")


def chores() -> list[tuple[str, dict]]:
    """Every bundled chore: (name, its chore.json), in name order."""
    out = []
    for name in sorted(os.listdir(CHORES)) if os.path.isdir(CHORES) else []:
        spec = os.path.join(CHORES, name, "chore.json")
        if os.path.isfile(spec):
            try:
                out.append((name, json.loads(open(spec, encoding="utf-8").read())))
            except (OSError, ValueError):
                out.append((name, {}))
    return out


def setting_lines(spec: dict) -> list[str]:
    """One line per setting: name, whether it's required, and what it's for."""
    lines = []
    for key, s in (spec.get("settings") or {}).items():
        about = s.get("about", "") if isinstance(s, dict) else ""
        default = s.get("default") if isinstance(s, dict) else s
        tag = f" (default {default})" if default is not None else " (required)"
        lines.append(f"    {key}{tag}" + (f": {about}" if about else ""))
    return lines


def cmd_list() -> None:
    found = chores()
    if not found:
        return print("no chores bundled")
    for name, spec in found:
        print(f"{name}  —  {spec.get('description', '').strip()}")
        for line in setting_lines(spec):
            print(line)
        print(f"    hobkin --chore {name} " + " ".join(
            f"--set {k}=..." for k, s in (spec.get("settings") or {}).items()
            if not (isinstance(s, dict) and s.get("default") is not None)).strip())
        print()


def cmd_install(names: list[str]) -> None:
    dest = chore_home()
    have = {n for n, _ in chores()}
    names = names or sorted(have)
    unknown = [n for n in names if n not in have]
    if unknown:
        sys.exit(f"hobkin-chores: no chore {', '.join(unknown)} (see: hobkin-chores list)")
    os.makedirs(dest, exist_ok=True)
    for name in names:
        out = os.path.join(dest, name)
        shutil.copytree(os.path.join(CHORES, name), out, dirs_exist_ok=True)
        for root, _, fs in os.walk(out):              # spells and tool `run`s must stay executable
            for f in fs:
                if f.endswith(".sh") or f == "run":
                    path = os.path.join(root, f)
                    os.chmod(path, os.stat(path).st_mode | 0o111)
        print(f"installed {name} -> {out}")
    print(f"\nGive one to a hobkin: hobkin --chore {names[0]} --set ... --id NAME")


def cmd_path() -> None:
    print(CHORES)
    print(f'add to config.json: "chore_dirs": [{json.dumps(CHORES)}]', file=sys.stderr)


def main(argv: list[str]) -> None:
    if not argv or argv[0] in ("-h", "--help", "help"):
        return print(__doc__)
    if argv[0] in ("-V", "--version"):
        return print(f"hobkin-chores {__version__}")
    cmd, rest = argv[0], argv[1:]
    if cmd == "list":
        return cmd_list()
    if cmd == "install":
        return cmd_install(rest)
    if cmd == "path":
        return cmd_path()
    sys.exit(f"hobkin-chores: unknown command {cmd!r} (list, install, path)")


def cli() -> None:
    main(sys.argv[1:])
