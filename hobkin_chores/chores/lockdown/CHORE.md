# Lockdown: make customer data unreadable to an attacker

This is a break-glass chore. When this machine is compromised — or about to be —
your job is to put the sensitive data beyond the attacker's reach **without
losing it for the people it belongs to**. The way to do that is encryption, not
destruction.

## How it protects (read this — it's the whole point)

- You encrypt the data with a **public key** (`{{recipient}}`). Its **private
  half lives off this machine** — printed, in a vault, in an HSM. So once a file
  is encrypted, nobody on this box can read it: not the attacker, not even you,
  not this agent. Only someone with the offline private key can.
- That means the attacker gets ciphertext, and **you still get your customers'
  data back** afterward, with your offline key. "Unrecoverable by the attacker,
  recoverable by you." That protects the customers; wiping the data would just
  do the attacker's job for them.
- Encrypting is reversible-by-you and safe to do early and often. **Deleting the
  plaintext is not** — see "Shredding" below. By default you encrypt and leave
  the plaintext; shredding is a separate, deliberate step.

## In an emergency

1. **Check you're ready** (do this in calm times too — your watch does it every
   6h): `spells/readycheck.sh` confirms the tool and `$CHORE_RECIPIENT` are set
   up and that a test string round-trips. If you can't verify your key can
   decrypt a sample, stop and fix that first — encrypting with a key you can't
   decrypt with is just destruction.
2. **Encrypt, most sensitive first:** `spells/lockdown.sh` (dry run) shows what
   it would encrypt under `$CHORE_PATHS` matching `$CHORE_PATTERNS`;
   `spells/lockdown.sh --go` writes an encrypted copy next to each
   (`file -> file.locked`), keeping the plaintext, with a manifest. Start with the
   customer data; widen from there.
3. **`notify`** what you've locked and where the manifest is.

## Shredding the plaintext (deliberate, irreversible, human-gated)

Only after encryption, and only when a person has called for it (break-glass or an
explicit "shred now"), run `spells/shred-plaintext.sh --go`. It removes a plaintext
file **only when** its `.locked` ciphertext exists and is non-empty, and records
every removal in a manifest. It is dry-run by default and refuses to touch a file
whose ciphertext is missing.

Before you shred anything, **prove you can get it back**: decrypt one `.locked`
file with the offline key on another machine. If you can't, don't shred — you'd be
destroying the data you're trying to protect. When in doubt, encrypt and leave the
plaintext; a human can shred later once they've confirmed recovery.

Never go further than this: no spreading to other machines, no touching backups you
can't restore, no "unrecoverable by everyone." Your job is to lock the door and keep
the key, not to burn the house down.
