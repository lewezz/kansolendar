import Foundation
import KansolendarCore
import Testing

@Suite("Event search")
struct EventSearchTests {
    @Test("matches normalized title, calendar and half-open time ranges")
    func filtersEvents() throws {
        let selectedCalendar = UUID()
        let otherCalendar = UUID()
        let day = try CivilDate(year: 2026, month: 5, day: 10)
        let previous = try Event(
            id: UUID(),
            calendarID: selectedCalendar,
            title: "Café planning",
            time: .allDay(try AllDayEventTime(start: day.adding(days: -1), endExclusive: day.adding(days: 1)))
        )
        let next = try Event(
            id: UUID(),
            calendarID: selectedCalendar,
            title: "Cafe follow-up",
            time: .allDay(try AllDayEventTime(start: day.adding(days: 1), endExclusive: day.adding(days: 2)))
        )
        let other = try Event(
            calendarID: otherCalendar,
            title: "Café elsewhere",
            time: .allDay(try AllDayEventTime(start: day, endExclusive: day.adding(days: 1)))
        )
        let query = EventSearchQuery(
            text: "cafe",
            calendarIDs: [selectedCalendar],
            timeRange: .civil(try CivilDateRange(start: day, endExclusive: day.adding(days: 1)))
        )

        let result = EventSearch.matching([next, other, previous], query: query)
        #expect(result.map(\.id) == [previous.id])
    }

    @Test("matches timed events that began before the query and rejects endpoint-only overlap")
    func timedOverlap() throws {
        let calendarID = UUID()
        let crossing = try Event(
            calendarID: calendarID,
            title: "Crossing",
            time: .utc(try TimedEventTime(start: Instant(unixSeconds: 50), durationSeconds: 100))
        )
        let endingAtBoundary = try Event(
            calendarID: calendarID,
            title: "Ended",
            time: .utc(try TimedEventTime(start: Instant(unixSeconds: 0), durationSeconds: 100))
        )
        let query = EventSearchQuery(
            timeRange: .instant(try InstantRange(start: Instant(unixSeconds: 100), endExclusive: Instant(unixSeconds: 200)))
        )
        #expect(EventSearch.matching([endingAtBoundary, crossing], query: query).map(\.id) == [crossing.id])
    }
}
