# Calendar domain model

Core defines validated, Sendable values independently of UI, storage, and keys.
Storage serializes versioned payloads; row IDs and parent relationships are
supplied separately during decoding.

## Main values

| Value | Current fields and role |
| --- | --- |
| LocalCalendar | UUID, name, color, sort order, default time zone |
| Event | UUID, calendar UUID, opaque iCalendar UID, title, notes, location, time, revision |
| VaultEvent | Event plus optional recurrence rule and occurrence cancellations |
| CivilDate | Gregorian year/month/day, years 1 through 9999; no time zone |
| Instant | Integer seconds since the Unix epoch |
| LocalDateTime | Civil date plus local clock components |
| TimeZoneID | Validated system-recognized time-zone identifier |
| CivilDateRange / InstantRange | Half-open ranges with exclusive ends |

The UID is data, not a path or the SQLite primary key. Storage enforces UID
uniqueness within a calendar. Event.update increments revision, but storage does
not compare revisions to implement optimistic concurrency.

## Event time

| Variant | Meaning |
| --- | --- |
| All-day | Civil start and exclusive end date; duration counted in days |
| UTC | Start instant and positive elapsed duration |
| Zoned | Local start, time-zone ID, repeated-time choice, resolved instant, and positive elapsed duration |

Moving a non-recurring event preserves its duration and time semantics. UTC
movement preserves its UTC clock time; zoned movement preserves local clock time
and zone. EventDateAdapter owns the editor conversion policy. The current timed
editor uses the system zone and the first repeated DST time. It does not provide
a complete time-zone/ambiguity editor.

Persisted zoned payloads retain resolved times and are checked against current
system time-zone rules during decoding. A rule mismatch is surfaced instead of
silently replacing saved values. No bundled time-zone database or VTIMEZONE
snapshot is stored.

## Recurrence

Core supports daily, weekly, monthly, and yearly frequencies; intervals from 1 to
999; weekly weekday selection; and never/count/until endings. Count endings are
limited to 100,000. Cancellations identify the original occurrence start and
must match the series' event/time kind.

Expansion is bounded by the engine's default limits: a 366-day query, 100,000
candidates, and 20,000 returned occurrences. These are protective budgets, not a
promise to process arbitrary recurrence documents. Storage persists rules and
cancellations; the UI has no recurrence-rule editor and refuses drag movement of
recurring series. Safe series/occurrence editing remains open work.

## Input limits

| Field | UTF-8 maximum |
| --- | --- |
| Calendar name | 256 bytes |
| Event title | 1,024 bytes |
| Event UID | 1,024 bytes |
| Notes | 65,536 bytes |
| Location | 4,096 bytes |

Names/titles must be nonblank. Control characters are rejected, except permitted
line breaks/tabs in notes. Encoded payloads have a separate 131,072-byte bound.
No attendee, attachment, tag, reminder, creation timestamp, or modification
timestamp field is currently persisted by these domain payloads.

Supported domain-date limits do not ensure that every padded month grid is
representable at the extremes. UI try! assumptions at those limits remain a
known issue. See [open work](open-questions.md).

Source: [domain files](../Packages/KansolendarKit/Sources/KansolendarCore/Domain/Events/Event.swift),
[recurrence rules](../Packages/KansolendarKit/Sources/KansolendarCore/Domain/Recurrence/RecurrenceRule.swift),
and [payload codec](../Packages/KansolendarKit/Sources/KansolendarStorage/VaultPayloadCodec.swift).
