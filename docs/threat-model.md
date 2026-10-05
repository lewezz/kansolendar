# Threat model

## Protected assets

Calendar titles, notes, locations, times, IDs, relationships, recurrence and cancellations reside inside authenticated whole-document ciphertext. A random data key is wrapped with the document's own password, independently of the origin Mac. Public filenames/properties and bounded cryptographic parameters remain visible.

Copied files permit offline guessing. PBKDF2 is platform-provided but not memory-hard; strong unique phrases matter. Password loss is irreversible. Tampering, truncation, parameter substitution and domain inconsistencies are rejected. Valid prior documents can still be replayed: there is no anti-rollback mechanism.

## Persistence and process state

Private encrypted staging and coordinated atomic replacement publish complete candidate state after saving. Local writer leases and saved-content hashes protect cooperative edits, not hostile/distributed writers or cloud conflicts. Staging is fsynced and directory metadata is synced when access permits; ordinary process interruption is not proof of abrupt power-loss durability.

Decrypted memory, visible screens and explicitly copied passwords are outside at-rest protection. Newly chosen passwords start hidden, but hiding them does not remove them from the unlocked process. Lock on close, screen lock, sleep and idle clears references and prevents stale UI publication; Swift does not guarantee physical zeroization.

## Reduced interfaces and application identity

The current format is the only accepted document. No older storage reader, conversion path, external calendar interchange or key-bearing reset capability remains. Removing those paths reduces dependencies and parsers while retaining validation of current files.

No network service, telemetry or synchronization exists. Ad hoc signing lacks Apple-verified publisher identity; trusted download/first-open handling remains important. Current absence of signing expiration is not a future OS compatibility guarantee. See [testing](testing.md) for verification limits.
