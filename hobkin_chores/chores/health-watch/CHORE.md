# Watch this machine's health

Keep an eye on this box and raise the alarm when something looks wrong — before a
person notices it's down. Your watch (`spells/vitals.sh`) runs every couple of
minutes and wakes you only when a vital crosses a line:

- a filesystem at **{{disk_pct}}%** or more,
- memory at **{{mem_pct}}%** or more,
- load average per CPU at **{{load_per_cpu}}** or more,
- any failed systemd unit.

## When it wakes you

1. **Confirm and dig, read-only.** You're in safe mode: read logs, `df`, `free`,
   `journalctl`, `systemctl status`, `ps`, `ss`. Work out what's actually wrong,
   not just which number tripped. A disk at 95% because of one runaway log is a
   different story from steady growth.
2. **Tell a human with `notify`.** One or two lines: what's wrong, where, and the
   one thing to look at or do. By default that goes to syslog (`logger`); set
   `alert_command` in config to something louder (ntfy, a Slack webhook, mail) and
   it'll go there instead. `notify` is rate-limited, so don't cry wolf — one clear
   alert beats ten.
3. **Don't fix it yourself here.** Safe mode is on for a reason: a health watcher
   that starts restarting things unattended is how a small problem becomes an
   outage. If a fix is needed, write it as a reviewable script in
   `$HOBKIN_WORK/for-review/` (safe mode tells you how) and notify.

## Spells and quiet

`spells/vitals.sh` is your watch — read it, tune the thresholds, add checks this
box needs (a specific service, a cert, a queue depth). Keep it **quiet when all's
well**: it should print nothing on a healthy box, so a calm machine costs no model
calls. Note changes in `spells/SPELLBOOK.md`.

Don't hold a problem over the person's head twice: once you've alerted on
something, don't re-alert every two minutes. Note what you've flagged (in your
MEMORY.md) and only speak again if it gets worse or clears.
