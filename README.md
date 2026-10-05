<p align="center">
  <img src="kansolendar-logo.png" alt="Kansolendar logo" width="180">
</p>

<h1 align="center">Kansolendar</h1>

<p align="center">A private, offline calendar for macOS.</p>

Kansolendar is a native SwiftUI calendar that stores your data locally. It has no
accounts, backend, analytics, or app-managed synchronization.

Create independent `.kanso` vault files, choose their names and locations, and
protect each with your own password. Each file can contain multiple calendars.
The existing Application Support vault remains available separately and uses
macOS Keychain.

## Current features

- Day, week, month, and year views, calendar filters, and title search.
- Create and delete calendars; create, edit, delete, and move events.
- All-day and timed events, notes, locations, and calendar colors.
- Independent password-protected `.kanso` documents and separate document windows.
- Encrypted backups, separate recovery kits, and validated restoration.
- Limited iCalendar import and export through file panels.
- Local appearance and accent settings.

The project targets Apple Silicon and macOS 14 or later. Its implementation uses
Swift 6, SwiftUI, Foundation, CryptoKit, CommonCrypto, Security, and system SQLite,
with a local Swift package and no remote package dependencies.

## Using vault files

Choose **Create Vault File…** or **Vault → Create New Vault File…**, select a name
and location, then enter and confirm a password of at least 15 characters. Use
**Open Vault File…** to reopen a document. Finder file association is declared in
the app, but still needs validation on the latest application build.

Kansolendar offers to copy a new password and open Apple Passwords. You add it
there manually. Touch ID can retrieve it in Passwords; Kansolendar itself asks for
the vault password. This is not a passkey or automatic Passwords integration.

Event payloads are encrypted before SQLite writes. Database structure, identifiers,
relationships, counts, and sizes remain visible. Recovery kits contain the actual
data key, and exported `.ics` files contain plaintext event details.

## Project status

The features above are present in source. The latest refactors have had static
checks only; compilation, package tests, signed-app integration, Finder opening,
and multi-window behavior have not been reverified for the current working tree.
There is one app target and one shared app scheme. No distribution package or
release workflow is currently established.

Start with the [documentation index](docs/README.md), [vault guide](docs/kanso-vault-files.md),
or [maintainer guide](docs/code-structure.md). The maintained
[product specification](kansolendar.md) records scope and current limitations.
