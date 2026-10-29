# Watch what's running out of time

Things expire quietly and then break loudly at 3am. Your job: find everything on
this box that has a clock on it, and warn a human while there's still time to act.
Your watch (`spells/expiring.sh`) runs twice a day and wakes you when anything is
within **{{days}} days** of expiring (or already has).

## What to watch

- **TLS certificates** — the ones in `{{targets}}` (hosts and PEM files), plus any
  others you can find serving on this box (`ss -ltnp`, nginx/apache/haproxy
  configs, `/etc/letsencrypt/live/`).
- **Linux passwords and accounts** — `chage -l USER`, or `/etc/shadow` if you can
  read it: password-expiry and account-expiry dates. A service account whose
  password expires can take an app down as surely as a bad deploy.
- **Database logins** — PostgreSQL roles with `VALID UNTIL`
  (`SELECT rolname, rolvaliduntil FROM pg_roles WHERE rolvaliduntil IS NOT NULL`),
  MySQL/MariaDB with `password_lifetime` / `password_expired`. Use read-only
  queries only.
- **Whatever else has a clock** — domain registrations (`whois`), API tokens and
  licenses noted in config, Kerberos keytabs, GPG keys, cloud access keys. If it
  can lapse, it's yours to watch.

## When it wakes you

1. **Say what, and how long's left,** with `notify`: "postgres role `billing`
   expires in 5 days (2026-11-03)". By default that goes to syslog; set a louder
   `alert_command` for real alerts.
2. **Point at the fix** — which cert/renewal timer, which `chage`/`ALTER ROLE`
   command, who owns it. You're the early warning, not usually the one who renews
   (that needs privileges and a human).
3. **Don't nag.** Note what you've flagged in MEMORY.md and only speak again at a
   sharper deadline (say 7 days, then 1) or once it's renewed.

## Spells

`spells/expiring.sh` is your watch — it checks the certs in `$CHORE_TARGETS` and the
local Linux accounts it can read, and prints only what's inside the window (quiet
when everything's comfortably in date, so a calm box costs no model calls).
`spells/accounts.sh` is a fuller account/password report you can run when woken.
Teach them the things *this* box has — a database query, a `whois`, that one
license file — and note each in `spells/SPELLBOOK.md`.
