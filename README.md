# hobkin-chores

Standing jobs for a [hobkin](https://github.com/frank-lynam/hobkin): ready-made
**chores** you hand an agent and leave it to. Drop a hobkin in, give it a chore,
walk away. It keeps a folder tidy, watches a machine's health, saves an
instance's data before you kill it — on its own, unattended, and cheaply.

The trick each chore agent is taught: be **the sorcerer's apprentice, only
wiser**. Don't haul the water by hand — enchant a broom. Write scripts (spells)
to do the job, make one the agent's *watch* so the chore mostly runs itself, and
keep a counter-spell for every spell so the workshop never floods.

## Get going

Needs hobkin 0.5.1+. Install this alongside it and copy the chores where hobkin
looks:

```sh
pipx install hobkin-chores        # or: uv tool install hobkin-chores
hobkin-chores list                # the chores, with what they do and their settings
hobkin-chores install             # copy them into ~/.hobkins/_shared/chores/
```

Then give one to a new or existing agent, with hobkin itself:

```sh
hobkin --chore sweep --set folder=~/Downloads --id tidier --safe
hobkin URL MODEL KEY --chore pulse --chat     # a new agent on a new model, watching this box
```

Working from a clone instead of installing? Point hobkin's `chore_dirs` at the
`chores/` folder (where `hobkin-chores path` prints), or pass a chore by its
path: `hobkin --chore ./chores/sweep --set folder=~/Downloads`.

## The chores

| Chore | What it does | Key settings |
|---|---|---|
| **sweep** | Keeps a folder organized — sorts loose files into subfolders, surfaces clutter — and finds leftover sysadmin artifacts (`.bak`, `.orig`, dated config copies), quarantining the stale ones. Never deletes. | `folder`, `artifact_paths`, `stale_days` |
| **pulse** | Takes a machine's vital signs — disk, memory, load, failed services — and raises the alarm when something's amiss. | `disk_pct`, `mem_pct`, `load_per_cpu` |
| **hourglass** | Watches everything that can expire — TLS certs, Linux passwords and accounts, database logins — and warns before the sand runs out. | `targets`, `days` |
| **ark** | Before you kill an instance: copies its logs, config and data to S3 / rclone / a mounted disk, with a manifest and checksums (two of every log). | `dest`, `sources` |
| **mender** | Mr. Fix-it: works out what happened to a sick or offline machine (locally, or over ssh when it's too broken to think for itself), finds the root cause, mends it gently and reversibly, and writes a report. | `target`, `symptom` |
| **mischief** | Chaos for your detection: during working hours, briefly stops services, kills processes and opens decoy ports, whatever its account can reach, always puts them back, and keeps a private ledger to score what the team caught. | `spare`, `window`, `hold` |
| **shipwright** | Hand it a pile of installation files: it works out how to install them, does it for real, and writes a repeatable, idempotent install script from the steps that actually worked. | `from`, `script` |
| **lockdown** | Breach response: encrypts sensitive data with a key *you* hold offline, so an attacker can't read it but you can still recover it. | `recipient`, `paths` |

`hobkin-chores list` prints each one's settings and the exact command to start it.

### A note on the two break-glass chores

**ark** and **lockdown** are for bad days, and both are built to protect
your data, not gamble with it:

- **ark** copies — it never deletes the source. It dumps databases properly
  (not live files), writes a manifest with checksums, and is safe to run again to
  top up. You run it when decommissioning; the agent confirms what landed before
  you kill the box.
- **lockdown** encrypts customer data with a **public key whose private half lives
  off the machine**. An attacker on the box (and the agent itself) then can't read
  it; *you* still can, with your offline key. That protects the customers —
  destroying the data would just do the attacker's job. Deleting the plaintext is a
  separate, deliberate, human-gated step that only runs once the ciphertext exists
  and you've proven you can decrypt it. The chore will not go further than "locked,
  and you hold the key."

### And the one that makes trouble on purpose

**mischief** is a chaos monkey with manners. Its playground is whatever its
account can reach, so give it a scoped account: it discovers the running services
and its account's processes, tries one, and remembers what turned out to be out of
reach. It never touches ssh or the network stack (lockouts), logging, auditing,
the monitoring under test, hobkin, its own session, or anything you `spare`. It
won't run as root unless you say so. It acts only in working hours, undoes every
prank after a short hold (and raises the alarm if something doesn't come back),
and stops for anyone who `touch`es `mischief.off` in its workspace. Its ledger is
the answer key for scoring detection: keep it from the team until you compare notes.

## How a chore is built

A chore is a folder (see `chores/` for the real ones):

```
sweep/
  chore.json      name, description, settings, and config to merge into the agent's
  CHORE.md        the instructions (part of the agent's prompt every turn)
  spells/         starter scripts, copied to the agent's work/spells/
  tools/          tools for the agent (hobkin "own tools"), copied to work/tools/
```

`chore.json`:

```json
{
  "name": "sweep",
  "description": "Keep a folder organized ...",
  "settings": {
    "folder": {"about": "the folder to keep tidy"},
    "threshold": {"default": "20", "about": "wake when more than this many loose files pile up"}
  },
  "config": {
    "idle_prompt": null,
    "safe_mode": {"write": ["{{folder}}"]},
    "wake": {"command": "spells/clutter.sh", "every": "15m"}
  }
}
```

- **`settings`** — each has an `about`, and either a `default` or nothing (a
  setting with no default must be given with `--set NAME=VALUE`).
- **`config`** — merged into the agent's `config.json`. Anything hobkin's config
  takes: a `wake` watch (a script hobkin runs while idle, waking the agent only
  when it prints something — watching costs no model calls), `safe_mode` (with
  `write` folders for a chore that edits a data folder), `alert_command`, a cheaper
  model, and so on.
- **`{{setting}}`** anywhere in `CHORE.md`, `config` or a tool's description is
  filled in. Every setting also reaches spells, tools and the watch as an
  environment variable: `folder` → `$CHORE_FOLDER`.
- **`CHORE.md`** is copied into the agent's folder, so it's part of the agent's
  instructions every turn, right next to the sorcerer's-apprentice rule hobkin
  adds for every chore.

Setting a chore up records it (and its settings) in the agent's `config.json`
under `"chore"`, and tells the agent it has a new job. Run it again with other
settings to change it. Writing your own? Copy the closest chore here, keep the
spells dry-run-by-default with a limit and a clean stop, and send a PR.

## Notifying you

Monitoring chores need to reach a human. hobkin gives a chore agent a `notify`
tool whenever `alert_command` is set (these chores default it to `logger`, so
alerts go to syslog out of the box — set it to ntfy, a Slack webhook or mail for
something louder). `notify` is rate-limited, so a chatty monitor can't flood you.

## Tests

```sh
python3 tests/test_chores.py
```

Validates every chore (its `chore.json`, that `{{settings}}` resolve, that spells
are executable and parse) and the `hobkin-chores` CLI. No network, no keys.

## License

MIT.
