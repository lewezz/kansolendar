# Architecture

## Implemented boundaries

Kansolendar is one native macOS application with a local Swift package. Its
dependency direction is:

```text
Kansolendar app (SwiftUI, AppKit, MainActor presentation)
    -> KansolendarStorage (vault API, SQLite, CryptoKit, Keychain, file I/O)
        -> KansolendarCore (validated domain values, recurrence, search, iCalendar)
    -> KansolendarCore
```

Core depends on Foundation, not UI or persistence frameworks. Storage links
system SQLite through the local CSQLite shim. The package has no remote
dependencies, ORM, SwiftData, generic dependency container, backend, or global
message bus. Services/repository responsibilities are expressed by focused vault
methods rather than separate framework targets or speculative interfaces.

See [code structure](code-structure.md) for the actual file map.

## Presentation

KansolendarApp declares the local window group, portable document window group,
and settings scene. RootView presents the vault gate or CalendarWorkspaceView.
Each root owns a MainActor observable VaultViewModel. Editor sheets hold local
form drafts; EventDateAdapter handles Foundation/domain conversions;
VaultError's app extension supplies messages; AppTheme owns shared preferences.

Day/week/month/year views share selected date, calendar filtering, and title
search. Current search and presentation operate on decrypted arrays in memory;
there is no persistent search index or materialized occurrence table.

## Persistence and keys

KansolendarVault is the public actor boundary used by the app. It exposes domain
values and safe error categories. SQLiteVaultDatabase owns the connection,
metadata, encrypted-record operations, and key session. SQLiteConnection owns
the C handle and synchronous transaction/backup primitives.

Portable files use an embedded password wrapper. The local Application Support
vault uses Keychain. These are explicit modes, not automatic migrations or
alternate application targets. PrivateFileIO owns descriptor checks and output
rules; RecoveryKitFileWriter preserves its error contract while sharing writes.

## Lifecycle and asynchronous work

Opening a portable document acquires security-scoped URL access before creating
the vault actor. Manual lock clears UI state and invalidates key-session access.
Closing a portable document detaches its model's vault, clears fields/lists, and
balances its captured file-access claim after requesting storage lock.

UI session IDs reject obsolete create/unlock/password-restore presentation.
Load IDs ensure calendars and events publish together and reject results after a
lock, close, or newer load. These tokens are separate from storage key-generation
checks. They do not cancel disk operations or guarantee all restore/lock
interleavings; that behavior still needs integration verification.

No background/sleep/idle/session-change automatic-lock observers are implemented.
closeDocument is portable-only. Do not infer the original proposal's five-minute
timeout or universal window-close policy from the current code.

## Transaction rules

SQLite work is synchronous inside its actor. withImmediateTransaction is a
non-nested, non-suspending BEGIN IMMEDIATE/COMMIT/ROLLBACK helper. Business
operations decide the atomic group: event plus cancellations, imported batch,
calendar deletion, schema changes, or metadata plus password wrapper.

Authentication, file selection, and asynchronous backup validation occur outside
SQL transactions. Actor isolation does not make SQLite nonblocking or eliminate
logical races across await. No dedicated SQLite executor or optimistic SQL
revision comparison is implemented; Event.revision is a persisted domain value,
not a complete conflict-detection protocol.

## Verification

This structure is present in source. The latest refactor has static checks only.
See [testing](testing.md) for outstanding compile, signed-app, and lifecycle work;
[decision records](adr/README.md) preserve earlier choices without presenting
superseded proposals as current guarantees.
