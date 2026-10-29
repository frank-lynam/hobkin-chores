# Save this instance's data to {{dest}}

This box is going away and nobody wants to find out next week that something
irreplaceable went with it. Your job: get everything that can't be re-created off
it, to **{{dest}}**, before it's killed.

Starting point for what to copy: `{{sources}}` — but **you know better than a
fixed list**. Look around first (what runs here, where its data and logs live) and
copy what matters, most precious first.

## The order that matters

1. **Data nobody else has, dumped properly.** A live database file copied
   mid-write is corrupt. Dump it the database's own way into
   `$HOBKIN_WORK/staging/` first — `pg_dump`, `mysqldump`, `sqlite3 .backup`,
   `redis-cli --rdb` — then upload the dump. Same for anything being written to.
2. **Recent state and uploads** — user files, queues, anything app-specific.
3. **Logs** — `/var/log`, the journal (`journalctl > staging/journal.txt`),
   app logs.
4. **Config** — `/etc`, app config, crontabs, unit files, env.
5. **A snapshot of how it stood** — `ps`, `df`, installed packages, open ports —
   so the box can be understood later.

## Do it with the spell

`spells/salvage.sh` is the broom: it copies a list of paths to `$CHORE_DEST`
(handling `s3://` with `aws s3 sync`, `remote:` with `rclone copy`, or a plain
folder with `cp`), writes a **manifest** (every file, its size and checksum) and a
log alongside the copies, and is **safe to run again** — it syncs, so a second run
after more changes tops it up rather than starting over.

- **Dry run first:** `salvage.sh` alone prints what it would copy and how big.
  `salvage.sh --go` does it. Try one source before the whole list.
- **Dumps are yours to make.** The spell copies files and folders; you make the
  database dumps into `staging/` first, then add `staging/` to what it copies.
- **Check it landed.** After `--go`, the manifest lists what went. Spot-check that
  the dump sizes look sane and the bucket has them. Then `notify` a one-line
  "salvage done: N files, M GB, manifest at …", and only then is it safe to kill
  the box.

Keep the spellbook (`spells/SPELLBOOK.md`) and, if a copy ever fails halfway, fix
the spell and run it again — it's built to resume.
