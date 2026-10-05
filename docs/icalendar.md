# iCalendar interchange

The app implements both import and export through file panels. The original
export-only proposal is superseded by this limited codec. `.ics` is plaintext
interchange, not the encrypted backup format. Finder association is registered
for `.kanso` only.

## Supported profile

| Item | Behavior |
| --- | --- |
| Container | VCALENDAR, VERSION:2.0, optional recognized PRODID/CALSCALE metadata |
| Component | VEVENT only |
| Identity and details | UID, SUMMARY, DESCRIPTION, LOCATION, optional DTSTAMP |
| All-day time | DTSTART/DTEND with VALUE=DATE and exclusive end |
| Timed input | UTC DTSTART/DTEND ending in Z |
| Timed output | UTC, including conversion of zoned events to resolved instants |
| Text | Escaping and UTF-8 line folding/unfolding |

The importer rejects properties outside its allowlist, unsupported component
structures, duplicate event properties, missing required fields, floating/local
TZID times, recurrence properties, alarms, attachments, and attendee/organizer
semantics. It does not silently accept a general calendar file and drop unknown
event semantics. The profile is deliberately narrower than full iCalendar.

Export includes the selected calendar's events and refuses stored recurrence or
cancellation data instead of flattening it. It writes VERSION, PRODID, CALSCALE,
UID, SUMMARY, supported details, and explicit start/end. The current exporter uses
a fixed epoch DTSTAMP; it has no persisted event audit timestamps. Zoned events
lose original zone presentation on interchange because output times are UTC.

## Limits and atomic import

ICalendarCodec accepts at most 10 MiB and 10,000 events. Each unfolded line is
limited to 256 KiB and an event to 512 properties. Domain text limits also apply.
Output lines fold at 75 UTF-8 bytes with a continuation prefix.

Select a destination calendar and use **Import → Import Events into Selected
Calendar…**. The whole file is decoded and validated first. Storage rejects UID
collisions within the destination calendar and commits the batch in one
transaction. A failure does not intentionally commit a partial import. UIDs can
exist in different calendars.

Use **Export → Export Selected Calendar…** to create a new plaintext file. Existing
destinations are refused. There is no EventKit dependency, URL fetch, subscription,
full RRULE parser, VTIMEZONE expansion, or automatic external-calendar opening.

Source: [ICalendarCodec](../Packages/KansolendarKit/Sources/KansolendarCore/Interchange/ICalendarCodec.swift)
and [vault boundary](../Packages/KansolendarKit/Sources/KansolendarStorage/KansolendarVault.swift).
See [testing](testing.md) for coverage and current verification limits.
