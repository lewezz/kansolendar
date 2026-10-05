# Code structure and maintenance

See the [documentation index](README.md) and [architecture](architecture.md) for
current product and module context.

Kansolendar has three dependency boundaries. The SwiftUI app owns windows, forms,
macOS panels, and presentation state. `KansolendarStorage` owns encrypted persistence
and key sessions. `KansolendarCore` owns validated calendar/event values and temporal
rules. Core has no dependency on SwiftUI, SQLite, or Keychain.

## Where changes belong

| Concern | Owner |
| --- | --- |
| Scenes, document windows, settings entry point | `Kansolendar/App/KansolendarApp.swift` |
| Shared appearance preferences and accent environment | `Kansolendar/App/AppTheme.swift` |
| Vault gate and password presentation | `Kansolendar/App/RootView.swift` |
| One window's vault state and user operations | `Kansolendar/App/VaultViewModel.swift` |
| Calendar navigation and workspace actions | `Kansolendar/App/CalendarWorkspaceView.swift` |
| Calendar/event drafts and editor controls | `Kansolendar/App/CalendarEditors.swift` |
| Foundation Date to domain EventTime conversion | `Kansolendar/App/EventDateAdapter.swift` |
| Safe storage error text for the user | `Kansolendar/App/VaultError+Presentation.swift` |
| Validated dates, events, recurrence, and iCalendar rules | `Packages/KansolendarKit/Sources/KansolendarCore` |
| Public vault operations and error mapping | `KansolendarStorage/KansolendarVault.swift` |
| Storage orchestration, encrypted records, and schema | `KansolendarStorage/SQLiteVaultDatabase.swift` |
| SQLite C handle, configuration, backups, and transactions | `KansolendarStorage/SQLiteConnection.swift` |
| Bounded file reads, private writes, and streamed copies | `KansolendarStorage/PrivateFileIO.swift` |
| Password-wrapped key format and derivation | `KansolendarStorage/PasswordKeyWrapper.swift` |
| Authenticated record envelopes and in-memory key generation | `KansolendarStorage/PayloadEnvelope.swift`, `VaultKeySession.swift` |
| Recovery-kit format and its error contract | `KansolendarStorage/RecoveryKit.swift` |

Storage paths in the table are relative to
`Packages/KansolendarKit/Sources`. New package source files are discovered by
SwiftPM. New app source files must also be registered in the Xcode project's file
references, App group, and Sources build phase.

## Invariants worth preserving

Each document window owns its own view model and vault actor. The model acquires
security-scoped access before opening a portable file and balances that access
when closing. Password fields and decrypted arrays are cleared when the session
is hidden. UI session/load identifiers reject obsolete asynchronous results;
these identifiers are separate from the storage actor's cryptographic key-session
generation. They protect presentation state and do not cancel disk operations.

Calendar and event lists are published only after both reads succeed. A lock,
close, or newer load invalidates a suspended read. Editors retain local drafts
until a successful save. All-day end dates are exclusive; timed events keep their
explicit time-zone identity and resolved instant. Date conversion and the
repeated-DST-time policy belong in EventDateAdapter, not in views or SQLite code.

SQLiteConnection belongs to one storage actor. Immediate transaction bodies are
synchronous and cannot nest; no `await` belongs inside them. Business operations
choose what is atomic, while the connection helper owns BEGIN/COMMIT/ROLLBACK.
In-memory success state is updated after commit. File cleanup is installed only
after reserving a new destination, so a refused overwrite preserves the old file.

Private file readers validate the opened descriptor, reject non-regular files and
symlinks, and enforce size limits while streaming. Writers handle partial writes,
retry interrupted calls, use owner-only permissions, synchronize successful output,
and remove incomplete output. RecoveryKitFileWriter delegates to that writer and
maps errors back to the recovery API's existing error type.

Passwords wrap randomly generated encryption keys; they do not replace those keys.
Wrapper sizes, KDF settings, and AAD identity fields are format contracts. Changing
one requires an explicit format/version strategy. Comments at those boundaries
explain why the checks exist so future refactors do not remove them as duplication.

## Verification status

The maintainability pass used source/reference inspection, plist/project parsing,
and whitespace consistency checks. No app build, package tests, or app launch was
performed because the user prohibited additional builds unless requested. Swift
type checking and runtime behavior still need verification when requested,
particularly lock/close during authentication or restore and preservation of an
existing backup destination.
