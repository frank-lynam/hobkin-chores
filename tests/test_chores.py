"""Validate every bundled chore and the hobkin-chores CLI. No network, no keys, no cost.

    python3 tests/test_chores.py
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHORES = os.path.join(ROOT, "hobkin_chores", "chores")
sys.path.insert(0, ROOT)
import hobkin_chores as hc  # noqa: E402

failed = False


def check(name, cond, info=""):
    global failed
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  {info}"))
    if not cond:
        failed = True


def placeholders(text):
    return set(re.findall(r"\{\{(\w+)\}\}", text))


names = sorted(n for n in os.listdir(CHORES) if os.path.isdir(os.path.join(CHORES, n)))
check("there are chores to test", bool(names), names)

for name in names:
    d = os.path.join(CHORES, name)
    spec_path, md_path = os.path.join(d, "chore.json"), os.path.join(d, "CHORE.md")
    check(f"[{name}] has chore.json and CHORE.md", os.path.isfile(spec_path) and os.path.isfile(md_path))
    try:
        spec = json.loads(open(spec_path, encoding="utf-8").read())
    except (OSError, ValueError) as e:
        check(f"[{name}] chore.json is valid JSON", False, str(e))
        continue
    check(f"[{name}] chore.json has name, description, settings, config",
          isinstance(spec.get("name"), str) and isinstance(spec.get("description"), str)
          and isinstance(spec.get("settings"), dict) and isinstance(spec.get("config"), dict), spec.keys())
    settings = spec.get("settings") or {}
    for key, s in settings.items():
        ok = isinstance(s, dict) and isinstance(s.get("about"), str) and s.get("about")
        check(f"[{name}] setting {key} has an 'about'", bool(ok), s)

    # every {{placeholder}} in CHORE.md, config and tool descriptions is a real setting
    md = open(md_path, encoding="utf-8").read()
    used = placeholders(md) | placeholders(json.dumps(spec.get("config") or {}))
    tools_dir = os.path.join(d, "tools")
    for t in os.listdir(tools_dir) if os.path.isdir(tools_dir) else []:
        tj = os.path.join(tools_dir, t, "tool.json")
        if os.path.isfile(tj):
            used |= placeholders(open(tj, encoding="utf-8").read())
            check(f"[{name}] tool {t} has an executable run", os.access(os.path.join(tools_dir, t, "run"), os.X_OK))
    unknown = used - set(settings)
    check(f"[{name}] every {{{{placeholder}}}} is a known setting", not unknown, unknown)

    # spells: executable and parse (bash -n); if there's a watch, it's wired in config
    spells = os.path.join(d, "spells")
    for f in sorted(os.listdir(spells)) if os.path.isdir(spells) else []:
        p = os.path.join(spells, f)
        if f.endswith(".sh"):
            check(f"[{name}] spell {f} is executable", os.access(p, os.X_OK))
            r = subprocess.run(["bash", "-n", p], capture_output=True, text=True)
            check(f"[{name}] spell {f} parses", r.returncode == 0, r.stderr.strip())
    wake = (spec.get("config") or {}).get("wake") or {}
    if wake.get("command"):
        rel = wake["command"]
        check(f"[{name}] the watch command exists", os.path.isfile(os.path.join(d, rel)), rel)

# the library view matches the folders
check("chores() finds them all", {n for n, _ in hc.chores()} == set(names))

# the CLI: list, path, and install into a temp HOBKIN_HOME
env = dict(os.environ)
with tempfile.TemporaryDirectory() as tmp:
    env["HOBKIN_HOME"] = tmp
    run = lambda *a: subprocess.run([sys.executable, "-c",
        "import sys; sys.argv=['hobkin-chores', *sys.argv[1:]]; import hobkin_chores; hobkin_chores.cli()", *a],
        env=env, cwd=ROOT, capture_output=True, text=True)
    r = run("list")
    check("[cli] list shows every chore", all(n in r.stdout for n in names), r.stdout + r.stderr)
    r = run("install")
    dest = os.path.join(tmp, "_shared", "chores")
    check("[cli] install copies chores where hobkin looks",
          r.returncode == 0 and all(os.path.isfile(os.path.join(dest, n, "chore.json")) for n in names), r.stdout + r.stderr)
    check("[cli] installed spells stay executable",
          all(os.access(p, os.X_OK) for n in names for p in
              [os.path.join(dest, n, "spells", f) for f in os.listdir(os.path.join(dest, n, "spells"))
               if os.path.isdir(os.path.join(dest, n, "spells"))]))
    r = run("install", "nope")
    check("[cli] install refuses an unknown chore", r.returncode != 0 and "no chore nope" in r.stderr, r.stderr)
    r = run("path")
    check("[cli] path prints the bundled chores dir", r.stdout.strip() == CHORES, r.stdout)

print("FAILED" if failed else "ALL PASSED")
sys.exit(1 if failed else 0)
