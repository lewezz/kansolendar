# Threat model

This model describes implemented defenses and current limitations, not a claim
that the current working tree is independently audited or release-verified.

## Assets and trust boundaries

Assets include calendar/event details, passwords, random data keys, recovery kits,
and the integrity/availability of vault files. Boundaries include untrusted file
input, the sandbox's user-selected file access, local Keychain authentication,
password wrapping, storage actor isolation, and decrypted presentation state.

The app process and its modules share memory. The operating system, signed-app
identity, system crypto/SQLite implementations, and account security are trusted
by the design. There is no server trust boundary because no backend exists.

## Threats and current defenses

| Threat | Implemented defense | Remaining limit |
| --- | --- | --- |
| Copy a vault without its key | Authenticated payload encryption and portable password wrapping | Metadata remains visible; passwords can be guessed offline |
| Swap ciphertext between records/vaults | AAD binds vault/key/kind/record/parent identities | Does not authenticate the whole row set |
| Corrupt authenticated content | Envelope/domain validation fails closed | Availability can still be destroyed |
| Delete rows or replay an old valid file | Structural checks and backups help recovery | No authenticated inventory or freshness proof |
| Read a local Keychain key without presence | Device-local user-presence item and typed access errors | App identity and signed integration must be verified |
| Malformed `.ics`, kit, or backup | Format limits, descriptor checks, bounded parsing/staging, prevalidation | Runtime/resource behavior still needs targeted checks |
| Overwrite an existing output | Exclusive file creation; snapshot cleanup installed after reservation | Does not coordinate arbitrary external filesystem mutation |
| Late UI update after lock/close | Content/session IDs reject obsolete presentation results | Tokens do not cancel storage operations |
| Compromise unlocked process/account | Sandbox reduces access scope | No defense against privileged memory/screen access |
| Obtain recovery kit plus data | Explicit kit export and separate storage guidance | Possession of both permits decryption |

## Privacy side channels

Document names, file paths selected by the user, SQLite structure and sizes,
plaintext exports, clipboard copies, and OS-managed file/screen history may expose
information outside payload encryption. Cloud-backed folders can synchronize
files through other software. The app does not control the Mac's other processes
or network services.

## Current review priorities

Validate signed/sandbox file access and local Keychain behavior for the eventual
artifact, Finder/multi-window isolation, restore/lock interleavings and rollback,
and calendar-boundary traps. Automatic idle/background/sleep locking and safe
recurrence editing are not implemented. No independent review or latest-tree
build/test result is asserted by this documentation.

See [security](security.md), [privacy](privacy.md), [backups](backups.md), and
[testing](testing.md). Adding network services, wider permissions, or a changed
key format would require updating these boundaries and product scope.
