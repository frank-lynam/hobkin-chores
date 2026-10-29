# Shipwright: turn a pile of installers into a repeatable install

In `{{from}}` there's a heap of installation files. Your job: get them installed
on this machine, for real, and leave behind **`shipwright/{{script}}`**, a script
that does the same install again on a fresh machine, built from what actually
worked rather than what the README claimed.

## 1. Survey before you touch anything

`spells/survey.sh` lists every file: what kind it is (`.deb`, `.rpm`, tarball,
AppImage, `.run`/`.sh` installer, wheel, `.jar`...), its size and sha256, any
checksum or signature files beside it, and READMEs and install notes. Read the notes.
Work out the order (dependencies first) and write the plan in your checklist.

**Verify before you run:** if there's a `SHA256SUMS`, a `.sha256` or an `.asc`,
check it. A file that fails its checksum doesn't get installed. Stop and `notify`.

## 2. Install through the journal

Run **every** install step through `spells/try.sh`:

    spells/try.sh sudo dpkg -i foo_1.2_amd64.deb
    spells/try.sh sudo apt-get install -f -y

It runs the command, shows the output, and appends it (with its exit code and
folder) to `shipwright/journal.tsv`. Dead ends belong in the journal too. That's
the point: the journal is the honest record of what it took. After each package,
**check it works** (`--version`, the service is up, the binary runs) and journal
that check too.

Don't paper over problems: no `--force-all`, no disabling signature checks or
SELinux/AppArmor to make something go in. If that's what it would take, stop and
ask.

## 3. Build the script from what worked

Write `shipwright/{{script}}` from the journal's successful steps, in order. Keep
the dead ends out, and keep the checks in:

- `set -euo pipefail` at the top, and a comment saying where the files come from
  (`FROM=${FROM:-{{from}}}`) and what it installs;
- verify each file's sha256 before using it (record them from the survey);
- **idempotent:** each step checks first ("already installed at this version?")
  and skips, so running it twice is harmless;
- the post-install checks at the end, and a clear "done" or failure message.

## 4. Prove it's repeatable

Run the script again on this machine: it should skip everything and pass its
checks. If `podman` or `docker` is around, the real test is a fresh container of
the same distro, with the files mounted. Note in the script's header which test
it passed. Then report: what got installed, the script's path, and anything a
human must still do (licenses, keys, config).
