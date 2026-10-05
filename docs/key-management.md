# Key management

## Portable vaults

Each newly created `.kanso` vault has a random 256-bit data-encryption key (DEK).
A user-chosen password derives a wrapping key using PBKDF2-HMAC-SHA256 with a
random 16-byte salt and 600,000 iterations. AES-GCM wraps the DEK; authenticated
context binds it to the vault ID and key ID. The record lives inside the document,
so no Keychain item or key sidecar is needed to reopen a portable vault.

Password validation requires at least 15 Unicode scalars, no control characters,
and at most 1,024 UTF-8 bytes. Creation and portable restoration require password
confirmation in the app. The plaintext password and derived key are not written
to the vault.

Apple Passwords saving is manual: the app can copy the password and open Passwords
(or System Settings when Passwords is unavailable). Touch ID protects retrieval
there; it does not directly unlock the `.kanso` document in Kansolendar. Clipboard
contents are not automatically cleared.

## Local Application Support vault

The separate local vault generates a random DEK and stores it as a generic
password in the Data Protection Keychain. Source attributes include
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `userPresence`, no synchronization,
and the app's Keychain group. A local authentication context requests access;
Touch ID is one system mechanism, not a separate key derivation algorithm.

Missing keys do not silently trigger replacement keys. Changes to app signing
identity or access groups require integration verification. This local backend
is separate from portable files and is not automatically migrated.

## Sessions and recovery

The storage actor retains a key only in its unlocked session; locking replaces
the generation token and drops the session key reference. UI session identifiers
separately reject obsolete presentation results. Clearing references does not
promise physical zeroization of every Swift memory copy.

A recovery kit contains the DEK in Base64, which is not encryption. Anyone with
that kit and a matching vault/backup can access the data. Store it separately.
For recovery without a working document password, create a new empty destination
vault and follow [backup restoration](backups.md). There is no general password
change/reset UI for an existing locked portable file.

Source: [password wrapper](../Packages/KansolendarKit/Sources/KansolendarStorage/PasswordKeyWrapper.swift),
[Keychain adapter](../Packages/KansolendarKit/Sources/KansolendarStorage/KeychainVaultKeyStore.swift),
and [key session](../Packages/KansolendarKit/Sources/KansolendarStorage/VaultKeySession.swift).
