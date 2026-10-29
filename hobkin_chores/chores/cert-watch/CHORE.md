# Watch these certificates

Make sure none of these TLS certificates expires while nobody's looking:

    {{targets}}

Your watch (`spells/expiry.sh`) checks them twice a day and wakes you when one is
within **{{days}} days** of expiring (or already expired, or unreachable).

## When it wakes you

1. **Say which, and how long's left,** with `notify`: "example.com cert expires in
   4 days (2026-11-02)". By default that goes to syslog; set `alert_command` to
   something louder for real alerts.
2. **Point at the fix if you know it** — which host, which cert file, whether it's
   Let's Encrypt (is the renewal timer failing?) or a manual cert. You're not here
   to renew it yourself (that usually needs privileges and a human); you're here so
   it never expires by surprise.
3. **Don't nag.** Once you've flagged a cert, note it in your MEMORY.md and only
   speak again when it gets to a sharper deadline (say, 7 days, then 1) or renews.

## Spells

`spells/expiry.sh` is the watch — it reads `$CHORE_TARGETS`, gets each certificate's
expiry with `openssl`, and prints only the ones inside the window. Add targets by
editing `$CHORE_TARGETS` in config, or teach the spell to read a list from a file.
Keep it quiet when every cert is comfortably in date. Note changes in
`spells/SPELLBOOK.md`.
