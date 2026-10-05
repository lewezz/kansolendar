# Product overview

Kansolendar is a native macOS calendar with local encrypted storage. It has one
SwiftUI app target and a local package containing domain and storage modules.
There is no backend, user account, telemetry service, or network-based calendar
operation.

The main document format is `.kanso`: a named, independently password-protected
vault saved wherever the user chooses. Each file can hold multiple calendars.
The pre-existing local Application Support vault is separate and uses macOS
Keychain. Password saving in Apple Passwords is a manual convenience offered by
the app, not direct integration.

The source includes four calendar views, calendar/event operations, title search,
appearance settings, encrypted backups, recovery kits, and limited `.ics`
import/export. Recurrence exists in Core and Storage but has no complete editor.

Calendar payloads are encrypted; SQLite metadata remains visible. Recovery kits
contain the data key, and `.ics` exports are plaintext. These distinctions are
explained in [security](security.md).

Project configuration targets Apple Silicon and macOS 14 or later. Recent code
refactors have had static checks only. Finder document routing, multi-window
behavior, signed-app integration, and restore/lock interactions remain pending
verification. A GitHub distribution channel is requested, but a distributable
release workflow is not established. See [testing](testing.md) and
[distribution](distribution.md).
