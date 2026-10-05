# Current feature scope

This page records source-level implementation, not a verified release checklist.
See [testing status](testing.md) for what remains unverified.

## Implemented in source

| Area | Behavior |
| --- | --- |
| Vaults | Create/open independent `.kanso` files; user-selected name, location, and password |
| Windows | Separate portable document windows and view models |
| Local store | Separate Application Support vault using Keychain |
| Calendar UI | Day, week, month, year, selected date, calendar filter, title search |
| Calendar operations | Create and delete calendars with colors |
| Event operations | Create, edit, delete, and move non-recurring events |
| Event details | All-day/timed values, notes, location |
| Appearance | System/light/dark preferences and accent selection |
| Recovery | Encrypted snapshots, explicit recovery kits, validated restore and rollback attempt |
| Interchange | Bounded import/export of supported all-day and UTC `.ics` events |
| Locking | Manual lock and portable-document close hooks |

## Partial or pending

Core/Storage can represent recurring series and cancellations, but a rule editor
and safe occurrence-versus-series edits are absent. Automatic locking on idle,
backgrounding, sleep, and session changes is absent. Finder/multiple-window flows
and the latest refactors need build and runtime validation.

## Outside current scope

Accounts, backend services, calendar synchronization, analytics, EventKit,
notifications, reminders, attendees, attachments, widgets, full `.ics` coverage,
and an automatic updater are not implemented. Intel/Universal builds are not
configured. Distribution packaging remains separate work.
