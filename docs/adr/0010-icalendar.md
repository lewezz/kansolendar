# ADR-0010: Limited iCalendar import and export

Documentation updated: 2026-10-05.

## Context

Interchange is useful, but a full calendar protocol introduces unsupported semantics and parser complexity.

## Decision reflected in the current source

Use a bounded native codec for VEVENT all-day and UTC inputs and corresponding plaintext exports. Reject unsupported semantics and duplicate properties; commit imports atomically.

## History and superseded assumptions

The owner deferred import in the original 2026-09-25 scope. Later implementation includes a limited importer and UI panels, so export-only wording no longer describes the current source. This record preserves that change rather than treating broad interoperability as complete.

## Consequences

Recurrence, TZID/floating input, alarms, attachments, and attendee semantics are unsupported. Zoned output becomes UTC; .ics is not an encrypted backup. See [iCalendar](../icalendar.md).

## Status

Limited import/export implemented in source. Current verification limits are tracked in [testing](../testing.md).
