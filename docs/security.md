# Security design and limits

## Payload protection

Kansolendar seals versioned calendar/event/control/exception payloads with
CryptoKit AES-256-GCM before binding them to SQLite. Each vault has a random
256-bit data key. Sealing uses a fresh GCM nonce. The envelope format is:

```text
KNSL magic[4] | version[1] | nonce[12] | ciphertext[n] | tag[16]
```

Plaintext payloads are bounded to 131,072 bytes. Authenticated context includes a
format domain/version, vault ID, key ID, record kind, record ID, and optional parent
ID. This prevents a valid ciphertext from being reassigned to another row/parent
without authentication failure. Opening checks format and bounds before returning
plaintext; payload decoding then validates the domain model.

## Key custody

Portable `.kanso` files embed a password-wrapped random key. The current wrapper
uses PBKDF2-HMAC-SHA256, a random 16-byte salt, 600,000 iterations, and AES-GCM
bound to vault/key identity. The version and fixed work factor are validated before
KDF work. PBKDF2 is not memory-hard, so a long unique password matters against
someone holding a copied document.

The separate local vault uses a device-local, non-synchronizing Keychain item
with user-presence access control. Passwords are not persisted by Kansolendar.
The app offers manual Apple Passwords saving; it does not provide passkeys or
native credential AutoFill. See [key management](key-management.md).

## Exposure that remains

SQLite headers, schema, random IDs, relationships, counts, and lengths remain
visible. Per-row authentication does not prove the existence of every expected
row, detect all deletion, or establish freshness against replay of an older valid
copy. No authenticated manifest or external anti-rollback state is implemented.

Recovery kits contain the actual key in Base64. `.ics` exports are plaintext.
Unlocked application memory, clipboard copies, screen/accessibility access, and
user-selected cloud-backed directories are outside encrypted-at-rest guarantees.
A compromised account or operating system can access an unlocked process.

## Defensive boundaries

File readers check the opened descriptor and stream within bounds. Private writes
use owner-only permissions, exclusive creation, interrupted/partial-write handling,
and synchronization. The sandbox has no app network entitlement. Storage session
generations and UI presentation tokens serve separate purposes; neither turns
Swift modules into process isolation or guarantees physical memory zeroization.

Manual lock and portable close handling exist; automatic idle/background/sleep
locking is absent. Signed-app behavior, Finder/document routing, restore/lock
interleavings, and the latest refactors need runtime verification. See
[threat model](threat-model.md), [testing](testing.md), and [open work](open-questions.md).

Source: [PayloadEnvelope](../Packages/KansolendarKit/Sources/KansolendarStorage/PayloadEnvelope.swift)
and [PasswordKeyWrapper](../Packages/KansolendarKit/Sources/KansolendarStorage/PasswordKeyWrapper.swift).
