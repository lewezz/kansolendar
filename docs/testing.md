# Testing and verification status

## Current evidence

Core and Storage have Swift Testing suites in the local package. Earlier work
records package runs and signed local-Keychain checks. Those historical results
are not an attestation for the latest refactored working tree.

The recent code refactors used source/control-flow inspection, project/plist
parsing, Xcode source-registration checks, and whitespace checks. This documentation
revision uses local-link, language, source-reference, and consistency checks only.
No application build, package test run, or app launch was performed during these
revision passes, following the user's instruction against additional builds.

## Existing package coverage

| Area | Suites and cases present in source |
| --- | --- |
| Domain | Date/range validation, event/calendar limits, recurrence, search, month grids |
| Interchange | Supported `.ics` round trips, unsupported input, size bounds |
| Cryptography | Envelope authentication/context, payload codecs, password wrapping, session generation |
| Key custody | Keychain query/access-control shape and typed errors |
| Persistence | Schema, encrypted CRUD, UID collisions, recurrence cancellations, corruption |
| Files and recovery | Permissions, snapshots, matching/mismatched kits, restoration, refused overwrites |
| Portable documents | Separate keys/passwords, copy/move reopen, wrong passwords, portable restore |

Tests use synthetic values and isolated storage/key-store fixtures. Their presence
is not a claim that every OS integration or recent regression has been tested.
No app UI-test or signed integration-test target is currently declared in the
Xcode project.

## Verification still needed

When requested, compile the current app and run the relevant package suites.
The package command is `swift test --package-path Packages/KansolendarKit` using
the selected Xcode toolchain; this command is documented, not executed here.

Then verify create/open/wrong-password/lock/reopen, Finder file routing, multiple
documents, close during authentication/loading/restore, security-scoped access,
local Keychain behavior, recovery into a new empty document, rollback preservation,
and refusal to overwrite an existing destination. Use disposable vaults rather
than an existing personal store.

Calendar boundaries, non-Gregorian system calendars, DST editor behavior,
recurrence editing, and resource use also need focused coverage. Packaging and
fresh-Mac launch checks belong to the concrete distribution artifact, not merely
a source project or development launch.

See [open work](open-questions.md), [distribution](distribution.md), and
[code structure](code-structure.md).
