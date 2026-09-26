import Foundation
import KansolendarCore
@testable import KansolendarStorage
import Testing

@Suite("Encrypted payload domain codec")
struct VaultPayloadCodecTests {
    private let calendarID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
    private let eventID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test("calendar preserves validated local settings")
    func calendarRoundTrips() throws {
        let calendar = try LocalCalendar(
            id: calendarID,
            name: "Personal",
            color: .purple,
            sortOrder: 4,
            defaultTimeZone: TimeZoneID("Europe/Madrid")
        )

        let decoded = try VaultPayloadCodec.decodeCalendar(VaultPayloadCodec.encode(calendar), id: calendar.id)

        #expect(decoded == calendar)
    }

    @Test("UTC event and recurrence preserve domain values")
    func utcEventAndRecurrenceRoundTrip() throws {
        let time = EventTime.utc(try TimedEventTime(start: Instant(unixSeconds: -1_234), durationSeconds: 3_600))
        let event = try Event(
            id: eventID,
            calendarID: calendarID,
            uid: "local-event-uid",
            title: "Private meeting",
            notes: "Synthetic note",
            location: "Room 4",
            time: time,
            revision: 7
        )
        let rule = try RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [.wednesday, .friday], end: .count(8))

        let decoded = try VaultPayloadCodec.decodeEvent(
            VaultPayloadCodec.encode(event, recurrence: rule),
            id: event.id,
            calendarID: event.calendarID
        )

        #expect(decoded.event == event)
        #expect(decoded.recurrence == rule)
    }

    @Test("all-day and zoned values preserve their time semantics")
    func nonUTCEventTimesRoundTrip() throws {
        let startDate = try CivilDate(year: 2026, month: 12, day: 31)
        let allDay = EventTime.allDay(try AllDayEventTime(
            start: startDate,
            endExclusive: startDate.adding(days: 1)
        ))
        let allDayEvent = try Event(id: eventID, calendarID: calendarID, title: "Year end", time: allDay)
        let allDayDecoded = try VaultPayloadCodec.decodeEvent(
            VaultPayloadCodec.encode(allDayEvent), id: eventID, calendarID: calendarID
        )
        #expect(allDayDecoded.event == allDayEvent)

        let local = try LocalDateTime(date: CivilDate(year: 2026, month: 10, day: 25), hour: 2, minute: 30)
        let zone = try TimeZoneID("Europe/Madrid")
        let zonedTime = EventTime.zoned(try ZonedEventTime(
            localStart: local,
            timeZone: zone,
            repeatedTime: .first,
            durationSeconds: 1_800,
            resolver: FoundationLocalTimeResolver()
        ))
        let zonedEvent = try Event(id: UUID(), calendarID: calendarID, title: "DST fold", time: zonedTime)
        let zonedDecoded = try VaultPayloadCodec.decodeEvent(
            VaultPayloadCodec.encode(zonedEvent), id: zonedEvent.id, calendarID: calendarID
        )
        #expect(zonedDecoded.event == zonedEvent)
    }

    @Test("unknown payload version and invalid bytes fail closed")
    func rejectsUnknownOrMalformedPayload() throws {
        let event = try Event(
            id: eventID,
            calendarID: calendarID,
            title: "Version fixture",
            time: .utc(try TimedEventTime(start: Instant(unixSeconds: 0), durationSeconds: 60))
        )
        let encoded = try VaultPayloadCodec.encode(event)
        let json = try #require(String(data: encoded, encoding: .utf8))
        let changedVersion = Data(json.replacingOccurrences(of: "\"version\":1", with: "\"version\":2").utf8)

        #expect(throws: VaultPayloadCodecError.unsupportedVersion(2)) {
            _ = try VaultPayloadCodec.decodeEvent(changedVersion, id: eventID, calendarID: calendarID)
        }
        #expect(throws: VaultPayloadCodecError.invalidPayload) {
            _ = try VaultPayloadCodec.decodeEvent(Data("not json".utf8), id: eventID, calendarID: calendarID)
        }
    }
}
