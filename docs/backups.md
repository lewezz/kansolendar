# Backups and recovery

## Files and export

| File | Contents | Protection |
| --- | --- | --- |
| `.kanso` | Active document, encrypted records, password-wrapped key | Document password |
| `.kansobackup` | SQLite snapshot with encrypted record payloads | Matching data key; portable snapshots also retain their wrapper |
| Recovery `.txt` | Vault/key IDs and Base64-encoded data key | Plaintext secret; keep separate |
| `.ics` | Supported event details | Plaintext; not a vault backup |

In an unlocked workspace, use **Export → Encrypted Backup…** and separately
**Export → Recovery Kit…**. Export destinations must be new files. The local
Keychain backend reauthenticates when obtaining key material; portable exports
reuse the unlocked key session. No scheduled backups or recovery kits are
created automatically.

The implementation snapshots SQLite to a private temporary directory, validates
its contents with the active key, then streams it to the chosen destination.
Backup copies are capped at 1 GiB. Recovery-kit input is capped at 512 bytes.
Private output files use owner-only permissions.

## Restore

Choose **Import → Restore Encrypted Backup…**, select the backup and matching
recovery kit, and confirm replacement. Portable restoration asks for a new,
confirmed password. For recovery into an independent file, first create and
unlock an empty `.kanso` vault and restore into that destination.

The implementation stages and validates the source, checks vault/key identity,
creates an encrypted safety snapshot, replaces the database, and validates
records again. On failure it attempts to restore the safety snapshot. If rollback
also fails, encrypted candidates are retained and a recovery-required error is
presented; the app does not claim successful recovery.

## Destination rules and limitations

An already populated portable vault can receive its own compatible backup when
the currently accessible key and identity match. A populated portable destination
with unrelated identity is refused. An empty destination can accept a different
vault and receive a new password wrapper. Restoration preserves the backup's
identity rather than generating a new history.

An existing portable destination with metadata needs an unlocked current key
session for the previous-key check. This is not a universal password reset for a
locked document. Recovery into a new empty vault avoids relying on the lost
password. The local Keychain store has a separate missing-key recovery path.
Cross-format restore is not supported in every direction; do not promise arbitrary
portable-to-local migration.

There is no password-change UI, backup scheduler, automatic recovery, or snapshot
freshness guarantee. Concurrent lock/restore behavior and the latest rollback
changes still need runtime validation. Keep the original backup and kit until
recovery has been verified. See [testing](testing.md).
