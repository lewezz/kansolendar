# Architecture

SwiftUI views render one window-owned VaultViewModel. The view model coordinates password presentation, domain CRUD and lifecycle invalidation. KansolendarCore owns validated calendar/event/time/recurrence values. KansolendarStorage exposes the password-only KansolendarVault actor and current-format whole-document persistence.

PortableVaultDatabase serializes candidate state, encrypts it, coordinates an atomic save, then publishes the committed snapshot. KansoFileLease supplies stable writer ownership and detects external changes. KansoDocumentCodec reuses validated domain payloads inside the encrypted inventory; KansoFileEnvelope authenticates the entire framing and content. PasswordKeyWrapper uses native PBKDF2 and AES-GCM.

There is one supported file format, one app target, no fixed local store, and no external calendar interchange or legacy compatibility layer. Close/lock clear storage and presentation references. Session/load generations prevent suspended operations from restoring private UI. Settings and opt-in bookmark history remain outside the document. See [security](security.md) and [testing](testing.md).
