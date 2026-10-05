# Open work and implementation limits

This replaces the initial proposal's question register. Resolved source choices
live in current guides and [ADRs](adr/README.md); the table below lists work that
remains relevant to the current application.

| Area | Current state | Remaining work |
| --- | --- | --- |
| Latest source verification | Static checks only for recent refactors | Compile, run relevant package suites, and verify OS integration when requested |
| Portable document routing | UTI, Finder URL routing, panels, and windows exist | Validate Finder opening, repeated opens, copies, multiple windows, and close behavior |
| Keychain identity | Local vault uses device-only user-presence items and a development bundle identity | Verify signed access and upgrade continuity for the eventual artifact |
| Automatic locking | Manual lock and portable-close hooks exist | Define and implement background/sleep/idle/session policy; local close semantics need review |
| Restore and locking | Staging, validation, safety copy, rollback, and UI result guards exist | Verify storage-level interleaving and failure paths; UI tokens do not cancel disk work |
| Calendar extremes | CivilDate supports years 1–9999 | Remove UI try! assumptions for unrepresentable padded grids |
| Recurrence UI | Rules/cancellations exist in Core/Storage; no complete editor | Preserve series semantics on editing and choose occurrence-versus-series operations |
| Time-zone editor | Uses system zone and first repeated DST choice | Validate non-Gregorian settings, DST selection, and editing of stored zoned values |
| Revision conflicts | Event revision is stored | Decide conflict handling before promising concurrent editing or optimistic writes |
| File format evolution | Local schema 1, portable schema 2, payload/wrapper version 1 | Design explicit future migrations and password-change workflow if required |
| Metadata and replay | Payloads authenticated; structure/freshness not hidden | Preserve the documented limit; do not claim tamper-proof or rollback-proof files |
| Distribution | One development-signed app; GitHub requested | Establish packaging/identity/update delivery and test the resulting artifact |

Full iCalendar support, notifications, attachments, attendees, widgets, EventKit,
cloud sync, telemetry, and automatic updates are outside current implementation.
They have no committed delivery date. This documentation does not authorize
builds, publication, or unrelated feature implementation.
