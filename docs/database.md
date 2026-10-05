# Persistence formats

## Current `.kanso` container

The current encrypted document framing is:

```text
KANSO\0\x03\0 magic[8] | header_length_be[4] | header_json | GCM_nonce[12] | ciphertext | tag[16]
```

The bounded public header contains random cryptographic context IDs and the
password-wrapped data key (version, KDF iterations, salt, sealed key). It contains
no calendar IDs, relationships, names or inventory. The exact magic, length and
serialized header are authenticated as GCM associated data.

The encrypted document codec version 1 stores its document ID, calendars and
events, with IDs, parent relationships and recurrence cancellations. Existing
validated payload codecs enforce domain values after decryption. Duplicate IDs,
orphaned events, per-calendar duplicate UIDs and invalid cancellations are refused.

Limits: 64 MiB encoded plaintext; at most 1,000 calendars and 100,000 events;
header at most 4,096 bytes. File framing bounds are checked before decryption,
and fixed KDF parameters prevent untrusted files requesting arbitrary work.

## Persistence ownership

One storage actor owns one decrypted document and key session. Mutation prepares
a candidate, validates and encrypts it, stages encrypted bytes with owner-only
permissions, then replaces the file atomically under NSFileCoordinator. Candidate
state publishes only after save succeeds. Failures that might leave ambiguous
persistence lock storage instead of presenting a stale editable document.

A stable per-path lock lives in Application Support inside the app container;
its hash-based marker has no plaintext path or key. It survives inode replacement
and excludes cooperative local editors. A saved-content digest refuses external
changes. It is not cross-machine coordination or an authenticated freshness log.
Foundation's replacement directory avoids assuming permission to arbitrary sibling
files. Parent metadata is fsynced when accessible; sandboxed save behavior needs
real file-panel verification.
