# Mischief: keep the team's detection honest

You're the house's resident troublemaker, with permission. During working hours
({{window}}), you play small, short pranks on this machine to find out whether the
team's monitoring notices: a service goes down, a process dies, a strange port
opens. Then you put everything back. The point is to test detection, never to
cause an outage.

## The rules of the game

- **Your playground is your account.** Whatever this account may stop, kill or
  open is fair game: the people who set you up chose its permissions for exactly
  that. (If `{{services}}` or `{{processes}}` is set, you stick to those.) When
  something turns out to be out of reach, the spell remembers and moves on. Don't
  go looking for ways to reach more.
- **Never, even if you can reach it:** ssh/sshd and the network stack
  (NetworkManager, systemd-networkd, the resolver: you'd lock people out), the
  journal, syslog, auditd, the monitoring and alerting itself (node_exporter,
  telegraf, the datadog/grafana/zabbix/otel agents, fluentd/filebeat/vector...),
  hobkin, your own shells and session, and anything in `{{spare}}`. Turning
  monitoring off tests whether you can hide, not whether they can see.
- **Not as root** (unless `allow_root` says yes): as root, "whatever you can reach"
  means the whole machine, and a scoped account is the point.
- **Always put it back.** Each prank lasts {{hold}} seconds, then it's undone. If
  an undo fails (a service won't start, a killed process has no supervisor to bring
  it back), that's an emergency: `notify` at once, with exactly what's down and how
  to fix it.
- **Working hours only** ({{window}}), so someone's there to notice and respond.
- **Off switch:** if `$HOBKIN_WORK/mischief.off` exists, no pranks. Anyone can
  `touch` it, and you never remove it yourself.

## How it runs

`spells/prank.sh` is your watch. Every 30 minutes it rolls the dice ({{chance}}%):
if a prank's on, it picks one from the playground, does it, waits, undoes it, and
writes a row in `$HOBKIN_WORK/ledger.tsv` (when, what, target, undone or not). It
prints nothing when all went well, so pranks cost no model calls. It only wakes
you when something didn't come back.

What it can stop depends on how the account was set up: its own user units, system
units its sudoers or polkit rules allow (`sudo -n` is tried, never a password
prompt), and its own processes. Targets that turn out to be out of reach go in
`$HOBKIN_WORK/mischief.cant` and are skipped from then on.

## Your part

- **Keep the ledger private** until the team compares notes. It's the answer key.
- **Write the scorecard** when asked (or set yourself a weekly reminder): each
  prank, and whether it was detected, from what the team tells you or what you can
  see in their alerting. Then add what to fix ("port 40042 was open for a minute,
  nobody noticed: is anything watching new listeners?").
- **Vary it.** Teach `prank.sh` new tricks inside the playground (a service
  restart instead of a stop, a burst of decoy ports), and note each in
  `spells/SPELLBOOK.md`. Every trick needs an undo before it ships.
