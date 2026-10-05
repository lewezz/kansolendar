# SQLite persistence and file format

Kansolendar uses system SQLite through CSQLite. Business details are encrypted
before binding into SQL; this is payload encryption, not full-file encryption.
The storage actor owns one SQLiteConnection and its key session.

## Locations and versions

The local store resolves Application Support through FileManager and uses
`Kansolendar/vault.sqlite` under that root. The actual root depends on the app's
sandbox identity; code does not hardcode a user's home directory. Its directory
is restricted to 0700 and database files to 0600.

Portable documents use a user-selected `.kanso` path. Their header application ID
is `0x4B414E53` (KANS). Files are checked for regular-file type and current-user
ownership; new documents refuse an existing destination.

| Version field | Current value |
| --- | --- |
| PRAGMA user_version, local schema | 1 |
| PRAGMA user_version, portable schema | 2 |
| vault_meta.schema_version | 1 in both modes |
| Payload codec and envelope version | 1 |
| Password-wrapper format version | 1 |

These version numbers serve different contracts. A newer schema is rejected;
opening a portable document does not automatically convert the local vault.

## Tables

| Table | Visible fields | Encrypted or wrapped field |
| --- | --- | --- |
| vault_meta | singleton, vault_id, schema_version, active_key_id | control_envelope |
| calendars | id | payload_envelope |
| events | id, calendar_id | payload_envelope |
| event_exceptions | id, event_id | payload_envelope |
| vault_key_wrap, portable only | singleton, vault_id, key_id | record containing salt/KDF metadata and wrapped key |

UUIDs are 16-byte BLOBs. Type/length checks are explicit SQL constraints; the
current schema is not declared STRICT. Events reference calendars with DELETE
RESTRICT, and exceptions reference events with DELETE CASCADE. Parent lookup
indexes exist on events.calendar_id and event_exceptions.event_id.

Calendar payloads contain name, color, sort order, and default zone. Event payloads
contain UID, title, notes, location, time, revision, and optional recurrence.
Exception payloads encode occurrence cancellations. There is no plaintext title,
date, UID, search index, or materialized occurrence table.

The control payload authenticates version, vault ID, and key ID. It is not an
authenticated inventory of all rows. The portable wrapper record is bounded to
4,096 bytes and belongs to the vault metadata through a foreign key.

## Transactions and connections

Connection setup enables foreign keys, defensive mode, a 1,000 ms busy timeout,
DELETE journaling, FULL synchronization, memory temporary storage, and disabled
trusted schema. There is no downloaded SQLite implementation, ORM, FTS index, or
custom page-encryption codec.

withImmediateTransaction centralizes synchronous non-nested write transactions.
It is used for schema setup, metadata/wrapper creation, event/cancellation changes,
imports, and calendar deletion. In-memory success state follows commit. The
connection's actor owner serializes calls; no await occurs inside a transaction.

Search decrypts records and filters in memory. No incremental RAM index or
optimistic revision-compare write protocol is currently implemented.

## File integrity and recovery

Payload envelopes range from 33 to 131,105 bytes and authenticate row identities.
SQLite integrity/foreign-key checks and payload validation are used during backup
validation. They do not prove that rows were not removed or that a database is the
newest copy. DELETE journals may exist while a transaction is active; move/copy a
vault only after locking and closing it.

Backups use SQLite's backup API plus private staging and validation. Restore
retains a safety snapshot and attempts rollback. See [backups](backups.md).
No general schema-migration backup framework, downgrade conversion, secure-delete
guarantee, or live multi-process coordination is implemented.

Source: [storage actor](../Packages/KansolendarKit/Sources/KansolendarStorage/SQLiteVaultDatabase.swift),
[connection](../Packages/KansolendarKit/Sources/KansolendarStorage/SQLiteConnection.swift),
and [location resolver](../Packages/KansolendarKit/Sources/KansolendarStorage/VaultDatabaseLocation.swift).
