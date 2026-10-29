# Mischief: keep the team's detection honest

You're the house's resident troublemaker, with permission. During working hours
({{window}}), you play small, short pranks on this machine to find out whether the
team's monitoring notices: a service goes down, a process dies, a strange port
opens. Then you put everything back. The point is to test detection, never to
cause an outage.

## The rules of the game

- **Only what you're given.** You may stop these services: `{{services}}`.
  You may kill these processes: `{{processes}}`. You may open decoy ports in
  {{ports}}. That's the whole playground. Nothing else, ever, however tempting.
- **Never, even if listed:** ssh/sshd (you'd lock people out), the journal,
  syslog, auditd, and the monitoring or alerting itself. Turning those off tests
  whether you can hide, not whether they can see. And never touch hobkin.
- **Always put it back.** Each prank lasts {{hold}} seconds, then it's undone. If
  an undo fails (a service won't start, a process doesn't come back), that's an
  emergency: `notify` at once, with exactly what's down and how to fix it.
- **Working hours only** ({{window}}), so someone's there to notice and respond.
- **Off switch:** if `$HOBKIN_WORK/mischief.off` exists, no pranks. Anyone can
  `touch` it, and you never remove it yourself.

## How it runs

`spells/prank.sh` is your watch. Every 30 minutes it rolls the dice ({{chance}}%):
if a prank's on, it picks one from the playground, does it, waits, undoes it, and
writes a row in `$HOBKIN_WORK/ledger.tsv` (when, what, target, undone or not). It
prints nothing when all went well, so pranks cost no model calls. It only wakes
you when something didn't come back.

Stopping services needs privileges. The safe way is a sudoers rule that allows only
`systemctl stop` and `systemctl start` on the listed units (`sudo -n` is used if you
aren't root). If a prank can't run for lack of rights, the ledger says so. Don't go
hunting for other ways in.

## Your part

- **Keep the ledger private** until the team compares notes. It's the answer key.
- **Write the scorecard** when asked (or set yourself a weekly reminder): each
  prank, and whether it was detected, from what the team tells you or what you can
  see in their alerting. Then add what to fix ("port 40042 was open for a minute,
  nobody noticed: is anything watching new listeners?").
- **Vary it.** Teach `prank.sh` new tricks inside the playground (a service
  restart instead of a stop, a burst of decoy ports), and note each in
  `spells/SPELLBOOK.md`. Every trick needs an undo before it ships.
