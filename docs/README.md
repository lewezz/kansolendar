# Kansolendar documentation

Updated: 2026-10-05. These guides describe the current working tree. Implemented
means present in source; it does not imply the latest refactors have passed
compilation or runtime tests. See [verification status](testing.md).

## Using the application

| Topic | Guide |
| --- | --- |
| Product overview and current scope | [Overview](executive-summary.md), [feature scope](mvp.md) |
| Create, open, name, and move vaults | [Portable `.kanso` vaults](kanso-vault-files.md) |
| Passwords, Apple Passwords, and the local Keychain vault | [Key management](key-management.md) |
| Encrypted backups and recovery | [Backups](backups.md) |
| Supported calendar interchange | [iCalendar](icalendar.md) |
| Data exposure and permissions | [Security](security.md), [privacy](privacy.md) |
| App target and distribution status | [Distribution](distribution.md) |

## Maintaining the application

| Topic | Guide |
| --- | --- |
| Source ownership and extension points | [Code structure](code-structure.md) |
| Module dependencies and lifecycle | [Architecture](architecture.md) |
| Calendar, event, and time semantics | [Domain model](data-model.md) |
| Schemas, encrypted records, and transactions | [Database](database.md) |
| Threat boundaries and known limitations | [Threat model](threat-model.md) |
| Error presentation and diagnostics | [Errors and logging](logging.md) |
| Existing tests and pending verification | [Testing](testing.md) |
| Remaining work and sequence | [Open work](open-questions.md), [roadmap](roadmap.md) |
| Decisions and superseded assumptions | [Architecture decision records](adr/README.md) |

The [root README](../README.md) introduces the app. The maintained
[product specification](../kansolendar.md) defines scope. ADRs record history;
current guides and source explain today's behavior. They no longer assume a
future project, a single fixed vault, or export-only iCalendar support.
