# ADR-0014: Password-only whole-document calendar vaults

Recorded: 2026-10-05. User-approved scope; implementation verification ongoing.

## Decision

Use independent named/location-selected `.kanso` files with all internal content
and metadata encrypted. Open/create chooser replaces automatic local-vault login.
Passwords remain portable; Touch ID is deferred, and no reset service
exists. Platform AES-GCM and the existing bounded PBKDF2 wrapper are reused rather
than a home-grown KDF. PBKDF2 is not memory-hard and requires strong passphrases.

Ad hoc signing without profiles avoids timed development provisioning, with one
arm64/macOS14+ app distributed through GitHub. No paid membership, synchronization
or collection is introduced. macOS first-open authorization is documented.

## Consequences

Only the current document format is supported; no conversion interface exists.
Close/system/idle locking clears sessions; idle defaults to five minutes with
1,2,3,4,5,10,15,30 choices. Recent history is optional and initially disabled.
Filesystem properties remain visible; valid-file rollback, compromised systems,
clipboard/screen exposure and future OS policy remain outside encryption guarantees.

See [testing](../testing.md) for acceptance still awaiting platform verification.
